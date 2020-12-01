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


   settings.c: video-settings-related things

*/

#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include "irrx.h"
#include "portdefs.h"
#include "spiflash.h"
#include "utils.h"
#include "vsync.h"
#include "settings.h"

#define SETTINGS_MINVERSION 6

typedef struct {
  uint8_t  version;
  uint8_t  checksum;
  // sub-structure to ensure future compatibility for flasher
  uint8_t  ir_checksum; // only codecount and codes
  uint8_t  ir_codecount;
  uint32_t ir_codes[63]; // theoretical maximum for 256 bytes of storage
  // end of flasher compatibility section
} storedsettings_flasher_t;


/* dummy variables */
uint32_t     video_settings[VIDMODE_COUNT];
uint32_t     video_settings_global;
video_mode_t current_videomode;
uint32_t     osdbg_settings;
uint8_t      audio_volume;
bool         audio_mute;

/* dummy functions */
void update_colormatrix(void) {}


void settings_init(void) {
  video_settings[0] = VIDEOIF_SET_LD_ENABLE;
  VIDEOIF->settings = VIDEOIF_SET_LD_ENABLE;
}

void settings_load(void) {
  // temporary dummy
}
