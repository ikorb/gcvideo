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
-- led_heartbeat.vhd: LED blinking patterns based on clock and VSync
--
----------------------------------------------------------------------------------

library IEEE;

use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library UNISIM;
use UNISIM.VComponents.all;

use work.Component_Defs.all;
use work.video_defs.all;

entity LED_Heartbeat is
  port (
    Clock          : in  std_logic;
    VSync          : in  std_logic;
    HeartbeatClock : out std_logic;
    HeartbeatVSync : out std_logic;
    HeartbeatVSync2: out std_logic
  );
end LED_Heartbeat;

architecture Behavioral of LED_Heartbeat is
  type vsync_counter_t is range 0 to 119;
  type clock_counter_t is range 0 to 2 ** 22 - 1;

  signal vsync_counter  : vsync_counter_t := 0;
  signal clock_counter  : clock_counter_t := 0;
  signal clock_phase    : natural range 0 to 3 := 0;
  signal hb_clock       : std_logic := '0';
  signal hb_vsync       : std_logic := '0';
  signal hb_vs_capture  : std_logic := '0';
  signal prev_vsync     : std_logic := '0';

begin

  process(Clock)
  begin
    if rising_edge(Clock) then
      if prev_vsync /= VSync then
        if vsync_counter /= 0 then
          vsync_counter <= vsync_counter - 1;
        else
          vsync_counter <= vsync_counter_t'high;
          hb_vsync <= not hb_vsync;
        end if;
      end if;
      prev_vsync <= VSync;

      if clock_counter /= 0 then
        clock_counter <= clock_counter - 1;
      else
        clock_counter <= clock_counter_t'high;

        if clock_phase /= 0 then
          clock_phase <= clock_phase - 1;
          hb_clock    <= '0';
        else
          clock_phase   <= 3;
          hb_clock      <= '1';
          hb_vs_capture <= hb_vsync;
        end if;
      end if;
    end if;
  end process;

  HeartbeatClock  <= hb_clock;
  HeartbeatVsync  <= hb_vs_capture;
  HeartbeatVsync2 <= hb_vsync;

end Behavioral;
