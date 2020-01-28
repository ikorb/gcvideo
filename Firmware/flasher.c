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


   flasher.c: Flash update tool for GCVideo
*/

#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include "crc32mpeg.h"
#include "exodecr.h"
#include "flashviewer.h"
#include "icap.h"
#include "menu-lite.h"
#include "osd.h"
#include "pad.h"
#include "portdefs.h"
#include "screens.h"
#include "spiflash.h"
#include "vsync.h"
#include "flasher.h"

#define HARDWARE_ID_ADDRESS 0x2fff0
#define HARDWARE_ID_LENGTH  16
#define MAIN_APP_ADDRESS    0x30000
#define FLASH_SIZE          0x80000
#define ERASE_BLOCK_SIZE    0x10000
#define SPI_READ_CMD        0x03 // the only supported command by some early M25P40
#define INFO_PAGE           0x10
#define INFO_LINE           0
#define RNG_MULT            1103515245
#define RNG_ADD             12345
#define RNG_MOD             (1 << 31)
#define RNG_SHIFT           8

static const char updater_signature[12] = "GCVUpdater10";

typedef struct {
  uint32_t hardware_id;
  uint32_t length; // not including this header
  uint32_t crc;
  char     version[8];
} imageheader_t;

static imageheader_t mainheader;

static uint32_t target_hardware_id;
static uint8_t *decodebuf_readptr;
uint8_t __attribute__((aligned(4))) decodebuffer[1254];
char    __attribute__((aligned(4))) decrunchbuffer[UNCOMPRESSED_CHUNK_SIZE];

typedef enum {
  STATE_OK,
  STATE_INVALID,
  STATE_BADCRC,
  STATE_FORCEFLASHER,
} flashstate_t;

/* blank items for choosing a firmware version */
static menuitem_t menu_items[] = {
  { "Abort" },

  { NULL },
  { NULL },
  { NULL },
  { NULL },

  { NULL },
  { NULL },
  { NULL },
  { NULL },

  { NULL },
  { NULL },
  { NULL },
  { NULL },

  { NULL },
  { NULL },
  { NULL },
  { NULL },
};

static menu_t firmware_menu = {
  13, 7, // xpos, ypos
  19, 0, // xsize, ysize
  0,     // entries
  menu_items
};


static void boot_main(void) {
  osd_clrscr();

  while (1) {
    icap_init();
    icap_write_register(ICAP_REG_GENERAL1,
                        (MAIN_APP_ADDRESS & 0xffff) + sizeof(imageheader_t));
    icap_write_register(ICAP_REG_GENERAL2,
                        (SPI_READ_CMD << 8) | (MAIN_APP_ADDRESS >> 16));
    icap_write_register(ICAP_REG_MODE_REG, ICAP_MODE_NEW_MODE | ICAP_MODE_BOOT_SPI | ICAP_MODE_RESERVED);
    icap_write_register(ICAP_REG_CMD, ICAP_CMD_REBOOT);
    icap_noop();
    icap_noop();

    VIDEOIF->osd_bg = 0; // enable output
    osd_gotoxy(3, 3);
    osd_puts("*** Booting main firmware failed! ***\n\nPlease power-cycle your console.\n");
  }
}

static flashstate_t validate_main_image(void) {
  spiflash_read_block(&mainheader, MAIN_APP_ADDRESS, sizeof(mainheader));

  if (mainheader.length >= FLASH_SIZE - MAIN_APP_ADDRESS - sizeof(mainheader)) {
    return STATE_INVALID;
  }

  /* assume that the main firmware has the correct ID if our copy is not set */
  if (target_hardware_id != 0 && mainheader.hardware_id != target_hardware_id) {
    return STATE_INVALID;
  }

  uint32_t flashcrc = spiflash_crc32(MAIN_APP_ADDRESS + sizeof(mainheader), mainheader.length);
  if (flashcrc != mainheader.crc) {
    return STATE_BADCRC;
  }

  return STATE_OK;
}


/* ------------------- */
/* --- linecapture --- */
/* ------------------- */

static uint8_t getu8(void) {
  return *decodebuf_readptr++;
}

static uint16_t getu16(void) {
  return ((uint16_t)getu8() << 8) | getu8();
}

static uint32_t getu32(void) {
  return ((uint32_t)getu16() << 16) | getu16();
}

static void spin(void) {
  static unsigned char spinpos = 0;
  static const char spinchars[] = "/-\\|";
  static tick_t prevtick = 0;

  if (getticks() != prevtick) {
    prevtick = getticks();
    osd_putcharat(3, 9, spinchars[spinpos++], ATTRIB_DIM_BG);
    if (spinpos >= 4)
      spinpos = 0;
  }
}

