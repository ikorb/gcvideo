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
-- Blanking_Regenerator: Regenerate syncs and blanking signal
--
----------------------------------------------------------------------------------

library IEEE;

use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.video_defs.all;

entity Blanking_Regenerator is
  port (
    PixelClock       : in  std_logic;
    PixelClockEnable : in  boolean;

    -- control
    ReblankingEnable : in  boolean;
    ResyncingEnable  : in  boolean;
    RBSettings       : in  ReblankerSettings_t;

    -- measurements
    VideoMeasurements: out VideoMeasurements_t;

    -- input video
    VideoIn          : in  VideoYCbCr;

    -- output video
    VideoOut         : out VideoYCbCr
  );
end Blanking_Regenerator;

architecture Behavioral of Blanking_Regenerator is
  -- incoming signal measurements
  signal prev_hsync: boolean;
  signal prev_vsync: boolean;
  signal prev_blank: boolean;

  signal h_counter          : HorizontalPixels;
  signal v_pixel_counter    : VerticalPixels;
  signal v_line_counter     : VerticalLines;
  signal v_line_out_counter : VerticalLines;
  signal active_line_counter: VerticalLines;
  signal vh_offset          : HorizontalPixels;

  signal seen_active     : boolean;
  signal prev_seen_active: boolean;
  signal count_vhoffset  : boolean;
  signal field_toggle    : boolean := false;

begin

  process (PixelClock, PixelClockEnable)
    variable h_sync_out: boolean;
    variable h_active  : boolean;
    variable v_active  : boolean;
  begin
    if rising_edge(PixelClock) and PixelClockEnable then
      prev_hsync <= VideoIn.HSync;
      prev_vsync <= VideoIn.VSync;
      prev_blank <= VideoIn.Blanking;

      -- horizontal counter, 0 is start of HSync
      if VideoIn.HSync and not prev_hsync then
        VideoMeasurements.HTotal <= h_counter;
        prev_seen_active <= seen_active;
        seen_active      <= false;
        h_counter        <= 1;
        v_line_counter   <= v_line_counter + 1;

        if count_vhoffset then
          count_vhoffset <= false;
          if field_toggle then
            VideoMeasurements.VHOffset0 <= vh_offset;
          else
            VideoMeasurements.VHOffset1 <= vh_offset;
          end if;
        end if;

      else
        h_counter <= h_counter + 1;
        if count_vhoffset then
          vh_offset <= vh_offset + 1;
        end if;
      end if;

      if not VideoIn.Blanking and prev_blank then
        -- vertical
        seen_active <= true;
        if not prev_seen_active then
          -- capture number of first line with active pixels
          if field_toggle then
            VideoMeasurements.VActiveStart0 <= v_line_counter;
          else
            VideoMeasurements.VActiveStart1 <= v_line_counter;
          end if;

          -- create a synthetic field toggle at the first active line
          -- simplifies reasoning across VSync and also ensures that
          -- both measurements are updated even in progressive modes
          field_toggle <= not field_toggle;
        end if;

        -- horizontal
        VideoMeasurements.HActiveStart <= h_counter;
      end if;

      -- vertical counter, 0 is start of VSync
      if VideoIn.VSync and not prev_vsync then
        VideoMeasurements.VTotal <= v_pixel_counter;
        v_pixel_counter <= 1;

        if VideoIn.HSync and not prev_hsync then
          -- also at HSync start, so offset is 0
          if field_toggle then
            VideoMeasurements.VHOffset0 <= 0;
          else
            VideoMeasurements.VHOffset1 <= 0;
          end if;
        else
          -- measure offset between start of VSync and start of HSync
          count_vhoffset <= true;
          vh_offset      <= 1;
        end if;

        -- tweak counting strategy so the nominal start
        -- is on the same line for both fields
        if VideoIn.HSync then
          v_line_counter <= 1;
        else
          v_line_counter <= 0;
        end if;
      else
        v_pixel_counter <= v_pixel_counter + 1;
      end if;

      -- sync regen
      if h_counter = RBSettings.HSyncStart then
        h_sync_out := true;

        -- active line count for reblanking uses output hsyncs
        v_line_out_counter <= v_line_out_counter + 1;

        if v_active then
          active_line_counter <= active_line_counter - 1;
        end if;
      end if;

      if h_counter = RBSettings.HSyncEnd then
        h_sync_out := false;
      end if;

      if v_pixel_counter = RBSettings.VSyncStart then
        VideoOut.VSync <= true;

        -- same hack as used on the input side above
        if h_sync_out then
          v_line_out_counter <= 1;
        else
          v_line_out_counter <= 0;
        end if;
      end if;

      if v_pixel_counter = RBSettings.VSyncEnd then
        VideoOut.VSync <= false;
      end if;

      -- blanking regen
      if h_counter = RBSettings.HActiveStart then
        h_active := true;
      end if;

      if h_counter = RBSettings.HActiveEnd then
        h_active := false;
      end if;

      if v_line_out_counter = RBSettings.VActiveStart then
        v_active := true;
        active_line_counter <= RBSettings.VActiveLines;
      else
        if v_active and active_line_counter = 0 then
          v_active := false;
        end if;
      end if;

      -- pixel passthrough as default
      VideoOut.PixelY  <= VideoIn.PixelY;
      VideoOut.PixelCb <= VideoIn.PixelCb;
      VideoOut.PixelCr <= VideoIn.PixelCr;

      if h_active and v_active then
        VideoOut.Blanking <= false;

        if VideoIn.Blanking and ReblankingEnable then
          -- explicitly set opened-up areas to black
          VideoOut.PixelY  <= x"00";
          VideoOut.PixelCb <= x"00";
          VideoOut.PixelCr <= x"00";
        end if;
      else
        VideoOut.Blanking <= true;
      end if;

      -- copy flags
      VideoOut.IsEvenField   <= VideoIn.IsEvenField;
      VideoOut.IsProgressive <= VideoIn.IsProgressive;
      VideoOut.IsPAL         <= VideoIn.IsPAL;
      VideoOut.Is30kHz       <= VideoIn.Is30kHz;

      -- overwrite sync and blanking when bypassed
      if not ReblankingEnable then
        VideoOut.Blanking <= VideoIn.Blanking;
      end if;

      if not ReblankingEnable or not ResyncingEnable then
        VideoOut.VSync <= VideoIn.VSync;
        h_sync_out     := VideoIn.HSync;
      end if;

      VideoOut.CSync <= VideoIn.CSync;
      VideoOut.HSync <= h_sync_out;
    end if;
  end process;

end Behavioral;
