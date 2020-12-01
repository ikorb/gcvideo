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


   screen_about.c: About box

*/

#include <stdbool.h>
#include <stddef.h>
#include <stdio.h>
#include <string.h>
#include "icap.h"
#include "menu.h"
#include "osd.h"
#include "pad.h"
#include "portdefs.h"
#include "screens.h"
#include "settings.h"

/* helper symbols for slightly better code readability */
#ifdef CONSOLE_WII
#  define MODE_WII 1
#else
#  define MODE_WII 0
#endif

#ifdef OUTPUT_DUAL
#  define DUAL_OUT 1
#else
#  define DUAL_OUT 0
#endif

enum {
  MENUITEM_UPDATEFW,
  MENUITEM_EXIT
};

static void about_draw(menu_t *menu);

static menuitem_t about_items[] = {
  { "Update Firmware", NULL, 7, 0 },
  { "Back",            NULL, 8, 0 },
};

static menu_t about_menu = {
  10, 9,
  25, 10,
  about_draw,
  sizeof(about_items) / sizeof(*about_items),
  about_items
};

static void about_draw(menu_t *menu) {
  int ver_len = strlen(VERSION);

  if (MODE_WII) {
    if (DUAL_OUT) {
      osd_putsat(11 + (23 - (15 + ver_len)) / 2, 10, "WiiVideo Dual v" VERSION);
    } else { //                                       123456789012345
      osd_putsat(11 + (23 - (14 + ver_len)) / 2, 10, "WiiVideo DVI v" VERSION);
    }

    if (VIDEOIF->flags & VIDEOIF_FLAG_MODE_WII) {
      osd_putsat(17, 11, "in Wii mode");
    } else {
      osd_putsat(17, 11, "in GC mode");
    }

  } else {
    if (DUAL_OUT) {
      osd_putsat(11 + (23 - (14 + ver_len)) / 2, 10, "GCVideo Dual v" VERSION);
    } else { //                                       12345678901234
      osd_putsat(11 + (23 - (13 + ver_len)) / 2, 10, "GCVideo DVI v" VERSION);
    }
  }
  osd_putsat(12, 12, "Copyright \013 2015-2020");
  osd_putsat(16, 13, "by Ingo Korb");
  osd_putsat(15, 14, "ingo@akana.de");
}

void screen_about(void) {
  osd_clrscr();

  menu_draw(&about_menu);
  if (menu_exec(&about_menu, MENUITEM_EXIT) == MENUITEM_UPDATEFW) {
    /* reboot to flasher */
    icap_init();
    icap_write_register(ICAP_REG_GENERAL1, 0x0001); // boot from address 1 instead of 0 as marker
    icap_write_register(ICAP_REG_GENERAL2, 0x0300); // top byte is SPI read command
    icap_write_register(ICAP_REG_MODE_REG, ICAP_MODE_NEW_MODE| ICAP_MODE_BOOT_SPI | ICAP_MODE_RESERVED);
    icap_write_register(ICAP_REG_CMD, ICAP_CMD_REBOOT);
    icap_noop();
    icap_noop();
  }
}
