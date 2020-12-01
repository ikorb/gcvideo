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


   screen_othersettings.c: Screen for misc. settings

*/

#include <stdbool.h>
#include <stddef.h>
#include "menu.h"
#include "osd.h"
#include "pad.h"
#include "portdefs.h"
#include "screens.h"
#include "settings.h"

#define MENUITEM_CABLEDETECT 0
#define MENUITEM_LIMITEDRGB  1
#define MENUITEM_DVIENHANCED 2
#define MENUITEM_169         3
#define MENUITEM_SWITCHDELAY 4
#define MENUITEM_VOLUME      5
#define MENUITEM_MUTE        6
#ifdef OUTPUT_DUAL
#  define MENUITEM_ANALOGOUT 7
#  define MENUITEM_EXIT      8
#  define HAVE_DUAL 1
#else
#  define MENUITEM_ANALOGOUT 0
#  define MENUITEM_EXIT      7
#  define HAVE_DUAL 0
#endif

/* --- getters and setters --- */

static int get_cabledetect(void) { return video_settings_global & VIDEOIF_SET_CABLEDETECT; }
static int get_rgblimited(void)  { return video_settings_global & VIDEOIF_SET_RGBLIMITED;  }
static int get_dvienhanced(void) { return video_settings_global & VIDEOIF_SET_DVIENHANCED; }
static int get_169(void)         { return video_settings_global & VIDEOIF_SET_169;         }
static int get_switchdelay(void) { return mode_switch_delay;                               }
static int get_volume(void)      { return audio_volume;                                    }
static int get_mute(void)        { return audio_mute;                                      }

static int get_analogmode(void) {
  uint32_t val = (video_settings_global & VIDEOIF_SET_ANALOG_MASK)
    >> VIDEOIF_SET_ANALOG_SHIFT;
  if (val == 3)
    return 2;
  else
    return val;
}


static void set_all_modes(uint32_t flag, bool state) {
  if (state)
    video_settings_global |=  flag;
  else
    video_settings_global &= ~flag;

  VIDEOIF->settings = video_settings[current_videomode] | video_settings_global;
}

static bool set_cabledetect(int value) {
  set_all_modes(VIDEOIF_SET_CABLEDETECT, value);
  return false;
}

static bool set_rgblimited(int value) {
  set_all_modes(VIDEOIF_SET_RGBLIMITED, value);
  return false;
}

static bool set_dvienhanced(int value) {
  set_all_modes(VIDEOIF_SET_DVIENHANCED, value);
  return true;
}

static bool set_169(int value) {
  set_all_modes(VIDEOIF_SET_169, value);
  return false;
}

static bool set_switchdelay(int value) {
  mode_switch_delay = value;
  return false;
}

static bool set_volume(int value) {
  audio_volume = value;
  if (!audio_mute)
    VIDEOIF->audio_volume = value;
  return false;
}

static bool set_mute(int value) {
  audio_mute = value;
  if (audio_mute)
    VIDEOIF->audio_volume = 0;
  else
    VIDEOIF->audio_volume = audio_volume;
  return false;
}

static bool set_analogmode(int value) {
  if (value == 2)
    value = 3;
  set_all_modes(VIDEOIF_SET_ANALOG_MASK, false);
  set_all_modes(value << VIDEOIF_SET_ANALOG_SHIFT, true);
  return false;
}

static valueitem_t value_cabledetect = { get_cabledetect, set_cabledetect, VALTYPE_BOOL };
static valueitem_t value_rgblimited  = { get_rgblimited,  set_rgblimited,  VALTYPE_BOOL };
static valueitem_t value_dvienhanced = { get_dvienhanced, set_dvienhanced, VALTYPE_BOOL };
static valueitem_t value_169         = { get_169,         set_169,         VALTYPE_BOOL };
static valueitem_t value_switchdelay = { get_switchdelay, set_switchdelay, VALTYPE_BYTE };
static valueitem_t value_volume      = { get_volume,      set_volume,      VALTYPE_BYTE };
static valueitem_t value_mute        = { get_mute,        set_mute,        VALTYPE_BOOL };

static valueitem_t __attribute__((unused)) value_analogmode =
  { get_analogmode, set_analogmode, VALTYPE_ANALOGMODE };

/* --- menu definition --- */

static void otherset_draw(menu_t *menu);

#ifdef OUTPUT_DUAL
static menuitem_t otherset_items[] = {
  { "Allow 480p mode",   &value_cabledetect,  1, 0 }, // 0
  { "RGB Limited Range", &value_rgblimited,   2, 0 }, // 1
  { "Enhanced DVI mode", &value_dvienhanced,  3, 0 }, // 2
  { "  Display as 16:9", &value_169,          4, 0 }, // 3
  { "Mode switch delay", &value_switchdelay,  5, 0 }, // 4
  { "Volume",            &value_volume,       6, 0 }, // 5
  { "Mute",              &value_mute,         7, 0 }, // 6
  { "Analog output",     &value_analogmode,   8, 0 }, // 7
  { "Exit",              NULL,               10, 0 }, // 8
};

static menu_t otherset_menu = {
  9, 9,
  26, 12,
  otherset_draw,
  sizeof(otherset_items) / sizeof(*otherset_items),
  otherset_items
};
#else
static menuitem_t otherset_items[] = {
  { "Allow 480p mode",   &value_cabledetect, 1, 0 }, // 0
  { "RGB Limited Range", &value_rgblimited,  2, 0 }, // 1
  { "Enhanced DVI mode", &value_dvienhanced, 3, 0 }, // 2
  { "  Display as 16:9", &value_169,         4, 0 }, // 3
  { "Mode switch delay", &value_switchdelay, 5, 0 }, // 4
  { "Volume",            &value_volume,      6, 0 }, // 5
  { "Mute",              &value_mute,        7, 0 }, // 6
  { "Exit",              NULL,               9, 0 }, // 7
};

static menu_t otherset_menu = {
  9, 9,
  26, 11,
  otherset_draw,
  sizeof(otherset_items) / sizeof(*otherset_items),
  otherset_items
};
#endif

static void otherset_draw(menu_t *menu) {
  if (video_settings_global & VIDEOIF_SET_DVIENHANCED) {
    otherset_items[MENUITEM_169].flags = 0;
  } else {
    otherset_items[MENUITEM_169].flags = MENU_FLAG_DISABLED;
  }

  if (HAVE_DUAL) {
    if (VIDEOIF->flags & VIDEOIF_FLAG_FORCE_YPBPR) {
      otherset_items[MENUITEM_ANALOGOUT].flags = MENU_FLAG_DISABLED;
    } else {
      otherset_items[MENUITEM_ANALOGOUT].flags = 0;
    }
  }

  /* some boards do not have cable detect connected */
#ifdef DISABLE_CABLEDETECT
  otherset_items[MENUITEM_CABLEDETECT].flags = MENU_FLAG_DISABLED;
#endif
}

void screen_othersettings(void) {
  osd_clrscr();
  menu_draw(&otherset_menu);
  menu_exec(&otherset_menu, 0);
}
