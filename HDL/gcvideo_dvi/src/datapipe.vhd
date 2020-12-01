----------------------------------------------------------------------------------
-- GCVideo DVI HDL
-- Copyright (C) 2014-2020, Ingo Korb <ingo@akana.de>
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
-- datapipe.vhd: Plugging processing modules into a data pipeline
--
----------------------------------------------------------------------------------

library IEEE;

use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library UNISIM;
use UNISIM.VComponents.all;

use work.Component_Defs.all;
use work.video_defs.all;

entity Datapipe is
  generic (
    TargetConsole: string; -- "GC" or "WII"
    Firmware     : string
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
    Flash_MOSI : out std_logic;
    Flash_MISO : in  std_logic;
    Flash_SCK  : out std_logic;
    Flash_SSEL : out std_logic;

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
    ForceYPbPr : in  std_logic;

    -- digital video out
    Pair_Red   : in  Pair_Swap_t;
    Pair_Green : in  Pair_Swap_t;
    Pair_Blue  : in  Pair_Swap_t;
    Pair_Clock : in  Pair_Swap_t;
    DVI_Clock  : out std_logic_vector(1 downto 0);
    DVI_Red    : out std_logic_vector(1 downto 0);
    DVI_Green  : out std_logic_vector(1 downto 0);
    DVI_Blue   : out std_logic_vector(1 downto 0)
  );
end Datapipe;

architecture Behavioral of Datapipe is
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

  -- scanlines
  signal scanlines_enabled: boolean;
  signal scanline_even    : boolean;
  signal scanline_ram_addr: std_logic_vector(7 downto 0);
  signal scanline_ram_data: std_logic_vector(8 downto 0);

  -- misc
  signal video_settings    : VideoSettings_t;
  signal clock_locked      : std_logic;
  signal obuf_oe           : std_logic;
  signal force_ypbpr       : boolean;
  signal output_422        : boolean;
  signal video_measurements: VideoMeasurements_t;
  signal infoframeram_data : std_logic_vector(8 downto 0);
  signal infoframeram_addr : std_logic_vector(8 downto 0);

