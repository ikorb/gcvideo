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


   osd.c: Simple text mode interface - no scrolling, no Y-wrapping

*/

#include <stdbool.h>
#include <stdint.h>
#include "portdefs.h"
#include "osd.h"

#define BOXCHAR_TOPLEFT  0x01
#define BOXCHAR_TOP      0x06
#define BOXCHAR_TOPRIGHT 0x02
#define BOXCHAR_LEFT     0x08
#define BOXCHAR_RIGHT    0x07
#define BOXCHAR_BOTLEFT  0x03
#define BOXCHAR_BOT      0x05
#define BOXCHAR_BOTRIGHT 0x04

static unsigned int cursor_x, cursor_y;
static volatile uint32_t *writeptr;
static unsigned int current_attr;

static void update_writeptr(void) {
  writeptr = OSDRAM->data + cursor_x + OSD_CHARS_PER_LINE * cursor_y;
}

void osd_init(void) {
  osd_clrscr();
  current_attr = ATTRIB_DIM_BG;
}

void osd_clrscr(void) {
  for (unsigned int i = 0; i < sizeof(OSDRAM->data) / sizeof(OSDRAM->data[0]); i++) {
    OSDRAM->data[i] = ' ';
  }

  cursor_x = 0;
  cursor_y = 0;
  update_writeptr();
}

void osd_clearline(unsigned int y, unsigned int attr) {
  for (unsigned int i = 0; i < OSD_CHARS_PER_LINE; i++) {
    OSDRAM->data[i + y * OSD_CHARS_PER_LINE] = ' ' | attr;
  }
}

void osd_putchar(const char c) {
  if (c == '\n') {
    cursor_x = 0;
    cursor_y++;
    if (cursor_y >= OSD_LINES_ON_SCREEN)
      cursor_y = 0;
    update_writeptr();
  } else {
    *writeptr++ = c | current_attr;
    cursor_x++;
    if (cursor_x == OSD_CHARS_PER_LINE) {
      cursor_x = 0;
      cursor_y++;
      if (cursor_y >= OSD_LINES_ON_SCREEN) {
        cursor_y = 0;
        update_writeptr();
      }
    }
  }
}

void osd_putcharat(unsigned int xpos, unsigned int ypos, const char c, unsigned int attr) {
  OSDRAM->data[xpos + OSD_CHARS_PER_LINE * ypos] = attr | c;
}

void osd_puts(const char *str) {
  while (*str)
    osd_putchar(*str++);
}

void osd_putsat(unsigned int xpos, unsigned int ypos, const char *str) {
  osd_gotoxy(xpos, ypos);
  while (*str)
    osd_putchar(*str++);
}

void osd_gotoxy(unsigned int x, unsigned int y) {
  cursor_x = x;
  cursor_y = y;
  update_writeptr();
}

void osd_setattr(bool dim_background, bool dim_text) {
  current_attr = 0;
  if (dim_background)
    current_attr = ATTRIB_DIM_BG;
  if (dim_text)
    current_attr |= ATTRIB_DIM_TEXT;
}

void osd_fillbox(unsigned int xpos, unsigned int ypos,
                 unsigned int xsize, unsigned int ysize, uint32_t ch) {
  for (unsigned int y = 0; y < ysize; y++) {
    volatile uint32_t *ptr = OSDRAM->data + xpos + OSD_CHARS_PER_LINE * (ypos + y);
    for (unsigned int x = 0; x < xsize; x++)
      *ptr++ = ch;
  }
}

void osd_drawborder(unsigned int xpos, unsigned int ypos,
                    unsigned int xsize, unsigned int ysize) {
  volatile uint32_t *ptr1 = OSDRAM->data + xpos + OSD_CHARS_PER_LINE * ypos;
  volatile uint32_t *ptr2 = OSDRAM->data + xpos + OSD_CHARS_PER_LINE * (ypos + ysize - 1);

  /* horizontal edges and corners */
  *ptr1++ = BOXCHAR_TOPLEFT;
  *ptr2++ = BOXCHAR_BOTLEFT;
  for (unsigned int x = 1; x < xsize - 1; x++) {
    *ptr1++ = BOXCHAR_TOP;
    *ptr2++ = BOXCHAR_BOT;
  }
  *ptr1 = BOXCHAR_TOPRIGHT;
  *ptr2 = BOXCHAR_BOTRIGHT;

  /* vertical edges */
  ptr1 = OSDRAM->data + OSD_CHARS_PER_LINE * (ypos + 1) + xpos;
  ptr2 = OSDRAM->data + OSD_CHARS_PER_LINE * (ypos + 1) + xpos + xsize - 1;
  for (unsigned int y = 1; y < ysize - 1; y++) {
    *ptr1 = BOXCHAR_LEFT;
    *ptr2 = BOXCHAR_RIGHT;
    ptr1 += OSD_CHARS_PER_LINE;
    ptr2 += OSD_CHARS_PER_LINE;
  }
}
