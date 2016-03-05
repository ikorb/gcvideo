/* GCVideo DVI Firmware

   Copyright (C) 2015-2016, Ingo Korb <ingo@akana.de>
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


   settings.c: video-settings-related things

*/

#include <stdio.h>
#include <stdint.h>
#include "portdefs.h"
#include "vsync.h"
#include "settings.h"

/* number of lines per frame in each video mode */
/* order matters! even are 60Hz, odd are 50Hz   */
/* bit 0 is set for interlaced */
const uint16_t video_out_lines[VIDMODE_COUNT] = {
  240, 288, 240 | 1, 288 | 1, 480, 576
};

const char *mode_names[VIDMODE_COUNT] = {
  "240p", "288p",
  "480i", "576i",
  "480p", "576p"
};

uint32_t     video_settings[VIDMODE_COUNT];
uint32_t     osdbg_settings;
uint32_t     mode_switch_delay;
bool         resbox_enabled;
video_mode_t current_videomode;
uint8_t      audio_volume;
bool         audio_mute;

video_mode_t detect_inputmode(void) {
  uint32_t cur_flags = VIDEOIF->flags & (VIDEOIF_FLAG_PROGRESSIVE | VIDEOIF_FLAG_PAL | VIDEOIF_FLAG_31KHZ);

  switch (cur_flags) {
  case VIDEOIF_FLAG_PAL | VIDEOIF_FLAG_31KHZ:
  case VIDEOIF_FLAG_PAL | VIDEOIF_FLAG_31KHZ | VIDEOIF_FLAG_PROGRESSIVE:
    /* assumption: the Cube cannot output 960i/1152i */
    return VIDMODE_576p;

  case VIDEOIF_FLAG_PAL | VIDEOIF_FLAG_PROGRESSIVE:
    return VIDMODE_288p;

  case VIDEOIF_FLAG_PAL:
    return VIDMODE_576i;

  case VIDEOIF_FLAG_31KHZ:
  case VIDEOIF_FLAG_31KHZ | VIDEOIF_FLAG_PROGRESSIVE:
    return VIDMODE_480p;

  case VIDEOIF_FLAG_PROGRESSIVE:
    return VIDMODE_240p;

  case 0:
  default:
    return VIDMODE_480i;
  }
}

void print_resolution(void) {
  uint32_t xres  = VIDEOIF->xres;
  uint32_t yres  = VIDEOIF->yres;
  uint32_t flags = VIDEOIF->flags;

  if (!(flags & VIDEOIF_FLAG_PROGRESSIVE))
    yres *= 2;

  printf("%3dx%3d%c%d", xres, yres,
         (flags & VIDEOIF_FLAG_PROGRESSIVE) ? 'p' : 'i',
         (flags & VIDEOIF_FLAG_PAL        ) ? 50  : 60);
}

void settings_init(void) {
  resbox_enabled = true;

  video_settings[VIDMODE_240p] = VIDEOIF_SET_CABLEDETECT | 0x80 | VIDEOIF_SET_LD_ENABLE;
  video_settings[VIDMODE_288p] = VIDEOIF_SET_CABLEDETECT | 0x80 | VIDEOIF_SET_LD_ENABLE;
  video_settings[VIDMODE_480i] = VIDEOIF_SET_CABLEDETECT | 0x80 | VIDEOIF_SET_LD_ENABLE | VIDEOIF_SET_SL_ALTERNATE;
  video_settings[VIDMODE_576i] = VIDEOIF_SET_CABLEDETECT | 0x80 | VIDEOIF_SET_LD_ENABLE | VIDEOIF_SET_SL_ALTERNATE;
  video_settings[VIDMODE_480p] = VIDEOIF_SET_CABLEDETECT | 0x80;
  video_settings[VIDMODE_576p] = VIDEOIF_SET_CABLEDETECT | 0x80;
  osdbg_settings = 0x501bf8;  // partially transparent, blue tinted background

  audio_mute        = false;
  audio_volume      = 255;
  mode_switch_delay = 0;
  current_videomode = detect_inputmode();
  VIDEOIF->settings = video_settings[current_videomode];
  VIDEOIF->osd_bg   = osdbg_settings;
  VIDEOIF->audio_volume = 255;
}
