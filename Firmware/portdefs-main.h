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


   portdefs.h: Hardware interface definitions for main firmware

*/

#ifndef PORTDEFS_MAIN_H
#define PORTDEFS_MAIN_H

#include <stdint.h>

#ifdef __cplusplus
  #define __I volatile
#else
  #define __I volatile const
#endif
#define __O  volatile
#define __IO volatile

/* --- InfoFrame RAM --- */

typedef struct {
  __IO uint32_t data[2048];
} IFRAM_TypeDef;

/* --- Scanline RAM --- */

#define SCANLINERAM_ENTRIES (256 * 4)

typedef struct {
  // profile 0 is unused (scanlines hardware-disabled)
  // no IO declaration because it is never written to by hardware
  /*__IO*/ uint32_t profiles[SCANLINERAM_ENTRIES];
} SCANLINERAM_TypeDef;

/* --- mixing it all together --- */

#define IFRAM_BASE       ((uint32_t)0xffff8000UL)
#define SCANLINERAM_BASE ((uint32_t)0xffffe000UL)

#define IFRAM       ((IFRAM_TypeDef *)IFRAM_BASE)
#define SCANLINERAM ((SCANLINERAM_TypeDef *)SCANLINERAM_BASE)

#endif
