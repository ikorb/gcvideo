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


   screen_mainmenu.c: Main menu screen

*/

#include <stdbool.h>
#include <stddef.h>
#include <stdio.h>
#include "menu.h"
#include "modeset_common.h"
#include "osd.h"
#include "pad.h"
#include "portdefs.h"
#include "screens.h"
#include "settings.h"
#include "spiflash.h"

// 0-4 are from modeset_common.h
#define MENUITEM_OSDSET      5
#define MENUITEM_OTHERSET    6
#define MENUITEM_VIEWALL     7
#define MENUITEM_STORE       8
#define MENUITEM_ABOUT       9
#define MENUITEM_EXIT        10

static menuitem_t mainmenu_items[];

/* --- getters and setters --- */

static int get_scanlines(void)   { return video_settings[current_videomode] & VIDEOIF_SET_SL_ENABLE;        }
static int get_slstrength(void)  { return video_settings[current_videomode] & VIDEOIF_SET_SL_STRENGTH_MASK; }
static int get_sleven(void)      { return video_settings[current_videomode] & VIDEOIF_SET_SL_EVEN;          }
static int get_slalt(void)       { return video_settings[current_videomode] & VIDEOIF_SET_SL_ALTERNATE;     }
static int get_linedoubler(void) { return video_settings[current_videomode] & VIDEOIF_SET_LD_ENABLE;        }

static bool set_scanlines(int value) {
  if (value)
    video_settings[current_videomode] |= VIDEOIF_SET_SL_ENABLE;
  else
    video_settings[current_videomode] &= ~VIDEOIF_SET_SL_ENABLE;

  VIDEOIF->settings = video_settings[current_videomode];
  return true;
}

static bool set_slstrength(int value) {
  video_settings[current_videomode] = (video_settings[current_videomode] & ~VIDEOIF_SET_SL_STRENGTH_MASK) | value;
  VIDEOIF->settings = video_settings[current_videomode];
  return false;
}

static bool set_sleven(int value) {
  if (value)
    video_settings[current_videomode] |=  VIDEOIF_SET_SL_EVEN;
  else
    video_settings[current_videomode] &= ~VIDEOIF_SET_SL_EVEN;

  VIDEOIF->settings = video_settings[current_videomode];
  return false;
}

static bool set_slalt(int value) {
  if (value)
    video_settings[current_videomode] |=  VIDEOIF_SET_SL_ALTERNATE;
  else
    video_settings[current_videomode] &= ~VIDEOIF_SET_SL_ALTERNATE;

  VIDEOIF->settings = video_settings[current_videomode];
  return false;
}

static bool set_linedoubler(int value) {
  if (value)
    video_settings[current_videomode] |= VIDEOIF_SET_LD_ENABLE;
  else
    video_settings[current_videomode] &= ~VIDEOIF_SET_LD_ENABLE;

  VIDEOIF->settings = video_settings[current_videomode];
  return true;
}

static valueitem_t value_scanlines = {
  get_scanlines, set_scanlines, VALTYPE_BOOL
};

static valueitem_t value_slstrength = {
  get_slstrength, set_slstrength, VALTYPE_BYTE
};

static valueitem_t value_sleven = {
  get_sleven, set_sleven, VALTYPE_EVENODD
};

static valueitem_t value_slalt = {
  get_slalt, set_slalt, VALTYPE_BOOL
};

static valueitem_t value_linedoubler = {
  get_linedoubler, set_linedoubler, VALTYPE_BOOL
};

/* --- menu items --- */

static menuitem_t mainmenu_items[] = {
  { "Linedoubler",            &value_linedoubler, 1, 0 }, // 0
  { "Scanlines",              &value_scanlines,   2, 0 }, // 1
  { " Scanline strength",     &value_slstrength,  3, 0 }, // 2
  { " Scanlines on",          &value_sleven,      4, 0 }, // 3
  { " Alternating scanlines", &value_slalt,       5, 0 }, // 4
  { "OSD settings...",        NULL,               7, 0 }, // 5
  { "Other settings...",      NULL,               8, 0 }, // 6
  { "View all modes...",      NULL,               9, 0 }, // 7
  { "Store settings",         NULL,              11, 0 }, // 8
  { "About...",               NULL,              12, 0 }, // 9
  { "Exit",                   NULL,              13, 0 }, // 10
};

static void mainmenu_draw(menu_t *menu);

static menu_t mainmenu = {
  7, 6,
  31, 18,
  mainmenu_draw,
  sizeof(mainmenu_items) / sizeof(*mainmenu_items),
  mainmenu_items
};

/* --- menu functions --- */

