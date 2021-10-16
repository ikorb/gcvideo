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
-- ZPUDevices.vhd: component definitions for the ZPU devices
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;

use work.zpupkg.all;
use work.video_defs.all;

package ZPUDevices is

  type ZPUDeviceIn is record
    Reset          : std_logic;
    mem_write      : std_logic_vector(31 downto 0);
    mem_addr       : std_logic_vector(31 downto 0);
    mem_writeEnable: std_logic;
    mem_bEnable    : std_logic;
    mem_hEnable    : std_logic;
    mem_readEnable : std_logic;
  end record;

  type ZPUDeviceOut is record
    mem_busy: std_logic;
    mem_read: std_logic_vector(wordSize-1 downto 0);
  end record;

  type ZPUMuxSelects is array(natural range <>) of std_logic;
  type ZPUMuxDevOuts is array(natural range <>) of ZPUDeviceOut;

  component ZPUBusMux is
    generic (
      Devices: Natural range 1 to 1000
    );
    port (
      Clock          : in  std_Logic;
      mem_readEnable : in  std_logic;
      mem_writeEnable: in  std_logic;

      DevSelects     : in  ZPUMuxSelects;
      DevOuts        : in  ZPUMuxDevOuts;

      mem_busy_out   : out std_logic;
      mem_read_out   : out std_logic_vector(31 downto 0)
    );
  end component;

  component zpu_rom is
    generic (
      ROMContents    : string;
      maxAddrBitBRAM : integer
    );
    port (
      clk : in std_logic;
      areset : in std_logic := '0';
      from_zpu : in ZPU_ToROM;
      to_zpu : out ZPU_FromROM
    );
  end component;

  component ZPUSimplePort is
    generic (
      DefaultValue: std_logic_vector(31 downto 0) := x"00000000"
    );
    port (
      Clock    : in  std_logic;
      ZSelect  : in  std_logic;
      ZPUBusIn : in  ZPUDeviceIn;
      ZPUBusOut: out ZPUDeviceOut;
      OutPort  : out std_logic_vector(31 downto 0);
      InPort   : in  std_logic_vector(31 downto 0)
    );
  end component;

  component PadReader is
    port (
      Clock    : in  std_logic;
      ZSelect  : in  std_logic;
      ZPUBusIn : in  ZPUDeviceIn;
      ZPUBusOut: out ZPUDeviceOut;
      IRQ      : out std_logic;
      PadData  : in  std_logic
    );
  end component;

  component ZPU_DPRAM is
    generic (
      AddressBits: natural range 1 to 32;
      DataBits   : natural range 1 to 32;
      Datafile   : string := ""
    );
    port (
      Clock    : in  std_logic;
      ZSelect  : in  std_logic;
      ZPUBusIn : in  ZPUDeviceIn;
      ZPUBusOut: out ZPUDeviceOut;
      RAMAddr  : in  std_logic_vector(AddressBits-1 downto 0);
      RAMData  : out std_logic_vector(DataBits-1 downto 0)
    );
  end component;

  component ZPUVideoInterface is
    port (
      Clock           : in  std_logic;
      PixelClockEnable: in  boolean;
      VideoIn         : in  VideoY422;
      VideoLD         : in  VideoY422;
      ConsoleMode     : in  console_mode_t;
      ForceYPbPr      : in  boolean;
      ZSelect         : in  std_logic;
      ZPUBusIn        : in  ZPUDeviceIn;
      ZPUBusOut       : out ZPUDeviceOut;
      IRQ             : out std_logic;
      VSettings       : out VideoSettings_t;
      VMeasure        : in  VideoMeasurements_t;
      OSDSettings     : out OSDSettings_t
    );
  end component;

  type ZPUIRQSignals is array(natural range <>) of std_logic;

  component ZPUIRQController is
    generic (
      Devices: natural range 1 to 31
    );
    port (
      Clock    : in  std_logic;
      ZSelect  : in  std_logic;
      ZPUBusIn : in  ZPUDeviceIn;
      ZPUBusOut: out ZPUDeviceOut;

      DevIRQs  : in  ZPUIRQSignals;
      IRQOut   : out std_logic
    );
  end component;

  component ZPU_SPI is
    generic (
      SPIClockDiv: natural range 1 to 255
    );
    port (
      Clock    : in  std_logic;
      ZSelect  : in  std_logic; -- ZPU peripheral select
      ZPUBusIn : in  ZPUDeviceIn;
      ZPUBusOut: out ZPUDeviceOut;
      SCOPI    : out std_logic; -- SPI controller out, peripheral in
      SCIPO    : in  std_logic; -- SPI controller in, peripheral out
      SClock   : out std_logic; -- SPI clock
      SSelect  : out std_logic  -- SPI select
    );
  end component;

  component ZPUWatchdog is
    generic (
      TriggerLimit: natural range 1 to 1000
    );
    port (
      Clock  : in  std_logic;
      Video  : in  VideoY422;
      Trigger: in  std_logic;
      Reset  : out std_logic
    );
  end component;

  component ZPUIRReceiver is
    generic (
      ClockScale: natural range 1 to 10000
    );
    port (
      Clock     : in  std_logic;
      ZSelect   : in  std_logic;
      ZPUBusIn  : in  ZPUDeviceIn;
      ZPUBusOut : out ZPUDeviceOut;
      IRQ       : out std_logic;
      IRReceiver: in  std_logic;
      IRButton  : in  std_logic
    );
  end component;

  component ZPULineCapture is
    port (
      Clock           : in  std_logic;
      ZSelect         : in  std_logic;
      ZPUBusIn        : in  ZPUDeviceIn;
      ZPUBusOut       : out ZPUDeviceOut;
      VideoIn         : in  VideoY422;
      PixelClockEnable: in  boolean
    );
  end component;

  component ZPUSignalDiag is
    port (
      Clock           : in  std_logic;
      ZSelect         : in  std_logic;
      ZPUBusIn        : in  ZPUDeviceIn;
      ZPUBusOut       : out ZPUDeviceOut;

      -- diagnosed signals
      VideoIn         : in  VideoY422;
      PixelClockEnable: in  boolean;
      I2S_BClock      : in  std_logic;
      I2S_LRClock     : in  std_logic;
      I2S_Data        : in  std_logic
    );
  end component;

end ZPUDevices;

package body ZPUDevices is
end ZPUDevices;
