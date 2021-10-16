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
-- ConsoleModeDetect: Detection of console mode for Wii
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.Component_Defs.all;
use work.video_defs.all;

entity ConsoleModeDetect is
  port (
    Clock      : in  std_logic;
    I2S_LRClock: in  std_logic;
    ConsoleMode: out console_mode_t
  );
end ConsoleModeDetect;

architecture Behavioral of ConsoleModeDetect is
  signal cmode_toggle: boolean := false;
  signal lrclock     : std_logic;
  signal prev_lrclock: std_logic;
begin

  Deglitch_LRClock: Deglitcher GENERIC MAP (
    SyncBits    => 3,
    CompareBits => 2
  ) PORT MAP (
    Clock       => Clock,
    ClockEnable => true,
    Input       => I2S_LRClock,
    Output      => lrclock
  );

  process(Clock)
  begin
    if rising_edge(Clock) then
      cmode_toggle <= not cmode_toggle;

      if prev_lrclock = '0' and lrclock = '1' then
        -- check only for even/odd instead of 1124 vs. 1125
        if cmode_toggle then
          ConsoleMode <= MODE_GC;
        else
          ConsoleMode <= MODE_WII;
        end if;

        cmode_toggle <= false;
      end if;

      prev_lrclock <= lrclock;
    end if;
  end process;

end Behavioral;
