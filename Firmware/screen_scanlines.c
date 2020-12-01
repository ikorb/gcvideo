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


   screen_scanlines.c: Screen for scanline settings

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
  MENUITEM_PROFILE,
  MENUITEM_CUSTOM,
  MENUITEM_STRENGTH,
  MENUITEM_HYBRID,
  MENUITEM_LUMINANCE,
  MENUITEM_VALUE,
  MENUITEM_EXIT
};

static uint8_t  scanline_luminance = 16;
static uint8_t  scanline_value;

/* --- getters and setters --- */

static int get_slprofile(void) { return scanline_selected_profile; }

static bool set_slprofile(int value) {
  uint32_t* ptr = &SCANLINERAM->profiles[(unsigned int)scanline_selected_profile * 256 + 250];

  *ptr++ = scanline_custom;
  *ptr++ = scanline_strength;
  *ptr   = scanline_hybrid;

  scanline_selected_profile = value;

  ptr = &SCANLINERAM->profiles[(unsigned int)scanline_selected_profile * 256 + 250];
  scanline_custom   = *ptr++;
  scanline_strength = *ptr++;
  scanline_hybrid   = *ptr;

  return true;
}

static int get_slvalue(void) {
  return SCANLINERAM->profiles[(unsigned int)scanline_selected_profile * 256 + scanline_luminance - 16];
}

static bool set_slvalue(int value) {
  SCANLINERAM->profiles[(unsigned int)scanline_selected_profile * 256 + scanline_luminance - 16] = value;
  return false;
}

/* --- valueitems --- */

static valueitem_t value_profile    = { VALTYPE_SLPROFILE, false, {{ get_slprofile, set_slprofile }} };
static valueitem_t value_custom     = { VALTYPE_BOOL, true,
                                        { .field = { &scanline_custom,    8, 24, VIFLAG_REDRAW }} };
static valueitem_t value_slstrength = { VALTYPE_FIXPOINT1, true,
                                        { .field = { &scanline_strength, 16, 16, VIFLAG_SLUPDATE | VIFLAG_REDRAW }} };
static valueitem_t value_hybrid     = { VALTYPE_FIXPOINT2, true,
                                        { .field = { &scanline_hybrid,   16, 16, VIFLAG_SLUPDATE | VIFLAG_REDRAW }} };
static valueitem_t value_slluma     = { VALTYPE_SLINDEX, true,
                                        { .field = { &scanline_luminance, 8, 24, VIFLAG_REDRAW }} };
static valueitem_t value_slvalue    = { VALTYPE_FIXPOINT1, false, {{ get_slvalue, set_slvalue }} };

/* --- menu definition --- */

static void scanline_draw(menu_t *menu);

static menuitem_t scanline_items[] = {
  { "Scanline profile", &value_profile,    1, 0 },
  { " Full custom",     &value_custom,     2, 0 },
  { " Brightness",      &value_slstrength, 3, 0 },
  { " Hybrid factor",   &value_hybrid,     4, 0 },
  { " Luminance",       &value_slluma,     5, 0 },
  { " Applied factor",  &value_slvalue,    6, MENU_FLAG_DISABLED },
  { "Exit",             NULL,              8, 0 },
};

static menu_t scanline_menu = {
  10, 3,
  25, 10,
  scanline_draw,
  sizeof(scanline_items) / sizeof(*scanline_items),
  scanline_items
};

static void scanline_draw(menu_t *menu) {
  if (scanline_custom) {
    scanline_items[MENUITEM_STRENGTH].flags = MENU_FLAG_DISABLED;
    scanline_items[MENUITEM_HYBRID].flags   = MENU_FLAG_DISABLED;
    scanline_items[MENUITEM_VALUE].flags    = 0;
  } else {
    scanline_items[MENUITEM_STRENGTH].flags = 0;
    scanline_items[MENUITEM_HYBRID].flags   = 0;
    scanline_items[MENUITEM_VALUE].flags    = MENU_FLAG_DISABLED;
  }

  scanline_value = SCANLINERAM->profiles[scanline_selected_profile * 256 + scanline_luminance - 16];

  if (scanline_selected_profile == (video_settings[current_videomode] & VIDEOIF_SET_SLPROFILE_MASK)) {
    osd_putcharat(33, 4, '*', ATTRIB_DIM_BG);
  }
}

void screen_scanlines(void) {
  scanline_selected_profile = (video_settings[current_videomode] & VIDEOIF_SET_SLPROFILE_MASK);
  if (!scanline_selected_profile)
    scanline_selected_profile = 1;

  uint32_t *ptr = &SCANLINERAM->profiles[(unsigned int)scanline_selected_profile * 256 + 250];
  scanline_custom   = *ptr++;
  scanline_strength = *ptr++;
  scanline_hybrid   = *ptr;

  osd_clrscr();
  menu_draw(&scanline_menu);
  menu_exec(&scanline_menu, 0);
  set_slprofile(1); // force write
}
