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


   icap.h: Interface to Spartan3A ICAP module

*/

#ifndef ICAP_H
#define ICAP_H

#include <stdint.h>

#define ICAP_HEADER_TYPE1 (1 << 13)
#define ICAP_HEADER_TYPE2 (2 << 13)

#define ICAP_OPCODE_NOOP  0
#define ICAP_OPCODE_READ  (1 << 11)
#define ICAP_OPCODE_WRITE (2 << 11)

#define ICAP_REG_CRC       ( 0 << 5)
#define ICAP_REG_CMD       ( 5 << 5)
#define ICAP_REG_STAT      ( 8 << 5)
#define ICAP_REG_GENERAL1  (19 << 5)
#define ICAP_REG_GENERAL2  (20 << 5)
#define ICAP_REG_MODE_REG  (21 << 5)
#define ICAP_REG_CCLK_FREQ (25 << 5)

#define ICAP_CMD_REBOOT 0x0e

#define ICAP_MODE_NEW_MODE (1 << 6)
#define ICAP_MODE_BOOT_SPI (1 << 3)
#define ICAP_MODE_RESERVED 7

void     icap_init(void);
void     icap_noop(void);
void     icap_write_register(uint16_t reg, uint16_t value);
uint16_t icap_read_register(uint16_t reg);

#endif
