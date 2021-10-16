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
-- ZPU_SPI.vhd: SPI and ICAP interface for ZPU
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library UNISIM;
use UNISIM.vcomponents.ICAP_SPARTAN3A;

use work.ZPUDevices.all;

entity ZPU_SPI is
  generic (
    SPIClockDiv: natural range 1 to 255
  );
  port (
    Clock    : in  std_logic;
    ZSelect  : in  std_logic; -- ZPU peripheral select
    ZPUBusIn : in  ZPUDeviceIn;
    ZPUBusOut: out ZPUDeviceOut;
    SCOPI    : out std_logic; -- SPI controller out, peripheral in
    SCIPO    : in  std_logic; -- SPI controller in, peripheral out
    SClock   : out std_logic; -- SPI clock
    SSelect  : out std_logic  -- SPI select
  );
end ZPU_SPI;

architecture Behavioral of ZPU_SPI is
  signal spi_clockcounter: natural range 0 to SPIClockDiv-1 := 0;
  signal spi_clock       : std_logic                        := '1';
  signal spi_sel         : std_logic                        := '1';
  signal spi_data        : std_logic_vector(7 downto 0)     := (others => '0');
  signal spi_state       : natural range 0 to 9             := 0;
  signal spi_active      : boolean                          := false;

  signal icap_out  : std_logic_vector(7 downto 0); -- 7 is LSB!
  signal icap_in   : std_logic_vector(7 downto 0); -- 7 is LSB!
  signal icap_clock: std_logic := '0';
  signal icap_ce   : std_logic := '0';
  signal icap_write: std_logic := '0';
  signal icap_busy : std_logic;

begin
  SSelect <= spi_sel;
  SClock  <= spi_clock;

  ZPUBusOut.mem_busy <= '1' when spi_active else '0'; -- hold CPU while busy

  icap_inst: ICAP_SPARTAN3A
    port map (
      BUSY  => icap_busy,
      O     => icap_out,
      CE    => not icap_ce, -- active-low input
      CLK   => icap_clock,
      I     => icap_in,
      WRITE => not icap_write -- active-low input
    );

  process(Clock)
  begin
    if rising_edge(Clock) then
      if ZPUBusIn.Reset = '1' then
        spi_state        <= 0;
        spi_active       <= false;
        SCOPI            <= '1';
        spi_sel          <= '1';
        spi_clock        <= '1';
        spi_clockcounter <= 0;
        spi_data         <= (others => '0');
      else
        -- ZPU interface
        if ZSelect = '1' then
          if ZPUBusIn.mem_writeEnable = '1' then
            -- write access
            case ZPUBusIn.mem_addr(4 downto 2) is
              -- SPI
              when "000" =>
                spi_data         <= ZPUBusIn.mem_write(7 downto 0);
                spi_state        <= 0;
                spi_active       <= true;
                SCOPI            <= ZPUBusIn.mem_write(7); -- output first bit immediately
                spi_clockcounter <= SPIClockDiv - 1;

              when "001" =>
                spi_sel <= ZPUBusIn.mem_write(0);

              -- ICAP
              when "100" =>
                for i in 0 to 7 loop
                  icap_in(i) <= ZPUBusIn.mem_write(7 - i);
                end loop;

              when "101" =>
                icap_clock <= ZPUBusIn.mem_write(0);
                icap_ce    <= ZPUBusIn.mem_write(1);
                icap_write <= ZPUBusIn.mem_write(2);

              when others => null;
            end case;

          else
            -- read access
            ZPUBusOut.mem_read <= (others => '0');

            case ZPUBusIn.mem_addr(4 downto 2) is
              -- SPI
              when "000" =>
                ZPUBusOut.mem_read(7 downto 0) <= spi_data;

              when "001" =>
                ZPUBusOut.mem_read(0) <= spi_sel;
                if spi_active then
                  ZPUBusOut.mem_read(1) <= '1';
                end if;

              -- ICAP
              when "100" =>
                for i in 0 to 7 loop
                  ZPUBusOut.mem_read(i) <= icap_out(7 - i);
                end loop;

              when "101" =>
                ZPUBusOut.mem_read(0) <= icap_busy;

              when others => null;

            end case;
          end if;
        end if;

        -- SPI state machine
        if spi_active = true then
          if spi_clockcounter /= 0 then
            spi_clockcounter <= spi_clockcounter - 1;
          else
            spi_clockcounter <= SPIClockDiv - 1;

            if spi_clock = '0' then
              if spi_state = 9 then
                -- SPI is no longer busy
                spi_active <= false;
              else
                -- at the rising edge, sample input
                spi_clock <= '1';
                spi_data  <= spi_data(6 downto 0) & SCIPO;
                spi_state <= spi_state + 1;
              end if;
            else
              -- at the falling edge, change output
              spi_clock <= '0';
              if spi_state = 8 then
                SCOPI     <= '1';
                spi_state <= 9;
              else
                SCOPI <= spi_data(7);
              end if;
            end if;
          end if;
        end if;

      end if;
    end if;
  end process;

end Behavioral;
