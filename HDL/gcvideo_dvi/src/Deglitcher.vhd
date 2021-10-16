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
-- Deglitcher.vhd: Consensus-based deglitcher plus synchronizer
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity Deglitcher is
  generic (
    SyncBits   : natural range 0 to 10;
    CompareBits: natural range 2 to 10
  );
  port (
    Clock      : in  std_logic;
    ClockEnable: in  boolean;
    Input      : in  std_logic;
    Output     : out std_logic
  );
end Deglitcher;

architecture Behavioral of Deglitcher is
  constant syncer_bits: natural := SyncBits + CompareBits;

  signal syncer: std_logic_vector(syncer_bits - 1 downto 0);
begin

  process (Clock, ClockEnable)
    variable i: natural;
    variable same: boolean;
  begin
    if rising_edge(Clock) and ClockEnable then
      syncer <= syncer(syncer_bits - 2 downto 0) & Input;

      -- check if the top CompareBits elements of syncer have the same value
      same := true;
      for i in 1 to CompareBits - 1 loop
        if syncer(SyncBits) /= syncer(i + SyncBits) then
          same := false;
        end if;
      end loop;

      -- if all top bits are identical, accept that value
      if same then
        Output <= syncer(SyncBits);
      end if;
    end if;
  end process;

end Behavioral;

