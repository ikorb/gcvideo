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
-- i2s_decoder.vhd: A simplified I2S decoder for 16 bit signals
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity i2s_decoder is
  port (
    -- Internal clock
    Clock      : in  std_logic;
    ClockEnable: in  boolean;

    -- I2S signals
    I2S_BClock : in  std_logic;
    I2S_LRClock: in  std_logic;
    I2S_Data   : in  std_logic;

    -- sample output
    Left        : out signed(15 downto 0);
    Right       : out signed(15 downto 0);
    LeftEnable  : out boolean;
    RightEnable : out boolean
  );
end i2s_decoder;

architecture Behavioral of i2s_decoder is
  signal shifter   : std_logic_vector(15 downto 0);
  signal prev_lrclk: std_logic;
  signal prev_bclk : std_logic;
begin

  process(Clock)
  begin
    if rising_edge(Clock) and ClockEnable then
      LeftEnable  <= false;
      RightEnable <= false;
      prev_bclk   <= I2S_BClock;

      -- check for rising edge on I2S_BClock
      if I2S_BClock /= prev_bclk and
         I2S_BClock  = '1' then
        prev_lrclk <= I2S_LRClock;

        -- check for edge on I2S_LRClock (channel change)
        if prev_lrclk /= I2S_LRClock then
          if prev_lrclk = '0' then
            Left        <= signed(shifter);
            LeftEnable  <= true;
          else
            Right       <= signed(shifter);
            RightEnable <= true;
          end if;
        end if;

        shifter <= shifter(14 downto 0) & I2S_Data;
      end if;
    end if;
  end process;

end Behavioral;