static void nospin(unsigned int attr) {
  osd_putcharat(3, 9, ' ', attr);
}

static void set_capture_range(unsigned int start, unsigned int end) {
  for (unsigned int i = 0; i < 255; i++) {
    if (i >= start && i <= end) {
      LINECAPTURE->needed_lines[i] = 1;
    } else {
      LINECAPTURE->needed_lines[i] = 0;
    }
  }
}

/* decode current captured line to a buffer */
static size_t decode_7bit(void* destination, size_t buffersize) {
  size_t length = LINECAPTURE->linedata[1] - 0x4040;
  length = (length & 0x7f) | ((length & 0x7f00) >> 1);

  if (length > (buffersize / 2)) {
    return 0;
  }

  unsigned int bitbuffer = 0;
  unsigned int bits_remain = 0;
  uint16_t *writeptr = (uint16_t*)destination;
  const volatile uint32_t *readptr = LINECAPTURE->linedata + 2;

  while (length > 0) {
    unsigned int curword = *readptr++ - 0x4040;

    if (bits_remain == 0) {
      bitbuffer = curword;
      bits_remain = 7;
      continue;
    }

    *writeptr++ = (curword << 1) | (bitbuffer & 0x0101);
    bitbuffer = (bitbuffer & 0xfefe) >> 1;
    bits_remain--;
    length--;
  }

  return 2 * (writeptr - (uint16_t*)destination);
}

static bool validate_line(unsigned int linelength) {
  uint8_t prefix[2] = {
    (LINECAPTURE->linedata[0] >> 8) & 0xff,
     LINECAPTURE->linedata[0] & 0xff
  };

  /* unscramble */
  uint32_t rngstate = (prefix[0] << 8) | prefix[1];
  for (unsigned int i = 0; i < linelength; i++) {
    rngstate = (RNG_MULT * rngstate + RNG_ADD) % RNG_MOD;
    uint8_t randval = (rngstate >> RNG_SHIFT) & 0xff;
    decodebuffer[i] ^= randval;
  }

  unsigned int buffercrc = getu32();

  crc_t crc = crc_init();
  crc = crc_update(crc, prefix, 2);
  crc = crc_update(crc, decodebuffer + 4, linelength - 4);
  crc = crc_finalize(crc);

  return buffercrc == crc;
}

static bool capture_line(void) {
  while (1) {
    LINECAPTURE->arm = 0; // value does not matter

    while (LINECAPTURE->linedata[0] & LINECAPTURE_FLAG_BUSY) {
      if (pad_buttons & (IRBUTTON_LONG | IR_BACK | IR_LEFT | PAD_START | PAD_Z)) {
        return false;
      }

      spin();
    }

    size_t len = decode_7bit(decodebuffer, sizeof(decodebuffer));
    decodebuf_readptr = decodebuffer;
    if (len >= 4 && validate_line(len)) {
      return true;
    }

    /* mark line as needed again */
    LINECAPTURE->needed_lines[(LINECAPTURE->linedata[0] >> 8) & 0xff] = 1;
  }
}

static bool choose_update(unsigned int fwcount) {
  uint8_t *orig_readptr = decodebuf_readptr;

  if (fwcount >= sizeof(menu_items) / sizeof(menu_items[0])) {
    fwcount = sizeof(menu_items) / sizeof(menu_items[0]) - 1;
  }

  /* build menu */
  firmware_menu.entries = fwcount + 1;
  firmware_menu.ysize   = fwcount + 3;
  char *stringptr = decrunchbuffer;
  unsigned int initial_item = 0;

  for (unsigned int i = 1; i <= fwcount; i++) {
    uint32_t signature_word = getu32();
    char signature_chars[4];

    /* restrict chars to printable ASCII */
    memcpy(signature_chars, &signature_word, sizeof(signature_chars));
    for (unsigned int j = 0; j < sizeof(signature_chars); j++) {
      if (signature_chars[j] < 32 || signature_chars[j] > 126) {
        signature_chars[j] = '?';
      }
    }

    int len = snprintf(stringptr, sizeof(decrunchbuffer) - (stringptr - decrunchbuffer),
                       "%08x (%c%c%c%c)", signature_word,
                       signature_chars[0], signature_chars[1],
                       signature_chars[2], signature_chars[3]);

    if (mainheader.hardware_id == signature_word) {
      initial_item = i;
    }

    menu_items[i].text = stringptr;
    stringptr += len + 1;
    if (stringptr >= decrunchbuffer + sizeof(decrunchbuffer)) {
      break;
    }

    decodebuf_readptr += 2 + 2 + 8;
  }

  nospin(0);
  menu_draw(&firmware_menu);
  int selection = menu_exec(&firmware_menu, initial_item);

  if (selection <= 0) {
    return false;
  }

  /* adjust pointer to start of selected entry */
  decodebuf_readptr = orig_readptr + (selection - 1) * 16;

  osd_clearline(4, 0);
  osd_gotoxy(7, 4);
  printf(" Chosen hardware ID: %08x ", getu32());

  return true;
}

