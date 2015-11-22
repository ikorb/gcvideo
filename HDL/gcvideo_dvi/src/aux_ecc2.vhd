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
-- aux_ecc2.vhd: Error Correction Code generator for aux data, 2 bit version
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;

entity aux_ecc2 is
  port (
    Clock      : in  std_logic;
    ClockEnable: in  boolean;
    DataIn     : in  std_logic_vector(1 downto 0);
    DataOut    : out std_logic_vector(1 downto 0);
    SendECC    : in  boolean
  );
end aux_ecc2;

architecture Behavioral of aux_ecc2 is
  signal reg: std_logic_vector(7 downto 0);
begin

  process(Clock, ClockEnable)
    variable feedback1, feedback2: std_logic;
    variable reg_temp: std_logic_vector(7 downto 0);
  begin
    if rising_edge(Clock) and ClockEnable then
      if SendECC then
        reg(7 downto 2) <= reg(5 downto 0);
        reg(1 downto 0) <= "00";
        DataOut         <= reg(6) & reg(7);
      else
        feedback1            := reg(7) xor DataIn(0);
        reg_temp(7)          := reg(6) xor feedback1;
        reg_temp(6)          := reg(5) xor feedback1;
        reg_temp(5 downto 1) := reg(4 downto 0);
        reg_temp(0)          := feedback1;

        feedback2       := reg_temp(7) xor DataIn(1);
        reg(7)          <= reg_temp(6) xor feedback2;
        reg(6)          <= reg_temp(5) xor feedback2;
        reg(5 downto 1) <= reg_temp(4 downto 0);
        reg(0)          <= feedback2;
        DataOut         <= DataIn;
      end if;
    end if;
  end process;

end Behavioral;
