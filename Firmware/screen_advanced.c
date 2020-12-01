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


   screen_advanced.c: Screen for advanced settings

*/

#include <stdbool.h>
#include <stddef.h>
#include "menu.h"
#include "osd.h"
#include "portdefs.h"
#include "screens.h"

enum {
  MENUITEM_SAMPLERATEHACK,
  MENUITEM_EXIT
};

/* --- valueitems --- */

static valueitem_t value_sampleratehack = { VALTYPE_BOOL, true,
                                            { .field = { NULL, VIDEOIF_BIT_SAMPLERATEHACK, 0, VIFLAG_ALLMODES }} };

/* --- menu definition --- */

static void advanced_draw(menu_t *menu);

static menuitem_t advanced_items[] = {
  { "Sample rate hack",     &value_sampleratehack, 7, 0 },
  { "Exit",                 NULL,                  9, 0 },
};

static menu_t advanced_menu = {
  7, 9,
  31, 11,
  advanced_draw,
  sizeof(advanced_items) / sizeof(*advanced_items),
  advanced_items
};

static void advanced_draw(menu_t *menu) {
#ifdef CONSOLE_WII
  if (VIDEOIF->flags & VIDEOIF_FLAG_MODE_WII) {
    advanced_items[MENUITEM_SAMPLERATEHACK].flags = MENU_FLAG_DISABLED;
  } else {
    advanced_items[MENUITEM_SAMPLERATEHACK].flags = 0;
  }
#endif
}

void screen_advanced(void) {
  osd_clrscr();
  menu_draw(&advanced_menu);
  menu_exec(&advanced_menu, 0);
}
