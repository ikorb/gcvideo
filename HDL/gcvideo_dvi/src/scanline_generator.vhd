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
-- scanline_generator.vhd: Scanline overlay
--
----------------------------------------------------------------------------------

library IEEE;

use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.component_defs.all;
use work.video_defs.all;

entity scanline_generator is
  port (
    PixelClock      : in  std_logic;
    PixelClockEnable: in  boolean;

    Enable          : in  boolean;
    Use_Even        : in  boolean;

    PixelY          : out std_logic_vector(7 downto 0);
    ScanlineStrength: in  std_logic_vector(8 downto 0);

    -- input video
    VideoIn         : in  VideoYCbCr;

    -- output video
    VideoOut        : out VideoYCbCr
  );
end scanline_generator;

architecture Behavioral of scanline_generator is

  -- one pixel to fetch the correct factor, one more to apply it
  constant Delayticks: Natural := 2;

  signal even_line  : boolean;
  signal prev_hsync : boolean;
  signal y_delay    : unsigned(7 downto 0);
  signal cb_delay   : signed(7 downto 0);
  signal cr_delay   : signed(7 downto 0);
  signal blank_delay: boolean;

  function scale_luma(val: unsigned(7 downto 0); factor: unsigned(8 downto 0))
    return unsigned is
    variable tmp: unsigned(16 downto 0);
  begin
    tmp := val * factor;
    return tmp(15 downto 8);
  end function;

  function scale_color(val: signed(7 downto 0); factor: unsigned(8 downto 0))
    return signed is
    variable tmp: signed(17 downto 0);
    variable factor_signed: signed(9 downto 0);
  begin
    factor_signed := signed("0" & factor);
    tmp := val * factor_signed;
    return tmp(15 downto 8);
  end function;

begin

  process(PixelClock, PixelClockEnable)
    variable factor: unsigned(8 downto 0);
  begin
    if rising_edge(PixelClock) and PixelClockEnable then
      -- determine even/odd line
      prev_hsync <= VideoIn.HSync;

      if VideoIn.VSync then
        even_line <= false;
      elsif prev_hsync /= VideoIn.HSync and not VideoIn.HSync then
        even_line <= not even_line;
      end if;

      y_delay     <= VideoIn.PixelY;
      cb_delay    <= VideoIn.PixelCb;
      cr_delay    <= VideoIn.PixelCr;
      blank_delay <= VideoIn.Blanking;

      PixelY <= std_logic_vector(VideoIn.PixelY);

      if not VideoIn.Is30kHz or not Enable then
        -- bypass for 15kHz modes by setting the factor to 1.0
        factor := "1" & x"00";
      else
        if not blank_delay and even_line = use_even then
          factor := unsigned(ScanlineStrength);
        else
          factor := "1" & x"00";
        end if;
      end if;

      -- apply brightness factor
      VideoOut.PixelY  <= scale_luma(y_delay, factor);
      VideoOut.PixelCb <= scale_color(cb_delay, factor);
      VideoOut.PixelCr <= scale_color(cr_delay, factor);
    end if;
  end process;

  -- generate delayed signals
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
      Delayticks  => Delayticks
    )
    port map (
      Clock       => PixelClock,
      ClockEnable => PixelClockEnable,
      Input       => VideoIn.VSync,
      Output      => VideoOut.VSync
    );

  Inst_CSyncDelay: delayline_bool
    generic map (
      Delayticks  => Delayticks
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

