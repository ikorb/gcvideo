/* GCVideo DVI Firmware

   Copyright (C) 2015-2020, Ingo Korb <ingo@akana.de>
   All rights reserved.

   Redistribution and use in source and binary forms, with or without
   modification, are permitted provided that the following conditions are met:

   1. Redistributions of source code must retain the above copyright notice,
      this list of conditions and the following disclaimer.
   2. Redistributions in binary form must reproduce the above copyright notice,
      this list of conditions and the following disclaimer in the documentation
      and/or other materials provided with the distribution.

   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
   AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
   IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
   ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
   LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
   CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
   SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
   INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
   CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
   ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
   THE POSSIBILITY OF SUCH DAMAGE.


   reblanker.c: video mode change detection and image parameter calculation

*/

#include <stdbool.h>
#include <stdint.h>
#include "pad.h"
#include "portdefs.h"
#include "settings.h"
#include "reblanker.h"

typedef struct {
  uint8_t  HSync;
  uint8_t  HBackporch;
  uint16_t VActive; // field, not frame
  uint8_t  VSync;
  uint8_t  VBackporch;
} VideoParameters_t;

static const VideoParameters_t ModeParameters[] = {
  { 62, 57, 240, 3, 16 }, // 240p
  { 63, 69, 288, 3, 20 }, // 288p
  { 62, 57, 240, 3, 16 }, // 480i
  { 63, 69, 288, 3, 20 }, // 576i
  { 62, 60, 480, 6, 31 }, // 480p
  { 64, 68, 576, 5, 40 }, // 576p
  // no entry for non-standard modes needed, array isn't accessed when one is used
};

static video_mode_t prev_inmode  = VIDMODE_NONSTANDARD;
static video_mode_t prev_outmode = VIDMODE_NONSTANDARD;
static uint32_t     prev_xres    = 0;
static uint32_t     prev_yres    = 0;
static uint8_t      disable_frames;

static uint32_t min(uint32_t a, uint32_t b) {
  if (a < b) {
    return a;
  }

  return b;
}

static void check_modechange(uint32_t cur_xres, uint32_t cur_yres,
                             video_mode_t inmode, video_mode_t outmode) {
  /* check for changes of the input/output modes */
  bool inmode_changed  = false;
  bool outmode_changed = false;

  if (inmode != prev_inmode) {
    inmode_changed = true;
  }

  if (outmode != prev_outmode) {
    outmode_changed = true;
  }

  if (inmode_changed || outmode_changed) {
    if (disable_frames > 0) {
      /* still disabled, count down */
      disable_frames--;

      if (disable_frames == 0) {
        /* done, reenable */
        if (inmode_changed) {
          pad_set_irq(PAD_VIDEOCHANGE);
        }

        prev_inmode  = inmode;
        prev_outmode = outmode;
        /* enable output again */
        VIDEOIF->osd_bg = osdbg_settings;
      }
    } else {
      /* first detection of mode change, disable output for three frames */
      /* (avoids missed mode switches on some TVs, e.g. from 480i to 240p) */
      disable_frames = 3;
      VIDEOIF->osd_bg = VIDEOIF_OSDBG_DISABLE_OUTPUT;
    }
  } else if (prev_xres != cur_xres || prev_yres != cur_yres) {
    /* input resolution changed, just set videochange to trigger resbox */
    pad_set_irq(PAD_VIDEOCHANGE);
    prev_xres = cur_xres;
    prev_yres = cur_yres;
  }
}

