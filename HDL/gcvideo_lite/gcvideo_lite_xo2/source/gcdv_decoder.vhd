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
-- gcdv_decoder: Decoder for the GameCube digital video port signals
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.video_defs.all;

entity gcdv_decoder is
  port (
    -- Gamecube signals
    VClockI: in  std_logic; -- 54 MHz clock, pin 2
    VData  : in  std_logic_vector(7 downto 0);
    CSel   : in  std_logic; -- "ClkSel" signal, pin 3

    -- output clock enables
    PixelClkEn  : out boolean; -- CE relative to input clock for complete pixels
    PixelClkEn2x: out boolean; -- same, but at twice the pixel rate

    -- video output signals
    Video       : out VideoYCbCr;
    CurrentIsCb : out boolean  -- if true, Cb is updated in the current pixel
  );
end gcdv_decoder;

architecture Behavioral of gcdv_decoder is
  signal current_y    : unsigned(7 downto 0);
  signal current_cb   : unsigned(7 downto 0);
  signal current_cr   : unsigned(7 downto 0);
  signal current_flags: std_logic_vector(7 downto 0);

  signal prev_csel  : std_logic;
  signal in_blanking: boolean;
  
  signal input_30khz: boolean := false;
  signal modecounter: natural range 0 to 3 := 0;
begin

  process (VClockI)
  begin
    if rising_edge(VClockI) then
      prev_csel <= CSel;

      -- read cube signals
      if prev_csel /= CSel then
        -- csel has changed, current value is Y
        current_y <= unsigned(VData);

        if VData = x"00" then
          -- in blanking, next color is flags
          in_blanking <= true;
        else
          in_blanking <= false;
        end if;

        -- detect if it's a 15kHz or 30kHz video mode
        modecounter <= 0;
        if modecounter < 2 then
          input_30khz <= true;
        else
          input_30khz <= false;
        end if;
          
      else
        -- current value is color or flags
        modecounter <= modecounter + 1;
        
        -- read color just once in 15kHz mode
        if (not input_30khz and modecounter = 1) or input_30khz then
          if in_blanking then
            current_flags <= VData;
          else
            if CSel = '0' then
              current_cb <= unsigned(VData);
            else
              current_cr <= unsigned(VData);
            end if;
          end if;
        end if;
      end if;
 
      -- generate output signals
      if prev_csel /= CSel then
        -- output pixel data when the next Y value is received
        PixelClkEn    <= true;
        PixelClkEn2x  <= true;
        Video.Blanking      <= in_blanking;
        Video.HSync         <= (current_flags(4) = '0');
        Video.VSync         <= (current_flags(5) = '0');
        Video.CSync         <= (current_flags(7) = '0');
        Video.IsProgressive <= (current_flags(0) = '1');
        Video.IsPAL         <= (current_flags(1) = '1');
        Video.IsEvenField   <= (current_flags(6) = '1');
        
        if in_blanking then
          -- Don't blank Cr/Cb, outputting the previous value simplifies
          -- the color interpolation at the right edge
          Video.PixelY  <= x"10";
          --Video.PixelCb <= x"80";
          --Video.PixelCr <= x"80";
        else
          Video.PixelY  <= current_y;
          Video.PixelCb <= current_cb;
          Video.PixelCr <= current_cr;
        end if;
        --CurrentIsCb   <= (prev_csel = '1');
	CurrentIsCb <= (CSel = '0');

        Video.Is30kHz <= input_30kHz;

      else
        PixelClkEn <= false;
        if input_30khz or modecounter = 1 then
          PixelClkEn2x <= true;
        else
          PixelClkEn2x <= false;
        end if;
      end if;
    end if;
  end process;

end Behavioral;

