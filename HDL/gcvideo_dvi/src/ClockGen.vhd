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
-- ClockGen.vhd: Clock generator for Spartan 3A/6 with DVI output
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

library UNISIM;
use UNISIM.VComponents.all;


entity ClockGen is
  PORT (
    ClockIn   : in  std_logic;
    Reset     : in  std_logic;
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
  signal vdcm_clk2x       : std_logic;
  signal vdcm_clkfx       : std_logic;
  signal vdcm_clkfx180    : std_logic;
  signal vdcm_clkfbout    : std_logic;
  signal vdcm_locked      : std_logic;
  signal vdcm_reset       : std_logic;
  signal vdcm_status      : std_logic_vector(7 downto 0);
  signal clock_54_internal: std_logic;

  signal adcm_clkfb          : std_logic;
  signal adcm_clk0           : std_logic;
  signal adcm_clkfx          : std_logic;
  signal adcm_locked         : std_logic;
  signal adcm_reset          : std_logic;
  signal adcm_status         : std_logic_vector(7 downto 0);
  signal clock_audio_internal: std_logic;

begin
  Locked <= vdcm_locked and adcm_locked;

  -- Input buffering
  --------------------------------------
  clkin1_buf : IBUFG
  port map
   (O => ClockIn_internal_neg,
    I => ClockIn);

  ClockIn_internal <= not ClockIn_internal_neg;

  -- Clocking primitive 1 - System+Video
  --------------------------------------

  -- Instantiation of the DCM primitive
  --    * Unused inputs are tied off
  --    * Unused outputs are labeled unused
  video_dcm_sp_inst: DCM_SP
  generic map
   (CLKDV_DIVIDE          => 2.0,
    CLKFX_DIVIDE          => 1,
    CLKFX_MULTIPLY        => 5,
    CLKIN_DIVIDE_BY_2     => true,
    CLKOUT_PHASE_SHIFT    => "NONE",
    CLK_FEEDBACK          => "2X",
    DESKEW_ADJUST         => "SYSTEM_SYNCHRONOUS",
    PHASE_SHIFT           => 0,
    STARTUP_WAIT          => TRUE)
  port map
   -- Input clock
   (CLKIN                 => ClockIn_internal,
    CLKFB                 => vdcm_clkfb,
    -- Output clocks
    CLK0                  => open,
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

  -- auto-reset on clock trouble
  process(Reset, vdcm_locked, vdcm_status)
  begin
    vdcm_reset <= Reset or (vdcm_status(2) and not vdcm_locked);
  end process;


  -- Clocking primitive 2 - Audio
  -- needs a fast clock to keep the SPDIF
  -- clock jitter low (32/216 * 54MHz)
  --------------------------------------

  -- Instantiation of the DCM primitive
  --    * Unused inputs are tied off
  --    * Unused outputs are labeled unused
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
    STARTUP_WAIT          => TRUE)
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
    RST                   => adcm_reset,
   -- Unused pin, tie low
    DSSEN                 => '0');

  -- feedback
  adcm_clkfb <= adcm_clk0;

  -- auto-reset on clock trouble
  process(Reset, adcm_locked, adcm_status)
  begin
    adcm_reset <= Reset or (adcm_status(2) and not adcm_locked);
  end process;

  -- Output buffering
  -------------------------------------

  clk54_buf: BUFG PORT MAP (
    I => vdcm_clk2x,
    O => clock_54_internal
  );
  Clock54M <= clock_54_internal;

  clkaud_buf: BUFG PORT MAP (
    I => adcm_clkfx,
    O => clock_audio_internal
  );
  ClockAudio <= clock_audio_internal;

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

end Behavioral;
