/* GCVideo DVI Firmware

   Copyright (C) 2015, Ingo Korb <ingo@akana.de>
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
#define MENUITEM_EXIT        5

/* --- getters and setters --- */

static int get_cabledetect(void) { return video_settings[current_videomode] & VIDEOIF_SET_CABLEDETECT; }
static int get_rgblimited(void)  { return video_settings[current_videomode] & VIDEOIF_SET_RGBLIMITED;  }
static int get_dvienhanced(void) { return video_settings[current_videomode] & VIDEOIF_SET_DVIENHANCED; }
static int get_169(void)         { return video_settings[current_videomode] & VIDEOIF_SET_169;         }
static int get_switchdelay(void) { return mode_switch_delay;                                           }

static void set_all_modes(uint32_t flag, bool state) {
  for (unsigned int i = 0; i < VIDMODE_COUNT; i++) {
    if (state)
      video_settings[i] |=  flag;
    else
      video_settings[i] &= ~flag;
  }
}

static bool set_cabledetect(int value) {
  set_all_modes(VIDEOIF_SET_CABLEDETECT, value);
  VIDEOIF->settings = video_settings[current_videomode];
  return false;
}

static bool set_rgblimited(int value) {
  set_all_modes(VIDEOIF_SET_RGBLIMITED, value);
  VIDEOIF->settings = video_settings[current_videomode];
  return false;
}

static bool set_dvienhanced(int value) {
  set_all_modes(VIDEOIF_SET_DVIENHANCED, value);
  VIDEOIF->settings = video_settings[current_videomode];
  return true;
}

static bool set_169(int value) {
  set_all_modes(VIDEOIF_SET_169, value);
  VIDEOIF->settings = video_settings[current_videomode];
  return false;
}

static bool set_switchdelay(int value) {
  mode_switch_delay = value;
  return false;
}

static valueitem_t value_cabledetect = { get_cabledetect, set_cabledetect, VALTYPE_BOOL };
static valueitem_t value_rgblimited  = { get_rgblimited,  set_rgblimited,  VALTYPE_BOOL };
static valueitem_t value_dvienhanced = { get_dvienhanced, set_dvienhanced, VALTYPE_BOOL };
static valueitem_t value_169         = { get_169,         set_169,         VALTYPE_BOOL };
static valueitem_t value_switchdelay = { get_switchdelay, set_switchdelay, VALTYPE_BYTE };

/* --- menu definition --- */

static void otherset_draw(menu_t *menu);

static menuitem_t otherset_items[] = {
  { "Allow 480p mode",   &value_cabledetect, 0, 0 }, // 0
  { "RGB Limited Range", &value_rgblimited,  1, 0 }, // 1
  { "Enhanced DVI mode", &value_dvienhanced, 2, 0 }, // 2
  { "  Display as 16:9", &value_169,         3, 0 }, // 3
  { "Mode switch delay", &value_switchdelay, 4, 0 }, // 4
  { "Exit",              NULL,               6, 0 }, // 5
};

static menu_t otherset_menu = {
  9, 10,
  26, 9,
  otherset_draw,
  sizeof(otherset_items) / sizeof(*otherset_items),
  otherset_items
};

static void otherset_draw(menu_t *menu) {
  if (video_settings[current_videomode] & VIDEOIF_SET_DVIENHANCED) {
    otherset_items[MENUITEM_169].flags = 0;
  } else {
    otherset_items[MENUITEM_169].flags = MENU_FLAG_DISABLED;
  }
}

void screen_othersettings(void) {
  osd_clrscr();
  menu_draw(&otherset_menu);
  menu_exec(&otherset_menu, 0);
}
