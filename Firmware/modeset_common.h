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


   modeset_common.h: Common parts of the video settings menus

*/

#ifndef MODESET_COMMON_H
#define MODESET_COMMON_H

#include <stdbool.h>
#include "menu.h"
#include "settings.h"

/* positions are assumed to be fixed for now */
enum {
  MENUITEM_LINEDOUBLER,
  MENUITEM_SLPROFILE,
  MENUITEM_SLEVEN,
  MENUITEM_SLALT,
  MODESET_COMMON_MENUITEM_COUNT
};

/* evil global variable */
extern video_mode_t modeset_mode;

/* valueitems */
extern valueitem_t modeset_value_slprofile;
extern valueitem_t modeset_value_sleven;
extern valueitem_t modeset_value_slalt;
extern valueitem_t modeset_value_linedoubler;

/* draw function */
void modeset_draw(menu_t *menu);

#endif
