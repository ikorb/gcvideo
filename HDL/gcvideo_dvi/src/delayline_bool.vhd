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
-- delayline_bool: A simple delay line for boolean-typed values
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity delayline_bool is
  generic (
    Delayticks: Natural := 4
  );
  port (
    Clock      : in  std_logic;
    ClockEnable: in  boolean;
    Input      : in  boolean;
    Output     : out boolean
  );
end delayline_bool;

architecture Behavioral of delayline_bool is
  type   delay_type is array(Delayticks - 2 downto 0) of boolean;
  signal delayline: delay_type;
begin

  ZeroTicks: if Delayticks = 0 generate
    Output <= Input;
  end generate;

  OneTick: if Delayticks = 1 generate
    process(Clock, ClockEnable)
    begin
      if rising_edge(Clock) and ClockEnable then
        Output <= Input;
      end if;
    end process;
  end generate;

  ManyTicks: if delayticks > 1 generate
    process (Clock, ClockEnable)
    begin
      if rising_edge(Clock) and ClockEnable then
        Output <= delayline(delayline'high);
        delayline(delayline'high downto 1) <= delayline(delayline'high - 1 downto 0);
        delayline(0) <= Input;
      end if;
    end process;
  end generate;

end Behavioral;

