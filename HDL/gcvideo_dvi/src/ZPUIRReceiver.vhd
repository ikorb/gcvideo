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
-- ZPUIRReceiver.vhd: IR remote pulse capture
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.video_defs.all;
use work.ZPUDevices.all;

entity ZPUIRReceiver is
  generic (
    ClockScale: natural range 1 to 10000
  );
  port (
    Clock     : in  std_logic;
    ZSelect   : in  std_logic;
    ZPUBusIn  : in  ZPUDeviceIn;
    ZPUBusOut : out ZPUDeviceOut;
    IRQ       : out std_logic;
    IRReceiver: in  std_logic;
    IRButton  : in  std_logic
  );
end ZPUIRReceiver;

architecture Behavioral of ZPUIRReceiver is

  constant Debounce_Maxcount: natural := 131072;

  signal button_count: natural range 0 to Debounce_Maxcount;
  signal button_sync : std_logic_vector(2 downto 0);
  signal button      : std_logic;

  signal rx_sync        : std_logic_vector(1 downto 0);
  signal irrx, prev_irrx: std_logic;
  signal divider        : natural range 0 to ClocKScale-1;
  signal rx_ce          : boolean;

  signal pulse_len      : unsigned(7 downto 0) := (others => '0');
  signal idle_state     : std_logic;
  signal timeout        : std_logic := '1';

  signal pulse_register : std_logic_vector(9 downto 0);
  signal need_irq       : std_logic := '0';
  signal irq_internal   : std_logic := '0';
begin

  -- debounce button
  process(Clock)
  begin
    if rising_edge(ClocK) then
      button_sync <= button_sync(1 downto 0) & IRButton;

      if button_sync(2) /= button_sync(1) then
        button_count <= Debounce_Maxcount;
      else
        if button_count /= 0 then
          button_count <= button_count - 1;
        else
          button <= button_sync(2);
        end if;
      end if;
    end if;
  end process;

  -- sync IR receiver
  process(Clock)
  begin
    if rising_edge(Clock) then
      irrx      <= rx_sync(1);
      rx_sync   <= rx_sync(0) & IRReceiver;
    end if;
  end process;

  -- generate clock enable for sampling the IR receiver
  process(Clock)
  begin
    if rising_edge(Clock) then
      if divider = 0 then
        divider <= ClockScale - 1;
        rx_ce <= true;
      else
        divider <= divider - 1;
        rx_ce <= false;
      end if;
    end if;
  end process;

  -- count pulse lengths on IR receiver
  process(Clock)
  begin
    if rising_edge(Clock) then
      need_irq <= '0';

      if rx_ce then
        prev_irrx <= irrx;

        if prev_irrx /= irrx then
          -- at pulse boundary
          if timeout = '0' then
            pulse_register <= (prev_irrx xor idle_state) & timeout & std_logic_vector(pulse_len);
            need_irq <= '1';
          end if;

          pulse_len <= (others => '0');
          timeout   <= '0';

        elsif timeout = '0' then
          if pulse_len = x"ff" then
            -- timed out, trigger interrupt
            idle_state     <= irrx;
            timeout        <= '1';
            need_irq       <= '1';
            pulse_register <= '0' & '1' & x"ff";

          else
            pulse_len <= pulse_len + 1;
          end if;
        end if;
      end if;
    end if;
  end process;

  -- bus interface
  process(Clock)
  begin
    if rising_edge(Clock) then
      if need_irq = '1' then
        irq_internal <= '1';
      end if;

      if (ZSelect = '1' and ZPUBusIn.mem_writeEnable = '1') or
          ZPUBusIn.Reset = '1' then
        irq_internal <= '0';
      end if;

      ZPUBusOut.mem_read(11 downto 0) <= irq_internal & button & pulse_register;
    end if;
  end process;

  IRQ <= irq_internal;

end Behavioral;
