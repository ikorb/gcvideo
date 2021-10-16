/* GCVideo DVI Firmware

   Copyright (C) 2015-2021, Ingo Korb <ingo@akana.de>
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

#define SETTINGS_VERSION 6 // bump if current reader cannot read older settings anymore

typedef struct {
  uint8_t  version;
  uint8_t  checksum;
  // sub-structure to ensure future compatibility for flasher
  uint8_t  ir_checksum; // only codecount and codes
  uint8_t  ir_codecount;
  uint32_t ir_codes[NUM_IRCODES];
  // end of flasher compatibility section
  uint8_t  size;
  uint8_t  resbox_enabled;
  uint8_t  volume;
  uint8_t  mute_and_crop486;
  uint32_t video_settings[VIDMODE_COUNT];
  uint32_t video_settings_global;
  uint32_t osdbg_settings;
  int8_t   brightness;
  int8_t   contrast;
  int8_t   saturation;
  int8_t   xshift;
  int8_t   yshift;
  // scanline settings are stored seperately
} storedsettings_t;

#define STOREDSET_MUTE    (1<<0)
#define STOREDSET_CROP486 (1<<1)

/* number of lines per frame in each video mode */
/* order matters! even are 60Hz, odd are 50Hz   */
/* bit 0 is set for interlaced */
const uint16_t video_out_lines[VIDMODE_COUNT] = {
  240, 288, 240 | 1, 288 | 1, 480, 576, 0
};

const char *mode_names[VIDMODE_COUNT] = {
  "240p", "288p",
  "480i", "576i",
  "480p", "576p",
  "NonStd"
};

static const unsigned char vidmode_by_flags[] = {
  VIDMODE_480i, // none
  VIDMODE_240p, // prog
  VIDMODE_576i, // pal
  VIDMODE_288p, // pal+prog
  VIDMODE_480p, // 31khz - technically 960i
  VIDMODE_480p, // prog+31khz
  VIDMODE_576p, // pal+31khz - technically 1152i
  VIDMODE_576p, // pal+prog+31khz
};

uint32_t     video_settings[VIDMODE_COUNT];
uint32_t     video_settings_global;
uint32_t     osdbg_settings;
minibool     resbox_enabled;
video_mode_t current_videomode;
uint8_t      audio_volume;
minibool     audio_mute;
int8_t       screen_x_shift;
int8_t       screen_y_shift;
uint8_t      scanline_selected_profile;
uint16_t     scanline_strength;
uint16_t     scanline_hybrid;
minibool     scanline_custom;
minibool     crop_486_to_480;

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

video_mode_t detect_videomode(bool inputmode) {
  uint32_t cur_flags = VIDEOIF->flags;
  uint32_t cur_yres  = VIDEOIF->yres;
  uint32_t htotal    = VIDEOIF->htotal;
  uint32_t vtotal    = VIDEOIF->vtotal & 0xfffff;

  if (inputmode) {
    cur_flags &= (VIDEOIF_FLAG_IN_PROGRESSIVE | VIDEOIF_FLAG_IN_PAL | VIDEOIF_FLAG_IN_31KHZ);
  } else {
    cur_flags = (cur_flags & (VIDEOIF_FLAG_LD_PROGRESSIVE | VIDEOIF_FLAG_LD_PAL | VIDEOIF_FLAG_LD_31KHZ))
      >> 6;
  }

  if (htotal > 870 || htotal < 800 || VIDEOIF->xres > 720 ||
      vtotal > 540000 || cur_yres > 576 )
    return VIDMODE_NONSTANDARD;

  /* GBI 486i/p to 480i/p crop */
  if (crop_486_to_480) {
    if (cur_yres == 486) {
      cur_yres = 480;
    }
    if (cur_yres == 243) {
      cur_yres = 240;
    }
  }

  /* figure out the maximum number of lines based on mode flags */
  unsigned int max_lines = 240;

  if (cur_flags & VIDEOIF_FLAG_IN_PAL) {
    max_lines = 288;
  }

  if ((cur_flags & VIDEOIF_FLAG_IN_31KHZ) ||
      (inputmode && (video_settings[current_videomode] & VIDEOIF_SET_LD_ENABLE))) {
    /* note: double-clocked SD modes are already detected by xres/htotal checks */
    max_lines *= 2;
  }

  if (cur_yres > max_lines) {
    return VIDMODE_NONSTANDARD;
  }

  return vidmode_by_flags[cur_flags];
}

