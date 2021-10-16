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
-- CPUSubsystem.vhd: Encapsulation module for the CPU subsystem of GCVideo
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use work.zpupkg.all;
use work.ZPUDevices.all;
use work.component_defs.all;
use work.video_defs.all;

entity CPUSubsystem is
  generic (
    Firmware         : string;
    Module           : string
  );
  port (
    Clock            : in  std_logic;
    ExtReset         : in  std_logic;
    VideoIn          : in  VideoY422;
    VideoLD          : in  VideoY422;
    PixelClockEnable : in  boolean;
    ConsoleMode      : in  console_mode_t;
    ForceYPbPr       : in  boolean;
    PadData          : in  std_logic;
    IRReceiver       : in  std_logic;
    IRButton         : in  std_logic;
    I2S_BClock       : in  std_logic;
    I2S_LRClock      : in  std_logic;
    I2S_Data         : in  std_logic;
    SPI_COPI         : out std_logic;
    SPI_CIPO         : in  std_logic;
    SPI_SCK          : out std_logic;
    SPI_SEL          : out std_logic;
    ScanlineRamAddr  : in  std_logic_vector(7 downto 0);
    ScanlineRamData  : out std_logic_vector(8 downto 0);
    InfoFrameRAMAddr : in  std_logic_vector(8 downto 0);
    InfoFrameRAMData : out std_logic_vector(8 downto 0);
    OSDRamAddr       : in  std_logic_vector(10 downto 0);
    OSDRamData       : out std_logic_vector(8 downto 0);
    OSDSettings      : out OSDSettings_t;
    VSettings        : out VideoSettings_t;
    VMeasure         : in  VideoMeasurements_t
  );
end CPUSubsystem;

architecture Behavioral of CPUSubsystem is

  constant ZPUBRAMSize: natural := 13;

  -- number of devices on the I/O bus
  constant DeviceCount: Natural := 8;

  -- number of interrupt-generating devices
  constant IRQDeviceCount: Natural := 3;

  -- ZPU signals
  signal cpu_reset          : std_logic;
  signal cpu_mem_busy       : std_logic;
  signal cpu_mem_read       : std_logic_vector(31 downto 0);
  signal cpu_mem_write      : std_logic_vector(31 downto 0);
  signal cpu_mem_addr       : std_logic_vector(31 downto 0);
  signal cpu_mem_writeEnable: std_logic;
  signal cpu_mem_bEnable    : std_logic;
  signal cpu_mem_hEnable    : std_logic;
  signal cpu_mem_readEnable : std_logic;
  signal cpu_interrupt      : std_logic;
  signal cpu_fromROM        : ZPU_FromROM;
  signal cpu_toROM          : ZPU_ToROM;

  signal watchdog_reset     : std_logic;

  -- device bus connections
  signal IRQControllerSel: std_logic;
  signal VideoIFSel      : std_logic;
  signal PadSel          : std_logic;
  signal ScanlineRAMSel  : std_logic;
  signal OSDRAMSel       : std_logic;
  signal SPISel          : std_logic;
  signal IRRxSel         : std_logic;
  signal IFRSel          : std_logic;

  signal ZPUIn           : ZPUDeviceIn;
  signal IRQControllerOut: ZPUDeviceOut;
  signal VideoIFOut      : ZPUDeviceOut;
  signal PadOut          : ZPUDeviceOut;
  signal ScanlineRAMOut  : ZPUDeviceOut;
  signal OSDRAMOut       : ZPUDeviceOut;
  signal SPIOut          : ZPUDeviceOut;
  signal IRRxOut         : ZPUDeviceOut;
  signal IFROut          : ZPUDeviceOut;

  signal VSyncIRQ        : std_logic;
  signal PadIRQ          : std_logic;
  signal IRRxIRQ         : std_logic;
  signal IRQSignals      : ZPUIRQSignals(0 to IRQDeviceCount-1);

  signal DeviceSels      : ZPUMuxSelects(0 to DeviceCount-1);
  signal DeviceOuts      : ZPUMuxDevOuts(0 to DeviceCount-1);

  signal scanline_ram_addr_ext: std_logic_vector(9 downto 0);
  signal vid_settings         : VideoSettings_t;

