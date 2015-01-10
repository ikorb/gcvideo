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
-- convert_422_to_444.vhd: Interpolate 4:2:2 YCbCr to 4:4:4
--
-- This module uses linear interpolation to generate 4:4:4 YCbCr from 4:2:2 YCbCr
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.component_defs.all;
use work.video_defs.all;

entity convert_422_to_444 is
  port (
    PixelClock      : in  std_logic;
    PixelClockEnable: in  boolean;
    
    -- input video
    VideoIn         : in  VideoYCbCr;
    CurrentIsCb     : in  boolean;

    -- output video
    VideoOut        : out VideoYCbCr
  );
end convert_422_to_444;

architecture Behavioral of convert_422_to_444 is

  -- delay in (enabled) clock cycles for untouched signals
  constant Delayticks: Natural := 3;
  
  -- stored color signals
  signal current_cr: unsigned(7 downto 0) := (others => '1');
  signal current_cb: unsigned(7 downto 0) := (others => '1');
  signal prev_cr   : unsigned(7 downto 0) := (others => '1');
  signal prev_cb   : unsigned(7 downto 0) := (others => '1');

  -- averaging function
  function average(a: unsigned(7 downto 0); b: unsigned(7 downto 0))
    return unsigned is
    variable a9 : unsigned(8 downto 0);
    variable b9 : unsigned(8 downto 0);
    variable res: unsigned(8 downto 0);
  begin
    a9  := "0" & a;
    b9  := "0" & b;
    res := a9 + b9;
    
    return res(8 downto 1);
  end function;

begin
  
  -- capture and interpolate colors
  process (PixelClock, PixelClockEnable)
  begin
    if rising_edge(PixelClock) and PixelClockEnable then
      -- capture color data
      if CurrentIsCb then
        -- pixel with start of new chroma information
        current_cb <= VideoIn.PixelCb;

        prev_cr    <= current_cr;
        prev_cb    <= current_cb;

        -- output interpolated chroma info for the delayed Y value
        VideoOut.PixelCb <= average(prev_cb, current_cb);
        VideoOut.PixelCr <= average(prev_cr, current_cr);
      else
        -- pixel with the remainder of the current chroma information
        current_cr <= VideoIn.PixelCr;
        
        -- output the previous "full" chroma info to coincide with the delayed Y value
        VideoOut.PixelCr <= prev_cr;
        VideoOut.PixelCb <= prev_cb;
      end if;
    end if;
  end process;

  -- generate delayed signals
  Inst_LumaDelay: delayline_unsigned
    generic map (
      Delayticks => Delayticks,
      Width      => 8
    )
    port map (
      Clock       => PixelClock,
      ClockEnable => PixelClockEnable,
      Input       => VideoIn.PixelY,
      Output      => VideoOut.PixelY
    );

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
      Delayticks  => Delayticks
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
