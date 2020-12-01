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


   menu-lite.c: Text mode menus, feature-reduced version

*/

#include <stdio.h>
#include "osd.h"
#include "pad.h"
#include "utils.h"
#include "menu-lite.h"

#define MENUMARKER_LEFT  9
#define MENUMARKER_RIGHT 10

/* (un)draw marker on a menu item */
static void mark_item(menu_t *menu, unsigned int item, char ch) {
  osd_putcharat(menu->xpos + 1, menu->ypos + item + 1, ch, ATTRIB_DIM_BG);
}


void menu_draw(menu_t *menu) {
  const menuitem_t *items = menu->items;
  unsigned int i;

  /* draw the menu */
  osd_fillbox(menu->xpos, menu->ypos, menu->xsize, menu->ysize, ' ' | ATTRIB_DIM_BG);
  osd_drawborder(menu->xpos, menu->ypos, menu->xsize, menu->ysize);
  osd_setattr(true, false);

  for (i = 0; i < menu->entries; i++) {
    osd_gotoxy(menu->xpos + 2, menu->ypos + i + 1);
    osd_puts(items[i].text);
  }
}


int menu_exec(menu_t *menu, unsigned int initial_item) {
  unsigned int cur_item = initial_item;

  /* mark initial menuitem */
  osd_setattr(true, false);
  mark_item(menu, cur_item, MENUMARKER_LEFT);

  /* wait until all buttons are released */
  pad_wait_for_release();

  /* handle input */
  while (1) {
    /* wait for input */
    while (!pad_buttons) ;

    unsigned int curbtns = pad_buttons;

    /* selection movement with up/down */
    if (curbtns & (PAD_UP | IR_UP)) {
      mark_item(menu, cur_item, ' ');

      if (cur_item > 0)
        cur_item--;
      else
        cur_item = menu->entries - 1;

      mark_item(menu, cur_item, MENUMARKER_LEFT);

      pad_clear(PAD_UP | PAD_LEFT | PAD_RIGHT |
                IR_UP  | IR_LEFT  | IR_RIGHT); // prioritize up/down over left/right
    }

    if (curbtns & (PAD_DOWN | IR_DOWN)) {
      mark_item(menu, cur_item, ' ');

      cur_item++;
      if (cur_item >= menu->entries)
        cur_item = 0;

      mark_item(menu, cur_item, MENUMARKER_LEFT);

      pad_clear(PAD_DOWN | PAD_LEFT | PAD_RIGHT |
                IR_DOWN  | IR_LEFT  | IR_RIGHT); // prioritize up/down over left/right
    }

    /* selection with X */
    if (curbtns & (PAD_X | IR_OK)) {
      pad_clear(PAD_X | IR_OK);
      mark_item(menu, cur_item, ' ');
      return cur_item;
    }

    /* abort with Y */
    if (curbtns & (PAD_Y | IR_BACK)) {
      pad_clear(PAD_Y | IR_BACK);
      mark_item(menu, cur_item, ' ');
      return MENU_ABORT;
    }

    /* clear unused buttons */
    pad_clear(PAD_START | PAD_Z | PAD_L | PAD_R | PAD_A | PAD_B);
  }
}
