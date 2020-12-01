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

#ifdef MODULE_main
#  include "portdefs-main.h"
#endif

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

typedef union {
  struct {
    __I uint32_t xres;
    __I uint32_t yres;
    __I uint32_t flags;
    __I uint32_t htotal;
    __I uint32_t hactive_start;
    __I uint32_t vtotal;
    __I uint32_t vactive_start0;
    __I uint32_t vhoffset0;
    __I uint32_t vactive_start1;
    __I uint32_t vhoffset1;
  };
  struct {
    __O uint32_t settings;
    __O uint32_t osd_bg;
    __O uint32_t audio_volume;
    __O uint32_t yr_factor_y_bias;
    __O uint32_t yb_yg_factor;
    __O uint32_t cbb_cbg_factor;
    __O uint32_t crg_crr_factor;
    __O uint32_t hsync_end_start;
    __O uint32_t hactive_end_start;
    __O uint32_t vsync_start;
    __O uint32_t vsync_end;
    __O uint32_t vactive_start;
    __O uint32_t vactive_lines;
    // "virtual" register, any write clears IRQ flag
    __O uint32_t clear_irq;
  };
} VideoInterface_TypeDef;

#define VIDEOIF_FLAG_IN_PROGRESSIVE (1<<0)
#define VIDEOIF_FLAG_IN_PAL         (1<<1)
#define VIDEOIF_FLAG_IN_31KHZ       (1<<2)
#define VIDEOIF_FLAG_MODE_WII       (1<<3)
#define VIDEOIF_FLAG_FORCE_YPBPR    (1<<4)
#define VIDEOIF_FLAG_EVENFIELD      (1<<5)
#define VIDEOIF_FLAG_LD_PROGRESSIVE (1<<6)
#define VIDEOIF_FLAG_LD_PAL         (1<<7)
#define VIDEOIF_FLAG_LD_31KHZ       (1<<8)

#define VIDEOIF_BIT_SL_EVEN          2
#define VIDEOIF_BIT_SL_ALTERNATE     3
#define VIDEOIF_BIT_LD_ENABLE        4
#define VIDEOIF_BIT_CABLEDETECT      5
#define VIDEOIF_BIT_DVIENHANCED      6
#define VIDEOIF_BIT_169              7
#define VIDEOIF_BIT_ANALOGMODE       8
#define VIDEOIF_BIT_ANALOGSOG        9
#define VIDEOIF_BIT_SAMPLERATEHACK   10
#define VIDEOIF_BIT_ENABLEREBLANK    11
#define VIDEOIF_BIT_ENABLERESYNC     12
#define VIDEOIF_BIT_CHROMAINTERP     13
#define VIDEOIF_BIT_NONSTD_MASK      14
#define VIDEOIF_BIT_COLOR_RGBLIMITED 15 // not completely true, but useful
#define VIDEOIF_BIT_COLOR_YCBCR      16
#define VIDEOIF_BIT_REGENCSYNC       17
#define VIDEOIF_BIT_SPOOFINTERLACE   31 // implemented in software, ignored by hardware

#define VIDEOIF_SET_SL_EVEN          (1<<VIDEOIF_BIT_SL_EVEN)
#define VIDEOIF_SET_SL_ALTERNATE     (1<<VIDEOIF_BIT_SL_ALTERNATE)
#define VIDEOIF_SET_LD_ENABLE        (1<<VIDEOIF_BIT_LD_ENABLE)
#define VIDEOIF_SET_CABLEDETECT      (1<<VIDEOIF_BIT_CABLEDETECT)
#define VIDEOIF_SET_DVIENHANCED      (1<<VIDEOIF_BIT_DVIENHANCED)
#define VIDEOIF_SET_169              (1<<VIDEOIF_BIT_169)
#define VIDEOIF_SET_ANALOGMODE       (1<<VIDEOIF_BIT_ANALOGMODE)
#define VIDEOIF_SET_ANALOGSOG        (1<<VIDEOIF_BIT_ANALOGSOG)
#define VIDEOIF_SET_SAMPLERATEHACK   (1<<VIDEOIF_BIT_SAMPLERATEHACK)
#define VIDEOIF_SET_ENABLEREBLANK    (1<<VIDEOIF_BIT_ENABLEREBLANK)
#define VIDEOIF_SET_ENABLERESYNC     (1<<VIDEOIF_BIT_ENABLERESYNC)
#define VIDEOIF_SET_NONSTD_MASK      (1<<VIDEOIF_BIT_NONSTD_MASK)
#define VIDEOIF_SET_CHROMAINTERP     (1<<VIDEOIF_BIT_CHROMAINTERP)
#define VIDEOIF_SET_REGENCSYNC       (1<<VIDEOIF_BIT_REGENCSYNC)
#define VIDEOIF_SET_SPOOFINTERLACE   (1<<VIDEOIF_BIT_SPOOFINTERLACE)

