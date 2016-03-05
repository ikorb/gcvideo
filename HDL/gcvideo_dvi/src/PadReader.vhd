----------------------------------------------------------------------------------
-- GCVideo DVI HDL
-- Copyright (C) 2014-2016, Ingo Korb <ingo@akana.de>
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
-- PadReader.vhd: Gamecube controller snooping module
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.component_defs.all;
use work.ZPUDevices.all;

entity PadReader is
  port (
    Clock    : in  std_logic;
    ZSelect  : in  std_logic;
    ZPUBusIn : in  ZPUDeviceIn;
    ZPUBusOut: out ZPUDeviceOut;
    IRQ      : out std_logic;
    PadData  : in  std_logic
  );
end PadReader;

architecture Behavioral of PadReader is
  -- number of clocks until a transfer is considered to be finished
  -- Hama clone pad needs ~9.3us to respond, so this timeout must be larger
  -- SD Media Loader sometimes retriggers controller poll after 13us, so this timeout must be smaller
  -- TODO: Maybe increase again (was 2047) and stop after 90 bits instead?
  constant TimeoutLength: natural := 700;
  constant SamplePoint  : natural := 100; -- was 128, but that fails with one specific NES adapter

  signal data_deglitched: std_logic;
  signal prev_data      : std_logic;
  signal pulselength    : natural range 0 to TimeoutLength;
  signal irq_internal   : std_logic := '0';

  signal bitshifter     : std_logic_vector(95 downto 0);
  signal bits           : unsigned(6 downto 0);
  signal packet_done    : boolean := true;
begin

  IRQ <= irq_internal;

  Deglitch_Pad: Deglitcher GENERIC MAP (
    SyncBits    => 3,
    CompareBits => 2
  ) PORT MAP (
    Clock       => Clock,
    ClockEnable => true,
    Input       => PadData,
    Output      => data_deglitched
  );

  ZPUBusOut.mem_busy <= '0';

  process(Clock)
  begin
    if rising_edge(Clock) then
      ---- read data from controller ----
      prev_data <= data_deglitched;

      -- check for start of bit
      if prev_data = '1' and data_deglitched = '0' then
        if packet_done then
          bitshifter  <= (others => '0');
          bits        <= (others => '0');
          packet_done <= false;
        end if;

        pulselength <= 0;
      else
        -- measure pulse length
        if pulselength < TimeoutLength then
          pulselength <= pulselength + 1;

          if pulselength = SamplePoint then
            -- sample bit
            bits       <= bits + 1;
            bitshifter <= bitshifter(94 downto 0) & data_deglitched;
          end if;
        elsif not packet_done then
          -- timer overflow, end of packet
          irq_internal <= '1';
          packet_done  <= true;
        end if;
      end if;

      ---- ZPU bus interface ----

      -- reset interrupt on any write or reset
      if (ZSelect = '1' and ZPUBusIn.mem_writeEnable = '1') or
          ZPUBusIn.Reset = '1' then
        irq_internal <= '0';
      end if;

      case ZPUBusIn.mem_addr(3 downto 2) is
        when "00" => ZPUBusOut.mem_read <= bitshifter(95 downto 64);
        when "01" => ZPUBusOut.mem_read <= bitshifter(63 downto 32);
        when "10" => ZPUBusOut.mem_read <= bitshifter(31 downto  0);
        when "11" =>
          ZPUBusOut.mem_read             <= (others => '0');
          ZPUBusOut.mem_read(6 downto 0) <= std_logic_vector(bits);
        when others => null;
      end case;

    end if;
  end process;

end Behavioral;

