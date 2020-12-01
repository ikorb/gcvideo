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


   portdefs-flasher.h: Hardware interface definitions for flash update firmware

*/

#ifndef PORTDEFS_FLASHER_H
#define PORTDEFS_FLASHER_H

#include <stdint.h>

#ifdef __cplusplus
  #define __I volatile
#else
  #define __I volatile const
#endif
#define __O  volatile
#define __IO volatile

#define HAVE_SPI_HWCRC

/* --- Line capture RAM --- */

typedef struct {
  union {
    __I uint32_t linedata[256 * 4];
    struct {
      __O uint32_t arm;
      __O uint32_t dummy[256 * 3 - 1];
      __O uint32_t needed_lines[255];
      __O uint32_t selected_page;
    };
  };
} LINECAPTURE_TypeDef;

#define LINECAPTURE_FLAG_BUSY (1 << 31)

/* --- mixing it all together --- */

#define LINECAPTURE_BASE ((uint32_t)0xffffe000UL)

#define LINECAPTURE ((LINECAPTURE_TypeDef *)LINECAPTURE_BASE)

#endif
