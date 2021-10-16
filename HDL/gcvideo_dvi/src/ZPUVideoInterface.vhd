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
-- ZPUVideoInterface.vhd: Video size measurement and a few config outputs
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.video_defs.all;
use work.ZPUDevices.all;

entity ZPUVideoInterface is
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
end ZPUVideoInterface;

architecture Behavioral of ZPUVideoInterface is
  -- no cable detect
  --                                                765432109876543210
  constant VidSettingsDefault: std_logic_vector := "000000000000000000";

  -- output disabled, colors don't matter
  constant OSDBGSettingsDefault: std_logic_vector := "1------------------------";

  signal current_pixelcount: natural range 0 to 2047;
  signal current_linecount : natural range 0 to 1023;
  signal pixel_counter     : natural range 0 to 2047;
  signal line_counter      : natural range 0 to 1023;

  signal prev_hsync        : boolean;
  signal prev_vsync        : boolean;
  signal active_line       : boolean;
  signal active_line_count : natural range 0 to 7;
  signal volume_setting    : std_logic_vector( 7 downto 0) := x"ff";
  signal vid_settings      : std_logic_vector(17 downto 0) := VidSettingsDefault;
  signal osd_bgsettings    : std_logic_vector(24 downto 0) := OSDBGSettingsDefault;
  signal color_matrix      : ColorMatrix_t;
  signal reblanker_settings: ReblankerSettings_t;

  signal stored_flags_in   : std_logic_vector(3 downto 0);
  signal stored_flags_ld   : std_logic_vector(2 downto 0);
  signal console_mode      : std_logic;
  signal force_ypbpr       : std_logic;
