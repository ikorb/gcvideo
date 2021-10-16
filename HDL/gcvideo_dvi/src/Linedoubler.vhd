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
-- Linedoubler: Simple line-doubler to convert 15kHz modes to 30kHz
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.component_defs.all;
use work.video_defs.all;

entity Linedoubler is
  port (
    PixelClock        : in  std_logic;

    -- input video
    Enable            : in  boolean;
    VideoIn           : in  VideoY422;
    PixelClockEnable  : in  boolean;
    PixelClockEnable2x: in  boolean;

    -- output video
    VideoOut          : out VideoY422;
    PixelOutEnable    : out boolean
  );
end Linedoubler;

architecture Behavioral of Linedoubler is
  constant VSYNC_LENGTH: natural := 5;  -- length of new VSync in lines minus one
  constant HSYNC_WIDTH : natural := 63; -- width of new HSync in pixels

  -- linedoubled video signal
  signal video_ld: VideoY422;

  -- line buffers
  constant linedata_size: natural := 8+8+2;
  type linebuffer_t is array(0 to 900) of unsigned(linedata_size-1 downto 0);

  signal linebuf1: linebuffer_t;
  signal linebuf2: linebuffer_t;

  signal output_use_buf1  : boolean := true;
  signal output_use1_delay: boolean := true;
  signal input_use_buf1   : boolean := false;

  signal buf_output_idx: natural range 0 to linebuffer_t'high := 1;
  signal buf_input_idx : natural range 0 to linebuffer_t'high := 3; -- contains index that was written to last

  -- input signal measurements
  signal measured_linelength: natural range 0 to linebuffer_t'high;
  signal prev_vsync_input   : boolean;
  signal prev_hsync_input   : boolean;
  signal prev_hsync_output  : boolean;
  signal vsync_seen         : boolean;
  signal vsync_pos          : boolean;
  signal vsync_seen_delay   : boolean;
  signal vsync_pos_delay    : boolean;

  -- output sync counters
  signal hsync_on_next      : boolean;
  signal hsync_pixels       : natural range 0 to 63;
  signal vsync_out_active   : boolean;
  signal vsync_on_next      : boolean;
  signal vsync_lines        : natural range 0 to 17;

  -- intermediate output signals as RAM output registers
  signal output1: unsigned(linedata_size-1 downto 0);
  signal output2: unsigned(linedata_size-1 downto 0);

