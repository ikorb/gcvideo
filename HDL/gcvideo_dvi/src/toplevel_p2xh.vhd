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
    TargetConsole: string -- "GC" or "WII"
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

    -- flash chip
    Flash_MOSI : out std_logic;
    Flash_MISO : in  std_logic;
    Flash_SCK  : out std_logic;
    Flash_SSEL : out std_logic;
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
  -- clocks
  signal Clock54M       : std_logic;
  signal ClockAudio     : std_logic;
  signal DVIClockP      : std_logic;
  signal DVIClockN      : std_logic;

  -- video pipeline signals
  signal video_422      : VideoY422;
  signal video_ld       : VideoY422;
  signal video_444      : VideoYCbCr;
  signal video_444_rb   : VideoYCbCr; -- reblanked
  signal video_444_sl   : VideoYCbCr; -- scanlined
  signal video_444_osd  : VideoYCbCr;
  signal video_rgb      : VideoRGB;
  signal video_out      : VideoRGB;

  signal pixel_clk_en   : boolean;
  signal pixel_clk_en_2x: boolean;
  signal pixel_clk_en_ld: boolean;
  signal pixel_clk_en_27: boolean; -- used for DVI output, automatically results in pixel-doubling for 15k modes

  -- internal 24 bit VGA signals
  signal VGA_Red        : std_logic_vector(7 downto 0);
  signal VGA_Green      : std_logic_vector(7 downto 0);
  signal VGA_Blue       : std_logic_vector(7 downto 0);
  signal VGA_HSync      : std_logic;
  signal VGA_VSync      : std_logic;
  signal VGA_Blank      : std_logic;

  -- encoded DVI signals
  signal red_enc        : std_logic;
  signal green_enc      : std_logic;
  signal blue_enc       : std_logic;
  signal clock_enc      : std_logic;

  -- OSD
  signal osd_ram_addr   : std_logic_vector(10 downto 0);
  signal osd_ram_data   : std_logic_vector(8 downto 0);
  signal osd_settings   : OSDSettings_t;

  -- audio
  signal audio          : AudioData;

  -- console mode detection
  signal console_mode   : console_mode_t := MODE_GC;

  -- misc
  signal video_settings : VideoSettings_t;
  signal clock_locked   : std_logic;
  signal scanline_even  : boolean;

  signal led1_counter   : natural range 0 to 24 := 0;
  signal led2_counter   : natural range 0 to 375000 := 0;
  signal heartbeat_led1 : std_logic := '0';
  signal heartbeat_led2 : std_logic := '0';
  signal heartbeat_vsync: std_logic := '0';
  signal heartbeat_hsync: std_logic := '0';

  signal obuf_oe        : std_logic;

