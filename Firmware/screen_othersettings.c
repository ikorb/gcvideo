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
#define MENUITEM_EXIT        2

/* --- getters and setters --- */

static int get_cabledetect(void) { return video_settings[current_videomode] & VIDEOIF_SET_CABLEDETECT; }
static int get_rgblimited(void)  { return video_settings[current_videomode] & VIDEOIF_SET_RGBLIMITED;  }

static bool set_cabledetect(int value) {
  for (unsigned int i = 0; i < VIDMODE_COUNT; i++) {
    if (value)
      video_settings[i] |=  VIDEOIF_SET_CABLEDETECT;
    else
      video_settings[i] &= ~VIDEOIF_SET_CABLEDETECT;
  }
  VIDEOIF->settings = video_settings[current_videomode];
  return false;
}

static bool set_rgblimited(int value) {
  for (unsigned int i = 0; i < VIDMODE_COUNT; i++) {
    if (value)
      video_settings[i] |=  VIDEOIF_SET_RGBLIMITED;
    else
      video_settings[i] &= ~VIDEOIF_SET_RGBLIMITED;
  }
  VIDEOIF->settings = video_settings[current_videomode];
  return false;
}

static valueitem_t value_cabledetect = { get_cabledetect, set_cabledetect, VALTYPE_BOOL };
static valueitem_t value_rgblimited  = { get_rgblimited,  set_rgblimited,  VALTYPE_BOOL };

/* --- menu definition --- */

static menuitem_t otherset_items[] = {
  { "Allow 480p mode",   &value_cabledetect, 0, 0 }, // 0
  { "RGB Limited Range", &value_rgblimited,  1, 0 }, // 1
  { "Exit",              NULL,               3, 0 }, // 2
};

static menu_t otherset_menu = {
  9, 12,
  26, 6,
  NULL,
  sizeof(otherset_items) / sizeof(*otherset_items),
  otherset_items
};

void screen_othersettings(void) {
  osd_clrscr();
  menu_draw(&otherset_menu);
  menu_exec(&otherset_menu, 0);
}
