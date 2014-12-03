----------------------------------------------------------------------------------
-- GCVideo DVI HDL Version 1.0
-- Copyright (C) 2014, Ingo Korb <ingo@akana.de>
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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
library UNISIM;
use UNISIM.VComponents.all;


entity ClockGen is
  PORT (
    ClockIn  : in  std_logic;
    Reset    : in  std_logic;
    Clock54M : out std_logic;
    DVIClockP: out std_logic;
    DVIClockN: out std_logic;
    Locked   : out std_logic
  );
end ClockGen;

architecture Behavioral of ClockGen is
	-- Input clock buffering
  signal ClockIn_internal     : std_logic;
  signal ClockIn_internal_neg : std_logic;
  -- Output clock buffering
  signal dvip_internal: std_logic;
  signal dvin_internal: std_logic;
  signal dcm_clkfb    : std_logic;
  signal dcm_clk2x    : std_logic;
  signal dcm_clkfx    : std_logic;
  signal dcm_clkfx180 : std_logic;
  signal dcm_clkfbout : std_logic;
  signal dcm_locked   : std_logic;
  signal dcm_reset    : std_logic;
  signal dcm_status   : std_logic_vector(7 downto 0);
  signal clock_54_internal: std_logic;

begin
  Locked <= dcm_locked;

  -- Input buffering
  --------------------------------------
  clkin1_buf : IBUFG
  port map
   (O => ClockIn_internal_neg,
    I => ClockIn);

  ClockIn_internal <= not ClockIn_internal_neg;

  -- Clocking primitive 1
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
    CLKFB                 => dcm_clkfb,
    -- Output clocks
    CLK0                  => open,
    CLK90                 => open,
    CLK180                => open,
    CLK270                => open,
    CLK2X                 => dcm_clk2x,
    CLK2X180              => open,
    CLKFX                 => dcm_clkfx,
    CLKFX180              => dcm_clkfx180,
    CLKDV                 => open,
   -- Ports for dynamic phase shift
    PSCLK                 => '0',
    PSEN                  => '0',
    PSINCDEC              => '0',
    PSDONE                => open,
   -- Other control and status signals
    LOCKED                => dcm_locked,
    STATUS                => dcm_status,
    RST                   => dcm_reset,
   -- Unused pin, tie low
    DSSEN                 => '0');

  -- feedback
  dcm_clkfb <= clock_54_internal;

  -- auto-reset on clock trouble
  process(Reset, dcm_locked, dcm_status)
  begin
    dcm_reset <= Reset or (dcm_status(2) and not dcm_locked);
  end process;

  -- Output buffering
  -------------------------------------

  clk54_buf: BUFG PORT MAP (
    I => dcm_clk2x,
    O => clock_54_internal
  );
  Clock54M <= clock_54_internal;

  dviclkp_buf: BUFG PORT MAP (
    I => dcm_clkfx,
    O => dvip_internal
  );

  dviclkn_buf: BUFG PORT MAP (
    I => dcm_clkfx180,
    O => dvin_internal
  );

  DVIClockP  <= dvip_internal;
  DVIClockN  <= dvin_internal;
  
end Behavioral;
