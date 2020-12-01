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


   screen_picturesettings.c: Screen for image adjustments

*/

#include <stdbool.h>
#include <stddef.h>
#include "menu.h"
#include "osd.h"
#include "pad.h"
#include "portdefs.h"
#include "screens.h"
#include "settings.h"

#define MENUITEM_BRIGHTNESS 0
#define MENUITEM_CONTRAST   1
#define MENUITEM_SATURATION 2
#define MENUITEM_NEUTRAL    3
#define MENUITEM_EXIT       4

/* --- getters and setters --- */

static int get_brightness(void) { return picture_brightness; }
static int get_contrast(void)   { return picture_contrast;   }
static int get_saturation(void) { return picture_saturation; }

static bool set_brightness(int value) {
  picture_brightness = value;
  update_imagecontrols();
  return false;
}

static bool set_contrast(int value) {
  picture_contrast = value;
  update_imagecontrols();
  return false;
}

static bool set_saturation(int value) {
  picture_saturation = value;
  update_imagecontrols();
  return true;
}

static valueitem_t value_brightness = { get_brightness, set_brightness, VALTYPE_SBYTE_127 };
static valueitem_t value_contrast   = { get_contrast,   set_contrast,   VALTYPE_SBYTE_127 };
static valueitem_t value_saturation = { get_saturation, set_saturation, VALTYPE_SBYTE_127 };

/* --- menu definition --- */

static menuitem_t pictureset_items[] = {
  { "Brightness",       &value_brightness, 1, 0 }, // 0
  { "Contrast",         &value_contrast,   2, 0 }, // 1
  { "Saturation",       &value_saturation, 3, 0 }, // 2
  { "Reset to neutral", NULL,              4, 0 }, // 3
  { "Exit",             NULL,              6, 0 }, // 4
};

static menu_t pictureset_menu = {
  9, 4,
  26, 8,
  NULL,
  sizeof(pictureset_items) / sizeof(*pictureset_items),
  pictureset_items
};

void screen_picturesettings(void) {
  int current_item = 0;

  osd_clrscr();

  while (1) {
    menu_draw(&pictureset_menu);
    current_item = menu_exec(&pictureset_menu, current_item);

    switch (current_item) {
    case MENU_ABORT:
    case MENUITEM_EXIT:
      return;

    case MENUITEM_NEUTRAL:
      picture_brightness = 0;
      picture_contrast   = 0;
      picture_saturation = 0;
      update_imagecontrols();
      break;

    default:
      break;
    }
  }
}
