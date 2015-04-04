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


   vsync.c: System tick and video mode change detection

*/

#include "pad.h"
#include "portdefs.h"
#include "vsync.h"

volatile tick_t tick_counter;

static uint32_t prev_xres;
static uint32_t prev_yres;
static uint32_t prev_flags;

void vsync_handler(void) {
  /* read current input video mode*/
  uint32_t cur_xres  = VIDEOIF->xres;
  uint32_t cur_yres  = VIDEOIF->yres;
  uint32_t cur_flags = VIDEOIF->flags;

  /* update tick counter */
  if (cur_flags & VIDEOIF_FLAG_PAL) {
    tick_counter += TICKS_PER_VSYNC_PAL;
  } else {
    tick_counter += TICKS_PER_VSYNC_NTSC;
  }

  /* check if input video mode has changed */
  if (cur_xres  != prev_xres ||
      cur_yres  != prev_yres ||
      cur_flags != prev_flags) {
    pad_set_irq(PAD_VIDEOCHANGE);

    prev_xres  = cur_xres;
    prev_yres  = cur_yres;
    prev_flags = cur_flags;
  }
}
