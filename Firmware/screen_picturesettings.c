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


   screen_picturesettings.c: Screen for image adjustments

*/

#include <stdbool.h>
#include <stddef.h>
#include "colormatrix.h"
#include "menu.h"
#include "osd.h"
#include "pad.h"
#include "portdefs.h"
#include "screens.h"
#include "settings.h"

enum {
  MENUITEM_BRIGHTNESS,
  MENUITEM_CONTRAST,
  MENUITEM_SATURATION,
  MENUITEM_XPOS,
  MENUITEM_YPOS,
  MENUITEM_RESET,
  MENUITEM_SAVEEXIT,
  MENUITEM_CANCEL
};

/* --- getters and setters --- */

static valueitem_t value_brightness = { VALTYPE_SBYTE_127, true,
                                        { .field = { &picture_brightness, 8, 24, VIFLAG_SBYTE | VIFLAG_COLORMATRIX }} };
static valueitem_t value_contrast   = { VALTYPE_SBYTE_127, true,
                                        { .field = { &picture_contrast,   8, 24, VIFLAG_SBYTE | VIFLAG_COLORMATRIX }} };
static valueitem_t value_saturation = { VALTYPE_SBYTE_127, true,
                                        { .field = { &picture_saturation, 8, 24, VIFLAG_SBYTE | VIFLAG_COLORMATRIX }} };
static valueitem_t value_xpos       = { VALTYPE_SBYTE_127, true,
                                        { .field = { &screen_x_shift, 8, 24, VIFLAG_SBYTE }} };
static valueitem_t value_ypos       = { VALTYPE_SBYTE_127, true,
                                        { .field = { &screen_y_shift, 8, 24, VIFLAG_SBYTE }} };


/* --- menu definition --- */

static menuitem_t pictureset_items[] = {
  { "Brightness",       &value_brightness, 1, 0 }, // 0
  { "Contrast",         &value_contrast,   2, 0 }, // 1
  { "Saturation",       &value_saturation, 3, 0 }, // 2
  { "X Position",       &value_xpos,       4, 0 }, // 3
  { "Y Position",       &value_ypos,       5, 0 }, // 4
  { "Reset",            NULL,              6, 0 }, // 5
  { "Save and Exit",    NULL,              8, 0 }, // 6
  { "Cancel",           NULL,              9, 0 }, // 7
};

static menu_t pictureset_menu = {
  9, 3,
  26, 11,
  NULL,
  sizeof(pictureset_items) / sizeof(*pictureset_items),
  pictureset_items
};

void screen_picturesettings(void) {
  int current_item = 0;

  osd_clrscr();

  int8_t prev_xshift     = screen_x_shift;
  int8_t prev_yshift     = screen_y_shift;
  int8_t prev_brightness = picture_brightness;
  int8_t prev_contrast   = picture_contrast;
  int8_t prev_saturation = picture_saturation;

  bool do_reblank = video_settings_global & VIDEOIF_SET_ENABLEREBLANK;
  bool do_resync  = video_settings_global & VIDEOIF_SET_ENABLERESYNC;

  if (do_reblank && do_resync) {
    pictureset_items[MENUITEM_XPOS].flags = 0;
    pictureset_items[MENUITEM_YPOS].flags = 0;
  } else {
    pictureset_items[MENUITEM_XPOS].flags = MENU_FLAG_DISABLED;
    pictureset_items[MENUITEM_YPOS].flags = MENU_FLAG_DISABLED;
  }

  while (1) {
    menu_draw(&pictureset_menu);
    current_item = menu_exec(&pictureset_menu, current_item);

    switch (current_item) {
    case MENU_ABORT:
    case MENUITEM_CANCEL:
      screen_x_shift     = prev_xshift;
      screen_y_shift     = prev_yshift;
      picture_brightness = prev_brightness;
      picture_contrast   = prev_contrast;
      picture_saturation = prev_saturation;
      update_colormatrix();
      return;

    case MENUITEM_SAVEEXIT:
      return;

    case MENUITEM_RESET:
      screen_x_shift     = 0;
      screen_y_shift     = 0;
      picture_brightness = 0;
      picture_contrast   = 0;
      picture_saturation = 0;
      update_colormatrix();
      break;

    default:
      break;
    }
  }
}
