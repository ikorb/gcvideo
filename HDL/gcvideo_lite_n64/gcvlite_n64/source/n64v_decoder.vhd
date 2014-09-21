----------------------------------------------------------------------------------
-- GCVideo Lite for N64 HDL Version 1.0
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
-- n64v_decoder: Decoder for the N64 divital video data
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.video_defs.all;

entity n64v_decoder is
  port (
    -- N64 signals
    VClockI: in  std_logic; -- ~50 MHz clock
    VData  : in  std_logic_vector(6 downto 0);
    DSync  : in  std_logic;

    -- output clock enables
    PixelClkEn  : out boolean; -- CE relative to input clock for complete pixels
    PixelClkEn2x: out boolean; -- same, but at twice the pixel rate

    -- video output signals
    Video       : out VideoRGB
  );
end n64v_decoder;

architecture Behavioral of n64v_decoder is
  signal current_flags: std_logic_vector(6 downto 0);
  signal current_r    : unsigned(6 downto 0);
  signal current_g    : unsigned(6 downto 0);
  signal current_b    : unsigned(6 downto 0);
  signal packet_count : natural range 0 to 2;
begin

  process (VClockI)
  begin
    if rising_edge(VClockI) then
      if DSync = '0' then
        -- output data from previous packet
	Video.PixelR   <= current_r;
	Video.PixelG   <= current_g;
	Video.PixelB   <= current_b;
        Video.Blanking <= (current_flags(2) = '0'); -- yes, it is /BLANK
	Video.HSync    <= (current_flags(1) = '0');
	Video.VSync    <= (current_flags(3) = '0');
        Video.CSync    <= (current_flags(0) = '0');

	PixelClkEn     <= true;
	PixelClkEn2x   <= true;

        -- prepare for next packet
        packet_count  <= 0;
	current_flags <= VData;
      else
        -- not a flag packet
	packet_count <= packet_count + 1;

        PixelClkEn   <= false;
	PixelClkEn2x <= false;

	case packet_count is
	  when 0 => current_r <= unsigned(VData);
	  when 1 => current_g <= unsigned(VData); PixelClkEn2x <= true;
	  when 2 => current_b <= unsigned(VData);
	end case;
      end if;
    end if;
  end process;

end Behavioral;

