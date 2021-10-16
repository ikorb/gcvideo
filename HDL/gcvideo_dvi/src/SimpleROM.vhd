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
-- SimpleROM.vhd: Single-port ROM with data from file
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use std.textio.all;

entity SimpleROM is
  generic (
    AddressBits: natural range 1 to 32;
    DataBits   : natural range 1 to 32;
    Datafile   : string
  );
  port (
    Clock      : in  std_logic;
    ClockEnable: in  boolean;
    Address    : in  std_logic_vector(AddressBits-1 downto 0);
    Data       : out std_logic_vector(DataBits-1 downto 0)
  );
end SimpleROM;

architecture Behavioral of SimpleROM is

  type rom_type is array(0 to 2**AddressBits-1) of std_logic_vector(DataBits-1 downto 0);

  -- initialize contents from data file
  -- (doesn't work with Quartus)
  impure function init_mem return rom_type is
    file mif_file: text open read_mode is DataFile;
    variable mif_line: line;
    variable temp_bv : bit_vector(DataBits-1 downto 0);
    variable temp_mem: rom_type;
  begin
    for i in 0 to 2**AddressBits-1 loop
      readline(mif_file, mif_line);
      read(mif_line, temp_bv);
      temp_mem(i) := to_stdlogicvector(temp_bv);
    end loop;
    return temp_mem;
  end function;

  signal memory: rom_type := init_mem;

begin

  -- clocked ROM process
  process(Clock, ClockEnable)
  begin
    if rising_edge(Clock) and ClockEnable then
      Data <= memory(to_integer(unsigned(Address)));
    end if;
  end process;

end Behavioral;