static bool look_for_update(void) {
  while (1) {
    /* grab info line */
    set_capture_range(INFO_LINE, INFO_LINE);
    LINECAPTURE->selected_page = INFO_PAGE;

    if (!capture_line())
      return false;

    /* check if a matching firmware is available */
    unsigned int fwcount = getu16();

    if (fwcount == 0) {
      osd_gotoxy(3, 7);
      osd_clearline(7, 0);
      osd_puts("Unable to parse firmware list.");
      continue;
    }

    if (target_hardware_id != 0) {
      bool found = false;
      for (unsigned int i = 0; i < fwcount; i++) {
        uint32_t signature = getu32();
        if (signature == target_hardware_id) {
          found = true;
          break;
        }

        decodebuf_readptr += 2 + 2 + 8;
      }

      if (found) {
        return true;
      }

      osd_gotoxy(3, 7);
      osd_clearline(7, 0);
      osd_puts("No compatible firmware found.");
    } else {
      return choose_update(fwcount);
    }
  }
}

static bool try_update(void) {
  if (!look_for_update()) {
    /* user requested exit */
    return false;
  }

  uint16_t lines = getu16();
  uint16_t page  = getu16();
  uint8_t version[9];

  for (unsigned int i = 0; i < 8; i++) {
    version[i] = getu8();
  }
  version[8] = 0;

  /* hide the update data */
  for (unsigned int i = 5 * OSD_CHARS_PER_LINE; i < 7 * OSD_CHARS_PER_LINE; i++) {
    /* keep existing text in the first two lines */
    OSDRAM->data[i] |= ATTRIB_DIM_BG;
  }

  for (unsigned int i = 7; i < OSD_LINES_ON_SCREEN; i++) {
    osd_clearline(i, ATTRIB_DIM_BG);
  }

  osd_gotoxy(3, 7);
  printf("Available version: %s", version);

  osd_putsat(3,  9, "Hold both X and Y on the game pad or");
  osd_putsat(3, 10, "push OK on the IR remote to install.");

  while (1) {
    if (((pad_buttons & (PAD_X | PAD_Y)) == (PAD_X | PAD_Y) &&
        time_after(getticks(), pad_last_change + HZ)) ||
        (pad_buttons & IR_OK)) {
      pad_clear(PAD_X | PAD_Y);
      break;
    } else if (pad_buttons & (PAD_START | PAD_Z | IR_BACK | IR_LEFT | IRBUTTON_LONG)) {
      /* user requested exit */
      return false;
    }
  }

  osd_clearline(7, ATTRIB_DIM_BG);
  osd_clearline(9, ATTRIB_DIM_BG);
  osd_clearline(10, ATTRIB_DIM_BG);
  osd_gotoxy(3, 7);
  printf("Installing version %s", version);

  /* start flashing */
  bool erased_blocks[(FLASH_SIZE - MAIN_APP_ADDRESS) / ERASE_BLOCK_SIZE];
  for (unsigned int i = 0; i < sizeof(erased_blocks); i++) {
    erased_blocks[i] = false;
  }

  /* grab pieces of the update and apply it */
  set_capture_range(0, lines - 1);
  LINECAPTURE->selected_page = page;

  unsigned int lines_remain = lines;
  while (lines_remain > 0) {
    osd_gotoxy(5, 9);
    printf("%d/%d parts written", lines - lines_remain, lines);

    if (!capture_line())
      break;

    unsigned int chunks = getu8();
    for (unsigned int i = 0; i < chunks; i++) {
      unsigned int chunknum = getu8();
      unsigned int chunklen = getu16();

      if (chunklen != UNCOMPRESSED_CHUNK_SIZE) {
        char *startptr =
          exo_decrunch((char *)decodebuf_readptr + chunklen,
                      decrunchbuffer + sizeof(decrunchbuffer), sizeof(decrunchbuffer));

        if (startptr != NULL) {
          unsigned int decrunch_size = (char*)decrunchbuffer + sizeof(decrunchbuffer) - startptr;

          if (decrunch_size != UNCOMPRESSED_CHUNK_SIZE) {
            startptr = NULL;
          }
        }

        if (startptr == NULL) {
          /* in theory we could try again, but the line CRC was ok so let the user decide */
          osd_gotoxy(3, 3);
          osd_puts("Compressed data is corrupted.\n   Please power-cycle and try again.");
          while (1) ;
        }
      } else {
        memcpy(decrunchbuffer, decodebuf_readptr, UNCOMPRESSED_CHUNK_SIZE);
      }

      decodebuf_readptr += chunklen;

      if (!erased_blocks[chunknum * UNCOMPRESSED_CHUNK_SIZE / ERASE_BLOCK_SIZE]) {
        erased_blocks[chunknum * UNCOMPRESSED_CHUNK_SIZE / ERASE_BLOCK_SIZE] = true;
        spiflash_erase_sector(MAIN_APP_ADDRESS + chunknum * UNCOMPRESSED_CHUNK_SIZE);
      }

      spiflash_write_page(MAIN_APP_ADDRESS + chunknum * UNCOMPRESSED_CHUNK_SIZE,
                          decrunchbuffer, UNCOMPRESSED_CHUNK_SIZE);
    }

    lines_remain--;
  }

  osd_clearline(9, ATTRIB_DIM_BG);
  osd_gotoxy(3, 9);
  flashstate_t flashstate = validate_main_image();
  if (flashstate != STATE_OK) {
    osd_puts("Installation failed.\n   Please power-cycle and try again.");
    while (1) ;
  }

  osd_puts("Installation ok.");
  pad_clear(PAD_ALL);

  unsigned int seconds_to_reboot = 15;

  while (seconds_to_reboot > 0) {
    osd_gotoxy(3, 12);
    printf("Restarting in %d second%c  ", seconds_to_reboot,
           seconds_to_reboot == 1 ? ' ' : 's');
    seconds_to_reboot--;

    time_t nexttick = getticks() + HZ;

    while (time_after(nexttick, getticks())) {
      if (pad_buttons & (PAD_START | IR_OK)) {
        /* early exit for impatient users */
        pad_clear(PAD_START | IR_OK);
        return true;
      }
    }
  }

  return true;
}

