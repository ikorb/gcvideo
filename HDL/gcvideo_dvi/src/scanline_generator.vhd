----------------------------------------------------------------------------------
-- GCVideo DVI HDL
-- Copyright (C) 2014-2020, Ingo Korb <ingo@akana.de>
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
use work.video_defs.all;

entity scanline_generator is
  port (
    PixelClock      : in  std_logic;
    PixelClockEnable: in  boolean;

    Enable          : in  boolean;
    Strength        : in  unsigned(7 downto 0);
    Use_Even        : in  boolean;

    -- input video
    VideoIn         : in  VideoYCbCr;

    -- output video
    VideoOut        : out VideoYCbCr
  );
end scanline_generator;

architecture Behavioral of scanline_generator is
  signal even_line : boolean;
  signal prev_hsync: boolean;

  function scale_luma(val: unsigned(7 downto 0); factor: unsigned(7 downto 0))
    return unsigned is
    variable tmp: unsigned(16 downto 0);
    variable factor_plus_one: unsigned(8 downto 0);
  begin
    factor_plus_one := ('0' & factor) + 1;
    tmp := val * factor_plus_one;
    return tmp(15 downto 8);
  end function;

  function scale_color(val: signed(7 downto 0); factor: unsigned(7 downto 0))
    return signed is
    variable tmp: signed(17 downto 0);
    variable factor_plus_one: signed(9 downto 0);
  begin
    factor_plus_one := signed("00" & factor) + 1;
    tmp := val * factor_plus_one;
    return tmp(15 downto 8);
  end function;

begin

  process(PixelClock, PixelClockEnable)
  begin
    if rising_edge(PixelClock) and PixelClockEnable then
      -- copy everything except pixels
      VideoOut.HSync         <= VideoIn.HSync;
      VideoOut.VSync         <= VideoIn.VSync;
      VideoOut.CSync         <= VideoIn.CSync;
      VideoOut.Blanking      <= VideoIn.Blanking;
      VideoOut.IsEvenField   <= VideoIn.IsEvenField;
      VideoOut.IsProgressive <= VideoIn.IsProgressive;
      VideoOut.IsPAL         <= VideoIn.IsPAL;
      VideoOut.Is30kHz       <= VideoIn.Is30kHz;

      if not VideoIn.Is30kHz or not Enable then
        -- bypass for 15kHz modes
        VideoOut.PixelY  <= VideoIn.PixelY;
        VideoOut.PixelCb <= VideoIn.PixelCb;
        VideoOut.PixelCr <= VideoIn.PixelCr;
      else
        -- determine even/odd line
        prev_hsync <= VideoIn.HSync;

        if VideoIn.VSync then
          even_line <= false;
        elsif prev_hsync /= VideoIn.HSync and not VideoIn.HSync then
          even_line <= not even_line;
        end if;

        -- reduce pixel brightness for every second line
        if not VideoIn.Blanking and even_line = use_even then
          if strength = x"00" then
            VideoOut.PixelY  <= x"00";
            VideoOut.PixelCb <= x"00";
            VideoOut.PixelCr <= x"00";
          else
            VideoOut.PixelY  <= scale_luma(VideoIn.PixelY, strength);
            VideoOut.PixelCb <= scale_color(VideoIn.PixelCb, strength);
            VideoOut.PixelCr <= scale_color(VideoIn.PixelCr, strength);
          end if;
        else
          VideoOut.PixelY  <= VideoIn.PixelY;
          VideoOut.PixelCb <= VideoIn.PixelCb;
          VideoOut.PixelCr <= VideoIn.PixelCr;
        end if;
      end if;
    end if;
  end process;

end Behavioral;

