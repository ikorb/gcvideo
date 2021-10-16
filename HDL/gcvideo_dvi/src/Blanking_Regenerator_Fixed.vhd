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
-- Blanking_Regenerator_Fixed: Regenerate the blanking signal using fixed windows
--                             and fix lengths of HSync/VSync
--
----------------------------------------------------------------------------------

library IEEE;

use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.video_defs.all;

entity Blanking_Regenerator_Fixed is
  port (
    PixelClock       : in  std_logic;
    PixelClockEnable : in  boolean;

    -- input video
    VideoIn          : in  VideoYCbCr;

    -- output video
    VideoOut         : out VideoYCbCr
  );
end Blanking_Regenerator_Fixed;

architecture Behavioral of Blanking_Regenerator_Fixed is
  signal current_line : natural range 0 to 650; -- both slightly more than necessary
  signal current_pixel: natural range 0 to 880;
  signal prev_hsync   : boolean;
  signal prev_vsync   : boolean;
  signal seen_vsync   : boolean;

  -- reblanking
  type blank_state_t is (BS_OUTSIDE_WIN, BS_INSIDE_WIN);
  signal vblank_state     : blank_state_t;
  signal hblank_state     : blank_state_t;
  signal hor_active_start : natural range 117 to 132 := 117;
  signal hor_active_end   : natural range 830 to 852 := 839;
  signal vert_active_start: natural range  18 to  41 :=  18;
  signal vert_active_end  : natural range 258 to 617 := 258;

  -- sync regen
  signal hsync_remain     : natural range 0 to 63;
  signal vsync_remain     : natural range 0 to 864*6;

begin

  -- generate a new blanking signal according to CEA timing
  process (PixelClock, PixelClockEnable)
    -- indicator vars to simplify conditions
    variable at_hsync_start: boolean := false;
    variable at_hsync_end  : boolean := false;
    variable at_vsync_start: boolean := false;
    variable at_vsync_end  : boolean := false;
  begin
    if rising_edge(PixelClock) and PixelClockEnable then
      -- copy flags and CSync
      VideoOut.CSync         <= VideoIn.CSync;
      VideoOut.IsEvenField   <= VideoIn.IsEvenField;
      VideoOut.IsProgressive <= VideoIn.IsProgressive;
      VideoOut.IsPAL         <= VideoIn.IsPAL;
      VideoOut.Is30kHz       <= VideoIn.Is30kHz;

      -- calculate the indicator variables
      prev_hsync <= VideoIn.HSync;
      prev_vsync <= VideoIn.VSync;

      if prev_hsync /= VideoIn.HSync then
        if VideoIn.HSync then
          at_hsync_start := true;
          at_hsync_end   := false;
        else
          at_hsync_start := false;
          at_hsync_end   := true;
        end if;
      else
        at_hsync_start := false;
        at_hsync_end   := false;
      end if;

      if prev_vsync /= VideoIn.VSync then
        if VideoIn.VSync then
          at_vsync_start := true;
          at_vsync_end   := false;
        else
          at_vsync_start := false;
          at_vsync_end   := true;
        end if;
      else
        at_vsync_start := false;
        at_vsync_end   := false;
      end if;

      ---- recreate syncs with corrent lengths
      if hsync_remain > 0 then
        hsync_remain <= hsync_remain - 1;
      else
        VideoOut.HSync <= false;
      end if;

      if at_hsync_start then
        VideoOut.HSync <= true;

        if VideoIn.IsPAL then
          if VideoIn.Is30kHz then
            -- 576p
            hsync_remain <= 64 -1;
          else
            -- 576i
            hsync_remain <= 63 -1;
          end if;
        else
          -- 480p/480i
          hsync_remain <= 62 -1;
        end if;
      end if;

      if vsync_remain > 0 then
        vsync_remain <= vsync_remain - 1;
      else
        VideoOut.VSync <= false;
      end if;

      if at_vsync_start then
        VideoOut.VSync <= true;

        if VideoIn.IsPAL then
          if VideoIn.Is30kHz then
            vsync_remain <= 5 * 864 - 1;
          else
            vsync_remain <= 3 * 864 - 1;
          end if;
        else
          if VideoIn.Is30kHz then
            vsync_remain <= 6 * 858 - 1;
          else
            vsync_remain <= 3 * 858 - 1;
          end if;
        end if;
      end if;

      ---- count non-sync pixels/lines as reference
      -- pixels (first pixel of HSync is 0)
      if at_hsync_start then
        current_pixel <= 0;
      else
        current_pixel <= current_pixel + 1;
      end if;

      -- lines, counted from the first HSync with an active VSync
      -- (this ensures that the window is at the same lines in both fields)
      if at_hsync_start and VideoIn.VSync and not seen_vsync then
        current_line <= 0;
        seen_vsync   <= true;
      elsif at_hsync_start then
        current_line <= current_line + 1;
      end if;

      if at_vsync_end then
        seen_vsync <= false;

        -- update blanking ranges
        if VideoIn.IsPAL then
          -- 576i/576p
          hor_active_start <= 132 - 2;
          hor_active_end   <= 852 - 2;
        else
          if VideoIn.Is30kHz then
            -- 480p
            hor_active_start <= 122 - 2;
            hor_active_end   <= 842 - 2;
          else
            -- 480i
            hor_active_start <= 119 - 2;
            hor_active_end   <= 839 - 2;
          end if;
        end if;

        if VideoIn.Is30kHz then
          if VideoIn.IsPAL then
            vert_active_start <= 41;
            vert_active_end   <= 617;
          else
            vert_active_start <= 36;
            vert_active_end   <= 516;
          end if;
        else
          -- 15kHz modes
          if VideoIn.IsPAL then
            vert_active_start <= 22; -- 288p maybe 24
            vert_active_end   <= 310; -- 288p maybe 312
          else
            vert_active_start <= 18; -- 480i maybe 19
            vert_active_end   <= 258; -- 480i maybe 259
          end if;
        end if;
      end if;

      ---- reblanking
      -- horizontal
      if at_hsync_start then
        hblank_state <= BS_OUTSIDE_WIN;
      end if;

      if current_pixel = hor_active_start then
        hblank_state <= BS_INSIDE_WIN;
      elsif current_pixel = hor_active_end then
        hblank_state <= BS_OUTSIDE_WIN;
      end if;

      -- vertical
      if at_vsync_start then
        vblank_state <= BS_OUTSIDE_WIN;
      end if;

      if current_line = vert_active_start then
        vblank_state <= BS_INSIDE_WIN;
      elsif current_line = vert_active_end then
        vblank_state <= BS_OUTSIDE_WIN;
      end if;

      if hblank_state = BS_INSIDE_WIN and vblank_state = BS_INSIDE_WIN then
        VideoOut.Blanking <= false;
        if VideoIn.Blanking then
          -- GC is blanked, generate black video
          VideoOut.PixelY  <= x"00";
          VideoOut.PixelCb <= x"00";
          VideoOut.PixelCr <= x"00";
        else
          VideoOut.PixelY  <= VideoIn.PixelY;
          VideoOut.PixelCb <= VideoIn.PixelCb;
          VideoOut.PixelCr <= VideoIn.PixelCr;
        end if;
      else
        -- in blanking
        VideoOut.Blanking <= true;
        VideoOut.PixelY   <= x"00";
        VideoOut.PixelCb  <= x"00";
        VideoOut.PixelCr  <= x"00";
      end if;

    end if;
  end process;

end Behavioral;