#define VIDEOIF_SET_SLPROFILE_MASK   3

#define VIDEOIF_SET_ANALOG_MASK      (3 << VIDEOIF_BIT_ANALOGMODE)
#define VIDEOIF_SET_ANALOG_SHIFT     VIDEOIF_BIT_ANALOGMODE

#define VIDEOIF_SET_COLORMODE_SHIFT  VIDEOIF_BIT_COLOR_RGBLIMITED
#define VIDEOIF_SET_COLORMODE_MASK   (3 << VIDEOIF_SET_COLORMODE_SHIFT)
#define VIDEOIF_SET_COLORMODE_RGBF   (0 << VIDEOIF_SET_COLORMODE_SHIFT)
#define VIDEOIF_SET_COLORMODE_RGBL   (1 << VIDEOIF_SET_COLORMODE_SHIFT)
#define VIDEOIF_SET_COLORMODE_Y444   (2 << VIDEOIF_SET_COLORMODE_SHIFT)
#define VIDEOIF_SET_COLORMODE_Y422   (3 << VIDEOIF_SET_COLORMODE_SHIFT)
#define VIDEOIF_SET_TEST_YCBCR       (2 << VIDEOIF_SET_COLORMODE_SHIFT)
#define VIDEOIF_SET_TEST_YCBCR422    (1 << VIDEOIF_SET_COLORMODE_SHIFT)

#define VIDEOIF_OSDBG_ALPHA_MASK     0xff0000
#define VIDEOIF_OSDBG_ALPHA_SHIFT    16
#define VIDEOIF_OSDBG_TINTCB_MASK    0x00ff00
#define VIDEOIF_OSDBG_TINTCB_SHIFT   8
#define VIDEOIF_OSDBG_TINTCR_MASK    0x0000ff
#define VIDEOIF_OSDBG_TINTCR_SHIFT   0

#define VIDEOIF_OSDBG_DISABLE_OUTPUT -1 // technically just bit 24, but -1 is one insn

/* --- PadReader --- */

typedef struct {
  __I  uint32_t data;
  __IO uint32_t bits;    // writing clears the interrupt flag
} PadReader_TypeDef;

#define PADREADER_BITS_SHIFTFLAG 0x80

/* --- SPI+ICAP --- */

typedef struct {
  __IO uint32_t spi_data;
  __IO uint32_t spi_flags;
  __IO uint32_t spi_crc;
  __IO uint32_t spi_data32;
  __IO uint32_t icap_data;
  __O  uint32_t icap_flags;
} SPICAP_TypeDef;

#define SPI_FLAG_SSEL     (1 << 0)
#define SPI_FLAG_BUSY     (1 << 1)
#define ICAP_FLAG_CLOCK   (1 << 0)
#define ICAP_FLAG_CE      (1 << 1)
#define ICAP_FLAG_WRITE   (1 << 2)
#define ICAP_FLAG_BUSY    (1 << 0)

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

/* --- InfoFrame RAM --- */

typedef struct {
  __IO uint32_t data[2048];
} IFRAM_TypeDef;

/* --- mixing it all together --- */

#define IFRAM_BASE         ((uint32_t)0xffff8000UL)
#define OSDRAM_BASE        ((uint32_t)0xffffc000UL)
// ffffe000: module-specific
#define PERIPH_BASE        ((uint32_t)0xfffff000UL)
#define IRQController_BASE (PERIPH_BASE)
#define VIDEOIF_BASE       (PERIPH_BASE + 0x100)
#define PADREADER_BASE     (PERIPH_BASE + 0x200)
#define SPICAP_BASE        (PERIPH_BASE + 0x300)
#define IRRX_BASE          (PERIPH_BASE + 0x400)

#define IRQController ((IRQController_TypeDef *)IRQController_BASE)
#define VIDEOIF       ((VideoInterface_TypeDef *)VIDEOIF_BASE)
#define PADREADER     ((PadReader_TypeDef *)PADREADER_BASE)
#define OSDRAM        ((OSDRAM_TypeDef *)OSDRAM_BASE)
#define IFRAM         ((IFRAM_TypeDef *)IFRAM_BASE)
#define SPICAP        ((SPICAP_TypeDef *)SPICAP_BASE)
#define IRRX          ((IRRX_TypeDef *)IRRX_BASE)

#endif
