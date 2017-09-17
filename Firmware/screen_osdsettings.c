/* GCVideo DVI Firmware

   Copyright (C) 2015-2017, Ingo Korb <ingo@akana.de>
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

#define MENUITEM_RESBOX 0
#define MENUITEM_ALPHA  1
#define MENUITEM_TINTCB 2
#define MENUITEM_TINTCR 3
#define MENUITEM_EXIT   4

/* --- getters and setters --- */

static int get_resbox(void)  { return resbox_enabled; }
static int get_alpha(void)   { return ( (osdbg_settings >> VIDEOIF_OSDBG_ALPHA_SHIFT ) & 0xff);               }
static int get_tint_cb(void) { return (((osdbg_settings >> VIDEOIF_OSDBG_TINTCB_SHIFT) & 0xff) ^ 0x80) - 128; }
static int get_tint_cr(void) { return (((osdbg_settings >> VIDEOIF_OSDBG_TINTCR_SHIFT) & 0xff) ^ 0x80) - 128; }

static bool set_resbox(int value) {
  resbox_enabled = !!value;
  return false;
}

static bool set_alpha(int value) {
  osdbg_settings = (osdbg_settings & ~VIDEOIF_OSDBG_ALPHA_MASK) | (value << VIDEOIF_OSDBG_ALPHA_SHIFT);
  VIDEOIF->osd_bg = osdbg_settings;
  return false;
}

static bool set_tint_cb(int value) {
  osdbg_settings = (osdbg_settings & ~VIDEOIF_OSDBG_TINTCB_MASK) | (((value + 128) ^ 0x80) << VIDEOIF_OSDBG_TINTCB_SHIFT);
  VIDEOIF->osd_bg = osdbg_settings;
  return false;
}

static bool set_tint_cr(int value) {
  osdbg_settings = (osdbg_settings & ~VIDEOIF_OSDBG_TINTCR_MASK) | (((value + 128) ^ 0x80) << VIDEOIF_OSDBG_TINTCR_SHIFT);
  VIDEOIF->osd_bg = osdbg_settings;
  return false;
}

static valueitem_t value_resbox      = { get_resbox,   set_resbox,   VALTYPE_BOOL  };
static valueitem_t value_alpha       = { get_alpha,    set_alpha,    VALTYPE_BYTE  };
static valueitem_t value_tint_cb     = { get_tint_cb,  set_tint_cb,  VALTYPE_SBYTE };
static valueitem_t value_tint_cr     = { get_tint_cr,  set_tint_cr,  VALTYPE_SBYTE };

/* --- menu definition --- */

static menuitem_t osdset_items[] = {
  { "Mode popup",      &value_resbox,   0, 0 }, // 0
  { "BG Transparency", &value_alpha,    1, 0 }, // 1
  { "BG Tint Blue",    &value_tint_cb,  2, 0 }, // 2
  { "BG Tint Red",     &value_tint_cr,  3, 0 }, // 3
  { "Exit",            NULL,            5, 0 }, // 4
};

static menu_t osdset_menu = {
  10, 11,
  24, 8,
  NULL,
  sizeof(osdset_items) / sizeof(*osdset_items),
  osdset_items
};

void screen_osdsettings(void) {
  osd_clrscr();
  menu_draw(&osdset_menu);
  menu_exec(&osdset_menu, 0);
}