void update_reblanker(void) {
  uint32_t cur_xres = VIDEOIF->xres;
  uint32_t cur_yres = VIDEOIF->yres;

  /* set up reblanker */
  video_mode_t cur_inmode  = detect_input_videomode();
  video_mode_t cur_outmode = detect_output_videomode();

  check_modechange(cur_xres, cur_yres, cur_inmode, cur_outmode);

  /* if input mode is nonstandard, enable bypass instead of trying to fix it */
  if (cur_inmode == VIDMODE_NONSTANDARD) {
    VIDEOIF->settings = video_settings[VIDMODE_NONSTANDARD] | video_settings_global;
    return;
  }

  int32_t actual_x_shift = screen_x_shift << 2;
  int32_t actual_y_shift = screen_y_shift;
  if (!(video_settings_global & VIDEOIF_SET_ENABLERESYNC)) {
    actual_x_shift = 0;
    actual_y_shift = 0;
  }

  /* center image horizontally */
  uint32_t htotal = VIDEOIF->htotal;
  uint32_t vtotal = VIDEOIF->vtotal;
  int32_t h_pad_front = ((720 - cur_xres) / 4) * 2; // ensure even number

  /* limit image shift to the available padding space */
  if (h_pad_front < actual_x_shift)
    actual_x_shift = h_pad_front;
  if (h_pad_front < -actual_x_shift)
    actual_x_shift = -h_pad_front;

  uint32_t h_act_start = VIDEOIF->hactive_start - h_pad_front - actual_x_shift;
  uint32_t h_act_end = h_act_start + 720;

  /* wrap if result under/overflows */
  if (h_act_start <= 1)
    h_act_start += htotal;
  if (h_act_end > htotal)
    h_act_end -= htotal;

  VIDEOIF->hactive_end_start = h_act_start | (h_act_end << 16);

  /* shift hsync to nominal location */
  int32_t hsync_end   = h_act_start - ModeParameters[cur_outmode].HBackporch;
  int32_t hsync_start = hsync_end   - ModeParameters[cur_outmode].HSync;

  if (hsync_end <= 0)
    hsync_end += htotal;

  if (hsync_start <= 0) {
    /* keep the offset intact because we need it to shift VSync */
    VIDEOIF->hsync_end_start = (hsync_end << 16) | (hsync_start + htotal);
  } else {
    VIDEOIF->hsync_end_start = (hsync_end << 16) | hsync_start;
  }

  /* center image vertically */
  uint32_t ld_yres = cur_yres; // y resolution after linedoubler
  if (video_settings[cur_inmode] & VIDEOIF_SET_LD_ENABLE) {
    ld_yres *= 2;
  }

  uint32_t vactive = ModeParameters[cur_outmode].VActive;
  int32_t v_pad_front = (vactive - ld_yres) / 2;

  /* limit shift to available padding space */
  if (v_pad_front < actual_y_shift)
    actual_y_shift = v_pad_front;
  if (v_pad_front < -actual_y_shift)
    actual_y_shift = -v_pad_front;

  /* v active start/end are relative to output vsync */
  uint32_t v_act_start = ModeParameters[cur_outmode].VSync + ModeParameters[cur_outmode].VBackporch;

  VIDEOIF->vactive_start = v_act_start;
  VIDEOIF->vactive_lines = vactive - 1;

  /* shift vsync to nominal location */
  int32_t vhoffset = 0;
  if (is_progressive(cur_outmode) && VIDEOIF->vhoffset0 != 0) {
    /* ensure vsync and hsync are aligned in progressive modes */
    vhoffset = htotal - VIDEOIF->vhoffset0;
  }

  /* calculate v active relative to input vsync for calculating the output vsync shift */
  uint32_t v_act_start_in = min(VIDEOIF->vactive_start0, VIDEOIF->vactive_start1)
     - v_pad_front - actual_y_shift;
  if (v_act_start_in <= 0) {
    v_act_start_in = 1;
  }

  int32_t vsync_end = hsync_start + vhoffset + htotal *
    (v_act_start_in - ModeParameters[cur_outmode].VBackporch);
  int32_t vsync_start = vsync_end - ModeParameters[cur_outmode].VSync * htotal;

  /* wrap */
  if (vsync_start <= 0)
    vsync_start += vtotal;
  if (vsync_end <= 0)
    vsync_end += vtotal;

  VIDEOIF->vsync_start = vsync_start;
  VIDEOIF->vsync_end   = vsync_end;
}