begin

  Inst_ZPU: zpu_core_flex GENERIC MAP (
    IMPL_MULTIPLY       => true,  -- Self explanatory  [needs 3 mults]
    IMPL_COMPARISON_SUB => true,  -- Include sub and (U)lessthan(orequal)
    IMPL_EQBRANCH       => true,  -- Include eqbranch and neqbranch
    IMPL_STOREBH        => false, -- Include halfword and byte writes [external RAM only!]
    IMPL_LOADBH         => false, -- Include halfword and byte reads  [external RAM only!]
    IMPL_CALL           => true,  -- Include call
    IMPL_SHIFT          => true,  -- Include lshiftright, ashiftright and ashiftleft
    IMPL_XOR            => true,  -- include xor instruction
    EXECUTE_RAM         => false, -- Map the stack / Boot ROM to 0x40000000, to allow pushsp, store to work.
    REMAP_STACK         => false, -- include support for executing code from outside the Boot ROM
    stackbit            => 30,
    maxAddrBit          => 31,
    maxAddrBitBRAM      => ZPUBRAMSize
  ) PORT MAP (
    clk                 => Clock,
    Reset               => cpu_reset,
    enable              => '1',
    in_mem_busy         => cpu_mem_busy,
    mem_read            => cpu_mem_read,
    mem_write           => cpu_mem_write,
    out_mem_addr        => cpu_mem_addr,
    out_mem_writeEnable => cpu_mem_writeEnable,
    out_mem_bEnable     => cpu_mem_bEnable,
    out_mem_hEnable     => cpu_mem_hEnable,
    out_mem_readEnable  => cpu_mem_readEnable,
    interrupt           => cpu_interrupt,
    break               => open,
    from_rom            => cpu_fromROM,
    to_rom              => cpu_toROM
  );

  Inst_BootRAM: zpu_rom GENERIC MAP (
    ROMContents    => Firmware,
    maxAddrBitBRAM => ZPUBRAMSize
  ) PORT MAP (
    clk      => Clock,
    from_zpu => cpu_toROM,
    to_zpu   => cpu_fromROM
  );

  -- watchdog
  Inst_Watchdog: ZPUWatchdog GENERIC MAP (
    TriggerLimit => 5
  ) PORT MAP (
    Clock   => Clock,
    Video   => VideoIn,
    Trigger => IRQControllerSel,
    Reset   => watchdog_reset
  );

  cpu_reset <= watchdog_reset or ExtReset;

  ---- devices
  -- interrupt controller
  IRQSignals <= (0 => VSyncIRQ, 1 => PadIRQ, 2 => IRRxIRQ);
  Inst_IRQController: ZPUIRQController GENERIC MAP (
    Devices => IRQDeviceCount
  ) PORT MAP (
    Clock     => Clock,
    ZSelect   => IRQControllerSel,
    ZPUBusIn  => ZPUIn,
    ZPUBusOut => IRQControllerOut,
    DevIRQs   => IRQSignals,
    IRQOut    => cpu_interrupt
  );

  -- Gamepad reader
  Inst_Padreader: PadReader PORT MAP (
    Clock     => Clock,
    ZSelect   => PadSel,
    ZPUBusIn  => ZPUIn,
    ZPUBusOut => PadOut,
    IRQ       => PadIRQ,
    PadData   => PadData
  );

  -- Video Interface device
  Inst_VideoInterface: ZPUVideoInterface port map (
    Clock            => Clock,
    PixelClockEnable => PixelClockEnable,
    VideoIn          => VideoIn,
    VideoLD          => VideoLD,
    ConsoleMode      => ConsoleMode,
    ForceYPbPr       => ForceYPbPr,
    ZSelect          => VideoIFSel,
    ZPUBusIn         => ZPUIn,
    ZPUBusOut        => VideoIFOut,
    IRQ              => VSyncIRQ,
    VSettings        => vid_settings,
    VMeasure         => VMeasure,
    OSDSettings      => OSDSettings
  );
  VSettings <= vid_settings;

  ramdevice_main: if Module = "main" generate
    -- Scanline strength RAM
    Inst_ScanlineRAM: ZPU_DPRAM generic map (
      AddressBits => 10,
      DataBits    => 9
      --InitValue   => x"00000100" -- factor 1.00
    ) port map (
      Clock       => Clock,
      ZSelect     => ScanlineRAMSel,
      ZPUBusIn    => ZPUIn,
      ZPUBusOut   => ScanlineRAMOut,
      RAMAddr     => scanline_ram_addr_ext,
      RAMData     => ScanlineRAMData
    );

    scanline_ram_addr_ext <= vid_settings.ScanlineProfile & ScanlineRAMAddr;
  end generate;

  ramdevice_flasher: if Module = "flasher" generate
    -- line capture RAM instead of scanline RAM
    Inst_LineCapture: ZPULineCapture port map (
      Clock            => Clock,
      ZSelect          => ScanlineRAMSel,
      ZPUBusIn         => ZPUIn,
      ZPUBusOut        => ScanlineRAMOut,
      VideoIn          => VideoIn,
      PixelClockEnable => PixelClockEnable
    );
  end generate;

  -- OSD RAM
  Inst_OSDRAM: ZPU_DPRAM GENERIC MAP (
    AddressBits => 11,
    DataBits    => 9
  ) PORT MAP (
    Clock       => Clock,
    ZSelect     => OSDRAMSel,
    ZPUBusIn    => ZPUIn,
    ZPUBusOut   => OSDRAMOut,
    RAMAddr     => OSDRamAddr,
    RAMData     => OSDRamData
  );

  -- SPI
  Inst_SPI: ZPU_SPI GENERIC MAP (
    SPIClockDiv => 2 -- just 13.5MHz because some M25P40 are 25MHz max =(
  ) PORT MAP (
    Clock     => Clock,
    ZSelect   => SPISel,
    ZPUBusIn  => ZPUIn,
    ZPUBusOut => SPIOut,
    SCOPI     => SPI_COPI,
    SCIPO     => SPI_CIPO,
    SClock    => SPI_SCK,
    SSelect   => SPI_SEL
  );

  -- IR Receiver
  Inst_IRRx: ZPUIRReceiver generic map (
    ClockScale => 4096
  ) port map (
    Clock      => Clock,
    ZSelect    => IRRxSel,
    ZPUBusIn   => ZPUIn,
    ZPUBusOut  => IRRxOut,
    IRQ        => IRRxIRQ,
    IRReceiver => IRReceiver,
    IRButton   => IRButton
  );

  -- Infoframe-RAM
  InfoFrameRAM: if Module = "main" generate
    Inst_IFRam: ZPU_DPRAM generic map (
      AddressBits => 9,
      DataBits    => 9,
      DataFile    => "infoframe_rom.mif"
      ) port map (
        Clock     => Clock,
        ZSelect   => IFRSel,
        ZPUBusIn  => ZPUIn,
        ZPUBusOut => IFROut,
        RAMAddr   => InfoFrameRAMAddr,
        RAMData   => InfoFrameRAMData
      );
  end generate;

  -- signal diagnostics device
  SignalDiag: if Module = "flasher" generate
    Inst_SignalDiag: ZPUSignalDiag port map (
      -- replaces InfoFrameRAM in flasher
      Clock            => Clock,
      ZSelect          => IFRSel,
      ZPUBusIn         => ZPUIn,
      ZPUBusOut        => IFROut,
      VideoIn          => VideoIn,
      PixelClockEnable => PixelClockEnable,
      I2S_BClock       => I2S_BClock,
      I2S_LRClock      => I2S_LRClock,
      I2S_Data         => I2S_Data
    );
  end generate;

  -- CPU-to-device signals
  ZPUIn.Reset           <= cpu_reset;
  ZPUIn.mem_write       <= cpu_mem_write;
  ZPUIn.mem_addr        <= cpu_mem_addr;
  ZPUIn.mem_writeEnable <= cpu_mem_writeEnable;
  ZPUIn.mem_bEnable     <= cpu_mem_bEnable;
  ZPUIn.mem_hEnable     <= cpu_mem_hEnable;
  ZPUIn.mem_readEnable  <= cpu_mem_readEnable;

  -- address decoder
  process(cpu_mem_addr, cpu_mem_writeEnable, cpu_mem_readEnable)
  begin
    IRQControllerSel <= '0';
    VideoIFSel       <= '0';
    PadSel           <= '0';
    ScanlineRAMSel   <= '0';
    OSDRAMSel        <= '0';
    SPISel           <= '0';
    IRRxSel          <= '0';
    IFRSel           <= '0';

    if cpu_mem_writeEnable = '1' or
       cpu_mem_readEnable  = '1' then
      case cpu_mem_addr(31 downto 28) is
        when x"f" => -- peripheral space
          if cpu_mem_addr(15 downto 13) = "100" then
            -- 0xffff8000-9fff, reused for signal diag in flasher
            IFRSel <= '1';
          elsif cpu_mem_addr(13) = '0' then
            -- OSD RAM needs 8k: 0xffffc000-dfff
            OSDRAMSel <= '1';
          elsif cpu_mem_addr(12) = '0' then
            -- 0xffffe000-efff
            ScanlineRAMSel <= '1'; -- used for linecapture in flasher
          else -- 0xffff f_00
            case cpu_mem_addr(11 downto 8) is -- select with 256-byte granularity
              when x"0"   => IRQControllerSel <= '1';
              when x"1"   => VideoIFSel       <= '1';
              when x"2"   => PadSel           <= '1';
              when x"3"   => SPISel           <= '1';
              when x"4"   => IRRxSel          <= '1';
              when others => null;
            end case;
          end if;

        when others => null;
      end case;
    end if;
  end process;

  -- device mux
  DeviceSels <= (
    0 => IRQControllerSel,
    1 => VideoIFSel,
    2 => PadSel,
    3 => ScanlineRAMSel,
    4 => OSDRAMSel,
    5 => SPISel,
    6 => IRRxSel,
    7 => IFRSel
  );

  DeviceOuts <= (
    0 => IRQControllerOut,
    1 => VideoIFOut,
    2 => PadOut,
    3 => ScanlineRAMOut,
    4 => OSDRAMOut,
    5 => SPIOut,
    6 => IRRxOut,
    7 => IFROut
  );

  MainZPUBusMux: ZPUBusMux
    generic map (
      Devices => DeviceCount
    ) port map (
      Clock => Clock,
      mem_readEnable  => cpu_mem_readEnable,
      mem_writeEnable => cpu_mem_writeEnable,
      DevSelects      => DeviceSels,
      DevOuts         => DeviceOuts,
      mem_busy_out    => cpu_mem_busy,
      mem_read_out    => cpu_mem_read
    );

end Behavioral;
