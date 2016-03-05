/* GCVideo DVI Firmware

   Copyright (C) 2015-2016, Ingo Korb <ingo@akana.de>
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


   screen_idle.c: Idle "screen" with occasional resolution popups

*/

#include <stdbool.h>
#include <stddef.h>
#include <stdio.h>
#include "menu.h"
#include "osd.h"
#include "pad.h"
#include "portdefs.h"
#include "screens.h"
#include "settings.h"

#define RESBOX_TIME (5 * HZ)
#define RESBOX_X    28
#define RESBOX_Y    2
#define RESBOX_XS   12
#define RESBOX_YS   3

void screen_idle(void) {
  tick_t resbox_timeout = 0;
  bool   resbox_active  = false;

  osd_clrscr();

  while (1) {
    tick_t now = getticks();

    /* check for menu hotkey */
    if ((pad_buttons & (PAD_L | PAD_R | PAD_X | PAD_Y)) == (PAD_L | PAD_R | PAD_X | PAD_Y) &&
        time_after(now, pad_last_change + HZ)) {
      if (pad_buttons & PAD_START)
        /* restore defaults */
        settings_init();
      return;
    }

    /* check for video mode change */
    if (pad_buttons & PAD_VIDEOCHANGE) {
      pad_clear(PAD_VIDEOCHANGE);

      /* update video settings */
      current_videomode = detect_inputmode();
      VIDEOIF->settings = video_settings[current_videomode];

      /* print resolution box */
      if (resbox_enabled) {
        resbox_timeout = now + RESBOX_TIME;
        resbox_active  = true;

        osd_drawborder(RESBOX_X, RESBOX_Y, RESBOX_XS, RESBOX_YS);
        osd_gotoxy(RESBOX_X + 1, RESBOX_Y + 1);
 
        print_resolution();
      }
    } else if (resbox_active && time_after(now, resbox_timeout)) {
      resbox_active = false;
      osd_fillbox(RESBOX_X, RESBOX_Y, RESBOX_XS, RESBOX_YS, ' ');
    }
  }
}
