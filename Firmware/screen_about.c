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
#include "menu.h"
#include "osd.h"
#include "pad.h"
#include "portdefs.h"
#include "screens.h"
#include "settings.h"
#include "spiflash.h"

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

void screen_about(void) {
  osd_clrscr();

  /* draw about-box */
  osd_fillbox(10, 10, 25, 9, ' ' | ATTRIB_DIM_BG);
  osd_drawborder(10, 10, 25, 9);
  osd_setattr(true, false);
  if (MODE_WII) {
    if (DUAL_OUT) {
      osd_putsat(13, 11, "WiiVideo Dual v" VERSION);
    } else {
      osd_putsat(14, 11, "WiiVideo DVI v" VERSION);
    }

    if (VIDEOIF->flags & VIDEOIF_FLAG_MODE_WII) {
      osd_putsat(17, 12, "in Wii mode");
    } else {
      osd_putsat(17, 12, "in GC mode");
    }

  } else {
    if (DUAL_OUT) {
      osd_putsat(14, 11, "GCVideo Dual v" VERSION);
    } else {
      osd_putsat(14, 11, "GCVideo DVI v" VERSION);
    }
  }
  osd_putsat(12, 13, "Copyright \013 2015-2020");
  osd_putsat(16, 14, "by Ingo Korb");
  osd_putsat(15, 15, "ingo@akana.de");
  osd_gotoxy(14, 17);
  printf("FlashID %02x%02x%02x%02x",
         flash_chip_id[0], flash_chip_id[1],
         flash_chip_id[2], flash_chip_id[3]);

  /* wait until all buttons are released */
  pad_wait_for_release();

  /* now wait for any button press */
  while (!(pad_buttons & PAD_ALL))
    if (pad_buttons & PAD_VIDEOCHANGE)
      return;
  pad_clear(PAD_ALL);
}
