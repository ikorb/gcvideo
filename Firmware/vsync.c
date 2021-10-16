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


   vsync.c: System tick and other once-per-frame things

*/

#include <stdbool.h>
#include "pad.h"
#include "portdefs.h"
#include "reblanker.h"
#include "settings.h"
#include "vsync.h"

#define IRBUTTON_MAX_FRAMES  255
#define IRBUTTON_MIN_FRAMES  2
#define IRBUTTON_LONG_FRAMES 60

volatile tick_t tick_counter;

static uint32_t prev_irbutton = IRRX_BUTTON;
static uint8_t  irbutton_count;

void vsync_handler(void) {
  /* update tick counter */
  if (VIDEOIF->flags & VIDEOIF_FLAG_IN_PAL) {
    tick_counter += TICKS_PER_VSYNC_PAL;
  } else {
    tick_counter += TICKS_PER_VSYNC_NTSC;
  }

  update_reblanker();

  /* read IR button */
  uint32_t cur_irbutton = IRRX->pulsedata & IRRX_BUTTON;

  if (cur_irbutton != prev_irbutton) {
    /* at edge */
    if (cur_irbutton) {
      /* release */
      if (irbutton_count > IRBUTTON_MIN_FRAMES && irbutton_count < IRBUTTON_LONG_FRAMES) {
        pad_set_irq(IRBUTTON_SHORT);
      }

    } else {
      /* press */
      irbutton_count = 0;
    }

  } else if (!cur_irbutton) {
    /* held */
    if (irbutton_count < IRBUTTON_MAX_FRAMES)
      irbutton_count++;

    if (irbutton_count == IRBUTTON_LONG_FRAMES) {
      pad_set_irq(IRBUTTON_LONG);
    }
  }

  prev_irbutton = cur_irbutton;
}
