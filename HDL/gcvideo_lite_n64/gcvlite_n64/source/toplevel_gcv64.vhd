----------------------------------------------------------------------------------
-- GCVideo Lite for N64 HDL Version 1.0
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
-- toplevel_gcv64: The top-level module for gcvl64
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.component_defs.all;
use work.video_defs.all;

entity toplevel_gcv64 is
  port (
    VClock   : in  std_logic;
    VData    : in  std_logic_vector(6 downto 0);
    DSync    : in  std_logic;

    RGBSelect: in  std_logic;

    VideoR   : out std_logic_vector(7 downto 0);
    VideoG   : out std_logic_vector(7 downto 0);
    VideoB   : out std_logic_vector(7 downto 0);
    DACSYNCn : out std_logic;
    DACCLOCK : out std_logic;
    EXTHSYNCn: out std_logic;
    EXTVSYNCn: out std_logic;
    EXTCSYNCn: out std_logic
);
end toplevel_gcv64;

architecture Behavioral of toplevel_gcv64 is
  signal VClockI: std_logic;

  signal video_rgb      : VideoRGB;
  signal video_ycbcr    : VideoYCbCr;

  signal pixel_clk_en   : boolean;
  signal pixel_clk_en_2x: boolean;
  
  signal use_rgb        : boolean;

begin

  VClockI <= not VClock;
  
  -----------
  -- Video --
  -----------

  -- read N64 video data
  Inst_N64Video: N64V_Decoder PORT MAP (
    VClockI      => VClockI,
    VData        => VData,
    DSync        => DSync,
    PixelClkEn   => pixel_clk_en,
    PixelClkEn2x => pixel_clk_en_2x,
    Video        => video_rgb
  );

  -- convert to YCbCr
  Inst_rgbtoycbcr: convert_rgb_to_ycbcr PORT MAP (
    Clock         => VClockI,
    ClockEnable   => pixel_clk_en,
    ClockEnable2x => pixel_clk_en_2x,
    VideoIn       => video_rgb,
    VideoOut      => video_ycbcr
  );

  -- create DAC clock
  process(VClockI, pixel_clk_en_2x)
  begin
    if rising_edge(VClockI) and pixel_clk_en_2x then
      if pixel_clk_en then
        DACCLOCK <= '0';
      else
        DACCLOCK <= '1';
      end if;
    end if;
  end process;

  -- output everything
  process(VClockI, pixel_clk_en)
    variable out_hsync: boolean;
    variable out_vsync: boolean;
    variable out_csync: boolean;
  begin
    if rising_edge(VClockI) and pixel_clk_en then

      if RGBSelect = '0' then
        -- pads bridged, enable RGB
	if video_rgb.Blanking then
	  VideoR <= x"00";
	  VideoG <= x"00";
	  VideoB <= x"00";
	else
	  VideoR <= std_logic_vector(video_rgb.PixelR) & '0';
	  VideoG <= std_logic_vector(video_rgb.PixelG) & '0';
	  VideoB <= std_logic_vector(video_rgb.PixelB) & '0';
	end if;

	DACSYNCn <= '0';

	out_hsync := video_rgb.HSync;
	out_vsync := video_rgb.VSync;
	out_csync := video_rgb.CSync;

      else
        -- pads open, output component
	if video_ycbcr.Blanking then
	  VideoR <= x"80";
	  VideoG <= x"10";
	  VideoB <= x"80";
	else
	  VideoR <= std_logic_vector(video_ycbcr.PixelCr) & '0';
	  VideoG <= std_logic_vector(video_ycbcr.PixelY)  & '0';
	  VideoB <= std_logic_vector(video_ycbcr.PixelCb) & '0';
	end if;

	if video_ycbcr.CSync then
	  DACSYNCn <= '0';
	else
	  DACSYNCn <= '1';
	end if;

	out_hsync := video_ycbcr.HSync;
	out_vsync := video_ycbcr.VSync;
	out_csync := video_ycbcr.CSync;
      end if;

      -- output seperate sync signals
      if out_hsync then
        EXTHSYNCn <= '1';
      else
        EXTHSYNCn <= '0';
      end if;

      if out_vsync then
        EXTVSYNCn <= '1';
      else
        EXTVSYNCn <= '0';
      end if;

      if out_csync then
        EXTCSYNCn <= '1';
      else
        EXTCSYNCn <= '0';
      end if;

    end if;
  end process;

end Behavioral;

