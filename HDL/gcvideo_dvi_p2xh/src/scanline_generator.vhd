----------------------------------------------------------------------------------
-- GCVideo DVI HDL Version 1.0
-- Copyright (C) 2014, Ingo Korb <ingo@akana.de>
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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

use work.video_defs.all;

entity scanline_generator is
  port (
    PixelClock      : in  std_logic;
    PixelClockEnable: in  boolean;

    Enable          : in  boolean;
    Strength        : in  unsigned(3 downto 0);
    Use_Even        : in  boolean;
    
    -- input video
    VideoIn         : in  VideoRGB;

    -- output video
    VideoOut        : out VideoRGB
  );
end scanline_generator;

architecture Behavioral of scanline_generator is
  signal even_line : boolean;
  signal prev_hsync: boolean;
  
  function scale_component(val: unsigned(7 downto 0); factor: unsigned(3 downto 0))
    return unsigned is
    variable tmp: unsigned(12 downto 0);
    variable factor_plus_one: unsigned(4 downto 0);
  begin
    factor_plus_one := ('0' & factor) + 1;
    tmp := val * factor_plus_one;
    return tmp(11 downto 4);
  end function;
  
begin

  process(PixelCLock, PixelClockEnable)
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
        VideoOut.PixelR <= VideoIn.PixelR;
        VideoOut.PixelG <= VideoIn.PixelG;
        VideoOut.PixelB <= VideoIn.PixelB;
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
          if strength = x"0" then
            VideoOut.PixelR <= x"00";
            VideoOut.PixelG <= x"00";
            VideoOut.PixelB <= x"00";
          else
            VideoOut.PixelR <= scale_component(VideoIn.PixelR, strength);
            VideoOut.PixelG <= scale_component(VideoIn.PixelG, strength);
            VideoOut.PixelB <= scale_component(VideoIn.PixelB, strength);
          end if;
        else
          VideoOut.PixelR <= VideoIn.PixelR;
          VideoOut.PixelG <= VideoIn.PixelG;
          VideoOut.PixelB <= VideoIn.PixelB;
        end if;
      end if;
    end if;
  end process;

end Behavioral;

