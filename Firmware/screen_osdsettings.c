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


   screen_osdsettings.c: Menu screen for OSD-related settings

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
  MENUITEM_RESBOX,
  MENUITEM_ALPHA,
  MENUITEM_TINTCB,
  MENUITEM_TINTCR,
  MENUITEM_IRCONFIG,
  MENUITEM_EXIT
};

/* --- valueitems --- */

static valueitem_t value_resbox  = { VALTYPE_BOOL,     true,
                                     { .field = { &resbox_enabled, 8, 24, 0 }} };
static valueitem_t value_alpha   = { VALTYPE_BYTE,     true,
                                     { .field = { &osdbg_settings, 32, VIDEOIF_OSDBG_ALPHA_SHIFT,  VIFLAG_UPDATE_VIDEOIF }} };
static valueitem_t value_tint_cb = { VALTYPE_SBYTE_99, true,
                                     { .field = { &osdbg_settings,  8, VIDEOIF_OSDBG_TINTCB_SHIFT,
                                                  VIFLAG_UPDATE_VIDEOIF | VIFLAG_SBYTE }} };
static valueitem_t value_tint_cr = { VALTYPE_SBYTE_99, true,
                                     { .field = { &osdbg_settings,  8, VIDEOIF_OSDBG_TINTCR_SHIFT,
                                                  VIFLAG_UPDATE_VIDEOIF | VIFLAG_SBYTE }} };

/* --- menu definition --- */

static menuitem_t osdset_items[] = {
  { "Mode Popup",       &value_resbox,   1, 0 }, // 0
  { "BG Transparency",  &value_alpha,    2, 0 }, // 1
  { "BG Tint Blue",     &value_tint_cb,  3, 0 }, // 2
  { "BG Tint Red",      &value_tint_cr,  4, 0 }, // 3
  { "IR Key Config...", NULL,            5, 0 }, // 4
  { "Exit",             NULL,            7, 0 }, // 5
};

static menu_t osdset_menu = {
  11, 11,
  23, 9,
  NULL,
  sizeof(osdset_items) / sizeof(*osdset_items),
  osdset_items
};

void screen_osdsettings(void) {
  int current_item = 0;

  while (1) {
    osd_clrscr();
    menu_draw(&osdset_menu);
    current_item = menu_exec(&osdset_menu, current_item);

    switch (current_item) {
      case MENU_ABORT:
      case MENUITEM_EXIT:
      default:
        return;

      case MENUITEM_IRCONFIG:
        screen_irconfig(true);
        break;
    }
  }
}
