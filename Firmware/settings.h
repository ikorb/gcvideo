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


   settings.h: video-settings-related things

*/

#ifndef SETTINGS_H
#define SETTINGS_H

#include <stdbool.h>
#include <stdint.h>

#define SETTINGS_OFFSET 0x70000

typedef enum {
  VIDMODE_240p,
  VIDMODE_288p,
  VIDMODE_480i,
  VIDMODE_576i,
  /* the progressive modes must come last */
  VIDMODE_480p,
  VIDMODE_576p,
  VIDMODE_NONSTANDARD,

  VIDMODE_COUNT
} video_mode_t;

extern const uint16_t video_out_lines[VIDMODE_COUNT];
extern const char    *mode_names[VIDMODE_COUNT];

extern uint32_t     video_settings[VIDMODE_COUNT];
extern uint32_t     video_settings_global;
extern uint32_t     osdbg_settings;
extern bool         resbox_enabled;
extern video_mode_t current_videomode;
extern uint8_t      audio_volume;
extern bool         audio_mute;
extern uint8_t      scanline_selected_profile;
extern uint16_t     scanline_strength;
extern uint16_t     scanline_hybrid;
extern bool         scanline_custom;

void set_all_modes(uint32_t flag, bool state);
void update_scanlines(void);
video_mode_t detect_videomode(bool inputmode);
void print_resolution(void);
void settings_load(void);
void settings_save(void);
void settings_init(void);

static inline video_mode_t detect_input_videomode(void) {
   return detect_videomode(true);
}

static inline video_mode_t detect_output_videomode(void) {
   return detect_videomode(false);
}

static inline bool is_progressive(video_mode_t mode) {
   return (mode != VIDMODE_480i) && (mode != VIDMODE_576i);
}

#endif
