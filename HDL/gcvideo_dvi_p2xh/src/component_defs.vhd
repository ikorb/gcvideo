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
      PixelClock      : in  std_logic;
      PixelClockEnable: in  boolean;
      
      -- input video
      VideoIn         : in  VideoY422;

      -- output video
      VideoOut        : out VideoYCbCr
    );
  end component;

  component convert_yuv_to_rgb is
    port (
      PixelClock      : in  std_logic;
      PixelClockEnable: in  boolean;

      -- input video
      VideoIn         : in  VideoYCbCr;
      Limited_Range   : in  boolean;

      -- output video
      VideoOut        : out VideoRGB
    );
  end component;

  component Linedoubler is
  port (
    PixelClock        : in  std_logic;
    
    -- input video
    EnableProgressive : in  boolean;
    EnableInterlaced  : in  boolean;
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
      Strength        : in  unsigned(3 downto 0);
      Use_Even        : in  boolean;

      -- input video
      VideoIn         : in  VideoRGB;

      -- output video
      VideoOut        : out VideoRGB
    );
  end component;

  component Blanking_Regenerator_Fixed is
    port (
      PixelClock      : in  std_logic;
      PixelClockEnable: in  boolean;
      VideoIn         : in  VideoYCbCr;
      VideoOut        : out VideoYCbCr
    );
  end component;

  COMPONENT dvid
  GENERIC (
    Invert_Red  : Boolean := false;
    Invert_Green: Boolean := false;
    Invert_Blue : Boolean := false
  );
  PORT(
      clk         : IN std_logic;
      clk_n       : IN std_logic;
      clk_pixel   : IN std_logic;
      clk_pixel_en: IN boolean;
      red_p       : IN std_logic_vector(7 downto 0);
      green_p     : IN std_logic_vector(7 downto 0);
      blue_p      : IN std_logic_vector(7 downto 0);
      blank       : IN std_logic;
      hsync       : IN std_logic;
      vsync       : IN std_logic;          
      red_s       : OUT std_logic;
      green_s     : OUT std_logic;
      blue_s      : OUT std_logic;
      clock_s     : OUT std_logic
    );
  END COMPONENT;

  component ClockGen is
    PORT (
      ClockIn  : in  std_logic;
      Reset    : in  std_logic;
      Clock54M : out std_logic;
      DVIClockP: out std_logic;
      DVIClockN: out std_logic;
      Locked   : out std_logic
    );
  end component;

end component_defs;

package body component_defs is
end component_defs;
