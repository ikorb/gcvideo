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

enum {
  MENUITEM_OSDSET = MODESET_COMMON_MENUITEM_COUNT,
  MENUITEM_PICTURESET,
  MENUITEM_OUTPUTSET,
  MENUITEM_VIEWALL,
  MENUITEM_ADVANCED,
  MENUITEM_STORE,
  MENUITEM_ABOUT,
  MENUITEM_EXIT
};

static menuitem_t mainmenu_items[];

/* --- menu items --- */

static menuitem_t mainmenu_items[] = {
  { "Linedoubler",            &modeset_value_linedoubler, 2, 0 }, // 0
  { "Scanlines",              &modeset_value_scanlines,   3, 0 }, // 1
  { " Scanline strength",     &modeset_value_slstrength,  4, 0 }, // 2
  { " Scanlines on",          &modeset_value_sleven,      5, 0 }, // 3
  { " Alternating scanlines", &modeset_value_slalt,       6, 0 }, // 4
  { "OSD settings...",        NULL,                       8, 0 }, // 5
  { "Picture settings...",    NULL,                       9, 0 }, // 6
  { "Output settings...",     NULL,                      10, 0 }, // 7
  { "View all modes...",      NULL,                      11, 0 }, // 8
  { "Advanced settings...",   NULL,                      12, 0 }, // 9
  { "Store settings",         NULL,                      14, 0 }, // 10
  { "About...",               NULL,                      15, 0 }, // 11
  { "Exit",                   NULL,                      16, 0 }, // 12
};

static void mainmenu_draw(menu_t *menu);

#define MENU_POS_X  7
#define MENU_POS_Y  7
#define MENU_SIZE_X 31
#define MENU_SIZE_Y 19

#define LOGO_POS_X  16
#define LOGO_POS_Y  3
#define LOGO_SIZE_X 13
#define LOGO_SIZE_Y 4

static menu_t mainmenu = {
  MENU_POS_X,  MENU_POS_Y,
  MENU_SIZE_X, MENU_SIZE_Y,
  mainmenu_draw,
  sizeof(mainmenu_items) / sizeof(*mainmenu_items),
  mainmenu_items
};

/* --- menu functions --- */

static void mainmenu_draw(menu_t *menu) {
  modeset_draw(menu);

  /* draw the logo */
  osd_fillbox(LOGO_POS_X, LOGO_POS_Y, LOGO_SIZE_X, LOGO_SIZE_Y, ' ' | ATTRIB_DIM_BG);
  osd_drawborder(LOGO_POS_X, LOGO_POS_Y, LOGO_SIZE_X, LOGO_SIZE_Y);
  osd_gotoxy(LOGO_POS_X + 2, LOGO_POS_Y + 1);
  osd_puts("\x0c\x0d\x0e\x0f\x10\x11\x12\x13\x14");
  osd_gotoxy(LOGO_POS_X + 2, LOGO_POS_Y + 2);
  osd_puts("\x15\x16\x17\x18\x19\x1a\x1b\x1c\x1d");

  /* draw the two video mode lines */
  osd_gotoxy(MENU_POS_X + MENU_SIZE_X - 17, MENU_POS_Y + MENU_SIZE_Y - 3);
  osd_puts("In : ");
  print_resolution();
  osd_gotoxy(MENU_POS_X + MENU_SIZE_X - 17, MENU_POS_Y + MENU_SIZE_Y - 2);

  uint32_t outputlines = video_out_lines[current_videomode];
  bool interlaced = false;

  if (current_videomode <= VIDMODE_576i &&
      (video_settings[current_videomode] & VIDEOIF_SET_LD_ENABLE))
    outputlines *= 2;

  if (outputlines & 1) {
    outputlines *= 2;
    interlaced   = true;
  }

  printf("Out: 720x%3d%c%d",
         outputlines & ~3,
         interlaced  ? 'i' : 'p',
         (current_videomode & 1) ? 50 : 60);
}

void screen_mainmenu(void) {
  int current_item = 0;

  while (1) {
    modeset_mode = current_videomode;

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

    case MENUITEM_PICTURESET:
      screen_picturesettings();
      break;

    case MENUITEM_OUTPUTSET:
      screen_outputsettings();
      break;

    case MENUITEM_VIEWALL:
      screen_allmodes();
      break;

    case MENUITEM_ADVANCED:
      screen_advanced();
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

      settings_save();

      osd_gotoxy(15, 14);
      osd_puts("Settings saved");

      /* wait until all controller buttons are released */
      pad_wait_for_release();
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
