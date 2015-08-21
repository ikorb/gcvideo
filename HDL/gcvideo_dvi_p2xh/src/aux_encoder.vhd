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
-- aux_encoder.vhd: 4-to-10 bit encoder for aux data
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.ALL;

entity aux_encoder is
  port (
    Clock      : in  std_logic;
    ClockEnable: in  boolean;
    Data       : in  std_logic_vector(3 downto 0);
    EncData    : out std_logic_vector(9 downto 0)
  );
end aux_encoder;

architecture Behavioral of aux_encoder is

begin
  process(Clock, ClockEnable)
  begin
    if rising_edge(Clock) and ClockEnable then
      case Data is
        when "0000" => EncData <= "1010011100";
        when "0001" => EncData <= "1001100011";
        when "0010" => EncData <= "1011100100";
        when "0011" => EncData <= "1011100010";
        when "0100" => EncData <= "0101110001";
        when "0101" => EncData <= "0100011110";
        when "0110" => EncData <= "0110001110";
        when "0111" => EncData <= "0100111100";
        when "1000" => EncData <= "1011001100";
        when "1001" => EncData <= "0100111001";
        when "1010" => EncData <= "0110011100";
        when "1011" => EncData <= "1011000110";
        when "1100" => EncData <= "1010001110";
        when "1101" => EncData <= "1001110001";
        when "1110" => EncData <= "0101100011";
        when others => EncData <= "1011000011"; -- 1111
      end case;
    end if;
  end process;

end Behavioral;
