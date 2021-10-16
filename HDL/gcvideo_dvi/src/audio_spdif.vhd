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
-- audio_spdif.vhd: Audio-handling module
--
-- This module convers the I2S signal from the Gamecube into SPDIF.
-- Since there is no suitable 384fs clock available, the module
-- generates one using a phase accumulator. The resulting clock has
-- a bit of jitter, but it appears to be good enough for all SPDIF
-- receivers I can test.
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
use work.video_defs.all;

entity audio_spdif is
  port (
    Clock54    : in  std_logic;
    Clock162   : in  std_logic; -- 3*54 MHz
    ConsoleMode: in  console_mode_t;

    I2S_BClock : in  std_logic;
    I2S_LRClock: in  std_logic;
    I2S_Data   : in  std_logic;

    Volume     : in  unsigned(7 downto 0);

    Audio      : out AudioData;

    SPDIF_Out  : out std_logic
  );
end audio_spdif;

architecture Behavioral of audio_spdif is
  -- fractional clock enable generator for 384fs
  constant ClockDiv_Num_Wii: integer := 128;
  constant ClockDiv_Den_Wii: integer := 1125;
  constant ClockDiv_Num_GC : integer := 32;
  constant ClockDiv_Den_GC : integer := 281;

  signal clock_counter_wii: integer range -clockdiv_num_wii to clockdiv_den_wii := 0;
  signal clock_counter_gc : integer range -clockdiv_num_gc  to clockdiv_den_gc  := 0;
  signal clocken_spdif_wii: boolean;
  signal clocken_spdif_gc : boolean;
  signal clocken_spdif    : boolean;
  signal prev_mode        : console_mode_t := MODE_GC;

  -- cleaned-up versions of the I2S signals
  signal bclock : std_logic;
  signal lrclock: std_logic;
  signal adata  : std_logic;

  attribute keep: string;
  attribute keep of clocken_spdif:signal is "TRUE";

  -- audio samples
  signal audio_left          : signed(15 downto 0);
  signal audio_right         : signed(15 downto 0);
  signal audio_left_unscaled : signed(15 downto 0);
  signal audio_right_unscaled: signed(15 downto 0);
  signal enable_l            : boolean;
  signal enable_r            : boolean;
  signal enable_l_dly        : boolean;
  signal enable_r_dly        : boolean;

  -- syncing signals from other clock domains
  constant SYNC_LEVELS: integer := 3;

  type cmode_sync_t is array(0 to SYNC_LEVELS) of console_mode_t;

  signal consolemode_sync: cmode_sync_t;
  attribute shreg_extract: string;
  attribute shreg_extract of consolemode_sync: signal is "no";

  -- volume setting
  signal volume_adjusted     : signed(9 downto 0);

  function scale_audio(val: signed(15 downto 0); factor: signed(9 downto 0))
    return signed is
    variable tmp: signed(25 downto 0);
  begin
    tmp := val * factor;
    return tmp(23 downto 8);
  end function;

begin

  Audio.Left        <= audio_left;
  Audio.Right       <= audio_right;
  Audio.LeftEnable  <= enable_l_dly;
  Audio.RightEnable <= enable_r_dly;

  -- deglitch I2S signals
  Deglitch_BClock: Deglitcher GENERIC MAP (
    SyncBits    => 3,
    CompareBits => 2
  ) PORT MAP (
    Clock       => Clock54,
    ClockEnable => true,
    Input       => I2S_BClock,
    Output      => bclock
  );

  Deglitch_LRClock: Deglitcher GENERIC MAP (
    SyncBits    => 3,
    CompareBits => 2
  ) PORT MAP (
    Clock       => Clock54,
    ClockEnable => true,
    Input       => I2S_LRClock,
    Output      => lrclock
  );

  Deglitch_AData: Deglitcher GENERIC MAP (
    SyncBits    => 3,
    CompareBits => 2
  ) PORT MAP (
    Clock       => Clock54,
    ClockEnable => true,
    Input       => I2S_Data,
    Output      => adata
  );

  -- generate two clock enable signals for SPDIF, 384fs for Wii and GC modes
  process(Clock162)
  begin
    if rising_edge(Clock162) then
      consolemode_sync(0 to SYNC_LEVELS-1) <= consolemode_sync(1 to SYNC_LEVELS);
      consolemode_sync(SYNC_LEVELS)        <= ConsoleMode;
      prev_mode         <= consolemode_sync(0);
      clocken_spdif_wii <= false;
      clocken_spdif_gc  <= false;

      if prev_mode /= consolemode_sync(0) then
        -- reset counter on mode switch
        clock_counter_wii <= 0;
        clock_counter_gc  <= 0;

      else
        if clock_counter_wii < 0 then
          clock_counter_wii <= clock_counter_wii + ClockDiv_Den_Wii - ClockDiv_Num_Wii;
          clocken_spdif_wii <= true;
        else
          clock_counter_wii <= clock_counter_wii - ClockDiv_Num_Wii;
        end if;

        if clock_counter_gc < 0 then
          clock_counter_gc <= clock_counter_gc + ClockDiv_Den_GC - ClockDiv_Num_GC;
          clocken_spdif_gc <= true;
        else
          clock_counter_gc <= clock_counter_gc - ClockDiv_Num_GC;
        end if;

      end if;
    end if;
  end process;

  -- select one of the clock enable signals based on the current mode
  process(Clock162)
  begin
    if rising_edge(Clock162) then
      if consolemode_sync(0) = MODE_WII then
        clocken_spdif <= clocken_spdif_wii;
      else
        clocken_spdif <= clocken_spdif_gc;
      end if;
    end if;
  end process;

  -- read I2S audio data
  Inst_I2SDec: I2S_Decoder
    port map (
      Clock       => Clock54,
      ClockEnable => true,
      I2S_BClock  => bclock,
      I2S_LRClock => lrclock,
      I2S_Data    => adata,
      Left        => audio_left_unscaled,
      Right       => audio_right_unscaled,
      LeftEnable  => enable_l,
      RightEnable => enable_r
    );

  -- adjust volume
  process(Clock54)
    variable vol: unsigned(9 downto 0);
  begin
    if rising_edge(Clock54) then
      enable_l_dly <= enable_l;
      enable_r_dly <= enable_r;

      vol(7 downto 0) := Volume;
      vol(9 downto 8) := "00";
      volume_adjusted <= signed(vol) + 1;

      if enable_l then
        if Volume = x"00" then
          audio_left <= (others => '0');
        else
          audio_left <= scale_audio(audio_left_unscaled, volume_adjusted);
        end if;
      end if;

      if enable_r then
        if Volume = x"00" then
          audio_right <= (others => '0');
        else
          audio_right <= scale_audio(audio_right_unscaled, volume_adjusted);
        end if;
      end if;
    end if;
  end process;

  -- encode audio as SPDIF
  Inst_SPDIFEnc: SPDIF_Encoder
    port map (
      Clock54        => Clock54,
      Clock162       => Clock162,
      Clock162Enable => clocken_spdif,
      AudioLeft      => audio_left,
      AudioRight     => audio_right,
      EnableLeft     => enable_l,
      SPDIF          => SPDIF_Out
    );

end Behavioral;
