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


   main.c: Initialisation and interrupt mux

*/

#include <stdbool.h>
#include <stdio.h>
#include <string.h>
#include "menu.h"
#include "osd.h"
#include "pad.h"
#include "portdefs.h"
#include "screens.h"
#include "settings.h"
#include "spiflash.h"
#include "vsync.h"

#define barrier() asm volatile("" : : : "memory")

/* --- interrupt mux --- */

void irq_handler(void) {
  while (IRQController->Flags & IRQ_FLAG_ANY) {
    if (IRQController->Flags & IRQ_FLAG_VSYNC) {
      vsync_handler();
      VIDEOIF->flags = 0;
    }
    if (IRQController->Flags & IRQ_FLAG_PAD) {
      pad_handler();
      PADREADER->bits = 0;
    }
  }
}

/* --- main --- */

int main(int argc, char **argv) {
  /* initialize interrupt handling */
  VIDEOIF->flags = 0;
  IRQController->Enable = IRQ_FLAG_VSYNC | IRQ_FLAG_PAD | IRQ_FLAG_GLOBALEN;
  VIDEOIF->settings = VIDEOIF_SET_CABLEDETECT; // temporary during init

  /* run initializations */
  settings_init();
  osd_init();
  spiflash_init();

  VIDEOIF->settings = video_settings[current_videomode];
  VIDEOIF->osd_bg   = osdbg_settings;

  while (1) {
    screen_idle();
    screen_mainmenu();
  }
}
