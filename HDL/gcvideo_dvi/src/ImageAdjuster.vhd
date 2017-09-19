----------------------------------------------------------------------------------
-- GCVideo DVI HDL
-- Copyright (C) 2014-2017, Ingo Korb <ingo@akana.de>
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
-- PictureAdjuster.vhd: Brightness/Contrast/Saturation adjustment
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.component_defs.all;
use work.video_defs.all;

entity ImageAdjuster is
  port (
    PixelClock      : in  std_logic;
    PixelClockEnable: in  boolean;
    VideoIn         : in  VideoYCbCr;
    VideoOut        : out VideoYCbCr;
    Settings        : in  ImageControls_t
  );
end ImageAdjuster;

architecture Behavioral of ImageAdjuster is
  constant MODULE_DELAY: natural := 2;

  signal ymult : signed(18 downto 0);
  signal cbmult: signed(17 downto 0);
  signal crmult: signed(17 downto 0);

  -- clip Y to 0..(255-16) because internally it's adjusted to 0 IRE at 0
  function clip_y(v: signed)
    return unsigned is
  begin
    if v < 0 then
      return x"00";
    elsif v > 255-16 then
      return x"ef";
    else
      return resize(unsigned(v), 8);
    end if;
  end function;

  -- clip Cb/Cr to valid range
  function clip_c(v: signed)
    return signed is
  begin
    if v < 16 - 128 then
      return to_signed(16 - 128, 8);
    elsif v > 240 - 128 then
      return to_signed(240 - 128, 8);
    else
      return resize(signed(v), 8);
    end if;
  end function;

begin

  process(PixelClock, PixelClockEnable)
  begin
    if rising_edge(PixelClock) and PixelClockEnable then
      ymult <= resize(mksigned(VideoIn.pixelY) * mksigned(Settings.Contrast), 19) +
               Settings.Brightness * to_signed(128, 9);
      cbmult <= VideoIn.PixelCb * mksigned(Settings.Saturation);
      crmult <= VideoIn.PixelCr * mksigned(Settings.Saturation);

      VideoOut.PixelY  <= clip_y(ymult / 128);
      VideoOut.PixelCb <= clip_c(cbmult / 128);
      VideoOut.PixelCr <= clip_c(crmult / 128);
    end if;
  end process;

  -- generate delayed signals
  Inst_HSyncDelay: delayline_bool
    generic map (
      Delayticks  => MODULE_DELAY
    )
    port map (
      Clock       => PixelClock,
      ClockEnable => PixelClockEnable,
      Input       => VideoIn.HSync,
      Output      => VideoOut.HSync
    );

  Inst_VSyncDelay: delayline_bool
    generic map (
      Delayticks  => MODULE_DELAY
    )
    port map (
      Clock       => PixelClock,
      ClockEnable => PixelClockEnable,
      Input       => VideoIn.VSync,
      Output      => VideoOut.VSync
    );

  Inst_CSyncDelay: delayline_bool
    generic map (
      Delayticks  => MODULE_DELAY
    )
    port map (
      Clock       => PixelClock,
      ClockEnable => PixelClockEnable,
      Input       => VideoIn.CSync,
      Output      => VideoOut.CSync
    );

  Inst_BlankingDelay: delayline_bool
    generic map (
      Delayticks  => MODULE_DELAY
    )
    port map (
      Clock       => PixelClock,
      ClockEnable => PixelClockEnable,
      Input       => VideoIn.Blanking,
      Output      => VideoOut.Blanking
    );

  Inst_FieldDelay: delayline_bool
    generic map (
      Delayticks  => MODULE_DELAY
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
