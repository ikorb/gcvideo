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
-- TextOSD.vhd: Text mode video overlay
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.component_defs.all;
use work.video_defs.all;

entity TextOSD is
  port (
    PixelClock      : in  std_logic;
    PixelClockEnable: in  boolean;
    VideoIn         : in  VideoYCbCr;
    VideoOut        : out VideoYCbCr;
    Settings        : in  OSDSettings_t;

    RAMAddress      : out std_logic_vector(10 downto 0);
    RAMData         : in  std_logic_vector(8 downto 0)
  );
end TextOSD;

architecture Behavioral of TextOSD is
  signal prev_blanking : boolean := false;
  signal line_toggle   : boolean := false;
  signal pixel_toggle  : boolean := false;
  signal char_line     : unsigned(2 downto 0) := (others => '0');
  signal char_pixel    : natural range 0 to 7 := 0;
  signal shifter       : std_logic_vector(7 downto 0) := (others => '0');
  signal attributes    : std_logic_vector(1 downto 0) := (others => '0');

  signal video_addr    : unsigned(10 downto 0) := (others => '0');
  signal linestart_addr: unsigned(10 downto 0) := (others => '0');

  signal font_addr     : std_logic_vector(9 downto 0) := (others => '0');
  signal font_data     : std_logic_vector(7 downto 0) := (others => '0');

begin

  -- Font ROM
  Inst_FontROM: SimpleROM GENERIC MAP (
    AddressBits => 10,
    DataBits    => 8,
    Datafile    => "osdfont.mif"
  ) PORT MAP (
    Clock       => PixelClock,
    ClockEnable => PixelClockEnable,
    Address     => font_addr,
    Data        => font_data
  );

  RAMAddress <= std_logic_vector(video_addr);

  process(PixelClock, PixelClockEnable)
    variable DimmedY: unsigned(7 downto 0);
  begin
    if rising_edge(PixelClock) and PixelClockEnable then
      prev_blanking <= VideoIn.Blanking;

      -- fetch character data
      font_addr <= RAMData(6 downto 0) & std_logic_vector(char_line);

      if VideoIn.VSync then
        -- start of frame
        char_line      <= "000";
        char_pixel     <= 7;
        video_addr     <= (others => '0');
        linestart_addr <= (others => '0');
        line_toggle    <= not VideoIn.Is30kHz;
        pixel_toggle   <= false;

      elsif VideoIn.HSync then
        -- fetch character data
        shifter    <= font_data;
        attributes <= RAMData(8 downto 7);

      elsif not prev_blanking and VideoIn.Blanking then
        -- end of active area
        char_pixel   <= 7;
        pixel_toggle <= true;
        video_addr   <= linestart_addr;

        if line_toggle then
          if char_line < 7 then
            char_line <= char_line + 1;
          else
            char_line      <= "000";
            video_addr     <= linestart_addr + 45; -- 45 = 720 px/line / 16 px/char
            linestart_addr <= linestart_addr + 45;
          end if;
        end if;

        -- show lines twice in 30kHz modes
        if VideoIn.Is30kHz then
          line_toggle <= not line_toggle;
        end if;

      elsif not VideoIn.Blanking then
        if pixel_toggle then
          if char_pixel = 0 then
            -- advance screen address at beginning of character
            video_addr <= video_addr + 1;
          end if;

          if char_pixel < 7 then
            char_pixel <= char_pixel + 1;
            shifter    <= shifter(6 downto 0) & "0";
          else
            -- fetch font pixels and attributes at end of character
            char_pixel <= 0;
            shifter    <= font_data;
            attributes <= RAMData(8 downto 7);
          end if;
        end if;
        pixel_toggle <= not pixel_toggle;

      end if;

      -- calculate dimmed pixel values
      DimmedY := resize((VideoIn.PixelY * Settings.BGAlpha) / 256, 8);

      -- output the pixel
      case shifter(7) & attributes is
        when "001" | "011" |  -- dimmed background (char on dimmed bg)
             "100" | "110" => -- dimmed background (char as dim-mask)
                       VideoOut.PixelY  <= DimmedY;
                       VideoOut.PixelCb <= Settings.BGTintCb;
                       VideoOut.PixelCr <= Settings.BGTintCr;
        when "101"  => VideoOut.PixelY  <= to_unsigned(235, 8); -- active color
                       VideoOut.PixelCb <= x"00";
                       VideoOut.PixelCr <= x"00";
        when "111"  => VideoOut.PixelY  <= to_unsigned(85, 8);  -- inactive color
                       VideoOut.PixelCb <= x"00";
                       VideoOut.PixelCr <= x"00";
        when others => VideoOut.PixelY  <= VideoIn.PixelY;      -- transparent
                       VideoOut.PixelCb <= VideoIn.PixelCb;
                       VideoOut.PixelCr <= VideoIn.PixelCr;
      end case;
    end if;
  end process;

  -- generate delayed signals
  Inst_HSyncDelay: delayline_bool
    generic map (
      Delayticks  => 1
    )
    port map (
      Clock       => PixelClock,
      ClockEnable => PixelClockEnable,
      Input       => VideoIn.HSync,
      Output      => VideoOut.HSync
    );

  Inst_VSyncDelay: delayline_bool
    generic map (
      Delayticks  => 1
    )
    port map (
      Clock       => PixelClock,
      ClockEnable => PixelClockEnable,
      Input       => VideoIn.VSync,
      Output      => VideoOut.VSync
    );

  Inst_CSyncDelay: delayline_bool
    generic map (
      Delayticks  => 1
    )
    port map (
      Clock       => PixelClock,
      ClockEnable => PixelClockEnable,
      Input       => VideoIn.CSync,
      Output      => VideoOut.CSync
    );

  Inst_BlankingDelay: delayline_bool
    generic map (
      Delayticks  => 1
    )
    port map (
      Clock       => PixelClock,
      ClockEnable => PixelClockEnable,
      Input       => VideoIn.Blanking,
      Output      => VideoOut.Blanking
    );

  Inst_FieldDelay: delayline_bool
    generic map (
      Delayticks  => 1
    )
    port map (
      Clock       => PixelClock,
      ClockEnable => PixelClockEnable,
      Input       => VideoIn.IsEvenField,
      Output      => VideoOut.IsEvenField
    );

  -- copy non-delayed, non-processed signals
  VideoOut.IsProgressive <= VideoIn.IsProgressive;
  VideoOut.IsPAL         <= VideoIn.IsPAL;
  VideoOut.Is30kHz       <= VideoIn.Is30kHz;

end Behavioral;

