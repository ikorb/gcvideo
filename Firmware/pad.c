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


   pad.c: Gamepad reader and button event generator

*/

#include "portdefs.h"
#include "vsync.h"
#include "pad.h"

/* button repeat settings */
// FIXME: run-time configurable?
#define INITIAL_DELAY     (HZ / 2)
#define REPEAT_DELAY_SLOW (HZ / 10)
#define REPEAT_DELAY_FAST  1
#define REPEAT_SLOWCOUNT   20

#define PAD_SCAN_MASK   0xfffff0f0UL
#define PAD_SCAN_PREFIX 0x01000000UL
#define PAD_BUTTON_MASK 0x3efe0000UL

static tick_t   prev_padtick;
static uint32_t prev_data;        // for debouncing
static uint32_t prev_buttons;     // for repeat
static tick_t   next_repeat_tick;
static uint32_t repeat_count;

static uint32_t paddata[3];

volatile tick_t   pad_last_change;
volatile uint32_t pad_buttons;

void pad_wait_for_release(void) {
  /* wait until all controller buttons are released */
  while (pad_buttons & PAD_ALL_GC)
    if (pad_buttons & PAD_VIDEOCHANGE)
      return;

  /* clear IR remote buttons too */
  pad_clear(PAD_ALL);
}

void pad_handler(void) {
  /* copy data to local array */
  for (unsigned int word = 0; word < 3; word++) {
    uint32_t tmp = 0;

    for (unsigned int byte = 0; byte < 4; byte++) {
      tmp = (tmp << 8) | (PADREADER->data & 0xff);

      while (PADREADER->bits & PADREADER_BITS_SHIFTFLAG) ;
    }

    paddata[word] = tmp;
  }

  /* check for a known packet */
  if (PADREADER->bits < 90 ||
      (paddata[0] & PAD_SCAN_MASK) != PAD_SCAN_PREFIX)
    return;

  tick_t now = getticks();

  /* check only once per frame */
  if (now == prev_padtick)
    return;

  prev_padtick = now;

  uint32_t curdata = paddata[1] & PAD_BUTTON_MASK;

  /* accept only if same as last time */
  if (curdata != prev_data) {
    prev_data = curdata;
    return;
  }

  /* update buttons */
  curdata = (curdata >> 17) & PAD_ALL_GC;
  if (prev_buttons != curdata) {
    /* buttons have changed */
    pad_last_change  = now;
    prev_buttons     = curdata;
    pad_buttons      = (pad_buttons & ~PAD_ALL_GC) | curdata;
    next_repeat_tick = now + INITIAL_DELAY;
    repeat_count     = REPEAT_SLOWCOUNT;
    return;
  }

  /* use key repeat only for up/down/left/right */
  if ((curdata & (PAD_UP | PAD_DOWN | PAD_LEFT | PAD_RIGHT)) == 0)
    return;

  /* no change, check for key repeat */
  if (time_after(now, next_repeat_tick)) {
    pad_set_irq(curdata);

    if (repeat_count) {
      repeat_count--;
      next_repeat_tick += REPEAT_DELAY_SLOW;
    } else {
      next_repeat_tick += REPEAT_DELAY_FAST;
    }
  }
}
