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


   portdefs.h: Hardware interface definitions

*/

#ifndef PORTDEFS_H
#define PORTDEFS_H

#include <stdint.h>

#ifdef __cplusplus
  #define __I volatile
#else
  #define __I volatile const
#endif
#define __O  volatile
#define __IO volatile

/* --- IRQ controller --- */

typedef struct {
  union { // 0
    __I uint32_t Flags;
    __O uint32_t Enable;
  };
  __IO  uint32_t TempDisable;
} IRQController_TypeDef;

#define IRQ_FLAG_VSYNC    (1U<<0)
#define IRQ_FLAG_PAD      (1U<<1)
#define IRQ_FLAG_ANY      (1U<<31)  // read
#define IRQ_FLAG_GLOBALEN (1U<<31)  // write

/* --- Video Interface --- */

typedef struct {
  __I  uint32_t xres;
  __I  uint32_t yres;
  __IO uint32_t flags;
  __IO uint32_t settings;
  __IO uint32_t osd_bg;
  __IO uint32_t audio_volume;
} VideoInterface_TypeDef;

#define VIDEOIF_FLAG_PROGRESSIVE (1<<0)
#define VIDEOIF_FLAG_PAL         (1<<1)
#define VIDEOIF_FLAG_31KHZ       (1<<2)

#define VIDEOIF_SET_SL_STRENGTH_MASK 0xff
#define VIDEOIF_SET_SL_ENABLE        (1<<8)
#define VIDEOIF_SET_SL_EVEN          (1<<9)
#define VIDEOIF_SET_SL_ALTERNATE     (1<<10)
#define VIDEOIF_SET_LD_ENABLE        (1<<11)
#define VIDEOIF_SET_DISABLE_OUTPUT   (1<<12)
#define VIDEOIF_SET_CABLEDETECT      (1<<13)
#define VIDEOIF_SET_RGBLIMITED       (1<<14)
#define VIDEOIF_SET_DVIENHANCED      (1<<15)
#define VIDEOIF_SET_169              (1<<16)

#define VIDEOIF_OSDBG_ALPHA_MASK     0xff0000
#define VIDEOIF_OSDBG_ALPHA_SHIFT    16
#define VIDEOIF_OSDBG_TINTCB_MASK    0x00ff00
#define VIDEOIF_OSDBG_TINTCB_SHIFT   8
#define VIDEOIF_OSDBG_TINTCR_MASK    0x0000ff
#define VIDEOIF_OSDBG_TINTCR_SHIFT   0

/* --- PadReader --- */

typedef struct {
  __I  uint32_t data;
  __IO uint32_t bits;    // writing clears the interrupt flag
} PadReader_TypeDef;

#define PADREADER_BITS_SHIFTFLAG 0x80

/* --- SPI --- */

typedef struct {
  __IO uint32_t data;
  __IO uint32_t flags;
} SPI_TypeDef;

#define SPI_FLAG_SSEL (1 << 0)
#define SPI_FLAG_BUSY (1 << 1)

/* --- OSD RAM --- */

typedef struct {
  __IO uint32_t data[2048];
} OSDRAM_TypeDef;

/* --- mixing it all together --- */

#define OSDRAM_BASE        ((uint32_t)0xffffc000UL)
#define PERIPH_BASE        ((uint32_t)0xfffff000UL)
#define IRQController_BASE (PERIPH_BASE)
#define VIDEOIF_BASE       (PERIPH_BASE + 0x100)
#define PADREADER_BASE     (PERIPH_BASE + 0x200)
#define SPI_BASE           (PERIPH_BASE + 0x300)

#define IRQController ((IRQController_TypeDef *)IRQController_BASE)
#define VIDEOIF       ((VideoInterface_TypeDef *)VIDEOIF_BASE)
#define PADREADER     ((PadReader_TypeDef *)PADREADER_BASE)
#define OSDRAM        ((OSDRAM_TypeDef *)OSDRAM_BASE)
#define SPI           ((SPI_TypeDef *)SPI_BASE)

#endif
