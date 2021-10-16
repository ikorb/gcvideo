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
    Firmware     : string;
    Module       : string  -- "main" or "flasher"
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
  signal video_gcdv_out     : VideoY422;
  signal video_ld_in        : VideoY422;
  signal video_ld_out       : VideoY422;
  signal video_422conv_in   : VideoY422;
  signal video_422conv_out  : VideoYCbCr;
  signal video_reblanker_in : VideoYCbCr;
  signal video_reblanker_out: VideoYCbCr;
  signal video_scanliner_in : VideoYCbCr;
  signal video_scanliner_out: VideoYCbCr;
  signal video_osd_in       : VideoYCbCr;
  signal video_osd_out      : VideoYCbCr;
  signal video_cmatrix_in   : VideoYCbCr;
  signal video_cmatrix_out  : VideoRGB;
  signal video_ycrange_in   : VideoYCbCr;
  signal video_dvienc_in    : VideoRGB;
  signal video_dac_in       : VideoRGB;

  signal pixel_clk_en          : boolean; -- base pixel clock from GCDV decoder
  signal pixel_clk_en_2x       : boolean; -- double base pixel clock from GCDV decoder
  signal pixel_clk_en_27       : boolean; -- fixed 27MHz for DVI output, results in pixel-doubling for 15k modes

  signal pixel_clk_en_ld_out   : boolean;
  signal pixel_clk_en_422conv  : boolean := false;
  signal pixel_clk_en_reblanker: boolean := false;
  signal pixel_clk_en_scanliner: boolean := false;
  signal pixel_clk_en_osd      : boolean := false;
  signal pixel_clk_en_cmatrix  : boolean := false;
  signal pixel_clk_en_ycrange  : boolean := false;
  signal pixel_clk_en_dac      : boolean := false;

  -- analog output
  signal pixel_y_range  : unsigned(7 downto 0);
  signal pixel_cb_range : unsigned(7 downto 0);
  signal pixel_cr_range : unsigned(7 downto 0);
  signal use_syncongreen: boolean;

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

  -- video settings
  signal video_settings   : VideoSettings_t;
  signal vs_enhanced_mode : boolean;
  signal vs_widescreen    : boolean;
  signal vs_colormode     : std_logic_vector(1 downto 0);
  signal vs_sampleratehack: boolean;
  signal vs_analogrgbout  : boolean;
  signal vs_rebuildcsync  : boolean;

  -- misc
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
    Firmware         => Firmware,
    Module           => Module
  ) port map (
    Clock            => Clock54M,
    ExtReset         => not clock_locked,
    VideoIn          => video_gcdv_out,
    VideoLD          => video_ld_out,
    PixelClockEnable => pixel_clk_en,
    ConsoleMode      => console_mode,
    ForceYPbPr       => force_ypbpr,
    PadData          => PadData,
    IRReceiver       => IRReceiver,
    IRButton         => IRButton,
    I2S_BClock       => I2S_BClock,
    I2S_LRClock      => I2S_LRClock,
    I2S_Data         => I2S_Data,
    SPI_COPI         => Flash_COPI,
    SPI_CIPO         => Flash_CIPO,
    SPI_SCK          => Flash_SCK,
    SPI_SEL          => Flash_SEL,
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
    Video             => video_dvienc_in,
    EnhancedMode      => vs_enhanced_mode,
    Widescreen        => vs_widescreen,
    ColorMode         => vs_colormode,
    SampleRateHack    => vs_sampleratehack,
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

  vs_main: if Module = "main" generate
    vs_enhanced_mode  <= video_settings.EnhancedMode;
    vs_widescreen     <= video_settings.Widescreen;
    vs_sampleratehack <= video_settings.SampleRateHack;
    vs_colormode      <= video_settings.ColorMode;
    vs_analogrgbout   <= video_settings.AnalogRGBOutput;
    vs_rebuildcsync   <= video_settings.RebuildCSync;
  end generate;

  vs_flasher: if Module = "flasher" generate
    vs_enhanced_mode  <= false;
    vs_widescreen     <= false;
    vs_sampleratehack <= false;
    vs_colormode      <= "01"; -- RGB limited range
    vs_analogrgbout   <= false;
    vs_rebuildcsync   <= false;
  end generate;

  -- main clock generator
  Inst_ClockGen: ClockGen
    generic map (
      TargetConsole => TargetConsole
    ) port map (
      ClockIn    => VClockN,
      BClock     => I2S_BClock,
      Clock54M   => Clock54M,
      ClockAudio => ClockAudio,
      DVIClockP  => DVIClockP,
      DVIClockN  => DVIClockN,
      Locked     => clock_locked
    );

  audio_main: if Module = "main" generate
    -- audio module
    Inst_Audio: Audio_SPDIF
      port map (
        Clock54     => Clock54M,
        Clock162    => ClockAudio,
        ConsoleMode => console_mode,
        I2S_BClock  => I2S_BClock,
        I2S_LRClock => I2S_LRClock,
        I2S_Data    => I2S_Data,
        Volume      => video_settings.Volume,
        Audio       => audio,
        SPDIF_Out   => SPDIF_Out
      );
  end generate;

  audio_flasher: if Module = "flasher" generate
    -- no audio
    SPDIF_Out         <= '0';
    audio.Left        <= (others => '0');
    audio.Right       <= (others => '0');
    audio.LeftEnable  <= false;
    audio.RightEnable <= false;
  end generate;

  -- read gamecube video data
  Inst_GCVideo: GCDV_Decoder
    PORT MAP (
      VClockI            => Clock54M,
      VData              => VData,
      CSel               => CSel,
      PixelClockEnable   => pixel_clk_en,
      PixelClockEnable2x => pixel_clk_en_2x,
      Video              => video_gcdv_out
    );

  -- linedouble 15kHz modes to 30kHz
  Inst_Linedoubler: Linedoubler
    PORT MAP (
      PixelClock         => Clock54M,
      PixelClockEnable   => pixel_clk_en,
      PixelClockEnable2x => pixel_clk_en_2x,
      Enable             => video_settings.LinedoublerEnabled,
      VideoIn            => video_ld_in,
      VideoOut           => video_ld_out,
      PixelOutEnable     => pixel_clk_en_ld_out
    );

  -- interpolate 4:2:2 to 4:4:4
  Inst_422_to_444: Convert_422_to_444
    PORT MAP (
      PixelClock        => Clock54M,
      PixelClockEnable  => pixel_clk_en_422conv,
      InterpolateChroma => video_settings.InterpolateChroma,
      Output422         => output_422,
      VideoIn           => video_422conv_in,
      VideoOut          => video_422conv_out
    );

  output_422 <= (video_settings.ColorMode = "11");

  blanking_regen_main: if Module = "main" generate
    -- regenerate blanking signal
    Inst_Reblanking: Blanking_Regenerator
      PORT MAP (
        PixelClock        => Clock54M,
        PixelClockEnable  => pixel_clk_en_reblanker,
        ReblankingEnable  => video_settings.EnableReblanking,
        ResyncingEnable   => video_settings.EnableResyncing,
        RBSettings        => video_settings.RBSettings,
        VideoMeasurements => video_measurements,
        VideoIn           => video_reblanker_in,
        VideoOut          => video_reblanker_out
      );

    -- overlay scanlines
    Inst_Scanliner: Scanline_Generator
      PORT MAP (
        PixelClock       => Clock54M,
        PixelClockEnable => pixel_clk_en_scanliner,
        Enable           => scanlines_enabled,
        Use_Even         => scanline_even,
        PixelY           => scanline_ram_addr,
        ScanlineStrength => scanline_ram_data,
        VideoIn          => video_scanliner_in,
        VideoOut         => video_scanliner_out
      );

    scanlines_enabled <= video_settings.ScanlineProfile /= "00";
    scanline_even <= video_settings.ScanlinesEven xor
                     (not video_gcdv_out.IsProgressive and
                          video_gcdv_out.IsEvenField   and
                          video_settings.ScanlinesAlternate);

  end generate;

  blanking_regen_flasher: if Module = "flasher" generate
    -- regenerate blanking signal
    Inst_Reblanking: Blanking_Regenerator_Fixed
      PORT MAP (
        PixelClock       => Clock54M,
        PixelClockEnable => pixel_clk_en_reblanker,
        VideoIn          => video_reblanker_in,
        VideoOut         => video_reblanker_out
      );

    video_measurements.HTotal        <= 0;
    video_measurements.HActiveStart  <= 0;
    video_measurements.VTotal        <= 0;
    video_measurements.VActiveStart0 <= 0;
    video_measurements.VActiveStart1 <= 0;
    video_measurements.VHOffset0     <= 0;
    video_measurements.VHOffset1     <= 0;

    -- no scanlines
  end generate;

  -- add OSD overlay
  Inst_OSD: TextOSD
    PORT MAP (
      PixelClock       => Clock54M,
      PixelClockEnable => pixel_clk_en_osd,
      VideoIn          => video_osd_in,
      VideoOut         => video_osd_out,
      Settings         => osd_settings,
      RAMAddress       => osd_ram_addr,
      RAMData          => osd_ram_data
    );

  -- value range rescaling for analog output
  Inst_ycrange: ycrange
    port map (
      Clock       => Clock54M,
      ClockEnable => pixel_clk_en_ycrange,
      PixelY      => video_ycrange_in.PixelY,
      PixelCb     => video_ycrange_in.PixelCb,
      PixelCr     => video_ycrange_in.PixelCr,
      OutY        => pixel_y_range,
      OutCb       => pixel_cb_range,
      OutCr       => pixel_cr_range
    );

  -- color conversion
  colorspace_main: if Module = "main" generate
    -- convert color space
    Inst_colormatrix: ColorMatrix
      PORT MAP (
        PixelClock       => Clock54M,
        PixelClockEnable => pixel_clk_en_cmatrix,
        Settings         => video_settings,
        VideoIn          => video_cmatrix_in,
        VideoOut         => video_cmatrix_out
      );
  end generate;

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

  -- generate signals for analog output: DAC Clock
  process(Clock54M)
  begin
    if rising_edge(Clock54M) then
      if pixel_clk_en_dac then
        DAC_Clock <= '0';
      else
        DAC_Clock <= '1';
      end if;
    end if;
  end process;

  -- parallel video data
  process(Clock54M, pixel_clk_en_dac)
    variable csync: boolean;
  begin
    if rising_edge(Clock54M) and pixel_clk_en_dac then
      if vs_rebuildcsync then
        csync := video_dac_in.VSync xor video_dac_in.HSync;
      else
        csync := video_dac_in.CSync;
      end if;

      if use_syncongreen then
        if csync then
          DAC_SyncN <= '0';
        else
          DAC_SyncN <= '1';
        end if;
      else
        DAC_SyncN <= '0';
      end if;

      DAC_Red   <= std_logic_vector(video_dac_in.PixelR);
      DAC_Green <= std_logic_vector(video_dac_in.PixelG);
      DAC_Blue  <= std_logic_vector(video_dac_in.PixelB);
    end if;
  end process;

  -- external Syncs
  process(Clock54M, pixel_clk_en_ld_out)
    variable csync: boolean;
    variable hsync: boolean;
    variable vsync: boolean;
  begin
    if rising_edge(Clock54M) and pixel_clk_en_ld_out then
      if Module = "flasher" then
        csync := video_gcdv_out.CSync;
        hsync := video_gcdv_out.HSync;
        vsync := video_gcdv_out.VSync;

      else
        if vs_rebuildcsync then
          csync := video_dvienc_in.VSync xor video_dvienc_in.HSync;
        else
          csync := video_dvienc_in.CSync;
        end if;

        hsync := video_dvienc_in.HSync;
        vsync := video_dvienc_in.VSync;
      end if;

      if csync then
        CSync_out <= '0';
      else
        CSync_out <= '1';
      end if;

      if vsync then
        VSync_out <= '0';
      else
        VSync_out <= '1';
      end if;

      if hsync then
        HSync_out <= '0';
      else
        HSync_out <= '1';
      end if;

    end if;
  end process;


  -- signal connections
  Connections_Flasher: if Module = "flasher" generate
    -- reduced pipeline, monochrome only
    --   in -> OSD -> linedoubler -> reblanker -> dvid
    --         +-> dac
    video_osd_in       <= to_444_mono(video_gcdv_out);
    video_ld_in        <= to_422_mono(video_osd_out);
    video_reblanker_in <= to_444_mono(video_ld_out);
    video_dvienc_in    <= to_rgb_mono(video_reblanker_out);

    pixel_clk_en_osd       <= pixel_clk_en;
    pixel_clk_en_reblanker <= pixel_clk_en_ld_out;
    pixel_clk_en_dac       <= pixel_clk_en;

    DAC_RGBMode     <= false;
    use_syncongreen <= true;

    process(Clock54M, pixel_clk_en)
    begin
      if rising_edge(Clock54M) and pixel_clk_en then
        video_dac_in.PixelR <= x"80";
        video_dac_in.PixelG <= video_osd_out.PixelY;
        video_dac_in.PixelB <= x"80";
        video_dac_in.HSync  <= video_osd_out.HSync;
        video_dac_in.VSync  <= video_osd_out.VSync;
        video_dac_in.CSync  <= video_osd_out.CSync;

        if video_osd_out.Blanking then
          video_dac_in.PixelG <= x"00";
          -- let's hope that the signals on R and B are clamped to something useful...
        end if;

      end if;
    end process;

  end generate;

  Connections_Main: if Module = "main" generate
    video_ld_in        <= video_gcdv_out;
    video_422conv_in   <= video_ld_out;
    video_reblanker_in <= video_422conv_out;
    video_scanliner_in <= video_reblanker_out;
    video_osd_in       <= video_scanliner_out;
    video_cmatrix_in   <= video_osd_out;
    video_ycrange_in   <= video_osd_out;
    video_dvienc_in    <= video_cmatrix_out;

    pixel_clk_en_422conv   <= pixel_clk_en_ld_out;
    pixel_clk_en_reblanker <= pixel_clk_en_ld_out;
    pixel_clk_en_scanliner <= pixel_clk_en_ld_out;
    pixel_clk_en_osd       <= pixel_clk_en_ld_out;
    pixel_clk_en_cmatrix   <= pixel_clk_en_ld_out;
    pixel_clk_en_ycrange   <= pixel_clk_en_ld_out;
    pixel_clk_en_dac       <= pixel_clk_en_ld_out;

    process(Clock54M, pixel_clk_en_ld_out)
    begin
      if rising_edge(Clock54M) and pixel_clk_en_ld_out then
        if force_ypbpr or not video_settings.AnalogRGBOutput then
          -- YPbPr output
          DAC_RGBMode     <= false;
          use_syncongreen <= true;

          video_dac_in.PixelR <= pixel_cr_range;
          video_dac_in.PixelG <= pixel_y_range;
          video_dac_in.PixelB <= pixel_cb_range;
          video_dac_in.HSync  <= video_osd_out.HSync;
          video_dac_in.VSync  <= video_osd_out.VSync;
          video_dac_in.CSync  <= video_osd_out.CSync;

          if video_osd_out.Blanking then
            video_dac_in.PixelR <= x"80";
            video_dac_in.PixelG <= x"00";
            video_dac_in.PixelB <= x"80";
          end if;

        else
          -- RGB output
          DAC_RGBMode     <= true;
          use_syncongreen <= video_settings.SyncOnGreen;

          video_dac_in <= video_cmatrix_out;

          if video_cmatrix_out.Blanking then
            video_dac_in.PixelR <= x"00";
            video_dac_in.PixelG <= x"00";
            video_dac_in.PixelB <= x"00";
          end if;

        end if;
      end if;
    end process;

  end generate;

end Behavioral;