void run_mainloop(void) {
  flashstate_t flashstate;
  bool bad_main_id = false;
  bool first_time = true;

  icap_init();

  spiflash_read_block(decrunchbuffer, HARDWARE_ID_ADDRESS, HARDWARE_ID_LENGTH);
  if (!memcmp(updater_signature, decrunchbuffer, sizeof(updater_signature))) {
    memcpy(&target_hardware_id,
           decrunchbuffer + sizeof(updater_signature),
           sizeof(target_hardware_id));
  } else {
    bad_main_id = true;
  }

  while (1) {
    flashstate = validate_main_image();

    /* check if flasher entry was requested from main image */
    if (first_time && icap_read_register(ICAP_REG_GENERAL1) != 0) {
      first_time = false;
      flashstate = STATE_FORCEFLASHER;

      /* main hardware ID should be ok because it requested entry to here */
      if (target_hardware_id == 0)
        target_hardware_id = mainheader.hardware_id;
    }

    if (flashstate == STATE_OK) {
      if (!(IRRX->pulsedata & IRRX_BUTTON)) {
        flashstate = STATE_FORCEFLASHER;

        VIDEOIF->osd_bg = 0;
        osd_gotoxy(3, 5);
        osd_puts("Please release the IR config button.");
        while (!(IRRX->pulsedata & IRRX_BUTTON)) ;
        pad_clear(PAD_ALL);

      } else {
        /* boot main image */
        boot_main();
      }
    }

    /* explicit entry requested or something went wrong, enable output and print status */
    char version[9];
    retry:
    memcpy(version, mainheader.version, sizeof(mainheader.version));
    version[8] = 0;

    VIDEOIF->osd_bg = 0;
    osd_clrscr();
    osd_setattr(true, false);

    if (bad_main_id) {
      osd_putsat(3, 3, "!!! Updater hardware ID is invalid !!!");
      osd_putsat(3, 4, "--> YOU must choose the correct ID <--");
    }

    osd_gotoxy(3, 5);

    switch (flashstate) {
      case STATE_BADCRC:
        osd_puts("Main firmware is corrupted.\n");
        break;

      case STATE_INVALID:
        osd_puts("Main firmware is missing.\n");
        break;

      case STATE_FORCEFLASHER:
        osd_puts("Flash update requested.\n");
        osd_gotoxy(3, 6);
        printf("Installed version: %s", version);
        break;

      default:
        osd_puts("Weird program state detected.\n");
        break;
    }

    if (!try_update()) {
      if (pad_buttons & IRBUTTON_LONG) {
        pad_clear(PAD_ALL);
        for (unsigned int i = 5; i < OSD_LINES_ON_SCREEN; i++) {
          osd_clearline(i, ATTRIB_DIM_BG);
        }

        screen_irconfig(false);
        goto retry;

      } else if (pad_buttons & (PAD_Z | IR_LEFT)) {
        pad_clear(PAD_ALL);
        flash_viewer();
      }

      pad_clear(PAD_ALL);
    }
  }
}
