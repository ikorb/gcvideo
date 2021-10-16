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
-- crc32.vhd: bit-serial implementation of CRC-32-MPEG
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;

entity crc32 is
  port (
    Clock      : in  std_logic;
    DataIn     : in  std_logic;
    DataInValid: in  boolean;
    ResetCRC   : in  boolean;
    DataOut    : out std_logic_vector(31 downto 0)
  );
end crc32;

architecture Behavioral of crc32 is
  signal crc_register: std_logic_vector(31 downto 0);
begin

  DataOut <= crc_register;

  process(Clock)
  begin
    if rising_edge(Clock) then
      if DataInValid then
        if (crc_register(31) xor DataIn) = '1' then
          crc_register <= (crc_register(30 downto 0) & "0") xor x"04c11db7";
        else
          crc_register <=  crc_register(30 downto 0) & "0";
        end if;
      end if;

      if ResetCRC then
        crc_register <= x"ffffffff";
      end if;
    end if;
  end process;

end Behavioral;
