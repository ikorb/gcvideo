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
-- ZPU_DPRAM.vhd: Dual-ported RAM with ZPU interface on one side
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use std.textio.all;

use work.ZPUDevices.all;

entity ZPU_DPRAM is
  generic (
    AddressBits: natural range 1 to 32;
    DataBits   : natural range 1 to 32;
    Datafile   : string := ""
  );
  port (
    Clock    : in  std_logic;
    ZSelect  : in  std_logic;
    ZPUBusIn : in  ZPUDeviceIn;
    ZPUBusOut: out ZPUDeviceOut;
    RAMAddr  : in  std_logic_vector(AddressBits-1 downto 0);
    RAMData  : out std_logic_vector(DataBits-1 downto 0)
  );
end ZPU_DPRAM;

architecture Behavioral of ZPU_DPRAM is
  type ram_type is array(0 to 2**AddressBits - 1) of std_logic_vector(DataBits-1 downto 0);

  -- initialize contents from data file
  -- (doesn't work with Quartus)
  impure function init_mem return ram_type is
    file mif_file: text;
    variable mif_line: line;
    variable temp_bv : bit_vector(DataBits-1 downto 0);
    variable temp_mem: ram_type;
  begin
    temp_mem := (others => (others => '0'));
    if Datafile /= "" then
      file_open(mif_file, Datafile, read_mode);
      for i in 0 to 2**AddressBits-1 loop
        readline(mif_file, mif_line);
        read(mif_line, temp_bv);
        temp_mem(i) := to_stdlogicvector(temp_bv);
      end loop;
      file_close(mif_file);
    end if;
    return temp_mem;
  end function;

  signal dpram: ram_type := init_mem;

  signal write_delay: std_logic := '0';
  signal addr_a     : std_logic_vector(AddressBits-1 downto 0) := (others => '0');

begin

  ZPUBusOut.mem_read(31 downto DataBits) <= (others => '0');

  process(Clock)
  begin
    if rising_edge(Clock) then
      -- delay one cycle on reads
      ZPUBusOut.mem_busy <= ZPUBusIn.mem_readEnable;

      -- always read
      ZPUBusOut.mem_read(DataBits-1 downto 0) <=
        dpram(to_integer(unsigned(addr_a)));

      -- write if it was active
      if write_delay = '1' then
        dpram(to_integer(unsigned(addr_a))) <=
          ZPUBusIn.mem_write(DataBits-1 downto 0);
      end if;
      write_delay <= '0';

      -- capture address to register
      addr_a <= ZPUBusIn.mem_addr(AddressBits+1 downto 2);

      -- capture write signal for next cycle
      if ZSelect = '1' and ZPUBusIn.mem_writeEnable = '1' then
        write_delay <= '1';
      end if;

      -- port B is read-only and thus simpler
      RAMData <= dpram(to_integer(unsigned(RAMAddr)));
    end if;
  end process;

end Behavioral;