void print_resolution(void) {
  uint32_t xres  = VIDEOIF->xres;
  uint32_t yres  = VIDEOIF->yres;
  uint32_t flags = VIDEOIF->flags;

  if (current_videomode == VIDMODE_NONSTANDARD) {
    printf("%4dx%3d", xres, yres);
  } else {
    if (!(flags & VIDEOIF_FLAG_IN_PROGRESSIVE))
      yres *= 2;

    printf("%3dx%3d%c%d", xres, yres,
          (flags & VIDEOIF_FLAG_IN_PROGRESSIVE) ? 'p' : 'i',
          (flags & VIDEOIF_FLAG_IN_PAL        ) ? 50  : 60);
  }
}


void settings_load(void) {
  union {
    storedsettings_t st;
    uint8_t          byteset[sizeof(storedsettings_t)];
  } set;

  unsigned int setid;
  bool valid = false;

  /* scan for the first valid settings record */
  /* Note: This ignores partially-filled records due to increased record size, */
  /*       but this is handled when storing to save time.                      */
  for (setid = 0; setid < 256; setid += 8) {
    spiflash_read_block(&set, SETTINGS_OFFSET + setid * 256, sizeof(storedsettings_t));
    if (set.st.version == 0xff) {
      /* looks blank */
      continue;
    }

    if (set.st.version != SETTINGS_VERSION) {
      /* invalid, but not blank - stop here, anything above should also be in use */
      break;
    }

    /* found a record with the expected version, verify checksum */
    uint8_t sum = 0;

    for (unsigned int i = offsetof(storedsettings_t, ir_codecount);
         i < sizeof(storedsettings_t); i++) {
      sum += set.byteset[i];
    }

    if (sum == set.st.checksum) {
      valid = true;
    }

    /* Don't attempt to find another usable record,
     * saving assumes that the one before the current is blank. */
    break;
  }

  current_setid = setid;

  if (!valid) {
    return;
  }

  /* valid settings found, copy to main vars */
  memcpy(ir_codes, set.st.ir_codes, sizeof(ir_codes));

  resbox_enabled = set.st.resbox_enabled;
  audio_volume   = set.st.volume;
  audio_mute     = set.st.mute_and_crop486 & STOREDSET_MUTE;

  crop_486_to_480 = !!(set.st.mute_and_crop486 & STOREDSET_CROP486);

  memcpy(video_settings, set.st.video_settings, sizeof(video_settings));
  video_settings_global = set.st.video_settings_global;

  osdbg_settings     = set.st.osdbg_settings;
  picture_brightness = set.st.brightness;
  picture_contrast   = set.st.contrast;
  picture_saturation = set.st.saturation;
  screen_x_shift     = set.st.xshift;
  screen_y_shift     = set.st.yshift;

  spiflash_start_read(SETTINGS_OFFSET + ((current_setid + 2) << 8));
  for (unsigned int i = 256; i < SCANLINERAM_ENTRIES; i ++) {
    uint16_t val = spiflash_send_byte(0) << 8;
    val |= spiflash_send_byte(0);
    SCANLINERAM->profiles[i] = val;
  }
  spiflash_end_read();
}

