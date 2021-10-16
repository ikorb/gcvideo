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
-- ZPUIRQController.vhd: Interrupt controller for ZPU
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use work.ZPUDevices.all;

entity ZPUIRQController is
  generic (
    Devices: natural range 1 to 31
  );
  port (
    Clock    : in  std_logic;
    ZSelect  : in  std_logic;
    ZPUBusIn : in  ZPUDeviceIn;
    ZPUBusOut: out ZPUDeviceOut;

    DevIRQs  : in  ZPUIRQSignals;
    IRQOut   : out std_logic
  );
end ZPUIRQController;

architecture Behavioral of ZPUIRQController is
  signal enable_bits  : std_logic_vector(Devices-1 downto 0) := (others => '0');
  signal global_enable: std_logic := '0';
  signal temp_disable : std_logic := '0';
begin

  ZPUBusOut.mem_busy <= '0';

  process(Clock)
    variable i      : natural range 0 to Devices-1;
    variable any_int: std_logic;
  begin
    if rising_edge(Clock) then
      -- reset
      if ZPUBusIn.Reset = '1' then
        global_enable <= '0';
        temp_disable  <= '0';
        IRQOut        <= '0';
      else
        -- bus access
        if ZSelect = '1' then
          if ZPUBusIn.mem_writeEnable = '1' then
            -- ignore byte/halfword writes
            if ZPUBusIn.mem_bEnable = '0' and
               ZPUBusIn.mem_hEnable = '0' then
              if ZPUBusIn.mem_addr(2) = '0' then
                -- write interrupt enable bits
                enable_bits   <= ZPUBusIn.mem_write(Devices-1 downto 0);
                global_enable <= ZPUBusIn.mem_write(31);
              else
                -- write temp-disable bit
                temp_disable  <= ZPUBusIn.mem_write(0);
              end if;
            end if;

          elsif ZPUBusIn.mem_readEnable = '1' then
            ZPUBusOut.mem_read <= (others => '0');

            if ZPUBusIn.mem_addr(2) = '0' then
              -- read currently active interrupts

              any_int := '0';
              for i in 0 to Devices-1 loop
                ZPUBusOut.mem_read(i) <= DevIRQs(i) and enable_bits(i);
                any_int               := any_int or (DevIRQs(i) and enable_bits(i));
              end loop;

              ZPUBusOut.mem_read(31) <= any_int;
            else
              -- read temp-disable bit
              ZPUBusOut.mem_read(0) <= temp_disable;
            end if;

          end if;
        end if;

        -- interrupt forwarding
        IRQOut <= '0';
        if temp_disable = '0' and global_enable = '1' then
          for i in 0 to Devices-1 loop
            if DevIRQs(i) = '1' and enable_bits(i) = '1' then
             IRQOut <= '1';
            end if;
          end loop;
        end if;
      end if;
    end if;
  end process;

end Behavioral;

