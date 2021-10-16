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
-- component_defs.vhd: Component definitions
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.ALL;

use work.video_defs.all;

package component_defs is

  component delayline_unsigned is
    generic (
      Delayticks: Natural := 4;
      Width     : Natural := 1
    );
    port (
      Clock      : in  std_logic;
      ClockEnable: in  boolean;
      Input      : in  unsigned(Width - 1 downto 0);
      Output     : out unsigned(Width - 1 downto 0)
    );
  end component;

  component delayline_bool is
    generic (
      Delayticks: Natural := 4
    );
    port (
      Clock      : in  std_logic;
      ClockEnable: in  boolean;
      Input      : in  boolean;
      Output     : out boolean
    );
  end component;

  component gcdv_decoder is
    port (
      VClockI           : in  std_logic; -- 54 MHz clock, pin 2
      VData             : in  std_logic_vector(7 downto 0);
      CSel              : in  std_logic; -- "ClkSel" signal, pin 3

      -- output clock enables
      PixelClockEnable  : out boolean; -- CE relative to input clock for complete pixels
      PixelClockEnable2x: out boolean; -- same, but at twice the pixel rate

      -- video output
      Video             : out VideoY422
    );
  end component;

  component convert_422_to_444 is
    port (
      PixelClock       : in  std_logic;
      PixelClockEnable : in  boolean;

      -- control
      InterpolateChroma: in  boolean;
      Output422        : in  boolean;

      -- input video
      VideoIn          : in  VideoY422;

      -- output video
      VideoOut         : out VideoYCbCr
    );
  end component;

  component ycrange is
    port (
      Clock      : in  std_logic;
      ClockEnable: in  boolean;

      -- input video
      PixelY     : in  unsigned(7 downto 0);
      PixelCb    : in    signed(7 downto 0);
      PixelCr    : in    signed(7 downto 0);

      -- output video
      OutY       : out unsigned(7 downto 0);
      OutCb      : out unsigned(7 downto 0);
      OutCr      : out unsigned(7 downto 0)
    );
  end component;


  component colormatrix is
    port (
      PixelClock      : in  std_logic;
      PixelClockEnable: in  boolean;

      -- control
      Settings        : in  VideoSettings_t;

      -- input video
      VideoIn         : in  VideoYCbCr;

      -- output video
      VideoOut        : out VideoRGB
    );
  end component;

  component Linedoubler is
  port (
    PixelClock        : in  std_logic;

    -- input video
    Enable            : in  boolean;
    VideoIn           : in  VideoY422;
    PixelClockEnable  : in  boolean;
    PixelClockEnable2x: in  boolean;

    -- output video
    VideoOut          : out VideoY422;
    PixelOutEnable    : out boolean
  );
  end component;

  component scanline_generator is
    port (
      PixelClock      : in  std_logic;
      PixelClockEnable: in  boolean;

      Enable          : in  boolean;
      Use_Even        : in  boolean;

      PixelY          : out std_logic_vector(7 downto 0);
      ScanlineStrength: in  std_logic_vector(8 downto 0);

      -- input video
      VideoIn         : in  VideoYCbCr;

      -- output video
      VideoOut        : out VideoYCbCr
    );
  end component;

  component Blanking_Regenerator is
    port (
      PixelClock       : in  std_logic;
      PixelClockEnable : in  boolean;

      -- control
      ReblankingEnable : in  boolean;
      ResyncingEnable  : in  boolean;
      RBSettings       : in  ReblankerSettings_t;

      -- measurements
      VideoMeasurements: out VideoMeasurements_t;

      -- input video
      VideoIn          : in  VideoYCbCr;

      -- output video
      VideoOut         : out VideoYCbCr
    );
  end component;

  component Blanking_Regenerator_Fixed is
    port (
      PixelClock      : in  std_logic;
      PixelClockEnable: in  boolean;

      -- input video
      VideoIn         : in  VideoYCbCr;

      -- output video
      VideoOut        : out VideoYCbCr
    );
  end component;

  COMPONENT dvid
  PORT(
      clk              : in  std_logic;
      clk_n            : in  std_logic;
      clk_pixel        : in  std_logic;
      clk_pixel_en     : in  boolean;
      ConsoleMode      : in  console_mode_t;
      Video            : in  VideoRGB;
      EnhancedMode     : in  boolean;
      Widescreen       : in  boolean;
      ColorMode        : in  std_logic_vector(1 downto 0);
      SampleRateHack   : in  boolean;
      Audio            : in  AudioData;
      InfoFrameRAM_Addr: out std_logic_vector(8 downto 0);
      InfoFrameRAM_Data: in  std_logic_vector(8 downto 0);
      TMDSWord_Red     : out std_logic_vector(9 downto 0);
      TMDSWord_Green   : out std_logic_vector(9 downto 0);
      TMDSWord_Blue    : out std_logic_vector(9 downto 0);
      Pair_Red         : in  Pair_Swap_t := Pair_Regular;
      Pair_Green       : in  Pair_Swap_t := Pair_Regular;
      Pair_Blue        : in  Pair_Swap_t := Pair_Regular;
      Pair_Clock       : in  Pair_Swap_t := Pair_Regular;
      red_s            : out std_logic;
      green_s          : out std_logic;
      blue_s           : out std_logic;
      clock_s          : out std_logic
    );
  END COMPONENT;

  component ClockGen is
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
  end component;

  component i2s_decoder is
    port (
      -- Internal clock
      Clock      : in  std_logic;
      ClockEnable: in  boolean;

      -- I2S signals
      I2S_BClock : in  std_logic;
      I2S_LRClock: in  std_logic;
      I2S_Data   : in  std_logic;

      -- sample output
      Left       : out signed(15 downto 0);
      Right      : out signed(15 downto 0);
      LeftEnable : out boolean;
      RightEnable: out boolean
    );
  end component;

  component SPDIF_Encoder is
    port (
      Clock54       : in  std_logic;
      Clock162      : in  std_logic;
      Clock162Enable: in  boolean;
      AudioLeft     : in  signed(15 downto 0);
      AudioRight    : in  signed(15 downto 0);
      EnableLeft    : in  boolean;
      SPDIF         : out std_logic
    );
  end component;

  component audio_spdif is
    port (
      Clock54    : in  std_logic;
      Clock162   : in  std_logic;
      ConsoleMode: in  console_mode_t;

      I2S_BClock : in  std_logic;
      I2S_LRClock: in  std_logic;
      I2S_Data   : in  std_logic;
      Volume     : in  unsigned(7 downto 0);

      Audio      : out AudioData;

      SPDIF_Out  : out std_logic
    );
  end component;

  component Deglitcher is
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
  end component;

  component debouncer is
    Generic (
      BounceTicks: Integer := 10000;
      DebounceLTH: Boolean := true;
      DebounceHTL: Boolean := true
    );
    Port (
      clock  : in  std_logic;
      btn_in : in  std_logic;
      btn_out: out std_logic
    );
  end component;

  component CPUSubsystem is
    generic (
      Firmware        : string;
      Module          : string
    );
    port (
      Clock           : in  std_logic;
      ExtReset        : in  std_logic;
      VideoIn         : in  VideoY422;
      VideoLD         : in  VideoY422;
      PixelClockEnable: in  boolean;
      ConsoleMode     : in  console_mode_t;
      ForceYPbPr      : in  boolean;
      PadData         : in  std_logic;
      IRReceiver      : in  std_logic;
      IRButton        : in  std_logic;
      I2S_BClock      : in  std_logic;
      I2S_LRClock     : in  std_logic;
      I2S_Data        : in  std_logic;
      SPI_COPI        : out std_logic;
      SPI_CIPO        : in  std_logic;
      SPI_SCK         : out std_logic;
      SPI_SEL         : out std_logic;
      ScanlineRamAddr : in  std_logic_vector(7 downto 0);
      ScanlineRamData : out std_logic_vector(8 downto 0);
      InfoFrameRAMAddr: in  std_logic_vector(8 downto 0);
      InfoFrameRAMData: out std_logic_vector(8 downto 0);
      OSDRamAddr      : in  std_logic_vector(10 downto 0);
      OSDRamData      : out std_logic_vector(8 downto 0);
      OSDSettings     : out OSDSettings_t;
      VSettings       : out VideoSettings_t;
      VMeasure        : in  VideoMeasurements_t
    );
  end component;

  component TextOSD is
    port (
      PixelClock      : in  std_logic;
      PixelClockEnable: in  boolean;
      VideoIn         : in  VideoYCbCr;
      VideoOut        : out VideoYCbCr;
      Settings        : in  OSDSettings_t;

      RAMAddress      : out std_logic_vector(10 downto 0);
      RAMData         : in  std_logic_vector(8 downto 0)
    );
  end component;

  component SimpleROM is
    generic (
      AddressBits: natural range 1 to 32;
      DataBits   : natural range 1 to 32;
      Datafile   : string
    );
    port (
      Clock      : in  std_logic;
      ClockEnable: in  boolean;
      Address    : in  std_logic_vector(AddressBits-1 downto 0);
      Data       : out std_logic_vector(DataBits-1 downto 0)
    );
  end component;

  component ConsoleModeDetect is
    port (
      Clock      : in  std_logic;
      I2S_LRClock: in  std_logic;
      ConsoleMode: out console_mode_t
    );
  end component;

  component LED_Heartbeat is
    port (
      Clock          : in  std_logic;
      VSync          : in  std_logic;
      HeartbeatClock : out std_logic;
      HeartbeatVSync : out std_logic;
      HeartbeatVSync2: out std_logic
    );
  end component;

  component Datapipe is
    generic (
      TargetConsole: string; -- "GC" or "WII"
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

      -- exported internal signals
      ConsoleMode: out console_mode_t;
      PipeClock  : out std_logic;
      DAC_RGBMode: out boolean;

      -- audio out
      SPDIF_Out  : out std_logic;

      -- analog video out
      DAC_Red    : out std_logic_vector(7 downto 0);
      DAC_Green  : out std_logic_vector(7 downto 0);
      DAC_Blue   : out std_logic_vector(7 downto 0);
      DAC_SyncN  : out std_logic;
      DAC_Clock  : out std_logic;
      CSync_out  : out std_logic;
      VSync_out  : out std_logic;
      HSync_out  : out std_logic;
      ForceYPbPr : in  std_logic := '1'; -- default: Not forced

      -- digital video out
      Pair_Red   : in  Pair_Swap_t := Pair_Regular;
      Pair_Green : in  Pair_Swap_t := Pair_Regular;
      Pair_Blue  : in  Pair_Swap_t := Pair_Regular;
      Pair_Clock : in  Pair_Swap_t := Pair_Regular;
      DVI_Clock  : out std_logic_vector(1 downto 0);
      DVI_Red    : out std_logic_vector(1 downto 0);
      DVI_Green  : out std_logic_vector(1 downto 0);
      DVI_Blue   : out std_logic_vector(1 downto 0)
    );
  end component;

  component crc32 is
    port (
      Clock      : in  std_logic;
      DataIn     : in  std_logic;
      DataInValid: in  boolean;
      ResetCRC   : in  boolean;
      DataOut    : out std_logic_vector(31 downto 0)
    );
  end component;

end component_defs;

package body component_defs is
end component_defs;
