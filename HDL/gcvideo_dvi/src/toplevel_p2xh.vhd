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
-- toplevel_p2xh.vhd: top level module for the Pluto IIx HDMI board
--
----------------------------------------------------------------------------------

library IEEE;

use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library UNISIM;
use UNISIM.VComponents.all;

use work.Component_Defs.all;
use work.video_defs.all;

entity toplevel_p2xh is
  generic (
    TargetConsole: string; -- "GC" or "WII"
    SwapRed      : string := "NO";
    SwapGreen    : string := "NO";
    SwapBlue     : string := "NO";
    Firmware     : string;
    Module       : string
  );
  port (
    -- clocks
    VClockN    : in  std_logic;

    -- gamecube video signals
    VData      : in  std_logic_vector(7 downto 0);
    CSel       : in  std_logic; -- usually named ClkSel, but it's really a color select
    CableDetect: out std_logic;

    -- console audio signals
    I2S_BClock : in  std_logic;
    I2S_LRClock: in  std_logic;
    I2S_Data   : in  std_logic;

    -- gamecube controller
    PadData    : in  std_logic;

    -- IR receiver
    IRReceiver : in  std_logic;
    IRButton   : in  std_logic;

    -- flash chip
    Flash_COPI : out std_logic;
    Flash_CIPO : in  std_logic;
    Flash_SCK  : out std_logic;
    Flash_SEL  : out std_logic;
    Flash_Hold : out std_logic;

    -- board-internal
    LED1       : out std_logic;
    LED2       : out std_logic;

    -- audio out
    SPDIF_Out  : out std_logic;

    -- video out
    DVI_Clock  : out   std_logic_vector(1 downto 0);
    DVI_Red    : out   std_logic_vector(1 downto 0);
    DVI_Green  : out   std_logic_vector(1 downto 0);
    DVI_Blue   : out   std_logic_vector(1 downto 0);
    DDC_SCL    : inout std_logic;
    DDC_SDA    : inout std_logic
  );
end toplevel_p2xh;

architecture Behavioral of toplevel_p2xh is
  signal pipe_clock     : std_logic;
  signal console_mode   : console_mode_t;
  signal video_vsync    : std_logic;
  signal heartbeat_clock: std_logic;
  signal heartbeat_vsync: std_logic;
  signal swap_red       : Pair_Swap_t;
  signal swap_green     : Pair_Swap_t;
  signal swap_blue      : Pair_Swap_t;

begin

  swap_red   <= Pair_Regular when SwapRed   = "NO" else Pair_Swapped;
  swap_green <= Pair_Regular when SwapGreen = "NO" else Pair_Swapped;
  swap_blue  <= Pair_Regular when SwapBlue  = "NO" else Pair_Swapped;

  -- data pipe
  Inst_Datapipe: Datapipe generic map (
    TargetConsole => TargetConsole,
    Firmware      => Firmware,
    Module        => Module
  ) port map (
    VClockN     => VClockN,
    VData       => VData,
    CSel        => CSel,
    CableDetect => CableDetect,
    I2S_BClock  => I2S_BClock,
    I2S_LRClock => I2S_LRClock,
    I2S_Data    => I2S_Data,
    PadData     => PadData,
    IRReceiver  => IRReceiver,
    IRButton    => IRButton,
    Flash_COPI  => Flash_COPI,
    Flash_CIPO  => Flash_CIPO,
    Flash_SCK   => Flash_SCK,
    Flash_SEL   => Flash_SEL,
    ConsoleMode => console_mode,
    PipeClock   => pipe_clock,
    SPDIF_Out   => SPDIF_Out,
    VSync_out   => video_vsync,
    Pair_Red    => swap_red,
    Pair_Green  => swap_green,
    Pair_Blue   => swap_blue,
    DVI_Clock   => DVI_Clock,
    DVI_Red     => DVI_Red,
    DVI_Green   => DVI_Green,
    DVI_Blue    => DVI_Blue
  );

  -- misc outputs
  Flash_Hold  <= '1';
  DDC_SCL     <= 'Z'; -- currently not used, but must be defined to avoid
  DDC_SDA     <= 'Z'; --   damaging the FPGA I/O drivers

  -- heartbeat on LEDs
  Inst_Heartbeat: LED_Heartbeat port map (
    Clock          => pipe_clock,
    VSync          => video_vsync,
    HeartbeatClock => heartbeat_clock,
    HeartbeatVSync => heartbeat_vsync
  );

  leds_gc: if TargetConsole = "GC" generate
    LED1 <= heartbeat_clock;
    LED2 <= heartbeat_vsync;
  end generate;

  leds_wii: if TargetConsole = "WII" generate
    LED1 <= '1' when console_mode = MODE_WII else '0';
    LED2 <= heartbeat_clock xor heartbeat_vsync;
  end generate;

end Behavioral;
