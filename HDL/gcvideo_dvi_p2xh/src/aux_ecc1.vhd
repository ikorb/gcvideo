----------------------------------------------------------------------------------
-- GCVideo DVI HDL
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
-- aux_ecc1.vhd: Error Correction Code generator for aux data, 1 bit version
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;

entity aux_ecc1 is
  port (
    Clock      : in  std_logic;
    ClockEnable: in  boolean;
    DataIn     : in  std_logic;
    DataOut    : out std_logic;
    SendECC    : in  boolean
  );
end aux_ecc1;

architecture Behavioral of aux_ecc1 is
  signal reg: std_logic_vector(7 downto 0) := (others => '0');
begin

  process(Clock, ClockEnable)
    variable feedback: std_logic;
  begin
    if rising_edge(Clock) and ClockEnable then
      if SendECC then
        -- output phase
        reg(7 downto 1) <= reg(6 downto 0);
        reg(0)          <= '0';
        DataOut         <= reg(7);
      else
        -- calculation phase, copies data to output
        feedback        := reg(7) xor DataIn;
        reg(7)          <= reg(6) xor feedback;
        reg(6)          <= reg(5) xor feedback;
        reg(5 downto 1) <= reg(4 downto 0);
        reg(0)          <= feedback;
        DataOut         <= DataIn;
      end if;
    end if;
  end process;

end Behavioral;

