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


   screen_outputsettings.c: Screen for output-related settings

*/

#include <stdbool.h>
#include <stddef.h>
#include "menu.h"
#include "osd.h"
#include "pad.h"
#include "portdefs.h"
#include "screens.h"
#include "settings.h"

enum {
  MENUITEM_CABLEDETECT,
  MENUITEM_LIMITEDRGB,
  MENUITEM_DVIENHANCED,
  MENUITEM_169,
  MENUITEM_SWITCHDELAY,
  MENUITEM_VOLUME,
  MENUITEM_MUTE,
  MENUITEM_ANALOGOUT
  // _EXIT as #define because ANALOGOUT doesn't always exist
};

#ifdef OUTPUT_DUAL
#  define HAVE_DUAL 1
#  define MENUITEM_EXIT (MENUITEM_ANALOGOUT + 1)
#else
#  define HAVE_DUAL 0
#  define MENUITEM_EXIT (MENUITEM_ANALOGOUT)
#endif

/* --- getters and setters --- */

static int get_dvienhanced(void) { return video_settings_global & VIDEOIF_SET_DVIENHANCED; }
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

static bool set_dvienhanced(int value) {
  set_all_modes(VIDEOIF_SET_DVIENHANCED, value);
  return true;
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

static valueitem_t value_cabledetect = { VALTYPE_BOOL, true,
                                         { .field = { NULL, VIDEOIF_BIT_CABLEDETECT, 0, VIFLAG_ALLMODES }} };
static valueitem_t value_rgblimited  = { VALTYPE_BOOL, true,
                                         { .field = { NULL, VIDEOIF_BIT_RGBLIMITED, 0, VIFLAG_ALLMODES }} };
static valueitem_t value_169         = { VALTYPE_BOOL, true,
                                         { .field = { NULL, VIDEOIF_BIT_169, 0, VIFLAG_ALLMODES }} };
static valueitem_t value_dvienhanced = { VALTYPE_BOOL, false, {{ get_dvienhanced, set_dvienhanced }} };
static valueitem_t value_switchdelay = { VALTYPE_BYTE, false, {{ get_switchdelay, set_switchdelay }} };
static valueitem_t value_volume      = { VALTYPE_BYTE, false, {{ get_volume,      set_volume      }} };
static valueitem_t value_mute        = { VALTYPE_BOOL, false, {{ get_mute,        set_mute        }} };


static valueitem_t __attribute__((unused)) value_analogmode =
  { VALTYPE_ANALOGMODE, false, {{ get_analogmode, set_analogmode }} };

/* --- menu definition --- */

static void outputset_draw(menu_t *menu);

#ifdef OUTPUT_DUAL
static menuitem_t outputset_items[] = {
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

static menu_t outputset_menu = {
  9, 9,
  26, 12,
  outputset_draw,
  sizeof(outputset_items) / sizeof(*outputset_items),
  outputset_items
};
#else
static menuitem_t outputset_items[] = {
  { "Allow 480p mode",   &value_cabledetect, 1, 0 }, // 0
  { "RGB Limited Range", &value_rgblimited,  2, 0 }, // 1
  { "Enhanced DVI mode", &value_dvienhanced, 3, 0 }, // 2
  { "  Display as 16:9", &value_169,         4, 0 }, // 3
  { "Mode switch delay", &value_switchdelay, 5, 0 }, // 4
  { "Volume",            &value_volume,      6, 0 }, // 5
  { "Mute",              &value_mute,        7, 0 }, // 6
  { "Exit",              NULL,               9, 0 }, // 7
};

static menu_t outputset_menu = {
  9, 9,
  26, 11,
  outputset_draw,
  sizeof(outputset_items) / sizeof(*outputset_items),
  outputset_items
};
#endif

static void outputset_draw(menu_t *menu) {
  if (video_settings_global & VIDEOIF_SET_DVIENHANCED) {
    outputset_items[MENUITEM_169].flags = 0;
  } else {
    outputset_items[MENUITEM_169].flags = MENU_FLAG_DISABLED;
  }

  if (HAVE_DUAL) {
    if (VIDEOIF->flags & VIDEOIF_FLAG_FORCE_YPBPR) {
      outputset_items[MENUITEM_ANALOGOUT].flags = MENU_FLAG_DISABLED;
    } else {
      outputset_items[MENUITEM_ANALOGOUT].flags = 0;
    }
  }

  /* some boards do not have cable detect connected */
#ifdef DISABLE_CABLEDETECT
  outputset_items[MENUITEM_CABLEDETECT].flags = MENU_FLAG_DISABLED;
#endif
}

void screen_outputsettings(void) {
  osd_clrscr();
  menu_draw(&outputset_menu);
  menu_exec(&outputset_menu, 0);
}
