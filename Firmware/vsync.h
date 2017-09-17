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


   vsync.h: System tick and video mode change detection

*/

#ifndef TIME_H
#define TIME_H

#include <stdbool.h>

#define HZ 300

#define TICKS_PER_VSYNC_PAL  6
#define TICKS_PER_VSYNC_NTSC 5

typedef unsigned int  tick_t;
typedef   signed int stick_t;

extern volatile tick_t tick_counter;

static inline tick_t getticks(void) { return tick_counter; }

/* returns true if tick a is later than tick b */
/* assumes that they are less than half of the tick_t range apart */
static inline bool time_after(tick_t a, tick_t b) {
  union { tick_t ut; stick_t st; } ticks;
  ticks.ut = a - b;

  return ticks.st > 0;
}

void vsync_handler(void);

#endif
