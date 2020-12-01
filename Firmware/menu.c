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


   menu.c: Text mode menus

*/

#include <stdio.h>
#include "osd.h"
#include "pad.h"
#include "utils.h"
#include "menu.h"

#define MENUMARKER_LEFT  9
#define MENUMARKER_RIGHT 10

typedef enum {
  UPDATE_DECREMENT,
  UPDATE_INCREMENT
} updatetype_t;

typedef struct {
  int16_t lower;
  int16_t upper;
} cliprange_t;

static const cliprange_t clipranges[] = {
  [ VALTYPE_BOOL ]         = {    0,     1 },
  [ VALTYPE_EVENODD ]      = {    0,     1 },
  [ VALTYPE_RGBMODE ]      = {    0,     2 },
  [ VALTYPE_BYTE ]         = {    0,   255 },
  [ VALTYPE_SBYTE_99 ]     = {   -99,   99 },
  [ VALTYPE_SBYTE_127 ]    = {  -128,  127 },
};

static const uint8_t value_widths[] = {
  [ VALTYPE_BOOL ]         = 6,
  [ VALTYPE_EVENODD ]      = 6,
  [ VALTYPE_RGBMODE ]      = 7,
  [ VALTYPE_BYTE ]         = 6,
  [ VALTYPE_SBYTE_99 ]     = 6,
  [ VALTYPE_SBYTE_127 ]    = 6,
};

/* (un)draw marker on a menu item */
static void mark_item(menu_t *menu, unsigned int item, char ch) {
  osd_putcharat(menu->xpos + 1, menu->ypos + menu->items[item].line, ch, ATTRIB_DIM_BG);
}


static void print_value(menu_t *menu, unsigned int itemnum) {
  int value = menu->items[itemnum].value->get();
  const valuetype_t type = menu->items[itemnum].value->type;

  osd_gotoxy(menu->xpos + menu->xsize - value_widths[type],
             menu->ypos + menu->items[itemnum].line);
  switch (type) {
  case VALTYPE_BOOL:
    if (value)
      osd_puts("  On");
    else
      osd_puts(" Off");
    break;

  case VALTYPE_EVENODD:
    if (value)
      osd_puts("Even");
    else
      osd_puts(" Odd");
    break;

  case VALTYPE_RGBMODE:
    switch (value) {
    case 0:
      osd_puts("YPbPr");
      break;

    case 1:
      osd_puts("  RGB");
      break;

    default:
      osd_puts(" RGsB");
      break;
    }
    break;

  case VALTYPE_BYTE:
  case VALTYPE_SBYTE_99:
    printf("%4d", value);
    break;

  case VALTYPE_SBYTE_127:
    if (value == 0)
      printf("   0");
    else
      printf("%+4d", value);
    break;
  }
}


/* update a valueitem */
static void update_value(menu_t *menu, unsigned int itemid, updatetype_t upd) {
  valueitem_t *value = menu->items[itemid].value;
  int curval = value->get();

  if (upd == UPDATE_INCREMENT) {
    curval++;
  } else {
    curval--;
  }

  if (value->type == VALTYPE_BOOL ||
      value->type == VALTYPE_EVENODD) {
    /* bool always toggles */
    curval = value->get();
  }

  clip_value(&curval, clipranges[value->type].lower, clipranges[value->type].upper);

  if (value->set(curval)) {
    /* need a full redraw */
    menu_draw(menu);
    mark_item(menu, itemid, MENUMARKER_LEFT);
  } else {
    /* just update the changed value */
    print_value(menu, itemid);
  }
}

void menu_draw(menu_t *menu) {
  const menuitem_t *items = menu->items;
  unsigned int i;

  /* draw the menu */
  osd_fillbox(menu->xpos, menu->ypos, menu->xsize, menu->ysize, ' ' | ATTRIB_DIM_BG);
  osd_drawborder(menu->xpos, menu->ypos, menu->xsize, menu->ysize);

  /* run the callback, it might update the item flags */
  if (menu->drawcallback)
    menu->drawcallback(menu);

  for (i = 0; i < menu->entries; i++) {
    if (items[i].flags & MENU_FLAG_DISABLED)
      osd_setattr(true, true);
    else
      osd_setattr(true, false);

    /* print item */
    osd_gotoxy(menu->xpos + 2, menu->ypos + items[i].line);
    osd_puts(items[i].text);

    if (items[i].value) {
      print_value(menu, i);
    }
  }
}


int menu_exec(menu_t *menu, unsigned int initial_item) {
  const menuitem_t *items = menu->items;
  unsigned int cur_item = initial_item;

  /* ensure the initial item is valid */
  while (items[cur_item].flags & MENU_FLAG_DISABLED) {
    cur_item++;
    if (cur_item >= menu->entries)
      cur_item = 0;
  }

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

      do {
        if (cur_item > 0)
          cur_item--;
        else
          cur_item = menu->entries - 1;
      } while (items[cur_item].flags & MENU_FLAG_DISABLED);

      mark_item(menu, cur_item, MENUMARKER_LEFT);

      pad_clear(PAD_UP | PAD_LEFT | PAD_RIGHT |
                IR_UP  | IR_LEFT  | IR_RIGHT); // prioritize up/down over left/right
    }

    if (curbtns & (PAD_DOWN | IR_DOWN)) {
      mark_item(menu, cur_item, ' ');

      do {
        cur_item++;
        if (cur_item >= menu->entries)
          cur_item = 0;
      } while (items[cur_item].flags & MENU_FLAG_DISABLED);

      mark_item(menu, cur_item, MENUMARKER_LEFT);

      pad_clear(PAD_DOWN | PAD_LEFT | PAD_RIGHT |
                IR_DOWN  | IR_LEFT  | IR_RIGHT); // prioritize up/down over left/right
    }

    /* value change with left/right */
    if ((curbtns & (PAD_LEFT | IR_LEFT)) && items[cur_item].value) {
      update_value(menu, cur_item, UPDATE_DECREMENT);
      pad_clear(PAD_LEFT | IR_LEFT);
    }

    if ((curbtns & (PAD_RIGHT | IR_RIGHT)) && items[cur_item].value) {
      update_value(menu, cur_item, UPDATE_INCREMENT);
      pad_clear(PAD_RIGHT | IR_RIGHT);
    }

    /* selection with X */
    if (curbtns & (PAD_X | IR_OK)) {
      pad_clear(PAD_X | IR_OK);
      if (!items[cur_item].value) {
        /* no value attached, can exit from here */
        mark_item(menu, cur_item, ' ');
        return cur_item;

      } else {
        /* modify value */
        valueitem_t *vi = items[cur_item].value;

        switch (vi->type) {
        case VALTYPE_BOOL:
        case VALTYPE_EVENODD:
          update_value(menu, cur_item, UPDATE_INCREMENT); // bool always toggles
          break;

        default:
          break;
        }
      }
    }

    /* abort with Y */
    if (curbtns & (PAD_Y | IR_BACK)) {
      pad_clear(PAD_Y | IR_BACK);
      mark_item(menu, cur_item, ' ');
      return MENU_ABORT;
    }

    /* exit on video mode change (simplifies things) */
    if (curbtns & PAD_VIDEOCHANGE)
      return MENU_ABORT;

    /* clear unused buttons */
    pad_clear(PAD_START | PAD_Z | PAD_L | PAD_R | PAD_A | PAD_B);
  }
}
