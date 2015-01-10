----------------------------------------------------------------------------------
-- GCVideo Lite HDL Version 1.1
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
-- audio_spdif.vhd: Audio-handling module
--
-- This module convers the I2S signal from the Gamecube into SPDIF.
-- Since there is no suitable 128fs clock available, the module
-- generates one using a phase accumulator. The resulting clock has
-- a bit of jitter, but it appears to be good enough for all SPDIF
-- receivers I can test. For FPGAs with an on-chip PLL the jitter could
-- be reduced by generating a faster input clock and multiplying the
-- clockdiv_den constant by the multiplication factor of the PLL.
--
-- Using an external crystal is not a viable alternative because the
-- SPDIF encoder expects that the input data arrives at exactly the same
-- rate as the output signal needs it.
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.Component_Defs.all;

entity audio_spdif is
  port (
    Clock      : in  std_logic; -- 54 MHz

    I2S_BClock : in  std_logic;
    I2S_LRClock: in  std_logic;
    I2S_Data   : in  std_logic;

    SPDIF_Out  : out std_logic
  );
end audio_spdif;

architecture Behavioral of audio_spdif is
  constant clockdiv_num: integer := 32;
  constant clockdiv_den: integer := 281;

  -- cleaned-up versions of the I2S signals
  signal bclock : std_logic;
  signal lrclock: std_logic;
  signal adata  : std_logic;

  -- clock enable generation
  signal clock_counter: integer range -clockdiv_num to clockdiv_den := 0;
  signal clocken_spdif: boolean;

  -- audio samples
  signal audio_left : signed(15 downto 0);
  signal audio_right: signed(15 downto 0);
  signal enable_l   : boolean;
  signal enable_r   : boolean;

begin

  -- deglitch I2S signals
  Deglitch_BClock: Deglitcher GENERIC MAP (
    SyncBits    => 3,
    CompareBits => 2
  ) PORT MAP (
    Clock       => Clock,
    ClockEnable => true,
    Input       => I2S_BClock,
    Output      => bclock
  );

  Deglitch_LRClock: Deglitcher GENERIC MAP (
    SyncBits    => 3,
    CompareBits => 2
  ) PORT MAP (
    Clock       => Clock,
    ClockEnable => true,
    Input       => I2S_LRClock,
    Output      => lrclock
  );

  Deglitch_AData: Deglitcher GENERIC MAP (
    SyncBits    => 3,
    CompareBits => 2
  ) PORT MAP (
    Clock       => Clock,
    ClockEnable => true,
    Input       => I2S_Data,
    Output      => adata
  );

  -- generate a clock enable signal for SPDIF, 128*f_s
  process(Clock)
  begin
    if rising_edge(Clock) then
      if clock_counter < 0 then
        clock_counter <= clock_counter + clockdiv_den - clockdiv_num;
        clocken_spdif <= true;
      else
        clock_counter <= clock_counter - clockdiv_num;
        clocken_spdif <= false;
      end if;
    end if;
  end process;

  -- read I2S audio data
  Inst_I2SDec: I2S_Decoder
    PORT MAP (
      Clock       => Clock,
      ClockEnable => clocken_spdif,
      I2S_BClock  => bclock,
      I2S_LRClock => lrclock,
      I2S_Data    => adata,
      Left        => audio_left,
      Right       => audio_right,
      LeftEnable  => enable_l,
      RightEnable => enable_r
    );

  -- encode audio as SPDIF
  Inst_SPDIFEnc: SPDIF_Encoder
    PORT MAP (
      Clock       => Clock,
      ClockEnable => clocken_spdif,
      AudioLeft   => audio_left,
      AudioRight  => audio_right,
      EnableLeft  => enable_l,
      SPDIF       => SPDIF_Out
    );

end Behavioral;
