----------------------------------------------------------------------------------
-- GCVideo DVI HDL
-- Copyright (C) 2014-2018, Ingo Korb <ingo@akana.de>
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
-- convert_yuv_to_rgb: YCbCr 444 to RGB converter, inferred multiplier version
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.component_defs.all;
use work.video_defs.all;

entity convert_yuv_to_rgb is
  port (
    PixelClock      : in  std_logic;
    PixelClockEnable: in  boolean;

    -- input video
    VideoIn         : in  VideoYCbCr;
    Limited_Range   : in  boolean;

    -- output video
    VideoOut        : out VideoRGB
  );
end convert_yuv_to_rgb;

architecture Behavioral of convert_yuv_to_rgb is

  -- delay in (enabled) clock cycles for untouched signals
  constant Delayticks: Natural := 4;

  signal ystore: signed(18 downto 0) := (others => '0');
  signal rtemp : signed(18 downto 0) := (others => '0'); -- Cr for R
  signal gtempr: signed(18 downto 0) := (others => '0'); -- Cr for G
  signal gtempb: signed(18 downto 0) := (others => '0'); -- Cb for G
  signal gtmpb2: signed(18 downto 0) := (others => '0'); -- Cb for G, delayed
  signal btemp : signed(18 downto 0) := (others => '0'); -- Cb for B

  signal rsum    : signed(18 downto 0) := (others => '0'); -- (Y + rtemp) / 256
  signal gsum    : signed(18 downto 0) := (others => '0'); -- (Y - gtemp1 - gtemp2) / 256
  signal bsum    : signed(18 downto 0) := (others => '0'); -- (Y + btemp) / 256
  signal gsumtemp: signed(18 downto 0) := (others => '0');

  signal yscale : signed(10 downto 0) := to_signed(298, 11);
  signal yshift : signed( 5 downto 0) := to_signed(  0,  6);
  signal rscale : signed(10 downto 0) := to_signed(409, 11);
  signal grscale: signed(10 downto 0) := to_signed(208, 11);
  signal gbscale: signed(10 downto 0) := to_signed(100, 11);
  signal bscale : signed(10 downto 0) := to_signed(517, 11);
  signal rout   : unsigned(7 downto 0);
  signal bout   : unsigned(7 downto 0);

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

  -- capture and interpolate colors
  process (PixelClock, PixelClockEnable)
    variable cr_s: signed(7 downto 0);
    variable cb_s: signed(7 downto 0);
  begin
    if rising_edge(PixelClock) and PixelClockEnable then
      -- update factors for limited/full range
      if Limited_Range then
        yscale  <= to_signed(256, 11);
        yshift  <= to_signed( 16,  6);
        rscale  <= to_signed(351, 11);
        grscale <= to_signed(179, 11);
        gbscale <= to_signed( 86, 11);
        bscale  <= to_signed(443, 11);
      else
        yscale  <= to_signed(298, 11);
        yshift  <= to_signed(  0,  6);
        rscale  <= to_signed(409, 11);
        grscale <= to_signed(208, 11);
        gbscale <= to_signed(100, 11);
        bscale  <= to_signed(517, 11);
      end if;

      -- pipeline stage 1: calculate the scaled color values
      cr_s := VideoIn.PixelCr;
      cb_s := VideoIn.PixelCb;

        -- FIXME: Expression from S6, not optimal for S3A architecture
      ystore <= resize((mksigned(VideoIn.PixelY) + yshift) * yscale, 19)
              + to_signed(128, 19); -- add 0.5 to get a rounded result
      rtemp  <= rscale  * cr_s;
      gtempr <= grscale * cr_s;
      gtempb <= gbscale * cb_s;
      btemp  <= bscale  * cb_s;

      -- pipeline stage 2: add/subtract
      rsum     <= (ystore + rtemp) / 256;
      gsumtemp <= ystore - gtempr;
      gtmpb2   <= gtempb;
      bsum     <= (ystore + btemp) / 256;

      -- pipeline stage 3: clipping r/b, subtract g
      rout <= clip(rsum);
      gsum <= (gsumtemp - gtmpb2) / 256;
      bout <= clip(bsum);

      -- pipeline stage 4: clip g, output
      VideoOut.PixelR <= rout;
      VideoOut.PixelG <= clip(gsum);
      VideoOut.PixelB <= bout;
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

