----------------------------------------------------------------------------------
-- GCVideo DVI HDL
-- Copyright (C) 2014-2021, Ingo Korb <ingo@akana.de>
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
-- convert_422_to_444.vhd: Convert 4:2:2 YCbCr to 4:4:4
--
-- This module converts from 4:2:2 to 4:4:4 YCbCr with optional interpolation
--
----------------------------------------------------------------------------------

-- timing diagram:
-- * time moves downward
-- * b12/r12 is Cb/Cr for y1/y2, b34 for y3/y4 etc.
-- * when in blanking, the last color is held
-- * assumes Cb-first
-- * entries that still hold values from before the table start are left blank
--
-- Y_in CbCr IsCb|current_c1 current_c2 prev_c2 prev_c1 Y_out Cb_out       Cr_out
-- --------------+---------------------------------------------------------------------
-- y1   b12  t   |b12
-- y2   r12  f   |b12        r12
-- y3   b34  t   |b34        r12        b12     r12
-- y4   r34  f   |b34        r34        b12     r12     y1    b12          r12
-- y5   b56  t   |b56        r34        b34     r34     y2    avg(b12,b34) avg(r12,r34)
-- y6   r56  f   |b56        r56        b34     r34     y3    b34          r34


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.component_defs.all;
use work.video_defs.all;

entity convert_422_to_444 is
  port (
    PixelClock       : in  std_logic;
    PixelClockEnable : in  boolean;

    -- control
    InterpolateChroma: in  boolean;
    Output422        : in  boolean;

    -- input video
    VideoIn          : in  VideoY422;

    -- output video
    VideoOut         : out VideoYCbCr
  );
end convert_422_to_444;

architecture Behavioral of convert_422_to_444 is

  -- delay in (enabled) clock cycles for untouched signals
  constant Delayticks: Natural := 4;

  -- stored color signals
  signal current_c1: unsigned(7 downto 0) := (others => '1');
  signal current_c2: unsigned(7 downto 0) := (others => '1');
  signal prev_c1   : unsigned(7 downto 0) := (others => '1');
  signal prev_c2   : unsigned(7 downto 0) := (others => '1');

  signal prev_blanking: boolean;
  signal is_cbfirst   : boolean;

  -- averaging function, also converts output to signed
  function average(a: unsigned(7 downto 0); b: unsigned(7 downto 0))
    return signed is
    variable a9 : unsigned(8 downto 0);
    variable b9 : unsigned(8 downto 0);
    variable res: unsigned(8 downto 0);
  begin
    a9  := "0" & a;
    b9  := "0" & b;
    res := a9 + b9;

    return signed(res(8 downto 1) xor x"80");
  end function;

begin

  -- capture and interpolate colors
  process (PixelClock, PixelClockEnable)
    variable new_c1: signed(7 downto 0);
    variable new_c2: signed(7 downto 0);
  begin
    if rising_edge(PixelClock) and PixelClockEnable then
      -- test if the first pixel on line is Cr
      prev_blanking <= VideoIn.Blanking;

      if prev_blanking and not VideoIn.Blanking then
        is_cbfirst <= VideoIn.CurrentIsCb;
      end if;

      -- capture color data
      if VideoIn.CurrentIsCb = is_cbfirst then
        -- pixel with start of new chroma information
        if not VideoIn.Blanking then
          current_c1 <= VideoIn.PixelCbCr;
        end if;

        prev_c2 <= current_c2;
        prev_c1 <= current_c1;

        -- output interpolated chroma info for the delayed Y value
        if InterpolateChroma and not Output422 then
          new_c1 := average(prev_c1, current_c1);
          new_c2 := average(prev_c2, current_c2);
        else
          new_c1 := signed(prev_c1 xor x"80");
          new_c2 := signed(prev_c2 xor x"80");
        end if;

      else
        -- pixel with the remainder of the current chroma information
        if not VideoIn.Blanking then
          current_c2 <= VideoIn.PixelCbCr;
        end if;

        -- output the previous "full" chroma info to coincide with the delayed Y value
        if Output422 then
          -- 4:2:2 outputs all chroma over the red TMDS channel,
          -- so swapping here results in a Cb/Cr/Cb/Cr output
          new_c1 := signed(prev_c2 xor x"80");
          new_c2 := signed(prev_c1 xor x"80");
        else
          new_c1 := signed(prev_c1 xor x"80");
          new_c2 := signed(prev_c2 xor x"80");
        end if;
      end if;

      -- forward to the correct output channels
      if is_cbfirst then
        VideoOut.PixelCb <= new_c1;
        VideoOut.PixelCr <= new_c2;
      else
        VideoOut.PixelCb <= new_c2;
        VideoOut.PixelCr <= new_c1;
      end if;
    end if;
  end process;

  -- generate delayed signals
  Inst_LumaDelay: delayline_unsigned
    generic map (
      Delayticks  => Delayticks,
      Width       => 8
    )
    port map (
      Clock       => PixelClock,
      ClockEnable => PixelClockEnable,
      Input       => VideoIn.PixelY,
      Output      => VideoOut.PixelY
    );

  Inst_HSyncDelay: delayline_bool
    generic map (
      Delayticks  => Delayticks
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
      Delayticks  => Delayticks
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