void settings_save(void) {
  union {
    storedsettings_t st;
    uint8_t          byteset[sizeof(storedsettings_t)];
  } set;

  /* create settings record */
  memset(&set, 0, sizeof(set));
  set.st.size                  = sizeof(storedsettings_t);
  set.st.version               = SETTINGS_VERSION;
  set.st.ir_codecount          = NUM_IRCODES;
  set.st.video_settings_global = video_settings_global;
  set.st.osdbg_settings        = osdbg_settings;
  set.st.resbox_enabled        = resbox_enabled;
  set.st.volume                = audio_volume;
  if (audio_mute) {
    set.st.mute_and_crop486 |= STOREDSET_MUTE;
  }
  if (crop_486_to_480) {
    set.st.mute_and_crop486 |= STOREDSET_CROP486;
  }
  set.st.brightness            = picture_brightness;
  set.st.contrast              = picture_contrast;
  set.st.saturation            = picture_saturation;
  set.st.xshift                = screen_x_shift;
  set.st.yshift                = screen_y_shift;

  memcpy(set.st.ir_codes, ir_codes, sizeof(ir_codes));
  memcpy(set.st.video_settings, video_settings, sizeof(video_settings));

  /* calculate global checksum */
  uint8_t sum = 0;

  for (unsigned int i = offsetof(storedsettings_t, ir_codecount);
       i < sizeof(storedsettings_t); i++) {
    sum += set.byteset[i];
  }

  set.st.checksum = sum;

  /* calculate IR checksum */
  sum = 0;
  for (unsigned int i = offsetof(storedsettings_t, ir_codecount);
       i < offsetof(storedsettings_t, size); i++) {
    sum += set.byteset[i];
  }

  set.st.ir_checksum = sum;

  /* check if erase cycle is needed */
  if (current_setid < 8 || current_setid > 256 ||
      !spiflash_is_blank(SETTINGS_OFFSET + (current_setid - 8) * 256, 2048)) {
    spiflash_erase_sector(SETTINGS_OFFSET);
    current_setid = 256;
  }

  /* write data to flash */
  current_setid -= 8;
  spiflash_write_page(SETTINGS_OFFSET + current_setid * 256, &set, sizeof(set));

  unsigned int page_remain = 0;
  // note: first 256 word block of scanline RAM is unused
  for (unsigned int i = 256; i < SCANLINERAM_ENTRIES; i++) {
    if (page_remain == 0) {
      spiflash_end_write();
      spiflash_start_write(SETTINGS_OFFSET + current_setid * 256 + i * 2);
      page_remain = 128;
    }

    spiflash_send_byte((SCANLINERAM->profiles[i] >> 8) & 0xff);
    spiflash_send_byte(SCANLINERAM->profiles[i] & 0xff);
    page_remain--;
  }

  spiflash_end_write();
}


void settings_init(void) {
  resbox_enabled = true;

  video_settings_global = VIDEOIF_SET_ENABLEREBLANK | VIDEOIF_SET_ENABLERESYNC |
                          VIDEOIF_SET_CABLEDETECT   | VIDEOIF_SET_CHROMAINTERP;
  video_settings[VIDMODE_240p] = VIDEOIF_SET_LD_ENABLE;
  video_settings[VIDMODE_288p] = VIDEOIF_SET_LD_ENABLE;
  video_settings[VIDMODE_480i] = VIDEOIF_SET_LD_ENABLE | VIDEOIF_SET_SL_ALTERNATE;
  video_settings[VIDMODE_576i] = VIDEOIF_SET_LD_ENABLE | VIDEOIF_SET_SL_ALTERNATE;
  video_settings[VIDMODE_480p] = 0;
  video_settings[VIDMODE_576p] = 0;
  video_settings[VIDMODE_NONSTANDARD] = VIDEOIF_SET_NONSTD_MASK;
  osdbg_settings = 0x501bf8;  // partially transparent, blue tinted background
  picture_brightness = 0;
  picture_contrast   = 0;
  picture_saturation = 0;
  update_colormatrix();

  audio_mute        = false;
  audio_volume      = 255;
  current_videomode = detect_input_videomode();
  screen_x_shift    = 0;
  screen_y_shift    = 0;
  crop_486_to_480   = false;

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

void settings_commit(void) {
  /* update hardware to current settings */
  VIDEOIF->settings = video_settings[current_videomode] | video_settings_global;
  VIDEOIF->osd_bg   = osdbg_settings;
  if (audio_mute) {
    VIDEOIF->audio_volume = 0;
  } else {
    VIDEOIF->audio_volume = audio_volume;
  }
  update_colormatrix();
}
