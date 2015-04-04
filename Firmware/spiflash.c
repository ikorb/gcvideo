/* GCVideo DVI Firmware

   Copyright (C) 2015, Ingo Korb <ingo@akana.de>
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
#include <string.h>
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

#define STATUSREG_WIP      (1<<0)

#define SETTINGS_OFFSET  0x70000
#define SETTINGS_VERSION 1

uint8_t flash_chip_id[4];

static uint16_t current_setid;

typedef struct {
  uint8_t  checksum;
  uint8_t  version;
  uint8_t  flags;
  uint8_t  reserved;
  uint32_t video_settings[VIDMODE_COUNT];
  uint32_t osdbg_settings;
} storedsettings_t;

#define SET_FLAG_RESBOX (1<<0)
  

static void set_cs(bool state) {
  if (state)
    SPI->flags |=  SPI_FLAG_SSEL;
  else
    SPI->flags &= ~SPI_FLAG_SSEL;
}

static unsigned int send_byte(unsigned int byte) {
  SPI->data = byte;
  while (SPI->flags & SPI_FLAG_BUSY) ;
  return SPI->data;
}

static void read_chip_id(void) {
  /* read the single-byte chip ID */
  set_cs(false);
  send_byte(CMD_READ_SIGNATURE);
  send_byte(0x00); // three dummy bytes
  send_byte(0x00);
  send_byte(0x00);
  flash_chip_id[0] = send_byte(0x00);
  set_cs(true);

  /* read the JEDEC ID */
  set_cs(false);
  send_byte(CMD_READ_IDENT);
  flash_chip_id[1] = send_byte(0x00);
  flash_chip_id[2] = send_byte(0x00);
  flash_chip_id[3] = send_byte(0x00);
  set_cs(true);
}

static void write_enable(void) {
  set_cs(false);
  send_byte(CMD_WRITE_ENABLE);
  set_cs(true);
}

static void wait_write_done(void) {
  unsigned int result;

  do {
    set_cs(false);
    send_byte(CMD_READ_STATUS);
    result = send_byte(0x00);
    set_cs(true);
  } while (result & STATUSREG_WIP);
}

static void read_settings(unsigned int num, storedsettings_t *set) {
  uint8_t *byteset = (uint8_t *)set;

  set_cs(false);
  send_byte(CMD_READ_BYTES);
  send_byte(SETTINGS_OFFSET >> 16);
  send_byte(num);
  send_byte(0);
  for (unsigned int i = 0; i < sizeof(storedsettings_t); i++)
    byteset[i] = send_byte(0x00);
  set_cs(true);
}

static void write_settings(unsigned int num, storedsettings_t *set) {
  uint8_t *byteset = (uint8_t *)set;

  write_enable();
  set_cs(false);
  send_byte(CMD_PAGE_PROGRAM);
  send_byte(SETTINGS_OFFSET >> 16);
  send_byte(num);
  send_byte(0);
  for (unsigned int i = 0; i < sizeof(storedsettings_t); i++)
    send_byte(byteset[i]);

  for (unsigned int i = sizeof(storedsettings_t); i < 256; i++)
    send_byte(0xff);
  set_cs(true);

  wait_write_done();
}

void spiflash_read_settings(void) {
  storedsettings_t set;
  unsigned int i;

  /* scan for the first valid settings record */
  for (i = 0; i < 256; i++) {
    read_settings(i, &set);
    if (set.version == SETTINGS_VERSION) {
      /* found a record with the expected version, verify checksum */
      uint8_t *byteset = (uint8_t *)&set;
      uint8_t sum = 0;

      for (unsigned int j = 1; j < sizeof(storedsettings_t); j++)
        sum += byteset[j];

      if (sum == set.checksum)
        /* found a valid setting record */
        break;
    }
  }

  current_setid = i;
  if (i < 256) {
    /* valid settings found, copy to main vars */
    for (i = 0; i < VIDMODE_COUNT; i++)
      video_settings[i] = set.video_settings[i];
    osdbg_settings = set.osdbg_settings;
    if (set.flags & SET_FLAG_RESBOX)
      resbox_enabled = true;
    else
      resbox_enabled = false;
  }
}

void spiflash_write_settings(void) {
  storedsettings_t set;
  uint8_t *byteset = (uint8_t *)&set;
  uint8_t sum = 0;

  /* create settings record */
  memset(&set, 0, sizeof(storedsettings_t));
  set.version = SETTINGS_VERSION;
  for (unsigned int i = 0; i < VIDMODE_COUNT; i++)
    set.video_settings[i] = video_settings[i];
  set.osdbg_settings = osdbg_settings;
  if (resbox_enabled)
    set.flags |= SET_FLAG_RESBOX;

  for (unsigned int i = 1; i < sizeof(storedsettings_t); i++)
    sum += byteset[i];

  set.checksum = sum;

  /* check if erase cycle is needed */
  if (current_setid == 0) {
    write_enable();
    set_cs(false);
    send_byte(CMD_SECTOR_ERASE);
    send_byte(SETTINGS_OFFSET >> 16);
    send_byte(0);
    send_byte(0);
    set_cs(true);

    wait_write_done();
    current_setid = 256;
  }

  /* write data to flash */
  current_setid--;
  write_settings(current_setid, &set);
}

void spiflash_init(void) {
  read_chip_id();
  spiflash_read_settings();
}
