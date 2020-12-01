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


   spiflash.c: Read and store settings to the SPI flash chip

*/

#include <stdbool.h>
#include <stddef.h>
#include <string.h>
#include "irrx.h"
#include "portdefs.h"
#include "settings.h"
#include "spiflash.h"

#define CMD_WRITE_ENABLE   0x06
#define CMD_WRITE_DISABLE  0x04
#define CMD_READ_IDENT     0x9f
#define CMD_READ_STATUS    0x05
#define CMD_WRITE_STATUS   0x01
#define CMD_READ_BYTES     0x03
#define CMD_PAGE_PROGRAM   0x02
#define CMD_SECTOR_ERASE   0xd8
#define CMD_RELEASE_PWDN   0xab
#define CMD_READ_SIGNATURE 0xab // sic!

#define STATUSREG_WIP      (1<<0) // write in progress

static void set_cs(bool state) {
  if (state)
    SPICAP->spi_flags |=  SPI_FLAG_SSEL;
  else
    SPICAP->spi_flags &= ~SPI_FLAG_SSEL;
}

unsigned int spiflash_send_byte(unsigned int byte) {
  SPICAP->spi_data = byte;
  /* no busy check, handled via hardware waitstates */
  return SPICAP->spi_data;
}

static void write_enable(void) {
  set_cs(false);
  spiflash_send_byte(CMD_WRITE_ENABLE);
  set_cs(true);
}

static void wait_write_done(void) {
  unsigned int result;

  do {
    set_cs(false);
    spiflash_send_byte(CMD_READ_STATUS);
    result = spiflash_send_byte(0x00);
    set_cs(true);
  } while (result & STATUSREG_WIP);
}

bool spiflash_is_blank(uint32_t address, unsigned int length) {
  spiflash_start_read(address);

  while (length-- > 0) {
    if (spiflash_send_byte(0) != 0xff) {
      set_cs(true);
      return false;
    }
  }

  set_cs(true);
  return true;
}

static void start_command_addr(uint8_t command, uint32_t address) {
  set_cs(false);
  spiflash_send_byte(command);
  spiflash_send_byte((address >> 16) & 0xff);
  spiflash_send_byte((address >> 8) & 0xff);
  spiflash_send_byte(address & 0xff);
}

void spiflash_start_write(uint32_t address) {
  write_enable();
  start_command_addr(CMD_PAGE_PROGRAM, address);
}

void spiflash_end_write(void) {
  set_cs(true);
  wait_write_done();
}

void spiflash_start_read(uint32_t address) {
  start_command_addr(CMD_READ_BYTES, address);
}

void spiflash_end_read(void) {
  set_cs(true);
}

void spiflash_erase_sector(uint32_t address) {
  write_enable();
  start_command_addr(CMD_SECTOR_ERASE, address);
  spiflash_end_write();
}

void spiflash_read_block(void* buffer, uint32_t address, uint32_t length) {
  uint8_t *bytebuf = (uint8_t *)buffer;

  spiflash_start_read(address);
  for (unsigned int i = 0; i < length; i++)
    bytebuf[i] = spiflash_send_byte(0x00);
  set_cs(true);
}

void spiflash_write_page(uint32_t address, void* buffer, uint32_t length) {
  uint8_t *bytebuf = (uint8_t *)buffer;
  while (length > 0) {
   spiflash_start_write(address);

    do {
      spiflash_send_byte(*bytebuf++);
      address++;
      length--;
    } while (length > 0 && (address & 0xff) != 0);

    spiflash_end_write();
  }
}
