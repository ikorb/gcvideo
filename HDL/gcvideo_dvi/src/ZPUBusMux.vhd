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
-- ZPUBusMux.vhd: Bus multiplexer for ZPU
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use work.zpupkg.all;
use work.ZPUDevices.all;

entity ZPUBusMux is
  generic (
    Devices: Natural range 1 to 1000
  );
  port (
    Clock          : in  std_Logic;
    mem_readEnable : in  std_logic;
    mem_writeEnable: in  std_logic;

    DevSelects     : in  ZPUMuxSelects;
    DevOuts        : in  ZPUMuxDevOuts;

    mem_busy_out   : out std_logic;
    mem_read_out   : out std_logic_vector(31 downto 0)
  );
end ZPUBusMux;

architecture Behavioral of ZPUBusMux is
  signal current_device: integer range Devices-1 downto -1 := 0;
begin

  -- capture selected device at start of access
  process(Clock)
  begin
    if rising_edge(Clock) then
      if mem_writeEnable = '1' or
         mem_readEnable  = '1' then
        -- loop over the selects
        current_device <= -1;
        for i in 0 to Devices-1 loop
          if DevSelects(i) = '1' then
            current_device <= i;
          end if;
        end loop;
      end if;
    end if;
  end process;

  -- mux device outputs to CPU
  process(current_device, DevOuts, mem_readEnable, mem_writeEnable)
  begin
    if mem_readEnable  = '1' or
       mem_writeEnable = '1' then
      -- first cycle of device access, signal busy
      mem_read_out <= (others => '-');  -- don't care, saves FPGA resources
      mem_busy_out <= '1';
    elsif current_device = -1 then
      -- default device
      mem_busy_out <= '0';
      mem_read_out <= (others => '-');  -- same
    else
      -- copy outputs of selected device
      mem_busy_out <= DevOuts(current_device).mem_busy;
      mem_read_out <= DevOuts(current_device).mem_read;
    end if;
  end process;

end Behavioral;

