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
  __IO uint32_t TempDisable;
} IRQController_TypeDef;

#define IRQ_FLAG_VSYNC    (1U<<0)
#define IRQ_FLAG_PAD      (1U<<1)
#define IRQ_FLAG_IRRX     (1U<<2)
#define IRQ_FLAG_ANY      (1U<<31)  // read
#define IRQ_FLAG_GLOBALEN (1U<<31)  // write

#define IRQ_TempDisable   (1U<<0)

/* --- Video Interface --- */

typedef struct {
  __I  uint32_t xres;
  __I  uint32_t yres;
  __IO uint32_t flags;
  __IO uint32_t settings;
  __IO uint32_t osd_bg;
  __IO uint32_t audio_volume;
  __IO uint32_t image_controls;
} VideoInterface_TypeDef;

#define VIDEOIF_FLAG_PROGRESSIVE (1<<0)
#define VIDEOIF_FLAG_PAL         (1<<1)
#define VIDEOIF_FLAG_31KHZ       (1<<2)
#define VIDEOIF_FLAG_MODE_WII    (1<<3)
#define VIDEOIF_FLAG_FORCE_YPBPR (1<<4)

#define VIDEOIF_BIT_SL_EVEN          2
#define VIDEOIF_BIT_SL_ALTERNATE     3
#define VIDEOIF_BIT_LD_ENABLE        4
#define VIDEOIF_BIT_DISABLE_OUTPUT   5
#define VIDEOIF_BIT_CABLEDETECT      6
#define VIDEOIF_BIT_RGBLIMITED       7
#define VIDEOIF_BIT_DVIENHANCED      8
#define VIDEOIF_BIT_169              9
#define VIDEOIF_BIT_ANALOGMODE       10
#define VIDEOIF_BIT_ANALOGSOG        11
#define VIDEOIF_BIT_SAMPLERATEHACK   12

#define VIDEOIF_SET_SL_EVEN          (1<<VIDEOIF_BIT_SL_EVEN)
#define VIDEOIF_SET_SL_ALTERNATE     (1<<VIDEOIF_BIT_SL_ALTERNATE)
#define VIDEOIF_SET_LD_ENABLE        (1<<VIDEOIF_BIT_LD_ENABLE)
#define VIDEOIF_SET_DISABLE_OUTPUT   (1<<VIDEOIF_BIT_DISABLE_OUTPUT)
#define VIDEOIF_SET_CABLEDETECT      (1<<VIDEOIF_BIT_CABLEDETECT)
#define VIDEOIF_SET_RGBLIMITED       (1<<VIDEOIF_BIT_RGBLIMITED)
#define VIDEOIF_SET_DVIENHANCED      (1<<VIDEOIF_BIT_DVIENHANCED)
#define VIDEOIF_SET_169              (1<<VIDEOIF_BIT_169)
#define VIDEOIF_SET_ANALOGMODE       (1<<VIDEOIF_BIT_ANALOGMODE)
#define VIDEOIF_SET_ANALOGSOG        (1<<VIDEOIF_BIT_ANALOGSOG)
#define VIDEOIF_SET_SAMPLERATEHACK   (1<<VIDEOIF_BIT_SAMPLERATEHACK)

#define VIDEOIF_SET_SLPROFILE_MASK   3

#define VIDEOIF_SET_ANALOG_MASK      (3 << VIDEOIF_BIT_ANALOGMODE)
#define VIDEOIF_SET_ANALOG_SHIFT     VIDEOIF_BIT_ANALOGMODE

#define VIDEOIF_OSDBG_ALPHA_MASK     0xff0000
#define VIDEOIF_OSDBG_ALPHA_SHIFT    16
#define VIDEOIF_OSDBG_TINTCB_MASK    0x00ff00
#define VIDEOIF_OSDBG_TINTCB_SHIFT   8
#define VIDEOIF_OSDBG_TINTCR_MASK    0x0000ff
#define VIDEOIF_OSDBG_TINTCR_SHIFT   0

#define VIDEOIF_IMGCTL_SATURATION_MASK  0x1ff0000
#define VIDEOIF_IMGCTL_SATURATION_SHIFT 16
#define VIDEOIF_IMGCTL_BRIGHTNESS_MASK  0x000ff00
#define VIDEOIF_IMGCTL_BRIGHTNESS_SHIFT 8
#define VIDEOIF_IMGCTL_CONTRAST_MASK    0x00000ff
#define VIDEOIF_IMGCTL_CONTRAST_SHIFT   0

#define VIDEOIF_IMGCTL_NEUTRAL 0x00800080

/* --- PadReader --- */

typedef struct {
  __I  uint32_t data;
  __IO uint32_t bits;    // writing clears the interrupt flag
} PadReader_TypeDef;

#define PADREADER_BITS_SHIFTFLAG 0x80

/* --- Scanline RAM --- */

#define SCANLINERAM_ENTRIES (256 * 4)

typedef struct {
  // profile 0 is unused (scanlines hardware-disabled)
  // no IO declaration because it is never written to by hardware
  /*__IO*/ uint32_t profiles[SCANLINERAM_ENTRIES];
} SCANLINERAM_TypeDef;

/* --- SPI --- */

typedef struct {
  __IO uint32_t data;
  __IO uint32_t flags;
} SPI_TypeDef;

#define SPI_FLAG_SSEL (1 << 0)
#define SPI_FLAG_BUSY (1 << 1)

/* --- IR receiver --- */

typedef struct {
  __IO uint32_t pulsedata;
} IRRX_TypeDef;

#define IRRX_PULSE_MASK (0xff)
#define IRRX_TIMEOUT    (1 << 8)
#define IRRX_STATE      (1 << 9)
#define IRRX_BUTTON     (1 << 10)
#define IRRX_IRQ        (1 << 11)

/* --- OSD RAM --- */

typedef struct {
  __IO uint32_t data[2048];
} OSDRAM_TypeDef;

/* --- mixing it all together --- */

#define OSDRAM_BASE        ((uint32_t)0xffffc000UL)
#define SCANLINERAM_BASE   ((uint32_t)0xffffe000UL)
#define PERIPH_BASE        ((uint32_t)0xfffff000UL)
#define IRQController_BASE (PERIPH_BASE)
#define VIDEOIF_BASE       (PERIPH_BASE + 0x100)
#define PADREADER_BASE     (PERIPH_BASE + 0x200)
#define SPI_BASE           (PERIPH_BASE + 0x300)
#define IRRX_BASE          (PERIPH_BASE + 0x400)

#define IRQController ((IRQController_TypeDef *)IRQController_BASE)
#define VIDEOIF       ((VideoInterface_TypeDef *)VIDEOIF_BASE)
#define PADREADER     ((PadReader_TypeDef *)PADREADER_BASE)
#define SCANLINERAM   ((SCANLINERAM_TypeDef *)SCANLINERAM_BASE)
#define OSDRAM        ((OSDRAM_TypeDef *)OSDRAM_BASE)
#define SPI           ((SPI_TypeDef *)SPI_BASE)
#define IRRX          ((IRRX_TypeDef *)IRRX_BASE)

#endif