begin

  -- pass signals to output
  process(PixelClock)
  begin
    if rising_edge(PixelClock) then
      -- bypass for 30kHz or if not enabled
      if VideoIn.Is30kHz or not Enable then
        VideoOut       <= VideoIn;
        PixelOutEnable <= PixelClockEnable;
      else
        VideoOut       <= video_ld;
        PixelOutEnable <= PixelClockEnable2x;
      end if;
    end if;
  end process;

  -- linedoubling, input process
  process(PixelClock, PixelClockEnable)
    variable input_idx     : natural range 0 to linebuffer_t'high;
    variable use_buf1      : boolean;
    variable cicb_unsigned : unsigned(0 downto 0);
    variable blank_unsigned: unsigned(0 downto 0);
    variable linedata      : unsigned(linedata_size-1 downto 0);
  begin
    if rising_edge(PixelClock) and PixelClockEnable then
      prev_vsync_input <= VideoIn.VSync;
      prev_hsync_input <= VideoIn.HSync;
      input_idx        := buf_input_idx + 1;
      use_buf1         := input_use_buf1;

      -- data conversion...
      if VideoIn.CurrentIsCb then
        cicb_unsigned := to_unsigned(1, 1);
      else
        cicb_unsigned := to_unsigned(0, 1);
      end if;

      if VideoIn.Blanking then
        blank_unsigned := to_unsigned(1, 1);
      else
        blank_unsigned := to_unsigned(0, 1);
      end if;

      -- check for start of line (at HSync start)
      if VideoIn.HSync and prev_hsync_input /= VideoIn.HSync then
        -- prepare new line
        input_idx           := 0;
        use_buf1            := not use_buf1;
        measured_linelength <= buf_input_idx;
        vsync_seen          <= false;
      end if;

      -- check for start of field
      if VideoIn.VSync and prev_vsync_input /= VideoIn.VSync then
        vsync_seen <= true;
        vsync_pos  <= VideoIn.HSync;
      end if;

      -- store and count
      linedata := blank_unsigned    &
                  cicb_unsigned     &
                  VideoIn.PixelCbCr &
                  VideoIn.PixelY;

      if use_buf1 then
        linebuf1(input_idx) <= linedata;
      else
        linebuf2(input_idx) <= linedata;
      end if;

      buf_input_idx  <= input_idx;
      input_use_buf1 <= use_buf1;
    end if;
  end process;

  -- linedoubling, output process
  process(PixelClock, PixelClockEnable2x)
    variable output_idx: natural range 0 to linebuffer_t'high;
  begin
    if rising_edge(PixelClock) and PixelClockEnable2x then
      prev_hsync_output  <= VideoIn.HSync;
      output_idx         := buf_output_idx;
      output_use1_delay  <= output_use_buf1;

      -- swap buffers at HSync (input) start
      if prev_hsync_output /= VideoIn.HSync and VideoIn.HSync then
        output_idx         := 0;
        output_use1_delay  <= not output_use_buf1;
        output_use_buf1    <= not output_use_buf1;
        vsync_seen_delay   <= vsync_seen;
        vsync_pos_delay    <= vsync_pos;
        video_ld.HSync     <= true;
        hsync_pixels       <= HSYNC_WIDTH;

        if vsync_seen and vsync_pos then -- check current values if it's on the start of the new line
          video_ld.VSync   <= true;
          vsync_out_active <= true;
          vsync_lines      <= VSYNC_LENGTH;
        end if;
      end if;

      -- read from RAM into registers
      output1 <= linebuf1(output_idx);
      output2 <= linebuf2(output_idx);

      if output_use1_delay then
        video_ld.PixelY      <= output1( 7 downto  0);
        video_ld.PixelCbCr   <= output1(15 downto  8);
        video_ld.CurrentIsCb <= (output1(16) = '1');
        video_ld.Blanking    <= (output1(17) = '1');
      else
        video_ld.PixelY      <= output2( 7 downto  0);
        video_ld.PixelCbCr   <= output2(15 downto  8);
        video_ld.CurrentIsCb <= (output2(16) = '1');
        video_ld.Blanking    <= (output2(17) = '1');
      end if;

      if output_idx /= measured_linelength then
        buf_output_idx <= output_idx + 1;
      else
        buf_output_idx <= 0;
        hsync_on_next  <= true;

        if vsync_seen_delay and not vsync_pos_delay then -- check saved values if vsync is in the middle
          vsync_on_next <= true;
        end if;
      end if;

      -- HSync reconstruction
      if hsync_on_next then
        video_ld.HSync <= true;
        hsync_pixels   <= HSYNC_WIDTH;
        hsync_on_next  <= false;
      elsif hsync_pixels > 0 then
        hsync_pixels   <= hsync_pixels - 1;
      else
        video_ld.HSync <= false;
      end if;

      -- VSync reconstruction
      if vsync_on_next then
        video_ld.VSync   <= true;
        vsync_out_active <= true;
        vsync_lines      <= VSYNC_LENGTH;
        vsync_on_next    <= false;
      end if;

      if output_idx = 0 and vsync_out_active then
        if vsync_lines /= 0 then
          vsync_lines <= vsync_lines - 1;
        else
          video_ld.VSync   <= false;
          vsync_out_active <= false;
        end if;
      end if;

      video_ld.CSync         <= video_ld.HSync xor video_ld.VSync;
      video_ld.Is30kHz       <= true;
      video_ld.IsProgressive <= true;
      video_ld.IsEvenField   <= VideoIn.IsEvenField;
      video_ld.IsPAL         <= VideoIn.IsPAL;
    end if;
  end process;

end Behavioral;
