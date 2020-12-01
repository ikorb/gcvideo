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


   screen_irconfig.c: IR remote configuration screen

*/

#include <string.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdio.h>
#include "irrx.h"
#include "menu.h"
#include "osd.h"
#include "pad.h"
#include "portdefs.h"
#include "screens.h"
#include "settings.h"

static const char* keynames[] = {
  "Up", "Down", "Left", "Right", "Enter", "Back"
};

void screen_irconfig(void) {
  ir_command_t newcmds[NUM_IRCODES];

  osd_clrscr();
  osd_fillbox(6, 8, 32, 13, ' ' | ATTRIB_DIM_BG);
  osd_drawborder(6, 8, 32, 13);

  osd_setattr(true, false);
  osd_putsat(12,  9, "IR Remote key config");
  osd_putsat( 8, 18, "Push key on remote to assign");
  osd_putsat( 8, 19, "or hardware button to cancel");

  ir_gotcommand = 0;

  for (uint8_t btn_idx = 0; btn_idx < NUM_IRCODES; btn_idx++) {
  redo:
    for (uint8_t i = 0; i < NUM_IRCODES; i++) {
      osd_setattr(true, btn_idx != i);
      osd_putsat(17, 11 + i, keynames[i]);
    }

    /* wait for input */
    while (!ir_gotcommand && !(pad_buttons & (IRBUTTON_SHORT | PAD_ALL_GC)))
      ;

    if (pad_buttons & (IRBUTTON_SHORT | PAD_ALL_GC))
      break;

    /* check for duplicate */
    uint32_t command = ir_rawcommand;

    osd_gotoxy(24, 11 + btn_idx);
    osd_setattr(true, false);

    for (uint8_t i = 0; i < btn_idx; i++) {
      if (newcmds[i] == command) {
        printf("Dupe");
        goto redo;
      }
    }

    printf("Ok  ");

    /* store */
    newcmds[btn_idx] = command;
    ir_gotcommand = 0;
  }

  /* check for abort */
  if (pad_buttons & (IRBUTTON_SHORT | PAD_ALL_GC)) {
    pad_clear(PAD_ALL);
    return;
  }

  /* commit new button selections */
  memcpy(ir_codes, newcmds, sizeof(ir_codes));

  pad_clear(PAD_ALL);
}
