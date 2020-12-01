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
#include "menu.h"

#define MENUMARKER_LEFT  9
#define MENUMARKER_RIGHT 10

typedef enum {
  UPDATE_DECREMENT,
  UPDATE_INCREMENT
} updatetype_t;

/* (un)draw marker on a menu item */
static void mark_item(menu_t *menu, unsigned int item, char ch) {
  osd_putcharat(menu->xpos + 1, menu->ypos + menu->items[item].line + 1, ch, ATTRIB_DIM_BG);
}

/* (un)draw marker on a value item */
static void mark_value(menu_t *menu, unsigned int item, char ch) {
  osd_putcharat(menu->xpos + menu->xsize - 7, menu->ypos + menu->items[item].line + 1,
                ch, ATTRIB_DIM_BG);
}


static void print_value(menu_t *menu, unsigned int itemnum) {
  int value = menu->items[itemnum].value->get();

  osd_gotoxy(menu->xpos + menu->xsize - 6,
             menu->ypos + menu->items[itemnum].line + 1);
  switch (menu->items[itemnum].value->type) {
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
    osd_gotoxy(menu->xpos + menu->xsize - 7,
               menu->ypos + menu->items[itemnum].line + 1);
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

  switch (value->type) {
  case VALTYPE_BOOL:
  case VALTYPE_EVENODD:
    /* bool always toggles */
    curval = !curval;
    break;

  case VALTYPE_RGBMODE:
    if (upd == UPDATE_INCREMENT) {
      if (curval < 2)
        curval++;
    } else {
      if (curval > 0)
        curval--;
    }
    break;

  case VALTYPE_BYTE:
    if (upd == UPDATE_INCREMENT) {
      if (curval < 255)
        curval++;
    } else {
      if (curval > 0)
        curval--;
    }
    break;

  case VALTYPE_SBYTE_99:
    if (upd == UPDATE_INCREMENT) {
      if (curval < 99)
        curval++;
    } else {
      if (curval > -99)
        curval--;
    }
    break;

    case VALTYPE_SBYTE_127:
    if (upd == UPDATE_INCREMENT) {
      if (curval < 127)
        curval++;
    } else {
      if (curval > -128)
        curval--;
    }
    break;
  }

  if (value->set(curval)) {
    /* need a full redraw */
    menu_draw(menu);
    mark_item(menu, itemid, MENUMARKER_LEFT);
  } else {
    /* just update the changed value */
    print_value(menu, itemid);
  }
}


/* submenu for changing numeric values */
static void value_submenu(menu_t *menu, unsigned int itemid) {
  mark_value(menu, itemid, MENUMARKER_LEFT);

  while (1) {
    /* wait for input */
    while (!pad_buttons) ;

    unsigned int curbtns = pad_buttons;

    /* value change */
    if (curbtns & (PAD_LEFT | IR_LEFT)) {
      update_value(menu, itemid, UPDATE_DECREMENT);
      pad_clear(PAD_LEFT | PAD_UP | PAD_DOWN |
                IR_LEFT  | IR_UP  | IR_DOWN); // prioritize left/right
    }

    if (curbtns & (PAD_RIGHT | IR_RIGHT)) {
      update_value(menu, itemid, UPDATE_INCREMENT);
      pad_clear(PAD_RIGHT | PAD_UP | PAD_DOWN |
                IR_RIGHT  | IR_UP  | IR_DOWN); // prioritize left/right
    }

    /* exit with X/Y */
    if (curbtns & (PAD_X | PAD_Y | IR_OK | IR_BACK))
      break;

    /* video mode change is ignored */
  }
  pad_clear(PAD_ALL);

  mark_value(menu, itemid, ' ');
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
    osd_gotoxy(menu->xpos + 2, menu->ypos + items[i].line + 1);
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

        case VALTYPE_RGBMODE:
        case VALTYPE_BYTE:
        case VALTYPE_SBYTE_99:
        case VALTYPE_SBYTE_127:
          mark_item(menu, cur_item, ' ');
          value_submenu(menu, cur_item);
          mark_item(menu, cur_item, MENUMARKER_LEFT);
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
