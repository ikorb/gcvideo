/* GCVideo DVI Firmware

   Copyright (C) 2015-2017, Ingo Korb <ingo@akana.de>
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


   irrx.c: Infrared remote decoder

*/

#include "portdefs.h"
#include "pad.h"
#include "irrx.h"

#define INITIAL_REPEAT_COUNT 5
#define FAST_REPEAT_COUNT    20

/* state-based IR decoder */
typedef enum {
  RX_IDLE,
  RX_NEC_START_PAUSE,
  RX_NEC_REPEAT_PULSE,
  RX_NEC_DATA_PULSE,
  RX_NEC_DATA_SPACE,
  RX_NEC_FINAL_PULSE,
} ir_state_t;

volatile ir_command_t ir_rawcommand;
volatile uint8_t      ir_gotcommand;

ir_command_t ir_codes[NUM_IRCODES] = {
  // default: same remote as used by OSSC
  0x3ec12dd2, // Up
  0x3ec1cd32, // Down
  0x3ec1ad52, // Left
  0x3ec16d92, // Right
  0x3ec11de2, // OK
  0x3ec1ed12, // Exit
};

static const uint32_t ir_buttons[NUM_IRCODES] = {
  IR_UP,
  IR_DOWN,
  IR_LEFT,
  IR_RIGHT,
  IR_OK,
  IR_BACK
};

static ir_state_t rx_state;
static uint8_t    bits_remaining;
static uint32_t   rxdata;
static uint8_t    repeat_counter;
static uint8_t    prev_command;
static tick_t     prev_rx_tick;


static void emit_data(uint32_t data) {
  ir_rawcommand  = data;
  ir_gotcommand  = 1;
  repeat_counter = 0;
  prev_rx_tick   = getticks();

  for (uint8_t i = 0; i < NUM_IRCODES; i++) {
    if (ir_codes[i] == data) {
      pad_set_irq(ir_buttons[i]);
      prev_command = i;
      break;
    }
  }
}

/* trigger the previous button again */
/* (NEC IR code sends repeat every 100-110ms) */
static void emit_repeat(void) {
  /* check if the time delta is reasonable */
  if (time_after(getticks(), prev_rx_tick + HZ / 2))
    return;

  prev_rx_tick = getticks();

  /* vary-speed key repeat */
  if (repeat_counter < FAST_REPEAT_COUNT)
    repeat_counter++;

  /* initial delay */
  if (repeat_counter < INITIAL_REPEAT_COUNT)
    return;

  /* start with slow repeat, then speed up */
  if (repeat_counter < FAST_REPEAT_COUNT &&
      (repeat_counter & 1))
    return;

  pad_set_irq(ir_buttons[prev_command]);
}


void irrx_handler(void) {
  uint32_t   pulsedata    = IRRX->pulsedata;
  uint8_t    pulselen     = pulsedata & IRRX_PULSE_MASK;
  ir_state_t next_state = RX_IDLE;

  /* ignore short glitches */
  if (pulselen < 2)
    return;

  /* update reception state */

  if (pulsedata & IRRX_STATE) {
    /* pulselen is mark */
    switch (rx_state) {
    case RX_IDLE:
      if (pulselen >= 110) {
        next_state = RX_NEC_START_PAUSE;
      }
      break;

    case RX_NEC_REPEAT_PULSE:
      if (pulselen >= 3 && pulselen <= 12) {
        next_state = RX_IDLE;
        emit_repeat();
      }
      break;

    case RX_NEC_DATA_PULSE:
      if (pulselen >= 3 && pulselen <= 12) {
        next_state = RX_NEC_DATA_SPACE;
      }
      break;

    case RX_NEC_FINAL_PULSE:
      if (pulselen >= 3 && pulselen <= 12) {
        next_state = RX_IDLE;
        emit_data(rxdata);
      }
      break;

    default:
      break;
    }

  } else {
    /* pulselen is space */
    switch (rx_state) {
    case RX_IDLE:
      /* ignore timeout at end of transmission */
      if (pulsedata & IRRX_TIMEOUT) {
        next_state = RX_IDLE;
      }
      break;

    case RX_NEC_START_PAUSE:
      /* pause after start pulse, length determines full packet vs. repeat */
      if (pulselen >= 50 && pulselen <= 70) {
        next_state     = RX_NEC_DATA_PULSE;
        bits_remaining = 32;
        rxdata         = 0;
      } else if (pulselen >= 20 && pulselen <= 40) {
        next_state = RX_NEC_REPEAT_PULSE;
      }
      break;

    case RX_NEC_DATA_SPACE:
      if (pulselen >= 3 && pulselen <= 10) {
        rxdata = rxdata << 1;
        bits_remaining--;

        if (bits_remaining)
          next_state = RX_NEC_DATA_PULSE;
        else
          next_state = RX_NEC_FINAL_PULSE;

      } else if (pulselen > 10 && pulselen <= 30) {
        rxdata = (rxdata << 1) | 1;
        bits_remaining--;

        if (bits_remaining)
          next_state = RX_NEC_DATA_PULSE;
        else
          next_state = RX_NEC_FINAL_PULSE;

      }
      break;

    default:
      break;
    }

  }

  rx_state = next_state;
}
