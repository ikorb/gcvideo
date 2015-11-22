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
-- PadAnalyzer.vhd: Gamecube controller timing analyzer
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.component_defs.all;
use work.ZPUDevices.all;

entity PadAnalyzer is
  port (
    Clock    : in  std_logic;
    ZSelect  : in  std_logic;
    ZPUBusIn : in  ZPUDeviceIn;
    ZPUBusOut: out ZPUDeviceOut;
    PadData  : in  std_logic
  );
end PadAnalyzer;

architecture Behavioral of PadAnalyzer is
  type ram_type is array(0 to 2047) of std_logic_vector(17 downto 0);

  signal dpram: ram_type := (others => (others => '0'));

  signal write_delay: std_logic := '0';
  signal addr_a     : std_logic_vector(10 downto 0) := (others => '0');
  signal addr_b     : std_logic_vector(10 downto 0) := (others => '0');

  constant MaxPulseLen  : natural := 262144-1; -- 2^18-1
  constant MaxPulseCount: natural := 2047;

  signal data_deglitched: std_logic;
  signal prev_data      : std_logic;
  signal pulse_length   : natural range 0 to MaxPulseLen;

  signal capture_armed  : boolean := false;
  signal capture_active : boolean := false;
  signal pulse_count    : natural range 0 to MaxPulseCount;
begin

  Deglitch_Pad: Deglitcher GENERIC MAP (
    SyncBits    => 3,
    CompareBits => 2
  ) PORT MAP (
    Clock       => Clock,
    ClockEnable => true,
    Input       => PadData,
    Output      => data_deglitched
  );

  ZPUBusOut.mem_read(31 downto 18) <= (others => '0');

--  arm_out <= '1' when capture_armed else '0';
--  act_out <= '1' when capture_active else '0';

  process(Clock)
  begin
    if rising_edge(Clock) then
      ---- ZPU side
      -- delay one cycle on reads
      ZPUBusOut.mem_busy <= ZPUBusIn.mem_readEnable;

      -- always read
      ZPUBusOut.mem_read(17 downto 0) <=
        dpram(to_integer(unsigned(addr_a)));

      -- write if it was active
      if write_delay = '1' then
        dpram(to_integer(unsigned(addr_a))) <=
          ZPUBusIn.mem_write(17 downto 0);
      end if;
      write_delay <= '0';

      -- capture address to register
      addr_a <= ZPUBusIn.mem_addr(12 downto 2);

      -- capture write signal for next cycle
      if ZSelect = '1' and ZPUBusIn.mem_writeEnable = '1' then
        write_delay <= '1';

        -- writing to the last word turns capture on
        if ZPUBusIn.mem_addr(12 downto 2) = "111" & x"ff" then
          capture_armed <= true;
        end if;
      end if;

      ---- capture side
      prev_data <= data_deglitched;

      if prev_data /= data_deglitched then
        -- change of level, restart pulse measurement
        if capture_armed then
          if pulse_length = MaxPulseLen then
            -- found a very long space, start capture
            capture_armed  <= false;
            capture_active <= true;
            pulse_count    <= 0;
          end if;
        elsif capture_active then
          -- store pulse length in RAM
          dpram(pulse_count) <= std_logic_vector(to_unsigned(pulse_length, 18));
          if pulse_count = MaxPulseCount then
            capture_active <= false;
          else
            pulse_count <= pulse_count + 1;
          end if;
        end if;

        pulse_length <= 0;
      else
        if pulse_length /= MaxPulseLen then
          pulse_length <= pulse_length + 1;
        end if;
      end if;
    end if;
  end process;



end Behavioral;
