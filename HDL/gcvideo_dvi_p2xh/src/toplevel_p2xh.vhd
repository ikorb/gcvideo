----------------------------------------------------------------------------------
-- GCVideo DVI HDL Version 1.0
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
-- toplevel_p2xh.vhd: top level module for the Pluto IIx HDMI board
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
library UNISIM;
use UNISIM.VComponents.all;

use work.Component_Defs.all;
use work.video_defs.all;

entity toplevel_p2xh is
  port (
    -- clocks
    VClockN  : in  std_logic;
    
    -- gamecube video signals
    VData      : in  std_logic_vector(7 downto 0);
    CSel       : in  std_logic; -- usually named ClkSel, but it's really a color select
    CableDetect: out std_logic;

    -- board-internal
    LED1: out std_logic;
    LED2: out std_logic;
    
    -- selection jumpers
    Jumper1: in std_logic_vector(2 downto 0);
    Jumper2: in std_logic_vector(2 downto 0);
    SLSPins: in std_logic_vector(8 downto 0);

    -- test "connector" on video-side pin header
    -- (reused for scanline strength for now)
--    TestGND: out std_logic; -- must be GND
--    Test   : out std_logic_vector(7 downto 0);

    -- video out
    DVI_Clock: out   std_logic_vector(1 downto 0);
    DVI_Red  : out   std_logic_vector(1 downto 0);
    DVI_Green: out   std_logic_vector(1 downto 0);
    DVI_Blue : out   std_logic_vector(1 downto 0);
    DDC_SCL  : inout std_logic;
    DDC_SDA  : inout std_logic
  );
end toplevel_p2xh;

architecture Behavioral of toplevel_p2xh is
  -- clocks
  signal Clock54M     : std_logic;
  signal DVIClockP    : std_logic;
  signal DVIClockN    : std_logic;

  -- video pipeline signals
  signal video_422       : VideoY422;
  signal video_ld        : VideoY422;
  signal video_444       : VideoYCbCr;
  signal video_444_rb    : VideoYCbCr; -- reblanked
  signal video_rgb       : VideoRGB;
  --signal video_rgb_ld    : VideoRGB; -- linedoubled
  signal video_rgb_sl    : VideoRGB; -- scanlined
  signal video_out       : VideoRGB;

  signal pixel_clk_en    : boolean;
  signal pixel_clk_en_2x : boolean;
  signal pixel_clk_en_ld : boolean;
  signal pixel_clk_en_27 : boolean; -- used for DVI output, automatically results in pixel-doubling for 15k modes

  -- output disable logic
  signal prev_30khz      : boolean;
  signal prev_pal        : boolean;
  signal prev_progressive: boolean;
  signal prev_vsync      : boolean;
  signal disable_output  : natural range 0 to 3; -- number of VSyncs to disable

  -- internal 24 bit VGA signals
  signal VGA_Red  : std_logic_vector(7 downto 0);
  signal VGA_Green: std_logic_vector(7 downto 0);
  signal VGA_Blue : std_logic_vector(7 downto 0);
  signal VGA_HSync: std_logic;
  signal VGA_VSync: std_logic;
  signal VGA_Blank: std_logic;

  -- encoded DVI signals  
  signal red_enc     : std_logic;
  signal green_enc   : std_logic;
  signal blue_enc    : std_logic;
  signal clock_enc   : std_logic;

  -- misc
  signal clock_locked     : std_logic;
  signal double_prog      : boolean;
  signal double_int       : boolean;
  signal jumper1_sync     : std_logic_vector(2 downto 0);
  signal jumper2_sync     : std_logic_vector(2 downto 0);
  signal sls_sync         : std_logic_vector(8 downto 0);
  signal scanline_enable  : boolean;
  signal scanline_even    : boolean;
  signal scanline_prog    : boolean;
  signal scanline_int     : boolean;
  signal scanline_strength: unsigned(3 downto 0);