begin

  ZPUBusOut.mem_busy <= '0';
  console_mode       <= '1' when ConsoleMode = MODE_WII else '0';
  force_ypbpr        <= '1' when ForceYPbPr             else '0';

  -- forward stored videosettings to output
  VSettings.ScanlineProfile    <= vid_settings(1 downto 0);
  VSettings.ScanlinesEven      <= (vid_settings(2)  = '1');
  VSettings.ScanlinesAlternate <= (vid_settings(3)  = '1');
  VSettings.LinedoublerEnabled <= (vid_settings(4)  = '1' and vid_settings(14) = '0');
  VSettings.CableDetect        <= (vid_settings(5)  = '1');
  VSettings.EnhancedMode       <= (vid_settings(6)  = '1');
  VSettings.Widescreen         <= (vid_settings(7)  = '1');
  VSettings.AnalogRGBOutput    <= (vid_settings(8)  = '1');
  VSettings.SyncOnGreen        <= (vid_settings(9)  = '1');
  VSettings.SampleRateHack     <= (vid_settings(10) = '1');
  VSettings.EnableReblanking   <= (vid_settings(11) = '1' and vid_settings(14) = '0');
  VSettings.EnableResyncing    <= (vid_settings(12) = '1' and vid_settings(14) = '0');
  VSettings.InterpolateChroma  <= (vid_settings(13) = '1');
  -- bit 14 is the feature override bit set in non-standard modes
  VSettings.ColorMode          <= vid_settings(16 downto 15);
  VSettings.RebuildCSync       <= (vid_settings(17) = '1' and vid_settings(14) = '0');
  VSettings.Volume             <= unsigned(volume_setting);
  VSettings.Matrix             <= color_matrix;
  VSettings.RBSettings         <= reblanker_settings;

  -- putting this bit in an unrelated register simplifies the software side
  VSettings.DisableOutput      <= (osd_bgsettings(24) = '1');

  -- forward OSD settings to output
  OSDSettings.BGAlpha  <= unsigned(osd_bgsettings(23 downto 16));
  OSDSettings.BGTintCb <=   signed(osd_bgsettings(15 downto  8));
  OSDSettings.BGTintCr <=   signed(osd_bgsettings( 7 downto  0));

  process(Clock)
  begin
    if rising_edge(Clock) then
      ---- ZPU bus interface
      -- system reset
      if ZPUBusIn.Reset = '1' then
        IRQ             <= '0';
        vid_settings    <= VidSettingsDefault;
        osd_bgsettings  <= OSDBGSettingsDefault;
        volume_setting  <= x"ff";
      end if;

      -- reset interrupt flag on any write
      if ZSelect = '1' and ZPUBusIn.mem_writeEnable = '1' then
        IRQ <= '0';
      end if;

      -- read path
      case ZPUBusIn.mem_addr(5 downto 2) is
        when "0000" => ZPUBusOut.mem_read <= std_logic_vector(to_unsigned(pixel_counter, 32));
        when "0001" => ZPUBusOut.mem_read <= std_logic_vector(to_unsigned(line_counter,  32));

        when "0010" => ZPUBusOut.mem_read             <= (others => '0');
                       ZPUBusOut.mem_read(8 downto 6) <= stored_flags_ld;
                       ZPUBusOut.mem_read(5)          <= stored_flags_in(3);
                       ZPUBusOut.mem_read(4)          <= force_ypbpr;
                       ZPUBusOut.mem_read(3)          <= console_mode;
                       ZPUBusOut.mem_read(2 downto 0) <= stored_flags_in(2 downto 0);

        when "0011" => ZPUBusOut.mem_read <= std_logic_vector(to_unsigned(VMeasure.HTotal, 32));
        when "0100" => ZPUBusOut.mem_read <= std_logic_vector(to_unsigned(VMeasure.HActiveStart, 32));
        when "0101" => ZPUBusOut.mem_read <= std_logic_vector(to_unsigned(VMeasure.VTotal, 32));

        when "0110" => ZPUBusOut.mem_read <= std_logic_vector(to_unsigned(VMeasure.VActiveStart0, 32));
        when "0111" => ZPUBusOut.mem_read <= std_logic_vector(to_unsigned(VMeasure.VHOffset0, 32));
        when "1000" => ZPUBusOut.mem_read <= std_logic_vector(to_unsigned(VMeasure.VActiveStart1, 32));
        when "1001" => ZPUBusOut.mem_read <= std_logic_vector(to_unsigned(VMeasure.VHOffset1, 32));

        when others => ZPUBusOut.mem_read <= (others => '-');  -- undefined
      end case;

      -- write path
      if ZSelect = '1' and ZPUBusIn.mem_writeEnable = '1' then
        case ZPUBusIn.mem_addr(5 downto 2) is
          when "0000" => vid_settings   <= ZPUBusIn.mem_write(17 downto 0);
          when "0001" => osd_bgsettings <= ZPUBusIn.mem_write(24 downto 0);
          when "0010" => volume_setting <= ZPUBusIn.mem_write( 7 downto 0);

          when "0011" =>
            color_matrix.YBias     <= signed(ZPUBusIn.mem_write( 9 downto  0));
            color_matrix.YRFactor  <= signed(ZPUBusIn.mem_write(31 downto 16));
          when "0100" =>
            color_matrix.YGFactor  <= signed(ZPUBusIn.mem_write(15 downto  0));
            color_matrix.YBFactor  <= signed(ZPUBusIn.mem_write(31 downto 16));
          when "0101" =>
            color_matrix.CbGFactor <= signed(ZPUBusIn.mem_write(15 downto  0));
            color_matrix.CbBFactor <= signed(ZPUBusIn.mem_write(31 downto 16));
          when "0110" =>
            color_matrix.CrRFactor <= signed(ZPUBusIn.mem_write(15 downto  0));
            color_matrix.CrGFactor <= signed(ZPUBusIn.mem_write(31 downto 16));

          when "0111" =>
            reblanker_settings.HSyncStart <= to_integer(unsigned(ZPUBusIn.mem_write(15 downto 0)));
            reblanker_settings.HSyncEnd   <= to_integer(unsigned(ZPUBusIn.mem_write(31 downto 16)));

          when "1000" =>
            reblanker_settings.HActiveStart <= to_integer(unsigned(ZPUBusIn.mem_write(15 downto 0)));
            reblanker_settings.HActiveEnd   <= to_integer(unsigned(ZPUBusIn.mem_write(31 downto 16)));

          when "1001" =>
            reblanker_settings.VSyncStart <= to_integer(unsigned(ZPUBusIn.mem_write(19 downto 0)));

          when "1010" =>
            reblanker_settings.VSyncEnd   <= to_integer(unsigned(ZPUBusIn.mem_write(19 downto 0)));

          when "1011" =>
            reblanker_settings.VActiveStart <= to_integer(unsigned(ZPUBusIn.mem_write(9 downto 0)));

          when "1100" =>
            reblanker_settings.VActiveLines <= to_integer(unsigned(ZPUBusIn.mem_write(9 downto 0)));

          -- Note: There must be at least one unused register that is written
          -- to for clearing the IRQ flag!
          when "1101" => null;

          when others => null;
        end case;
      end if;

      ---- update signal measurements
      -- (note: this measures the raw input signal, the BlankingRegen measures
      --        the result of the linedoubler)
      if PixelClockEnable then
        prev_vsync <= VideoIn.VSync;
        prev_hsync <= VideoIn.HSync;

        if not VideoIn.Blanking then
          -- non-blank pixel on line
          current_pixelcount <= current_pixelcount + 1;
          active_line        <= true;
        end if;

        if VideoIn.HSync and not prev_hsync and
           not VideoIn.VSync then
          -- start of HSync, outside VSync
          if active_line then
            -- measure just one line per frame, but not the first
            if active_line_count < 7 then
              active_line_count <= active_line_count + 1;
            end if;

            if active_line_count = 6 then
              pixel_counter <= current_pixelcount;
            end if;

            current_linecount <= current_linecount + 1;
          end if;

          current_pixelcount <= 0;
          active_line        <= false;
        end if;

        if VideoIn.VSync and not prev_vsync then
          -- start of VSync, copy remaining measurements
          IRQ <= '1';

          line_counter      <= current_linecount;
          current_linecount <= 0;
          active_line_count <= 0;

          stored_flags_in <= (others => '0');

          if VideoIn.IsProgressive then
            stored_flags_in(0) <= '1';
          end if;
          if VideoIn.IsPAL then
            stored_flags_in(1) <= '1';
          end if;
          if VideoIn.Is30kHz then
            stored_flags_in(2) <= '1';
          end if;
          if VideoIn.IsEvenField then
            stored_flags_in(3) <= '1';
          end if;

          stored_flags_ld <= (others => '0');

          if VideoLD.IsProgressive then
            stored_flags_ld(0) <= '1';
          end if;
          if VideoLD.IsPAL then
            -- technically redundant, but simplifies the software side
            stored_flags_ld(1) <= '1';
          end if;
          if VideoLD.Is30kHz then
            stored_flags_ld(2) <= '1';
          end if;

        end if;

      end if;
    end if;
  end process;

end Behavioral;

