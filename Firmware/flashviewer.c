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


   flashviewer.c: Flash memory hexdump viewer
*/

#include <stdint.h>
#include <stdio.h>
#include "flasher.h"
#include "osd.h"
#include "pad.h"
#include "spiflash.h"
#include "flashviewer.h"

static void dump_memory(int32_t address) {
  osd_clrscr();
  osd_puts("\n Flash memory dump tool\n");

  spiflash_read_block(decodebuffer, address, 16 * 8);
  uint8_t* bufptr = decodebuffer;

  for (unsigned int line = 0; line < 16; line++) {
    printf(" %05x: ", address);
    for (unsigned int byte = 0; byte < 8; byte++) {
      printf("%02x ", bufptr[byte]);
    }

    osd_putchar('|');
    for (unsigned int byte = 0; byte < 8; byte++) {
      if (*bufptr >= 32 && *bufptr < 127) {
        osd_putchar(*bufptr);
      } else {
        osd_putchar('.');
      }
      bufptr++;
    }
    osd_puts("|\n");
    address += 8;
  }
}

void flash_viewer(void) {
  int32_t address = 0;
  dump_memory(address);

  while (1) {
    if (pad_buttons) {
      if (pad_buttons & (PAD_START | IR_BACK)) {
        break;
      }

      if (pad_buttons & PAD_VIDEOCHANGE) {
        break;
      }

      if (pad_buttons & (PAD_LEFT | IR_LEFT)) {
        address -= 0x80;
        if (address < 0) {
          address = 0;
        }
      }

      if (pad_buttons & (PAD_RIGHT | IR_RIGHT)) {
        address += 0x80;
        if (address > 0x7ff80) {
          address = 0x7ff80;
        }
      }

      if (pad_buttons & (PAD_UP | IR_UP)) {
        address -= 0x1000;
        if (address < 0) {
          address = 0;
        }
      }

      if (pad_buttons & (PAD_DOWN | IR_DOWN)) {
        address += 0x1000;
        if (address >= 0x7f000) {
          address = 0x7f000;
        }
      }

      if (pad_buttons & (PAD_X | IR_OK)) {
        address = 0x30000;
      }

      if (pad_buttons & PAD_Y) {
        address = 0x70000;
      }

      pad_clear(PAD_ALL);
      dump_memory(address);
    }
  }
}
