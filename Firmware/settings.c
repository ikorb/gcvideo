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
#include "colormatrix.h"
#include "irrx.h"
#include "portdefs.h"
#include "spiflash.h"
#include "vsync.h"
#include "settings.h"

#define SETTINGS_VERSION 5
#define SETTINGS_SIZE_V4 60
#define SETTINGS_SIZE_V5 63

typedef struct {
  uint8_t  checksum;
  uint8_t  version;
  uint8_t  flags;
  uint8_t  volume;
  uint32_t video_settings[VIDMODE_COUNT];
  uint32_t osdbg_settings;
  uint32_t ir_codes[NUM_IRCODES];
  int8_t   brightness;
  int8_t   contrast;
  int8_t   saturation;
} storedsettings_t;

#define SET_FLAG_RESBOX (1<<0)
#define SET_FLAG_MUTE   (1<<1)


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
uint32_t     video_settings_global;
uint32_t     osdbg_settings;
bool         resbox_enabled;
video_mode_t current_videomode;
uint8_t      audio_volume;
bool         audio_mute;
uint8_t      scanline_selected_profile;
uint16_t     scanline_strength;
uint16_t     scanline_hybrid;
bool         scanline_custom;

static uint16_t current_setid;

void set_all_modes(uint32_t flag, bool state) {
  if (state)
    video_settings_global |=  flag;
  else
    video_settings_global &= ~flag;

  VIDEOIF->settings = video_settings[current_videomode] | video_settings_global;
}

void update_scanlines(void) {
  if (scanline_custom) {
    // profile uses custom setting, no update needed
    return;
  }

  for (unsigned int i = 0; i <= 235 - 16; i++) { // 219
    unsigned int str_adjusted = 0;

    if (scanline_hybrid * i < 128 * 219) {
      str_adjusted = (256 - scanline_strength) * (128 * 219 - scanline_hybrid * i) / (128 * 219);
    }

    SCANLINERAM->profiles[scanline_selected_profile * 256 + i] = 256 - str_adjusted;
  }
}

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


void settings_load(void) {
  storedsettings_t set;
  unsigned int i;
  bool valid = false;

  /* scan for the first valid settings record */
  for (i = 0; i < 256; i++) {
    spiflash_read_block(&set, SETTINGS_OFFSET + 256 * i, sizeof(storedsettings_t));
    if (set.version == SETTINGS_VERSION ||
        set.version == 4) {
      /* found a record with the expected version, verify checksum */
      uint8_t *byteset = (uint8_t *)&set;
      uint8_t sum = 0;
      uint8_t size = 0;

      switch (set.version) {
      case 4: size = SETTINGS_SIZE_V4; break;
      case 5: size = SETTINGS_SIZE_V5; break;
      }

      for (unsigned int j = 1; j < size; j++)
        sum += byteset[j];

      if (size != 0 && sum == set.checksum) {
        /* found a valid setting record */
        valid = true;
        break;
      }
    }

    if (set.version  != 0xff ||
        set.checksum != 0xff) {
      /* found an invalid, but non-empty record */
      /* stop here because we can only write to empty records */
      break;
    }
  }

  current_setid = i;
  if (valid) {
    /* valid settings found, copy to main vars */
    for (i = 0; i < VIDMODE_COUNT; i++)
      video_settings[i] = set.video_settings[i];

    osdbg_settings    = set.osdbg_settings;

    if (set.flags & SET_FLAG_RESBOX)
      resbox_enabled = true;
    else
      resbox_enabled = false;

    audio_volume = set.volume & 0xff;
    if (set.flags & SET_FLAG_MUTE)
      audio_mute = true;
    else
      audio_mute = false;

    memcpy(ir_codes, set.ir_codes, sizeof(ir_codes));

    if (set.version >= 5) {
      picture_brightness = set.brightness;
      picture_contrast   = set.contrast;
      picture_saturation = set.saturation;
      update_colormatrix();
    }
  }
}

void settings_save(void) {
  storedsettings_t set;
  uint8_t *byteset = (uint8_t *)&set;
  uint8_t sum = 0;

  /* create settings record */
  memset(&set, 0, sizeof(storedsettings_t));
  set.version = SETTINGS_VERSION;

  for (unsigned int i = 0; i < VIDMODE_COUNT; i++)
    set.video_settings[i] = video_settings[i];

  set.osdbg_settings    = osdbg_settings;

  if (resbox_enabled)
    set.flags |= SET_FLAG_RESBOX;

  set.volume = audio_volume;
  if (audio_mute)
    set.flags |= SET_FLAG_MUTE;

  memcpy(set.ir_codes, ir_codes, sizeof(ir_codes));

  set.brightness = picture_brightness;
  set.contrast   = picture_contrast;
  set.saturation = picture_saturation;

  /* calculate checksum */
  for (unsigned int i = 1; i < sizeof(storedsettings_t); i++)
    sum += byteset[i];

  set.checksum = sum;

  /* check if erase cycle is needed */
  if (current_setid == 0) {
    spiflash_erase_sector(SETTINGS_OFFSET);
    current_setid = 256;
  }

  /* write data to flash */
  current_setid--;
  spiflash_write_page(SETTINGS_OFFSET + 256 * current_setid, &set, sizeof(storedsettings_t));
}


void settings_init(void) {
  resbox_enabled = true;

  video_settings_global = VIDEOIF_SET_CABLEDETECT;
  video_settings[VIDMODE_240p] = VIDEOIF_SET_LD_ENABLE;
  video_settings[VIDMODE_288p] = VIDEOIF_SET_LD_ENABLE;
  video_settings[VIDMODE_480i] = VIDEOIF_SET_LD_ENABLE | VIDEOIF_SET_SL_ALTERNATE;
  video_settings[VIDMODE_576i] = VIDEOIF_SET_LD_ENABLE | VIDEOIF_SET_SL_ALTERNATE;
  video_settings[VIDMODE_480p] = 0;
  video_settings[VIDMODE_576p] = 0;
  osdbg_settings = 0x501bf8;  // partially transparent, blue tinted background
  picture_brightness = 0;
  picture_contrast   = 0;
  picture_saturation = 0;
  update_colormatrix();

  audio_mute        = false;
  audio_volume      = 255;
  current_videomode = detect_inputmode();

  /* initialize scanline profiles */
  scanline_selected_profile = 1;
  scanline_strength = 192;
  scanline_hybrid   = 0;
  SCANLINERAM->profiles[1 * 256 + 250] = 0;
  SCANLINERAM->profiles[1 * 256 + 251] = scanline_strength;
  SCANLINERAM->profiles[1 * 256 + 252] = scanline_hybrid;
  update_scanlines();

  scanline_selected_profile = 2;
  scanline_strength = 128;
  scanline_hybrid   = 96;
  SCANLINERAM->profiles[2 * 256 + 250] = 0;
  SCANLINERAM->profiles[2 * 256 + 251] = scanline_strength;
  SCANLINERAM->profiles[2 * 256 + 252] = scanline_hybrid;
  update_scanlines();

  scanline_selected_profile = 3;
  scanline_strength = 64;
  scanline_hybrid   = 160;
  SCANLINERAM->profiles[3 * 256 + 250] = 0;
  SCANLINERAM->profiles[3 * 256 + 251] = scanline_strength;
  SCANLINERAM->profiles[3 * 256 + 252] = scanline_hybrid;
  update_scanlines();
}
