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


   osd.h: Simple text mode interface

*/

#ifndef OSD_H
#define OSD_H

#include <stdbool.h>
#include <stdint.h>

#define ATTRIB_DIM_BG   0x80
#define ATTRIB_DIM_TEXT 0x100

void osd_init(void);
void osd_clrscr(void);
void osd_putchar(const char c);
void osd_putcharat(unsigned int xpos, unsigned int ypos, const char c, unsigned int attr);
void osd_puts(const char *str);
void osd_putsat(unsigned int xpos, unsigned int ypos, const char *str);
void osd_gotoxy(unsigned int x, unsigned int y);
void osd_setattr(bool dim_background, bool dim_text);
void osd_fillbox(unsigned int xpos, unsigned int ypos,
                 unsigned int xsize, unsigned int ysize, uint32_t ch);
void osd_drawborder(unsigned int xpos, unsigned int ypos,
                    unsigned int xsize, unsigned int ysize);
void osd_puthex(uint32_t value, unsigned int line);

#endif
