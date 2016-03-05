/* GCVideo DVI Firmware

   Copyright (C) 2015-2016, Ingo Korb <ingo@akana.de>
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


   modeset_common.h: Common parts of the video settings menus

*/

#ifndef MODESET_COMMON_H
#define MODESET_COMMON_H

#include <stdbool.h>
#include "menu.h"
#include "settings.h"

/* positions are assumed to be fixed for now */
#define MENUITEM_LINEDOUBLER 0
#define MENUITEM_SCANLINES   1
#define MENUITEM_SLSTRENGTH  2
#define MENUITEM_SLEVEN      3
#define MENUITEM_SLALT       4

/* evil global variable */
extern video_mode_t modeset_mode;

/* valueitems */
extern valueitem_t modeset_value_scanlines;
extern valueitem_t modeset_value_slstrength;
extern valueitem_t modeset_value_sleven;
extern valueitem_t modeset_value_slalt;
extern valueitem_t modeset_value_linedoubler;

/* draw function */
void modeset_draw(menu_t *menu);

/* setters and getters */
int  modeset_get_scanlines(void);
int  modeset_get_slstrength(void);
int  modeset_get_sleven(void);
int  modeset_get_slalt(void);
int  modeset_get_linedoubler(void);
bool modeset_set_scanlines(int value);
bool modeset_set_slstrength(int value);
bool modeset_set_sleven(int value);
bool modeset_set_slalt(int value);
bool modeset_set_linedoubler(int value);

#endif
