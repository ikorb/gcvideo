/* GCVideo DVI Updater

   Copyright (C) 2019-2020, Ingo Korb <ingo@akana.de>
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


   main.c: A very hardcoded image viewer

*/

#include <malloc.h>
#include <stdint.h>
#include <stdio.h>
#include <ogcsys.h>
#include <gccore.h>
#include <string.h>

#ifdef TARGET_WII
#include <wiiuse/wpad.h>
#endif

#define START_LINE 80
#define DATA_ADDRESS 0x80800000

static const uint32_t signature[] = {
  // gcvupd10
  0x67637675, 0x70643130
};

/* structure:
 * 2 words signature
 * 2 words version (8 ASCII chars)
 * 1 word  screen count
 * n words screen offsets
 * remainder screens
 */
static const uint32_t* updatedata = (uint32_t*)DATA_ADDRESS;

static volatile int wii_button_action = 0;

#ifdef TARGET_WII

static void wii_reset_button(unsigned int unused, void* unused2) {
  wii_button_action = SYS_RETURNTOMENU;
}

static void wii_power_button(void) {
  wii_button_action = SYS_POWEROFF;
}

static void wiimote_power_button(int unused) {
  wii_button_action = SYS_POWEROFF;
}

static void init_console(void) {
  PAD_Init();
  WPAD_Init();
  WPAD_SetDataFormat(WPAD_CHAN_ALL, WPAD_FMT_BTNS);

  SYS_SetResetCallback(wii_reset_button);
  SYS_SetPowerCallback(wii_power_button);
  WPAD_SetPowerButtonCallback(wiimote_power_button);
}

static void handle_button_action(void) {
  SYS_ResetSystem(wii_button_action, 0, 0);
}

static void scan_pads(void) {
  PAD_ScanPads();
  WPAD_ScanPads();
}

static u32 read_buttons(void) {
  u32 buttons = PAD_ButtonsDown(0);
  u32 wiibuttons = WPAD_ButtonsDown(0);

  if (wiibuttons & WPAD_BUTTON_HOME) {
    buttons |= PAD_BUTTON_START;
  }

  return buttons;
}

#else

static void init_console(void) {
  PAD_Init();
}

static void handle_button_action(void) {}

static void scan_pads(void) {
  PAD_ScanPads();
}

static u32 read_buttons(void) {
  return PAD_ButtonsDown(0);
}

#endif

static GXRModeObj rmode;
static uint32_t *xfb = NULL;
static char updversion[9] = { 0 };

static const uint32_t* screenoffsets;

static uint32_t screencount(void) {
  return updatedata[4];
}

static void show_failure(void) {
  printf("\n\n"
         "    GCVideo Firmware Updater v" VERSION "\n"
         "    >> This updater is unconfigured, please use a configured one instead! <<\n"
         "    Press Start or Home to exit.\n");

  while (wii_button_action == 0) {
    VIDEO_WaitVSync();
    scan_pads();

    uint16_t buttons = read_buttons();

    if (buttons & PAD_BUTTON_START) {
      break;
    }
  }
}

static void plot(unsigned int x, unsigned int y, uint16_t color) {
  unsigned int offset = (y * rmode.fbWidth + x) / 2;

  uint32_t pixel = xfb[offset];

  if (x & 1) {
    pixel &= 0xffff0000;
    pixel |= color;
  } else {
    pixel &= 0x0000ffff;
    pixel |= color << 16;
  }
  xfb[offset] = pixel;
}

static void display_updatedata(void) {
  memcpy(updversion, updatedata + 2, 8);
  screenoffsets = updatedata + 5;

  /* draw a special pattern for diagnostics in the first two lines */
  for (unsigned int x = 0; x < 220; x++) {
    uint16_t color = x + 16;
    color = (color << 8) | color;

    for (unsigned int y = 0; y < 2; y++) {
      plot(x +   1, y, color);
      plot(x + 221, y, color);
      plot(x + 441, y, color);
    }
  }

  printf("\n\n"
         "      GCVideo Firmware Updater v" VERSION ", containing GCVideo %s\n"
         "      Please select About->Update Firmware in the GCVideo menu.\n"
         "      Press Start or Home to exit the updater.\n", updversion);

  while (wii_button_action == 0) {
    for (unsigned int i = 0; i < screencount(); i++) {
      memcpy(xfb + START_LINE * rmode.fbWidth / 2,
             updatedata + screenoffsets[i],
             4 * (screenoffsets[i + 1] - screenoffsets[i]));

      /* wait for two VSyncs to make sure both fields have been shown */
      for (unsigned int j = 0; j < 2; j++) {
        VIDEO_WaitVSync();
        scan_pads();

        uint16_t buttons = read_buttons();
        if (buttons & PAD_BUTTON_START) {
          return;
        }
      }
    }
  }
}

int main(int argc, char **argv) {
  VIDEO_Init();
  init_console();

  // fixed 720x480 interlaced mode
  rmode = TVNtsc480Int;
  rmode.viWidth = 720;
  rmode.fbWidth = 720;

  xfb = MEM_K0_TO_K1(SYS_AllocateFramebuffer(&rmode));
  CON_Init(xfb, 0, 0, rmode.fbWidth, rmode.xfbHeight, rmode.fbWidth * VI_DISPLAY_PIX_SZ);

  VIDEO_Configure(&rmode);
  VIDEO_SetNextFramebuffer(xfb);
  VIDEO_SetBlack(FALSE);
  VIDEO_Flush();
  VIDEO_WaitVSync();

  if (rmode.viTVMode & VI_NON_INTERLACE)
    VIDEO_WaitVSync();

  /* extract update data */
  if (updatedata[0] != signature[0] || updatedata[1] != signature[1]) {
    show_failure();
  } else {
    display_updatedata();
  }

  printf("\e[2J\n\n     Exiting...");

  if (wii_button_action) {
    handle_button_action();
  }

  return 0;
}
