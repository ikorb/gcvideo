#include <stdbool.h>
#include <stdio.h>
#include "portdefs.h"
#include "icap.h"

static uint8_t icap_flags = 0;

static void icap_set_flags(uint8_t newvalue) {
  icap_flags = newvalue;
  SPICAP->icap_flags = newvalue;
}

static void icap_toggleclock(void) {
  SPICAP->icap_flags = icap_flags | ICAP_FLAG_CLOCK;
  SPICAP->icap_flags = icap_flags;
}

static void icap_write(uint16_t value) {
  SPICAP->icap_data = value >> 8;
  icap_toggleclock();
  SPICAP->icap_data = value & 0xff;
  icap_toggleclock();
}

static uint16_t icap_read(void) {
  uint16_t value = 0;
  bool timeout = true;

  for (unsigned int i = 0; i < 30; i++) {
    icap_toggleclock();
    if (!(SPICAP->icap_flags & ICAP_FLAG_BUSY)) {
      value = SPICAP->icap_data << 8;
      timeout = false;
      break;
    }
  }

  if (timeout)
    printf("timeout\n");

  icap_toggleclock();
  value |= SPICAP->icap_data;
  icap_toggleclock();

  return value;
}

void icap_init(void) {
  icap_set_flags(ICAP_FLAG_WRITE);
  icap_toggleclock();
  icap_toggleclock();
  icap_set_flags(ICAP_FLAG_WRITE | ICAP_FLAG_CE);
  icap_write(0xffff);
  icap_write(0xaa99);
}

void icap_noop(void) {
  icap_write(ICAP_HEADER_TYPE1 | ICAP_OPCODE_NOOP);
}

void icap_write_register(uint16_t reg, uint16_t value) {
  icap_write(reg | ICAP_HEADER_TYPE1 | ICAP_OPCODE_WRITE | 1);
  icap_write(value);
}

uint16_t icap_read_register(uint16_t reg) {
  icap_write(reg | ICAP_HEADER_TYPE1 | ICAP_OPCODE_READ | 1);

  // two dummy accesses needed
  icap_noop();
  icap_noop();

  // switch to read mode
  icap_set_flags(0);
  icap_toggleclock();
  icap_set_flags(ICAP_FLAG_CE);

  uint16_t value = icap_read();

  // switch back to write mode
  icap_set_flags(0);
  icap_toggleclock();
  icap_set_flags(ICAP_FLAG_WRITE | ICAP_FLAG_CE);
  icap_noop();

  return value;
}
