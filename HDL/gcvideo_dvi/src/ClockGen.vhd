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
-- ClockGen.vhd: Clock generator for Spartan 3A/6 with DVI output
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

library UNISIM;
use UNISIM.VComponents.all;
use work.component_defs.all;


entity ClockGen is
  generic (
    TargetConsole: string  -- "GC" or "WII"
  );
  port (
    ClockIn   : in  std_logic;
    BClock    : in  std_logic;
    Clock54M  : out std_logic;
    ClockAudio: out std_logic;
    DVIClockP : out std_logic;
    DVIClockN : out std_logic;
    Locked    : out std_logic
  );
end ClockGen;

architecture Behavioral of ClockGen is
  -- Input clock buffering
  signal ClockIn_internal     : std_logic;
  signal ClockIn_internal_neg : std_logic;

  -- Output clock buffering
  signal dvip_internal    : std_logic;
  signal dvin_internal    : std_logic;
  signal vdcm_clkfb       : std_logic;
  signal vdcm_clk0        : std_logic;
  signal vdcm_clk2x       : std_logic;
  signal vdcm_clkfx       : std_logic;
  signal vdcm_clkfx180    : std_logic;
  signal vdcm_clkfbout    : std_logic;
  signal vdcm_locked      : std_logic;
  signal vdcm_reset       : std_logic := '1';
  signal vdcm_status      : std_logic_vector(7 downto 0);
  signal clock_54_internal: std_logic;

  signal adcm_clkfb          : std_logic;
  signal adcm_clk0           : std_logic;
  signal adcm_clkfx          : std_logic;
  signal adcm_locked         : std_logic;
  signal adcm_locked_sync    : std_logic_vector(2 downto 0) := (others => '0');
  signal adcm_reset          : std_logic := '1';
  signal adcm_status         : std_logic_vector(7 downto 0);
  signal adcm_status_sync1   : std_logic_vector(7 downto 0);
  signal adcm_status_sync2   : std_logic_vector(7 downto 0);
  signal adcm_reset_count    : natural range 0 to 7 := 0;
  signal clock_audio_internal: std_logic;

  -- clock reset logic
  type reset_state_t is (WAIT_FOR_BCLOCK, RESET_RELEASE, RUNNING);

  signal reset_state      : reset_state_t := WAIT_FOR_BCLOCK;

  signal vdcm_locked_sync : std_logic_vector(2 downto 0) := (others => '0');
  signal vdcm_status_sync1: std_logic_vector(7 downto 0);
  signal vdcm_status_sync2: std_logic_vector(7 downto 0);

  signal bclock_deglitched: std_logic;
  signal prev_bclock      : std_logic;
  signal reset_count      : natural range 0 to 7 := 7;

