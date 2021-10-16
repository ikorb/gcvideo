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
-- ZPUWatchdog.vhd: Watchdog to reset after a few frames without trigger
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.video_defs.all;
use work.ZPUDevices.all;

entity ZPUWatchdog is
  generic (
    TriggerLimit: natural range 1 to 1000
  );
  port (
    Clock  : in  std_logic;
    Video  : in  VideoY422;
    Trigger: in  std_logic;
    Reset  : out std_logic
  );
end ZPUWatchdog;

architecture Behavioral of ZPUWatchdog is
  signal prev_vsync : boolean := false;
  signal vsync_count: natural range 0 to TriggerLimit := TriggerLimit;
begin

  process(Clock)
  begin
    if rising_edge(Clock) then
      prev_vsync <= Video.VSync;

      -- reset counter on trigger signal
      if Trigger = '1' then
        vsync_count <= TriggerLimit;
      end if;

      -- count frames
      if Video.VSync and not prev_vsync then
        Reset <= '0';

        if vsync_count = 0 then
          -- no trigger seen for multiple frames, activate reset
          Reset       <= '1';
          vsync_count <= TriggerLimit;
        else
          vsync_count <= vsync_count - 1;
        end if;

      end if;
    end if;
  end process;

end Behavioral;

