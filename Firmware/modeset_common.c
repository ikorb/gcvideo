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


   modeset_common.c: Common parts of the video settings menus

*/

#include <stdbool.h>
#include <stdio.h>
#include "osd.h"
#include "portdefs.h"
#include "modeset_common.h"

video_mode_t modeset_mode;

int modeset_get_scanlines(void)   { return video_settings[modeset_mode] & VIDEOIF_SET_SL_ENABLE;        }
int modeset_get_slstrength(void)  { return video_settings[modeset_mode] & VIDEOIF_SET_SL_STRENGTH_MASK; }
int modeset_get_sleven(void)      { return video_settings[modeset_mode] & VIDEOIF_SET_SL_EVEN;          }
int modeset_get_slalt(void)       { return video_settings[modeset_mode] & VIDEOIF_SET_SL_ALTERNATE;     }
int modeset_get_linedoubler(void) { return video_settings[modeset_mode] & VIDEOIF_SET_LD_ENABLE;        }

bool modeset_set_scanlines(int value) {
  if (value)
    video_settings[modeset_mode] |= VIDEOIF_SET_SL_ENABLE;
  else
    video_settings[modeset_mode] &= ~VIDEOIF_SET_SL_ENABLE;

  if (current_videomode == modeset_mode)
    VIDEOIF->settings = video_settings[modeset_mode];
  return true;
}

bool modeset_set_slstrength(int value) {
  video_settings[modeset_mode] = (video_settings[modeset_mode] & ~VIDEOIF_SET_SL_STRENGTH_MASK) | value;

  if (current_videomode == modeset_mode)
    VIDEOIF->settings = video_settings[modeset_mode];
  return false;
}

bool modeset_set_sleven(int value) {
  if (value)
    video_settings[modeset_mode] |=  VIDEOIF_SET_SL_EVEN;
  else
    video_settings[modeset_mode] &= ~VIDEOIF_SET_SL_EVEN;

  if (current_videomode == modeset_mode)
    VIDEOIF->settings = video_settings[modeset_mode];
  return false;
}

bool modeset_set_slalt(int value) {
  if (value)
    video_settings[modeset_mode] |=  VIDEOIF_SET_SL_ALTERNATE;
  else
    video_settings[modeset_mode] &= ~VIDEOIF_SET_SL_ALTERNATE;

  if (current_videomode == modeset_mode)
    VIDEOIF->settings = video_settings[modeset_mode];
  return false;
}

bool modeset_set_linedoubler(int value) {
  if (value)
    video_settings[modeset_mode] |= VIDEOIF_SET_LD_ENABLE;
  else
    video_settings[modeset_mode] &= ~VIDEOIF_SET_LD_ENABLE;

  if (current_videomode == modeset_mode)
    VIDEOIF->settings = video_settings[modeset_mode];
  return true;
}

valueitem_t modeset_value_scanlines = {
  modeset_get_scanlines, modeset_set_scanlines, VALTYPE_BOOL
};

valueitem_t modeset_value_slstrength = {
  modeset_get_slstrength, modeset_set_slstrength, VALTYPE_BYTE
};

valueitem_t modeset_value_sleven = {
  modeset_get_sleven, modeset_set_sleven, VALTYPE_EVENODD
};

valueitem_t modeset_value_slalt = {
  modeset_get_slalt, modeset_set_slalt, VALTYPE_BOOL
};

valueitem_t modeset_value_linedoubler = {
  modeset_get_linedoubler, modeset_set_linedoubler, VALTYPE_BOOL
};

void modeset_draw(menu_t *menu) {
  /* update the item-enable flags based on current settings */
  if (modeset_mode <= VIDMODE_576i && !(video_settings[modeset_mode] & VIDEOIF_SET_LD_ENABLE)) {
    menu->items[MENUITEM_SCANLINES ].flags = MENU_FLAG_DISABLED;
    menu->items[MENUITEM_SLSTRENGTH].flags = MENU_FLAG_DISABLED;
    menu->items[MENUITEM_SLEVEN    ].flags = MENU_FLAG_DISABLED;
    menu->items[MENUITEM_SLALT     ].flags = MENU_FLAG_DISABLED;
  } else {
    menu->items[MENUITEM_SCANLINES ].flags = 0;
    menu->items[MENUITEM_SLSTRENGTH].flags = 0;
    menu->items[MENUITEM_SLEVEN    ].flags = 0;
    menu->items[MENUITEM_SLALT     ].flags = 0;

    if (video_settings[modeset_mode] & VIDEOIF_SET_SL_ENABLE) {
      menu->items[MENUITEM_SLSTRENGTH].flags = 0;
      menu->items[MENUITEM_SLEVEN    ].flags = 0;
      menu->items[MENUITEM_SLALT     ].flags = 0;
    } else {
      menu->items[MENUITEM_SLSTRENGTH].flags = MENU_FLAG_DISABLED;
      menu->items[MENUITEM_SLEVEN    ].flags = MENU_FLAG_DISABLED;
      menu->items[MENUITEM_SLALT     ].flags = MENU_FLAG_DISABLED;
    }
  }

  if (modeset_mode != VIDMODE_480i &&
      modeset_mode != VIDMODE_576i &&
      menu->items[MENUITEM_SLALT].flags == 0)
    /* alternating needs a valid field flag and thus works only in interlaced modes */
    menu->items[MENUITEM_SLALT].flags = MENU_FLAG_DISABLED;

  if (modeset_mode >= VIDMODE_480p)
    menu->items[MENUITEM_LINEDOUBLER].flags = MENU_FLAG_DISABLED;
  else
    menu->items[MENUITEM_LINEDOUBLER].flags = 0;

  /* header */
  osd_gotoxy(menu->xpos + 9, menu->ypos + 1);
  osd_setattr(true, false);
  printf("%s settings", mode_names[modeset_mode]);
}
