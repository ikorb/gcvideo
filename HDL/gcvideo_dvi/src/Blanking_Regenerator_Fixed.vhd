----------------------------------------------------------------------------------
-- GCVideo DVI HDL
-- Copyright (C) 2014-2017, Ingo Korb <ingo@akana.de>
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
    VideoIn          : in  VideoYCbCr;
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
  signal hor_active_start : natural range 121 to 131 := 121;
  signal hor_active_end   : natural range 841 to 851 := 841;
  signal vert_active_start: natural range  18 to  41 :=  18;
  signal vert_active_end  : natural range 258 to 617 := 258;

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
      -- copy everything except blanking and pixels
      VideoOut.HSync         <= VideoIn.HSync;
      VideoOut.VSync         <= VideoIn.VSync;
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

      ---- count non-sync pixels/lines as reference
      -- pixels (first pixel of HSync is 0)
      if at_hsync_start then
        current_pixel   <= 0;
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
          hor_active_start <= 131;
          hor_active_end   <= 851;
        else
          hor_active_start <= 121;
          hor_active_end   <= 841;
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
