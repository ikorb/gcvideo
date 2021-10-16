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


   flasher-diag.c: Diagnostics mode for flasher
*/

#include <stdint.h>
#include <stdio.h>
#include "flasher.h"
#include "osd.h"
#include "pad.h"
#include "portdefs.h"
#include "vsync.h"
#include "flasher-diag.h"

static bool capture_line(void) {
  LINECAPTURE->arm = 0;

  while (LINECAPTURE->linedata[0] & LINECAPTURE_FLAG_BUSY) {
    if (pad_buttons & (PAD_START | PAD_Y | IR_BACK)) {
      return false;
    }
  }

  return true;
}

static void print_bitmask(uint8_t bits) {
  if (bits == 0) {
    osd_puts("None    ");
    return;
  }

  for (unsigned int i = 0; i < 8; i++) {
    if (bits & (1 << i)) {
      osd_putchar('0' + i);
    } else {
      osd_putchar(' ');
    }
  }
}

static bool check_signaldiag(void) {
  osd_clearline(7, ATTRIB_DIM_BG);
  osd_putsat(2, 7, "Bits stuck at 0: ");
  print_bitmask(SIGNALDIAG->stuck_0);
  osd_clearline(8, ATTRIB_DIM_BG);
  osd_putsat(2, 8, "Bits stuck at 1: ");
  print_bitmask(SIGNALDIAG->stuck_1);

  osd_clearline(11, ATTRIB_DIM_BG);
  osd_putsat(2, 11, "BClock  ");

  uint32_t active = SIGNALDIAG->audio_active;
  if (active & SIGNALDIAG_ACTIVE_BCLOCK) {
    if (SIGNALDIAG->bclock_glitches == 0) {
      osd_puts("OK");
    } else {
      printf("Glitchy (%d)", SIGNALDIAG->bclock_glitches);
    }
  } else {
    osd_puts("Missing");
  }

  osd_clearline(12, ATTRIB_DIM_BG);
  osd_putsat(2, 12, "LRClock ");
  if (active & SIGNALDIAG_ACTIVE_LRCLOCK) {
    if (SIGNALDIAG->lrclock_glitches == 0) {
      osd_puts("OK");
    } else {
      printf("Glitchy (%d)", SIGNALDIAG->lrclock_glitches);
    }
  } else {
    osd_puts("Missing");
  }

  osd_clearline(13, ATTRIB_DIM_BG);
  osd_putsat(2, 13, "AData   ");
  if (active & SIGNALDIAG_ACTIVE_ADATA) {
    // This signal seems to be more prone to glitches for some reason
    uint32_t glitches = SIGNALDIAG->adata_glitches;
    if (glitches <= 1) {
      osd_puts("OK");
    } else if (glitches < 100) {
      printf("OK (%d)", glitches);
    } else if (glitches < 1000) {
      printf("probably Ok? (%d)", glitches);
    } else {
      printf("Glitchy (%d)", glitches);
    }
  } else {
    osd_puts("Missing or silence");
  }
}

static void check_test_line(void) {
  LINECAPTURE->selected_page = 0;
  set_capture_range(0, 0);

  if (!capture_line()) { // FIXME: Timeout?
    return;
  }

  /* print signaldiag part first, avoids flickering */
  check_signaldiag();

  for (unsigned int i = 0; i < 3 * 220; i++) {
    uint16_t dataword = LINECAPTURE->linedata[i] + 0x1000;
    decodebuffer[i]       = dataword >> 8;
    decodebuffer[i + 660] = dataword & 0xff;
  }

  /* check if the data looks plausible */
  unsigned int matches = 0;
  for (unsigned int i = 0; i < 220; i++) {
    if (decodebuffer[i] == decodebuffer[i + 1 * 220]) matches++;
    if (decodebuffer[i] == decodebuffer[i + 2 * 220]) matches++;
    if (decodebuffer[i] == decodebuffer[i + 3 * 220]) matches++;
    if (decodebuffer[i] == decodebuffer[i + 4 * 220]) matches++;
    if (decodebuffer[i] == decodebuffer[i + 5 * 220]) matches++;
  }

  osd_clearline(5, ATTRIB_DIM_BG);
  osd_gotoxy(2, 5);
  if (matches < (unsigned int)(0.7 * 220 * 5)) {
    osd_puts("No test pattern, results are unreliable");
  } else if (matches != 220 * 5) {
    printf("%3d mismatches found, maybe crosstalk?", 220 * 5 - matches);
  } else {
    osd_puts("Test pattern detected");
  }

  uint8_t mismatches = 0;
  for (unsigned int i = 0; i < 220; i++) {
    for (unsigned int j = 0; j < 6; j++) {
      mismatches |= (decodebuffer[j * 220 + i] ^ (i + 16));
    }
  }

  osd_clearline(9, ATTRIB_DIM_BG);
  osd_putsat(2, 9, "Unexpected bits: ");
  print_bitmask(mismatches);
}

void flasher_diag(void) {
  osd_clrscr();
  for (unsigned int i = 2; i <= 14; i++) {
    osd_clearline(i, ATTRIB_DIM_BG);
  }
  osd_putsat(14, 3, "Diagnostics mode");

  while (1) {
    if (pad_buttons & (PAD_START | PAD_Y | IR_BACK)) {
      break;
    }

    check_test_line();
  }

  pad_clear(PAD_ALL);
}