static void mainmenu_draw(menu_t *menu) {
  /* update the item-enable flags based on current settings */
  if (current_videomode <= VIDMODE_576i && !(video_settings[current_videomode] & VIDEOIF_SET_LD_ENABLE)) {
    mainmenu_items[MENUITEM_SCANLINES ].flags = MENU_FLAG_DISABLED;
    mainmenu_items[MENUITEM_SLSTRENGTH].flags = MENU_FLAG_DISABLED;
    mainmenu_items[MENUITEM_SLEVEN    ].flags = MENU_FLAG_DISABLED;
    mainmenu_items[MENUITEM_SLALT     ].flags = MENU_FLAG_DISABLED;
  } else {
    mainmenu_items[MENUITEM_SCANLINES ].flags = 0;
    mainmenu_items[MENUITEM_SLSTRENGTH].flags = 0;
    mainmenu_items[MENUITEM_SLEVEN    ].flags = 0;
    mainmenu_items[MENUITEM_SLALT     ].flags = 0;

    if (video_settings[current_videomode] & VIDEOIF_SET_SL_ENABLE) {
      mainmenu_items[MENUITEM_SLSTRENGTH].flags = 0;
      mainmenu_items[MENUITEM_SLEVEN    ].flags = 0;
      mainmenu_items[MENUITEM_SLALT     ].flags = 0;
    } else {
      mainmenu_items[MENUITEM_SLSTRENGTH].flags = MENU_FLAG_DISABLED;
      mainmenu_items[MENUITEM_SLEVEN    ].flags = MENU_FLAG_DISABLED;
      mainmenu_items[MENUITEM_SLALT     ].flags = MENU_FLAG_DISABLED;
    }
  }

  if (current_videomode != VIDMODE_480i &&
      current_videomode != VIDMODE_576i &&
      mainmenu_items[MENUITEM_SLALT].flags == 0)
    /* alternating needs a valid field flag and thus works only in interlaced modes */
    mainmenu_items[MENUITEM_SLALT].flags = MENU_FLAG_DISABLED;

  if (current_videomode >= VIDMODE_480p)
    mainmenu_items[MENUITEM_LINEDOUBLER].flags = MENU_FLAG_DISABLED;
  else
    mainmenu_items[MENUITEM_LINEDOUBLER].flags = 0;

  /* header */
  osd_gotoxy(menu->xpos + 9, menu->ypos + 1);
  osd_setattr(true, false);
  printf("%s settings", mode_names[current_videomode]);

  /* draw the two video mode lines */
  osd_gotoxy(menu->xpos + menu->xsize - 20, menu->ypos + menu->ysize - 3);
  osd_puts("Input : ");
  print_resolution();
  osd_gotoxy(menu->xpos + menu->xsize - 20, menu->ypos + menu->ysize - 2);

  uint32_t outputlines = video_out_lines[current_videomode];
  bool interlaced = false;

  if (current_videomode <= VIDMODE_576i &&
      (video_settings[current_videomode] & VIDEOIF_SET_LD_ENABLE))
    outputlines *= 2;

  if (outputlines & 1) {
    outputlines *= 2;
    interlaced   = true;
  }

  printf("Output: 720x%3d%c%d",
         outputlines & ~3,
         interlaced  ? 'i' : 'p',
         (current_videomode & 1) ? 50 : 60);
}

void screen_mainmenu(void) {
  int current_item = 0;

  while (1) {
    /* (re)draw */
    osd_clrscr();
    menu_draw(&mainmenu);

    /* run */
    current_item = menu_exec(&mainmenu, current_item);

    switch (current_item) {
    case MENU_ABORT:
    case MENUITEM_EXIT:
      return;

    case MENUITEM_OSDSET:
      screen_osdsettings();
      break;

    case MENUITEM_OTHERSET:
      screen_othersettings();
      break;

    case MENUITEM_VIEWALL:
      screen_allmodes();
      break;

    case MENUITEM_ABOUT:
      screen_about();
      break;

    case MENUITEM_STORE:
      osd_clrscr();

      /* show "saving" message because page erase needs 1-3s */
      osd_fillbox(13, 13, 18, 3, ' ' | ATTRIB_DIM_BG);
      osd_drawborder(13, 13, 18, 3);
      osd_gotoxy(15, 14);
      osd_puts("Saving...");

      spiflash_write_settings();

      osd_gotoxy(15, 14);
      osd_puts("Settings saved");

      /* wait until all buttons are released */
      while (pad_buttons & PAD_ALL)
        if (pad_buttons & PAD_VIDEOCHANGE)
          return;

      /* now wait for any button press */
      pad_clear(PAD_ALL);
      while (!(pad_buttons & PAD_ALL))
        if (pad_buttons & PAD_VIDEOCHANGE)
          return;
      pad_clear(PAD_ALL);

      break;

    default:
      break;
    }
  }
}
