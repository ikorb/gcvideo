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
-- colormatrix: matrix multiplier for color conversion
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.component_defs.all;
use work.video_defs.all;

entity ColorMatrix is
  port (
    PixelClock      : in  std_logic;
    PixelClockEnable: in  boolean;

    -- control
    Settings        : in  VideoSettings_t;

    -- input video
    VideoIn         : in  VideoYCbCr;

    -- output video
    VideoOut        : out VideoRGB
  );
end ColorMatrix;

architecture Behavioral of colormatrix is

  -- delay in (enabled) clock cycles for untouched signals
  constant Delayticks: Natural := 2;

  signal yr_mult: signed(26 downto 0);
  signal yg_mult: signed(26 downto 0);
  signal yb_mult: signed(26 downto 0);

  signal color_r: signed(23 downto 0);
  signal color_g: signed(24 downto 0);
  signal color_b: signed(23 downto 0);

  signal rsum   : signed(14 downto 0);
  signal gsum   : signed(14 downto 0);
  signal bsum   : signed(14 downto 0);

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
    variable y_shifted: signed(10 downto 0);
    variable cb_r     : signed(23 downto 0);
    variable cb_g     : signed(23 downto 0);
    variable cb_b     : signed(23 downto 0);
    variable cr_r     : signed(23 downto 0);
    variable cr_g     : signed(23 downto 0);
    variable cr_b     : signed(23 downto 0);
    variable rsum     : signed(27 downto 0);
    variable bsum     : signed(27 downto 0);
  begin
    if rising_edge(PixelClock) and PixelClockEnable then
      ---- pipeline stage 1: Y-offset, all multiplications and Cr/Cb sums
      -- Y offset
      y_shifted := mksigned(VideoIn.PixelY) + resize(Settings.Matrix.YBias, 11);

      -- Y parts of R/G/B
      yr_mult <= Settings.Matrix.YRFactor * y_shifted;
      yg_mult <= Settings.Matrix.YGFactor * y_shifted;
      yb_mult <= Settings.Matrix.YBFactor * y_shifted;

      -- Cb/Cr parts of R/G/B
      cb_g := VideoIn.PixelCb * Settings.Matrix.CbGFactor;
      cb_b := VideoIn.PixelCb * Settings.Matrix.CbBFactor;
      cr_r := VideoIn.PixelCr * Settings.Matrix.CrRFactor;
      cr_g := VideoIn.PixelCr * Settings.Matrix.CrGFactor;

      -- Cb/Cr sums for R/G/B
      color_r <= cr_r;
      color_g <= resize(cb_g, 25) + cr_g;
      color_b <= cb_b;

      ---- pipeline stage 2: RGB sums and clipping
      if Settings.ColorMode(1) = '1' then
        rsum := (yr_mult + resize(color_r, 28)) / 4096 + 128;
        bsum := (yb_mult + resize(color_b, 28)) / 4096 + 128;
      else
        rsum := (yr_mult + resize(color_r, 28)) / 4096;
        bsum := (yb_mult + resize(color_b, 28)) / 4096;
      end if;

      VideoOut.PixelR <= clip(resize(rsum, 15));
      VideoOut.PixelG <= clip(resize((yg_mult + resize(color_g, 28)) / 4096, 15));
      VideoOut.PixelB <= clip(resize(bsum, 15));

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