begin
  Locked <= vdcm_locked; --and adcm_locked;

  Deglitch_BClock: Deglitcher GENERIC MAP (
    SyncBits    => 3,
    CompareBits => 2
  ) PORT MAP (
    Clock       => ClockIn_internal,
    ClockEnable => true,
    Input       => BClock,
    Output      => bclock_deglitched
  );


  -- Input buffering
  --------------------------------------
  clkin1_buf : IBUFG
  port map
   (O => ClockIn_internal_neg,
    I => ClockIn);

  ClockIn_internal <= not ClockIn_internal_neg;

  -- Clocking primitive 1 - System+Video
  --------------------------------------

  video_dcm_sp_inst: DCM_SP
  generic map
   (CLKDV_DIVIDE          => 2.0,
    CLKFX_DIVIDE          => 2,
    CLKFX_MULTIPLY        => 5,
    CLKIN_DIVIDE_BY_2     => false,
    CLKOUT_PHASE_SHIFT    => "NONE",
    CLK_FEEDBACK          => "1X",
    DESKEW_ADJUST         => "SYSTEM_SYNCHRONOUS",
    PHASE_SHIFT           => 0,
    STARTUP_WAIT          => FALSE)
  port map
   -- Input clock
   (CLKIN                 => ClockIn_internal,
    CLKFB                 => vdcm_clkfb,
    -- Output clocks
    CLK0                  => vdcm_clk0,
    CLK90                 => open,
    CLK180                => open,
    CLK270                => open,
    CLK2X                 => vdcm_clk2x,
    CLK2X180              => open,
    CLKFX                 => vdcm_clkfx,
    CLKFX180              => vdcm_clkfx180,
    CLKDV                 => open,
   -- Ports for dynamic phase shift
    PSCLK                 => '0',
    PSEN                  => '0',
    PSINCDEC              => '0',
    PSDONE                => open,
   -- Other control and status signals
    LOCKED                => vdcm_locked,
    STATUS                => vdcm_status,
    RST                   => vdcm_reset,
   -- Unused pin, tie low
    DSSEN                 => '0');

  -- feedback
  vdcm_clkfb <= clock_54_internal;


  wii_startdelay: if TargetConsole = "WII" generate
    -- hold DCMs in reset until Wii clock stabilizes
    --
    -- Wii clock switches to 27MHz for part of the boot process,
    -- this procedure delays GCVideo boot until the input is back to 54MHz.
    process(ClockIn_internal)
    begin
      if rising_edge(ClockIn_internal) then
        -- sync DCM signals
        vdcm_locked_sync  <= vdcm_locked_sync(1 downto 0) & vdcm_locked;
        vdcm_status_sync2 <= vdcm_status_sync1;
        vdcm_status_sync1 <= vdcm_status;

        prev_bclock <= bclock_deglitched;

        case reset_state is
          when WAIT_FOR_BCLOCK =>
            -- wait for a few edges on bclock before starting to release reset
            if bclock_deglitched /= prev_bclock then
              if reset_count = 0 then
                reset_state <= RESET_RELEASE;
                reset_count <= 7;
              else
                reset_count <= reset_count - 1;
              end if;
            end if;

          when RESET_RELEASE =>
            -- hold reset for seven more input clocks
            if reset_count = 0 then
              reset_state <= RUNNING;
            else
              reset_count <= reset_count - 1;
            end if;

          when RUNNING =>
            if vdcm_status_sync2(1) = '1' or -- CLKIN not toggling
               vdcm_status_sync2(2) = '1' or -- CLKFX not toggling
              (vdcm_locked_sync(2) = '1' and vdcm_locked_sync(1) = '0') then -- DCM lock lost
              reset_state <= WAIT_FOR_BCLOCK;
              reset_count <= 7;
              vdcm_reset  <= '1';
            else
              vdcm_reset  <= '0';
            end if;

        end case;
      end if;
    end process;

  end generate;

  gc_lockreset: if TargetConsole = "GC" generate
    -- Gamecube turns on 54MHz and stays there
    process(ClockIn_internal)
    begin
      if rising_edge(ClockIn_internal) then
        -- sync DCM signals
        vdcm_locked_sync  <= vdcm_locked_sync(1 downto 0) & vdcm_locked;
        vdcm_status_sync2 <= vdcm_status_sync1;
        vdcm_status_sync1 <= vdcm_status;

        case reset_state is
          when WAIT_FOR_BCLOCK | RESET_RELEASE =>
            -- hold reset for seven more input clocks
            if reset_count = 0 then
              reset_state <= RUNNING;
            else
              reset_count <= reset_count - 1;
            end if;

          when RUNNING =>
            if vdcm_status_sync2(1) = '1' or -- CLKIN not toggling
               vdcm_status_sync2(2) = '1' or -- CLKFX not toggling
              (vdcm_locked_sync(2) = '1' and vdcm_locked_sync(1) = '0') then -- DCM lock lost
              reset_state <= WAIT_FOR_BCLOCK;
              reset_count <= 7;
              vdcm_reset  <= '1';
            else
              vdcm_reset  <= '0';
            end if;

        end case;
      end if;
    end process;

  end generate;


  -- Clocking primitive 2 - Audio
  --   needs a fast clock to keep the SPDIF
  --   clock jitter low (32/216 * 54MHz)
  --------------------------------------
  audio_dcm_sp_inst: DCM_SP
  generic map
   (CLKDV_DIVIDE          => 2.0,
    CLKFX_DIVIDE          => 1,
    CLKFX_MULTIPLY        => 6,
    CLKIN_DIVIDE_BY_2     => true,
    CLKOUT_PHASE_SHIFT    => "NONE",
    CLK_FEEDBACK          => "1X",
    DESKEW_ADJUST         => "SYSTEM_SYNCHRONOUS",
    PHASE_SHIFT           => 0,
    STARTUP_WAIT          => FALSE)
  port map
   -- Input clock
   (CLKIN                 => ClockIn_internal,
    CLKFB                 => adcm_clkfb,
    -- Output clocks
    CLK0                  => adcm_clk0,
    CLK90                 => open,
    CLK180                => open,
    CLK270                => open,
    CLK2X                 => open,
    CLK2X180              => open,
    CLKFX                 => adcm_clkfx,
    CLKFX180              => open,
    CLKDV                 => open,
   -- Ports for dynamic phase shift
    PSCLK                 => '0',
    PSEN                  => '0',
    PSINCDEC              => '0',
    PSDONE                => open,
   -- Other control and status signals
    LOCKED                => adcm_locked,
    STATUS                => adcm_status,
    RST                   => adcm_reset or vdcm_reset,
   -- Unused pin, tie low
    DSSEN                 => '0');

  -- feedback
  adcm_clkfb <= adcm_clk0;

  -- auto-reset on clock trouble
  process(ClockIn_internal)
  begin
    if rising_edge(ClockIn_internal) then
      -- sync DCM signals
      adcm_locked_sync  <= adcm_locked_sync(1 downto 0) & adcm_locked;
      adcm_status_sync2 <= adcm_status_sync1;
      adcm_status_sync1 <= adcm_status;

      -- ensure reset is held for a few clocks
      adcm_reset <= '0';
      if adcm_reset_count > 0 then
        adcm_reset_count <= adcm_reset_count - 1;
        adcm_reset       <= '1';
      else
        -- check failure indicators
        if adcm_status_sync2(1) = '1' or -- CLKIN not toggling
           adcm_status_sync2(2) = '1' or -- CLKFX not toggling
          (adcm_locked_sync(2) = '1' and adcm_locked_sync(1) = '0') then
          adcm_reset_count <= 7;
        end if;
      end if;
    end if;
  end process;

  -- Output buffering
  -------------------------------------

  clk54_buf: BUFG PORT MAP (
    I => vdcm_clk0,
    O => clock_54_internal
  );
  Clock54M <= clock_54_internal;

  dviclkp_buf: BUFG PORT MAP (
    I => vdcm_clkfx,
    O => dvip_internal
  );

  dviclkn_buf: BUFG PORT MAP (
    I => vdcm_clkfx180,
    O => dvin_internal
  );

  DVIClockP  <= dvip_internal;
  DVIClockN  <= dvin_internal;

  -- buffer clkfx output of DCM
  clkaud_gc_buf: BUFG PORT MAP (
    I => adcm_clkfx,
    O => clock_audio_internal
  );

  ClockAudio <= clock_audio_internal;

end Behavioral;