begin

  -- static outputs
  DDC_SCL     <= 'Z'; -- currently not used, but must be defined to avoid
  DDC_SDA     <= 'Z'; --   damaging the FPGA I/O drivers
  CableDetect <= '1'; -- reserved for future OSD ;)

  -- DVI output
  Inst_DVI: dvid GENERIC MAP (
    Invert_Green => true,
    Invert_Blue  => true
  ) PORT MAP (
    clk          => DVIClockP,
    clk_n        => DVIClockN,
    clk_pixel    => Clock54M,
    clk_pixel_en => pixel_clk_en_27,
    red_p        => VGA_Red,
    green_p      => VGA_Green,
    blue_p       => VGA_Blue,
    blank        => VGA_Blank,
    hsync        => VGA_HSync,
    vsync        => VGA_VSync,
    -- outputs
    red_s        => red_enc,
    green_s      => green_enc,
    blue_s       => blue_enc,
    clock_s      => clock_enc
  );
  
  OBUFDS_red   : OBUFDS port map ( O => DVI_Red(0),   OB => DVI_Red(1),   I => red_enc);
  OBUFDS_green : OBUFDS port map ( O => DVI_Green(0), OB => DVI_Green(1), I => green_enc);
  OBUFDS_blue  : OBUFDS port map ( O => DVI_Blue(0),  OB => DVI_Blue(1),  I => blue_enc);
  OBUFDS_clock : OBUFDS port map ( O => DVI_Clock(0), OB => DVI_Clock(1), I => clock_enc);

  -- DVI clock generator
  Inst_ClockGen: ClockGen
    PORT MAP (
      ClockIn       => VClockN,
      Reset         => '0',
      Clock54M      => Clock54M,
      DVIClockP     => DVIClockP,
      DVIClockN     => DVIClockN,
      Locked        => clock_locked
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
      EnableProgressive  => double_prog,
      EnableInterlaced   => double_int,
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

  -- convert YUV to RGB
  Inst_yuv_to_rgb: Convert_yuv_to_rgb
    PORT MAP (
      PixelClock         => Clock54M,
      PixelClockEnable   => pixel_clk_en_ld,

      VideoIn            => video_444_rb,
      Limited_Range      => false,
      VideoOut           => video_rgb
    );

  -- overlay scanlines
  Inst_Scanliner: Scanline_Generator
    PORT MAP (
      PixelClock         => Clock54M,
      PixelClockEnable   => pixel_clk_en_ld,
      Enable             => scanline_enable,
      Strength           => scanline_strength,
      Use_Even           => scanline_even,
      VideoIn            => video_rgb,
      VideoOut           => video_rgb_sl
    );

  -- figure out if scanlines should be enabled
  scanline_enable <=
    (not video_422.Is30kHz and     video_422.IsProgressive) or  -- 240p/288p
    (scanline_prog         and     video_422.IsProgressive) or  -- 480p/576p
    (scanline_int          and not video_422.IsProgressive);    -- 480i/576i

  process (Clock54M)
  begin
    if rising_edge(Clock54M) then
      if not video_422.IsProgressive and video_422.IsEvenField then
        scanline_even <= false;
      else
        scanline_even <= true;
      end if;
    end if;
  end process;

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

  -- check for format changes to disable output for a short time
  -- avoids flickering and other issues on some displays
  -- This checks the pre-linedoubled signal because there are still
  -- differences between a linedoubled signal and an originally-progressive one.
  -- (FIXME: Still necessary after LD improvements?)
  process (Clock54M, pixel_clk_en_ld)
  begin
    if rising_edge(Clock54M) and pixel_clk_en then
      prev_30khz       <= video_422.Is30kHz;
      prev_pal         <= video_422.IsPAL;
      prev_progressive <= video_422.IsProgressive;
      prev_vsync       <= video_422.VSync;
      
      if prev_30khz       /= video_422.Is30kHz or
         prev_pal         /= video_422.IsPAL   or
         prev_progressive /= video_422.IsProgressive then
        -- format changed, disable output for 3 frames or fields
        disable_output <= 3;
      elsif prev_vsync /= video_422.VSync and
            video_422.VSync               and
            disable_output /= 0 then
        disable_output <= disable_output - 1;
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
      if video_out.Blanking or disable_output /= 0 then
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
  
  -- read jumpers
  process (Clock54M, pixel_clk_en)
    variable i: natural range 0 to 8;
    variable sls_prio: natural range 0 to 9;
  begin
    if rising_edge(Clock54M) and pixel_clk_en then
      jumper1_sync <= Jumper1;
      jumper2_sync <= Jumper2;
      sls_sync     <= SLSPins;

      -- check linedoubling jumper setting
      case jumper1_sync is
        when "111" =>
          double_prog <= false;
          double_int  <= false;

        when "110" =>
          double_prog <= true;
          double_int  <= true;

        when "101" =>
          double_prog <= true;
          double_int  <= false;

        when "011" =>
          double_prog <= false;
          double_int  <= true;

        when others =>
          double_prog <= false;
          double_int  <= false;
      end case;

      -- check scanline mode jumper settings
      case jumper2_sync is
        when "111" =>
          scanline_prog <= false;
          scanline_int  <= false;

        when "110" =>
          scanline_prog <= true;
          scanline_int  <= true;

        when "101" =>
          scanline_prog <= true;
          scanline_int  <= false;

        when "011" =>
          scanline_prog <= false;
          scanline_int  <= true;

        when others =>
          scanline_prog <= false;
          scanline_int  <= false;
      end case;

      -- check scanline strength
      -- (should infer a priority encoder)
      sls_prio := 9;
      for i in 0 to 8 loop
        if sls_sync(i) = '0' then
          sls_prio := i;
        end if;
      end loop;

      case sls_prio is
        when 0 => scanline_strength <= x"0";
        when 1 => scanline_strength <= x"2";
        when 2 => scanline_strength <= x"4";
        when 3 => scanline_strength <= x"6";
        when 4 => scanline_strength <= x"9";
        when 5 => scanline_strength <= x"b";
        when 6 => scanline_strength <= x"c";
        when 7 => scanline_strength <= x"d";
        when 8 => scanline_strength <= x"e";
        when 9 => scanline_strength <= x"f"; -- no conection -> off
      end case;
    end if;
  end process;

  -- output test signals
--  TestGND <= '0'; -- Rigol logic probe GND pin
--  Test(0) <= '0' when video_422.VSync       else '1';
--  Test(1) <= '0' when video_422.HSync       else '1';
--  Test(2) <= '1' when video_422.IsEvenField else '0';
--  Test(3) <= '1' when video_422.Blanking    else '0';
--  Test(4) <= '0' when video_ld.VSync        else '1';
--  Test(5) <= '0' when video_ld.HSync        else '1';
--  Test(6) <= '1' when video_ld.Blanking     else '0';
--  Test(7 downto 7) <= (others => '0');

  -- show flags on LEDs
  LED1 <= '1' when video_422.IsProgressive else '0';
  LED2 <= '1' when video_422.IsPAL         else '0';
  
  -- select output signal
  video_out <= video_rgb_sl;

end Behavioral;

