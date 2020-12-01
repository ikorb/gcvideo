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


   screen_allmodes.c: Per-mode options

*/

#include <stdbool.h>
#include <stddef.h>
#include "menu.h"
#include "modeset_common.h"
#include "osd.h"
#include "pad.h"
#include "portdefs.h"
#include "screens.h"
#include "settings.h"

/* ----- per-mode settings menu ----- */

static menuitem_t modeset_items[] = {
  { "Linedoubler",            &modeset_value_linedoubler, 1, 0 }, // 0
  { "Scanlines",              &modeset_value_scanlines,   2, 0 }, // 1
  { " Scanline strength",     &modeset_value_slstrength,  3, 0 }, // 2
  { " Scanlines on",          &modeset_value_sleven,      4, 0 }, // 3
  { " Alternating scanlines", &modeset_value_slalt,       5, 0 }, // 4
  { "Exit",                   NULL,                       7, 0 }, // 5
};

static menu_t modeset_menu = {
  7, 9,
  31, 10,
  modeset_draw,
  sizeof(modeset_items) / sizeof(*modeset_items),
  modeset_items
};

/* --- menu functions --- */

static void screen_modesettings(video_mode_t mode) {
  modeset_mode = mode;
  osd_clrscr();
  menu_draw(&modeset_menu);
  menu_exec(&modeset_menu, 0);
}



/* ----- mode selection menu ----- */

#define MENUITEM_AM_EXIT     6

static menuitem_t allmodes_items[] = {
  // assumption: Entries use the same item IDs as video_mode_t
  { "240p...", NULL, 0, 0 }, // 0
  { "288p...", NULL, 1, 0 }, // 1
  { "480i...", NULL, 2, 0 }, // 2
  { "576i...", NULL, 3, 0 }, // 3
  { "480p...", NULL, 4, 0 }, // 4
  { "576p...", NULL, 5, 0 }, // 5
  { "Exit",    NULL, 7, 0 }, // 6
};

static menu_t allmodes_menu = {
  15, 9,
  15, 10,
  NULL,
  sizeof(allmodes_items) / sizeof(*allmodes_items),
  allmodes_items
};

void screen_allmodes(void) {
  int current_item = 0;

  while (1) {
    osd_clrscr();
    menu_draw(&allmodes_menu);
    current_item = menu_exec(&allmodes_menu, current_item);

    switch (current_item) {
    case MENU_ABORT:
    case MENUITEM_AM_EXIT:
      return;

    default:
      screen_modesettings(current_item);
      break;
    }
  }
}
