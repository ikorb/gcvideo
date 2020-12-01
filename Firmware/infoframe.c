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


   infoframe.c: Infoframe generator

*/

#include <stdio.h>

#include <stdbool.h>
#include "osd.h"
#include "portdefs.h"
#include "settings.h"
#include "infoframe.h"

#define DB1_SCANINFO_NONE       (0 << 0)
#define DB1_SCANINFO_OVERSCAN   (1 << 0)
#define DB1_SCANINFO_UNDERSCAN  (2 << 0)
#define DB1_BARINFO_NONE        (0 << 2)
#define DB1_BARINFO_H           (1 << 2)
#define DB1_BARINFO_V           (2 << 2)
#define DB1_BARINFO_HV          (3 << 2)
#define DB1_COLOR_RGB           (0 << 5)
#define DB1_COLOR_YCBCR422      (1 << 5)
#define DB1_COLOR_YCBCR444      (2 << 5)

#define DB2_FRAMEASPECT_NODATA  (0 << 4)
#define DB2_FRAMEASPECT_4_3     (1 << 4)
#define DB2_FRAMEASPECT_16_9    (2 << 4)
#define DB2_COLORIMETRY_NODATA  (0 << 6) // should be used for RGB output
#define DB2_COLORIMETRY_170M    (1 << 6)

#define DB3_RGB_LIMITEDRANGE    (1 << 2)
#define DB3_RGB_FULLRANGE       (2 << 2)
#define DB3_ITCONTENT           (1 << 7)

#define DB5_PIXELREP_NONE       (0 << 0)
#define DB5_PIXELREP_2          (1 << 0)
#define DB5_CONTENT_GAME        (3 << 4)

// codes for 4:3, add 1 for 16:9
#define VIC_240p   8
#define VIC_288p  23
#define VIC_480i   6
#define VIC_576i  21
#define VIC_480p   2
#define VIC_576p  17

static const uint8_t mode_to_vic[VIDMODE_COUNT] = {
  VIC_240p,
  VIC_288p,
  VIC_480i,
  VIC_576i,
  VIC_480p,
  VIC_576p,
  VIC_480p // technically this should be 0, but based on OSSC reports some sinks don't like that
};

static uint8_t packetbody[4 * 7];

static void update_checksum(void) {
  uint8_t sum = 0x82 + 0x02 + 0x0d; // header is constant
  for (unsigned int i = 1; i < sizeof(packetbody); i++) {
    sum += packetbody[i];
  }

  packetbody[0] = (256 - sum) & 0xff;
}

static void store_shuffled(volatile uint32_t* target) {
  uint32_t header = 0x0d0282 << 4;
  uint8_t *ptr = packetbody;

  for (unsigned int i = 0; i < 7; i++) {
    for (unsigned int j = 0; j < 8; j += 2) {
      uint32_t val = 0;

      if (header & (1 << (4*i + j/2))) {
        val |= 1 << 0;
      }

      if (ptr[0] & (1 << j)) {
        val |= 1 << 1;
      }
      if (ptr[0] & (2 << j)) {
        val |= 1 << 2;
      }

      // not needed for AVI frames without bar info
#if 0
      if (ptr[7] & (1 << j)) {
        val |= 1 << 3;
      }
      if (ptr[7] & (2 << j)) {
        val |= 1 << 4;
      }

      if (ptr[14] & (1 << j)) {
        val |= 1 << 5;
      }
      if (ptr[14] & (2 << j)) {
        val |= 1 << 6;
      }

      if (ptr[21] & (1 << j)) {
        val |= 1 << 7;
      }
      if (ptr[21] & (2 << j)) {
        val |= 1 << 8;
      }
#endif
      *target++ = val;
    }
    ptr++;
  }
}

static void build_one_set(uint32_t offset, uint8_t aspect, uint8_t vic, uint8_t pixelrep) {
  packetbody[1] = DB1_SCANINFO_OVERSCAN | DB1_BARINFO_NONE | DB1_COLOR_RGB;
  packetbody[2] = aspect | DB2_COLORIMETRY_NODATA;
  packetbody[3] = DB3_ITCONTENT | DB3_RGB_FULLRANGE;
  packetbody[4] = vic;
  packetbody[5] = DB5_CONTENT_GAME | pixelrep;
  update_checksum();
  store_shuffled(IFRAM->data + offset);

  packetbody[3] = DB3_ITCONTENT | DB3_RGB_LIMITEDRANGE;
  update_checksum();
  store_shuffled(IFRAM->data + offset + 32);
}


void update_infoframe(video_mode_t outmode) {
  if ((video_settings_global & VIDEOIF_SET_SPOOFINTERLACE) &&
      outmode <= 1) {
    /* use 480i/576i VIC for 240p/288p */
    outmode += 2;
  }

  uint8_t vic = mode_to_vic[outmode];

  if (video_settings_global & VIDEOIF_SET_169)
    vic++;

  uint8_t pixelrep;
  if (VIDEOIF->flags & VIDEOIF_FLAG_LD_31KHZ) {
    pixelrep = DB5_PIXELREP_NONE;
  } else {
    pixelrep = DB5_PIXELREP_2;
  }

  build_one_set(256, DB2_FRAMEASPECT_4_3, vic, pixelrep);
  build_one_set(384, DB2_FRAMEASPECT_16_9, vic + 1, pixelrep);
}