begin

  -- mode detection for Wii
  mode_detect: if TargetConsole = "WII" generate
    Inst_CMD: ConsoleModeDetect port map (
      Clock       => Clock54M,
      I2S_LRClock => I2S_LRClock,
      ConsoleMode => console_mode
    );

    -- (note: console_mode is initialized to MODE_GC)
  end generate;
  ConsoleMode <= console_mode;

  -- forward internal clock to top level
  PipeClock <= Clock54M;

  -- logic/bool adapters
  force_ypbpr <= (ForceYPbPr = '0');
  obuf_oe     <= '1' when video_settings.DisableOutput else '0';

  -- cable detect output
  process(video_settings)
  begin
    if video_settings.CableDetect then
      CableDetect <= '1';
    else
      if TargetConsole = "WII" then
        -- avoid a hard low so an external cable doesn't short the output
        CableDetect <= 'Z';
      else
        CableDetect <= '0';
      end if;
    end if;
  end process;

  -- CPU subsystem
  Inst_CPU: CPUSubsystem generic map (
    Firmware         => Firmware
  ) port map (
    Clock            => Clock54M,
    ExtReset         => not clock_locked,
    VideoIn          => video_422,
    VideoLD          => video_ld,
    PixelClockEnable => pixel_clk_en,
    ConsoleMode      => console_mode,
    ForceYPbPr       => force_ypbpr,
    PadData          => PadData,
    IRReceiver       => IRReceiver,
    IRButton         => IRButton,
    SPI_MOSI         => Flash_MOSI,
    SPI_MISO         => Flash_MISO,
    SPI_SCK          => Flash_SCK,
    SPI_SSEL         => Flash_SSEL,
    ScanlineRamAddr  => scanline_ram_addr,
    ScanlineRamData  => scanline_ram_data,
    InfoFrameRAMAddr => infoframeram_addr,
    InfoFrameRAMData => infoframeram_data,
    OSDRamAddr       => osd_ram_addr,
    OSDRamData       => osd_ram_data,
    OSDSettings      => osd_settings,
    VSettings        => video_settings,
    VMeasure         => video_measurements
  );

  -- DVI output
  Inst_DVI: dvid port map (
    clk               => DVIClockP,
    clk_n             => DVIClockN,
    clk_pixel         => Clock54M,
    clk_pixel_en      => pixel_clk_en_27,
    ConsoleMode       => console_mode,
    Video             => video_out,
    EnhancedMode      => video_settings.EnhancedMode,
    Widescreen        => video_settings.Widescreen,
    ColorMode         => video_settings.ColorMode,
    SampleRateHack    => video_settings.SampleRateHack,
    InfoFrameRAM_Addr => infoframeram_addr,
    InfoFrameRAM_Data => infoframeram_data,
    Audio             => audio,
    -- outputs
    Pair_Red          => Pair_Red,
    Pair_Green        => Pair_Green,
    Pair_Blue         => Pair_Blue,
    Pair_Clock        => Pair_Clock,
    red_s             => red_enc,
    green_s           => green_enc,
    blue_s            => blue_enc,
    clock_s           => clock_enc
  );

  OBUFDS_red   : OBUFTDS port map ( O => DVI_Red(0),   OB => DVI_Red(1),   I => red_enc,   T => obuf_oe);
  OBUFDS_green : OBUFTDS port map ( O => DVI_Green(0), OB => DVI_Green(1), I => green_enc, T => obuf_oe);
  OBUFDS_blue  : OBUFTDS port map ( O => DVI_Blue(0),  OB => DVI_Blue(1),  I => blue_enc,  T => obuf_oe);
  OBUFDS_clock : OBUFTDS port map ( O => DVI_Clock(0), OB => DVI_Clock(1), I => clock_enc, T => obuf_oe);

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
      ConsoleMode => console_mode,
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
      PixelClock        => Clock54M,
      PixelClockEnable  => pixel_clk_en_ld,
      InterpolateChroma => video_settings.InterpolateChroma,
      Output422         => output_422,
      VideoIn           => video_ld,
      VideoOut          => video_444
    );
  output_422 <= (video_settings.ColorMode = "11");

  -- regenerate blanking signal
  Inst_Reblanking: Blanking_Regenerator
    PORT MAP (
      PixelClock        => Clock54M,
      PixelClockEnable  => pixel_clk_en_ld,
      ReblankingEnable  => video_settings.EnableReblanking,
      ResyncingEnable   => video_settings.EnableResyncing,
      RBSettings        => video_settings.RBSettings,
      VideoMeasurements => video_measurements,
      VideoIn           => video_444,
      VideoOut          => video_444_rb
    );

  -- overlay scanlines
  Inst_Scanliner: Scanline_Generator
    PORT MAP (
      PixelClock       => Clock54M,
      PixelClockEnable => pixel_clk_en_ld,
      Enable           => scanlines_enabled,
      Use_Even         => scanline_even,
      PixelY           => scanline_ram_addr,
      ScanlineStrength => scanline_ram_data,
      VideoIn          => video_444_rb,
      VideoOut         => video_444_sl
    );

  scanlines_enabled <= video_settings.ScanlineProfile /= "00";
  scanline_even <= video_settings.ScanlinesEven xor
                   (not video_422.IsProgressive and video_422.IsEvenField and video_settings.ScanlinesAlternate);

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

  -- convert color space
  Inst_colormatrix: ColorMatrix
    PORT MAP (
      PixelClock       => Clock54M,
      PixelClockEnable => pixel_clk_en_ld,
      Settings         => video_settings,
      VideoIn          => video_444_osd,
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

  -- apply blanking to final RGB signal
  process (Clock54M, pixel_clk_en_ld)
  begin
    if rising_edge(Clock54M) and pixel_clk_en_ld then
      video_out <= video_rgb;

      if video_rgb.Blanking then
        video_out.PixelR <= (others => '0');
        video_out.PixelG <= (others => '0');
        video_out.PixelB <= (others => '0');
      end if;
    end if;
  end process;

  -- generate signals for analog output: DAC Clock
  process(Clock54M)
  begin
    if rising_edge(Clock54M) then
      if pixel_clk_en_ld then
        DAC_Clock <= '0';
      else
        DAC_Clock <= '1';
      end if;
    end if;
  end process;

  -- parallel video data
  process(Clock54M, pixel_clk_en_ld)
  begin
    if rising_edge(Clock54M) and pixel_clk_en_ld then
      if video_settings.AnalogRGBOutput and ForceYPbPr /= '0' then
        -- RGB mode
        DAC_RGBMode <= true;

        if video_settings.SyncOnGreen then
          if video_out.CSync then
            DAC_SyncN <= '0';
          else
            DAC_SyncN <= '1';
          end if;
        else
          DAC_SyncN <= '0';
        end if;

        -- video_out already has blanking applied
        DAC_Red   <= std_logic_vector(video_out.PixelR);
        DAC_Green <= std_logic_vector(video_out.PixelG);
        DAC_Blue  <= std_logic_vector(video_out.PixelB);
      else
        -- component mode
        DAC_RGBMode <= false;

        if video_444_osd.CSync then
          DAC_SyncN <= '0';
        else
          DAC_SyncN <= '1';
        end if;

        if video_444_osd.Blanking then
          DAC_Red   <= x"80";
          DAC_Green <= x"10";
          DAC_Blue  <= x"80";
        else
          DAC_Red   <= std_logic_vector(video_444_osd.PixelCr + 128);
          DAC_Green <= std_logic_vector(video_444_osd.PixelY);
          DAC_Blue  <= std_logic_vector(video_444_osd.PixelCb + 128);
        end if;
      end if;
    end if;
  end process;

  -- external Syncs
  process(Clock54M, pixel_clk_en_ld)
  begin
    if rising_edge(Clock54M) and pixel_clk_en_ld then
      if video_out.CSync then
        CSync_out <= '0';
      else
        CSync_out <= '1';
      end if;

      if video_out.VSync then
        VSync_out <= '0';
      else
        VSync_out <= '1';
      end if;

      if video_out.HSync then
        HSync_out <= '0';
      else
        HSync_out <= '1';
      end if;
    end if;
  end process;

end Behavioral;
