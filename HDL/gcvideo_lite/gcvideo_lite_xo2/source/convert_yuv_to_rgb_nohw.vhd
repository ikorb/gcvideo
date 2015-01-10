----------------------------------------------------------------------------------
-- GCVideo Lite HDL Version 1.1
-- Copyright (C) 2014-2015, Ingo Korb <ingo@akana.de>
-- All rights reserved.
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions are met:
--
-- 1. Redistributions of source code must retain the above copyright notice,
--    this list of conditions and the following disclaimer.
-- 2. Redistributions in binary form must reproduce the above copyright notice,
--    this list of conditions and the following disclaimer in the documentation
--    and/or other materials provided with the distribution.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
-- AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
-- IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
-- ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
-- LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
-- CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
-- SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
-- INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
-- CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
-- ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
-- THE POSSIBILITY OF SUCH DAMAGE.
--
-- convert_yuv_to_rgb_nohw.vhd: YCbCr to RGB conversion without multiplications
--
-- This module converts 4:4:4 YCbCr to full-range RGB using only shifts and
-- additions. The coefficients have been optimized to create a simple add/shift
-- tree without compromising accuracy too much.
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.component_defs.all;
use work.video_defs.all;

entity convert_yuv_to_rgb is
  port (
    PixelClock        : in  std_logic;
    PixelClockEnable  : in  boolean;
    PixelClockEnable2x: in  boolean;
    
    -- input video
    VideoIn           : in  VideoYCbCr;
    Limited_Range     : in  boolean;

    -- output video
    VideoOut          : out VideoRGB
  );
end convert_yuv_to_rgb;

architecture Behavioral of convert_yuv_to_rgb is
  -- delay in (enabled) clock cycles for untouched signals
  constant Delayticks: Natural := 3;

  -- Y path
  signal y_scaled5 : signed(11 downto 0);
  signal y_scaled75: signed(15 downto 0);
  signal y_shifted : signed(15 downto 0);

  -- Cb
  signal cb_buffered : signed( 7 downto 0);
  signal cb_scaled25 : signed(12 downto 0);
  signal cb_scaled129: signed(15 downto 0);
  signal cb_buffered2: signed( 7 downto 0);

  -- Cr
  signal cr_scaled51 : signed(13 downto 0);
  signal cr_buf51    : signed(13 downto 0);

  -- intermediate result for green
  signal green_temp  : signed(14 downto 0);

  -- summed components
  signal rsum: signed(16 downto 0);
  signal gsum: signed(16 downto 0);
  signal bsum: signed(16 downto 0);

  -- 8 bit unsigned to 8 bit signed, removing the 0x80 offset
  function mksigned_offset(a: unsigned(7 downto 0))
    return signed is
    variable tmp: signed(7 downto 0);
  begin
    return signed(not a(7) & a(6 downto 0));
  end function;
  
  -- 8 bit unsigned to 9 bit signed, no modifications
  function mksigned(a: unsigned(7 downto 0))
    return signed is
  begin
    return signed("0" & a);
  end function;

  -- clip value to 8 bit range
  function clip(v: signed)
    return unsigned is
  begin
    if v < 0 then
      return x"00";
    elsif v > 255 then
      return x"ff";
    else
      return resize(unsigned(v), 8);
    end if;
  end function;

begin
  -- Simplified version, supports only full-range RGB
  assert(not Limited_Range) report "The color conversion module only supports full-range RGB" severity failure;
  
  -- capture and interpolate colors
  process (PixelClock, PixelClockEnable)
    variable y_signed : signed(8 downto 0);
    variable cr_signed: signed(7 downto 0);
    variable cb_signed: signed(7 downto 0);
  begin
    if rising_edge(PixelClock) and PixelClockEnable2x then
      -- double-clocked conversion to reuse registers between adjacent stages
      if PixelClockEnable then
        -- stage 1: conversion, first scaling step
        y_signed    := mksigned(VideoIn.PixelY);
        cb_signed   := mksigned_offset(VideoIn.PixelCb);
        cr_signed   := mksigned_offset(VideoIn.PixelCr);
        y_scaled75  <= resize(y_signed, 16) + (resize(y_signed, 16) sll 2);
        cb_buffered <= cb_signed;
        cb_scaled25 <= resize(cb_signed, 13) + (resize(cb_signed, 13) sll 1);
        cr_scaled51 <= resize(cr_signed, 14) + (resize(cr_signed, 14) sll 1);

        -- stage 3: Y offset, calculate green intermediate
        -- subtract 24 for better rounding, value selected for best PSNR
        rsum     <= resize(y_scaled75, 17)   - to_signed(1224, 17); -- 1224 == (75 * -16) - 24
        gsum     <= resize(cr_scaled51, 17)  + resize(cb_scaled25, 17);
        cr_buf51 <= cr_scaled51;
        bsum     <= resize(cb_buffered, 17) + (resize(cb_buffered, 17) sll 7);

        -- stage 5: clipping
        VideoOut.PixelR <= clip(rsum / 64);
        VideoOut.PixelG <= clip(gsum / 64);
        VideoOut.PixelB <= clip(bsum / 64);
      else
        -- stage 2: continue scaling
        y_scaled75   <= (y_scaled75  sll 4) - y_scaled75;
        cb_scaled25  <= (cb_scaled25 sll 3) + resize(cb_buffered, 13);
        cr_scaled51  <= (cr_scaled51 sll 4) + cr_scaled51;

        -- stage 4: calculate RGB values
        rsum <= rsum + (resize(cr_buf51, 17) sll 1);
        gsum <= rsum - gsum;
        bsum <= rsum + bsum;

        -- stage 6: nothing to do, values are already in the output registers
      end if;
    end if;
  end process;

  -- generate delayed signals
  Inst_HSyncDelay: delayline_bool
    generic map (
      Delayticks => Delayticks
    )
    port map (
      Clock       => PixelClock,
      ClockEnable => PixelClockEnable,
      Input       => VideoIn.HSync,
      Output      => VideoOut.HSync
    );

  Inst_VSyncDelay: delayline_bool
    generic map (
      Delayticks => Delayticks
    )
    port map (
      Clock       => PixelClock,
      ClockEnable => PixelClockEnable,
      Input       => VideoIn.VSync,
      Output      => VideoOut.VSync
    );

  Inst_CSyncDelay: delayline_bool
    generic map (
      Delayticks => Delayticks
    )
    port map (
      Clock       => PixelClock,
      ClockEnable => PixelClockEnable,
      Input       => VideoIn.CSync,
      Output      => VideoOut.CSync
    );

  Inst_BlankingDelay: delayline_bool
    generic map (
      Delayticks => Delayticks
    )
    port map (
      Clock       => PixelClock,
      ClockEnable => PixelClockEnable,
      Input       => VideoIn.Blanking,
      Output      => VideoOut.Blanking
    );

  Inst_FieldDelay: delayline_bool
    generic map (
      Delayticks => Delayticks
    )
    port map (
      Clock       => PixelClock,
      ClockEnable => PixelClockEnable,
      Input       => VideoIn.IsEvenField,
      Output      => VideoOut.IsEvenField
    );

  -- copy non-delayed, non-processed signals
  VideoOut.IsProgressive <= VideoIn.IsProgressive;
  VideoOut.IsPAL         <= VideoIn.IsPAL;
  VideoOut.Is30kHz       <= VideoIn.Is30kHz;

end Behavioral;

