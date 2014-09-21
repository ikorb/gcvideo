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

  component n64v_decoder is
    port (
      VClockI: in  std_logic; -- ~50 MHz clock from N64
      VData  : in  std_logic_vector(6 downto 0);
      DSync  : in  std_logic;

      -- output clock enables
      PixelClkEn  : out boolean; -- CE relative to input clock for complete pixels
      PixelClkEn2x: out boolean; -- same, but at twice the pixel rate

      -- video output signals
      Video       : out VideoRGB
    );
  end component;

  component convert_rgb_to_ycbcr is
    port (
      Clock        : in  std_logic;
      ClockEnable  : in  boolean;
      ClockEnable2x: in  boolean;
      VideoIn      : in  VideoRGB;
      VideoOut     : out VideoYCbCr
    );
  end component;

end component_defs;

package body component_defs is
end component_defs;
