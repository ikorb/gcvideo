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


   pad.h: Gamepad reader and button event generator

*/

#ifndef PAD_H
#define PAD_H

#include <stdint.h>
#include "portdefs.h"
#include "vsync.h"

// 17
#define PAD_LEFT  (1 << 0)
#define PAD_RIGHT (1 << 1)
#define PAD_DOWN  (1 << 2)
#define PAD_UP    (1 << 3)
#define PAD_Z     (1 << 4)
#define PAD_R     (1 << 5)
#define PAD_L     (1 << 6)
// 7 is unused
#define PAD_A     (1 << 8)
#define PAD_B     (1 << 9)
#define PAD_X     (1 << 10)
#define PAD_Y     (1 << 11)
#define PAD_START (1 << 12)
// 29

// mask for all GC buttons
#define PAD_ALL_GC ((1 << 13)-1)

// buttons for short and long hardware "IR-Config" button presses
#define IRBUTTON_SHORT (1 << 13)
#define IRBUTTON_LONG  (1 << 14)

// IR remote buttons
#define IR_UP          (1 << 15)
#define IR_DOWN        (1 << 16)
#define IR_LEFT        (1 << 17)
#define IR_RIGHT       (1 << 18)
#define IR_OK          (1 << 19)
#define IR_BACK        (1 << 20)

// mask for all non-synthetic buttions
#define PAD_ALL        ((1 << 21)-1)

// synthetic button, triggered once on every input video mode change
#define PAD_VIDEOCHANGE (1 << 21)

extern volatile uint32_t pad_buttons;
extern volatile tick_t   pad_last_change;

/* these two functions shouldn't be used in an interrupt handler! */
void pad_set(uint32_t which);
void pad_clear(uint32_t which);

/* same functions without disabling IRQ for atomicity */
void pad_set_irq(uint32_t which);
void pad_clear_irq(uint32_t which);

void pad_wait_for_release(void);
void pad_handler(void);

#endif