begin

  mode_detect: if TargetConsole = "WII" generate
    Inst_CMD: ConsoleModeDetect port map (
      Clock       => Clock54M,
      I2S_LRClock => I2S_LRClock,
      ConsoleMode => console_mode
    );

    -- (note: console_mode is initialized to MODE_GC)
  end generate;

  -- misc outputs
  l1_gc: if TargetConsole = "GC" generate
    LED1 <= heartbeat_led1;
  end generate;

  l1_wii: if TargetConsole = "WII" generate
    LED1 <= '1' when console_mode = MODE_WII else '0';
  end generate;

  LED2        <= heartbeat_led2;
  Flash_Hold  <= '1';
  DDC_SCL     <= 'Z'; -- currently not used, but must be defined to avoid
  DDC_SDA     <= 'Z'; --   damaging the FPGA I/O drivers
  CableDetect <= '1' when video_settings.CableDetect else '0';

  -- heartbeat on LEDs
  process (Clock54M)
  begin
    if rising_edge(Clock54M) then
      if heartbeat_vsync /= VGA_VSync then
        if led1_counter /= 0 then
          led1_counter <= led1_counter - 1;
        else
          led1_counter   <= 24;
          heartbeat_led1 <= not heartbeat_led1;
        end if;
      end if;
      heartbeat_vsync <= VGA_VSync;

      if heartbeat_hsync /= VGA_HSync then
        if led2_counter  /= 0 then
          led2_counter   <= led2_counter - 1;
        else
          led2_counter   <= 7500;
          heartbeat_led2 <= not heartbeat_led2;
        end if;
      end if;
      heartbeat_hsync <= VGA_HSync;
    end if;
  end process;

  -- CPU subsystem
  Inst_CPU: CPUSubsystem PORT MAP (
    Clock            => Clock54M,
    ExtReset         => not clock_locked,
    RawVideo         => video_422,
    PixelClockEnable => pixel_clk_en,
    PadData          => PadData,
    SPI_MOSI         => Flash_MOSI,
    SPI_MISO         => Flash_MISO,
    SPI_SCK          => Flash_SCK,
    SPI_SSEL         => Flash_SSEL,
    OSDRamAddr       => osd_ram_addr,
    OSDRamData       => osd_ram_data,
    OSDSettings      => osd_settings,
    VSettings        => video_settings
  );

  -- DVI output
  Inst_DVI: dvid GENERIC MAP (
    Invert_Green => true,
    Invert_Blue  => true
  ) PORT MAP (
    clk           => DVIClockP,
    clk_n         => DVIClockN,
    clk_pixel     => Clock54M,
    clk_pixel_en  => pixel_clk_en_27,
    red_p         => VGA_Red,
    green_p       => VGA_Green,
    blue_p        => VGA_Blue,
    blank         => VGA_Blank,
    hsync         => VGA_HSync,
    vsync         => VGA_VSync,
    EnhancedMode  => video_settings.EnhancedMode,
    IsProgressive => video_out.IsProgressive,
    IsPAL         => video_out.IsPAL,
    Is30kHz       => video_out.Is30kHz,
    Limited_Range => video_settings.LimitedRange,
    Widescreen    => video_settings.Widescreen,
    Audio         => audio,
    -- outputs
    red_s         => red_enc,
    green_s       => green_enc,
    blue_s        => blue_enc,
    clock_s       => clock_enc
  );

  OBUFDS_red   : OBUFTDS port map ( O => DVI_Red(0),   OB => DVI_Red(1),   I => red_enc,   T => obuf_oe);
  OBUFDS_green : OBUFTDS port map ( O => DVI_Green(0), OB => DVI_Green(1), I => green_enc, T => obuf_oe);
  OBUFDS_blue  : OBUFTDS port map ( O => DVI_Blue(0),  OB => DVI_Blue(1),  I => blue_enc,  T => obuf_oe);
  OBUFDS_clock : OBUFTDS port map ( O => DVI_Clock(0), OB => DVI_Clock(1), I => clock_enc, T => obuf_oe);

  obuf_oe <= '1' when video_settings.DisableOutput else '0';

  -- master clock generator
  Inst_ClockGen: ClockGen
    port map (
      ClockIn    => VClockN,
      Reset      => '0',
      Clock54M   => Clock54M,
      ClockAudio => ClockAudio,
      DVIClockP  => DVIClockP,
      DVIClockN  => DVIClockN,
      Locked     => clock_locked
    );

  -- audio module
  Inst_Audio: Audio_SPDIF
    port map (
      Clock       => ClockAudio,
      I2S_BClock  => I2S_BClock,
      I2S_LRClock => I2S_LRClock,
      I2S_Data    => I2S_Data,
      Volume      => video_settings.Volume,
      Audio       => audio,
      SPDIF_Out   => SPDIF_Out
    );

  -- read gamecube video data
  Inst_GCVideo: GCDV_Decoder
    PORT MAP (
      VClockI            => Clock54M,
      VData              => VData,
      CSel               => CSel,
      PixelClockEnable   => pixel_clk_en,
      PixelClockEnable2x => pixel_clk_en_2x,
      Video              => video_422
    );

  -- linedouble 15kHz modes to 30kHz
  Inst_Linedoubler: Linedoubler
    PORT MAP (
      PixelClock         => Clock54M,
      PixelClockEnable   => pixel_clk_en,
      PixelClockEnable2x => pixel_clk_en_2x,
      Enable             => video_settings.LinedoublerEnabled,
      VideoIn            => video_422,
      VideoOut           => video_ld,
      PixelOutEnable     => pixel_clk_en_ld
    );

  -- interpolate 4:2:2 to 4:4:4
  Inst_422_to_444: Convert_422_to_444
    PORT MAP (
      PixelClock       => Clock54M,
      PixelClockEnable => pixel_clk_en_ld,

      VideoIn          => video_ld,
      VideoOut         => video_444
    );

  -- regenerate blanking signal
  Inst_Reblanking: Blanking_Regenerator_Fixed
    PORT MAP (
      PixelClock       => Clock54M,
      PixelClockEnable => pixel_clk_en_ld,
      VideoIn          => video_444,
      VideoOut         => video_444_rb
    );

  -- overlay scanlines
  Inst_Scanliner: Scanline_Generator
    PORT MAP (
      PixelClock       => Clock54M,
      PixelClockEnable => pixel_clk_en_ld,
      Enable           => video_settings.ScanlinesEnabled,
      Strength         => video_settings.ScanlineStrength,
      Use_Even         => scanline_even,
      VideoIn          => video_444_rb,
      VideoOut         => video_444_sl
    );

  scanline_even <= video_settings.ScanlinesEven xor (not video_422.IsProgressive and video_422.IsEvenField and video_settings.ScanlinesAlternate);

  -- add OSD overlay
  Inst_OSD: TextOSD
    PORT MAP (
      PixelClock       => Clock54M,
      PixelClockEnable => pixel_clk_en_ld,
      VideoIn          => video_444_sl,
      VideoOut         => video_444_osd,
      Settings         => osd_settings,
      RAMAddress       => osd_ram_addr,
      RAMData          => osd_ram_data
    );

  -- convert YUV to RGB
  Inst_yuv_to_rgb: Convert_yuv_to_rgb
    PORT MAP (
      PixelClock       => Clock54M,
      PixelClockEnable => pixel_clk_en_ld,

      VideoIn          => video_444_osd,
      Limited_Range    => video_settings.LimitedRange,
      VideoOut         => video_rgb
    );

  -- create a fixed 27-MHz pixel clock
  process (Clock54M)
  begin
    if rising_edge(Clock54M) then
      if pixel_clk_en then
        pixel_clk_en_27 <= false; -- must be false because it's delayed one cycle
      else
        pixel_clk_en_27 <= not pixel_clk_en_27;
      end if;
    end if;
  end process;

  -- send video signals to output
  process (Clock54M, pixel_clk_en_ld)
  begin
    if rising_edge(Clock54M) and pixel_clk_en_ld then
      -- output sync signals
      if video_out.VSync then
        VGA_VSync <= '0';
      else
        VGA_VSync <= '1';
      end if;

      if video_out.HSync then
        VGA_HSync <= '0';
      else
        VGA_HSync <= '1';
      end if;

      -- output to VGA
      if video_out.Blanking then
        VGA_Red   <= (others => '0');
        VGA_Green <= (others => '0');
        VGA_Blue  <= (others => '0');
        VGA_Blank <= '1';
      else
        VGA_Red   <= std_logic_vector(video_out.PixelR);
        VGA_Green <= std_logic_vector(video_out.PixelG);
        VGA_Blue  <= std_logic_vector(video_out.PixelB);
        VGA_Blank <= '0';
      end if;
    end if;
  end process;

  -- select output signal
  video_out <= video_rgb;

end Behavioral;

