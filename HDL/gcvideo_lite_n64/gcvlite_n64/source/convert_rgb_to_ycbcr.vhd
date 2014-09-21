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
-- convert_rgb_to_ycbcr: RGB to YCbCr conversion without multiplications
--
-- This module converts 4:4:4 YCbCr to full-range RGB using only shifts and
-- additions. The coefficients have been optimized to create a simple add/shift
-- tree without compromising accuracy too much.
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.component_defs.all;
use work.video_defs.all;

entity convert_rgb_to_ycbcr is
  port (
    Clock        : in  std_logic;
    ClockEnable  : in  boolean;
    ClockEnable2x: in  boolean;
    VideoIn      : in  VideoRGB;
    VideoOut     : out VideoYCbCr
  );
end convert_rgb_to_ycbcr;

architecture Behavioral of convert_rgb_to_ycbcr is
  -- delay in (enabled) clock cycles for untouched signals
  constant Delayticks: Natural := 4;

  -- R
  signal r_buffered : unsigned( 6 downto 0);
  signal r_scaled3  : unsigned( 8 downto 0);
  signal r_scaled7  : unsigned( 9 downto 0);
  signal r_scaled19 : unsigned(11 downto 0);
  signal r_scaled33 : unsigned(12 downto 0);

  -- G
  signal g_buffered : unsigned( 6 downto 0);
  signal g_scaled3  : unsigned( 8 downto 0);
  signal g_scaled5  : unsigned( 9 downto 0);
  signal g_scaled37 : unsigned(12 downto 0);
  signal g_scaled47 : unsigned(12 downto 0);
  signal g_scaled129: unsigned(14 downto 0);

  -- B
  signal b_buffered : unsigned( 6 downto 0);
  signal b_scaled3  : unsigned( 8 downto 0);
  signal b_scaled7  : unsigned( 9 downto 0);
  signal b_scaled9  : unsigned(10 downto 0);
  signal b_scaled25 : unsigned(11 downto 0);

  -- summed components
  signal ysum1 : unsigned(14 downto 0);
  signal ysum2 : unsigned(14 downto 0);
  signal cbsum1: unsigned(14 downto 0);
  signal cbsum2: unsigned(14 downto 0);
  signal crsum1: unsigned(14 downto 0);
  signal crsum2: unsigned(14 downto 0);

begin
  -- capture and convert
  process (Clock, ClockEnable)
  begin
    if rising_edge(Clock) and ClockEnable then
      -- first step for multiplications
      r_buffered <= VideoIn.PixelR;
      r_scaled3  <= (resize(VideoIn.PixelR,  9) sll 1) + resize(VideoIn.PixelR,  9);
      g_buffered <= VideoIn.PixelG;
      g_scaled3  <= (resize(VideoIn.PixelG,  9) sll 1) + resize(VideoIn.PixelG,  9);
      g_scaled5  <= (resize(VideoIn.PixelG, 10) sll 2) + resize(VideoIn.PixelG, 10);
      b_buffered <= VideoIn.PixelB;
      b_scaled3  <= (resize(VideoIn.PixelB,  9) sll 1) + resize(VideoIn.PixelB,  9);

      -- second step for multiplications
      r_scaled7   <= (resize(r_buffered, 10) sll 3) - resize(r_buffered, 10);
      r_scaled19  <= (resize(r_buffered, 12) sll 4) + resize(r_scaled3,  12);
      r_scaled33  <= (resize(r_buffered, 13) sll 5) + resize(r_buffered, 13);
      g_scaled37  <= (resize(g_buffered, 13) sll 5) + resize(g_scaled5,  13);
      g_scaled47  <= (resize(g_scaled3,  13) sll 4) - resize(g_buffered, 13);
      g_scaled129 <= (resize(g_buffered, 15) sll 7) + resize(g_buffered, 15);
      b_scaled7   <= (resize(b_buffered, 10) sll 3) - resize(b_buffered, 10);
      b_scaled9   <= (resize(b_buffered, 11) sll 3) + resize(b_buffered, 11);
      b_scaled25  <= (resize(b_scaled3,  12) sll 3) + resize(b_buffered, 12);

      -- first step of summing
      ysum1  <= (resize(r_scaled33, 15) sll 1) +  resize(g_scaled129,15);
      ysum2  <=  resize(b_scaled25, 15)        +  to_unsigned( 2106, 15); -- ( 16 << 7) + 58
      cbsum1 <= (resize(b_scaled7,  15) sll 4) +  to_unsigned(16448, 15); -- (128 << 7) + 64
      cbsum2 <= (resize(r_scaled19, 15) sll 1) + (resize(g_scaled37, 15) sll 1);
      crsum1 <= (resize(r_scaled7,  15) sll 4) +  to_unsigned(16448, 15); -- (128 << 7) + 64 
      crsum2 <= (resize(g_scaled47, 15) sll 1) + (resize(b_scaled9,  15) sll 1);

      -- second step of summing (clipping not needed according to exhaustive simulation)
      VideoOut.PixelY  <= resize((resize(ysum1,  16) + resize(ysum2,  16)) srl 8, 7);
      VideoOut.PixelCb <= resize((resize(cbsum1, 16) - resize(cbsum2, 16)) srl 8, 7);
      VideoOut.PixelCr <= resize((resize(crsum1, 16) - resize(crsum2, 16)) srl 8, 7);
    end if;
  end process;

  -- generate delayed signals
  Inst_HSyncDelay: delayline_bool
    generic map (
      Delayticks => Delayticks
    )
    port map (
      Clock       => Clock,
      ClockEnable => ClockEnable,
      Input       => VideoIn.HSync,
      Output      => VideoOut.HSync
    );

  Inst_VSyncDelay: delayline_bool
    generic map (
      Delayticks => Delayticks
    )
    port map (
      Clock       => Clock,
      ClockEnable => ClockEnable,
      Input       => VideoIn.VSync,
      Output      => VideoOut.VSync
    );

  Inst_CSyncDelay: delayline_bool
    generic map (
      Delayticks => Delayticks
    )
    port map (
      Clock       => Clock,
      ClockEnable => ClockEnable,
      Input       => VideoIn.CSync,
      Output      => VideoOut.CSync
    );

  Inst_BlankingDelay: delayline_bool
    generic map (
      Delayticks => Delayticks
    )
    port map (
      Clock       => Clock,
      ClockEnable => ClockEnable,
      Input       => VideoIn.Blanking,
      Output      => VideoOut.Blanking
    );

end Behavioral;

