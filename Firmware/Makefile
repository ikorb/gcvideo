# GCVideo DVI Firmware
#
# Copyright (C) 2015, Ingo Korb <ingo@akana.de>
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
# THE POSSIBILITY OF SUCH DAMAGE.
#
#
# Makefile: program construction rules
#

VERSION := 2.1

PERL := perl
CROSS_PREFIX=zpu-elf-
CC := $(CROSS_PREFIX)gcc
LD := $(CROSS_PREFIX)ld
AS := $(CROSS_PREFIX)as
CFLAGS = -Wall -Os -g -std=gnu99 -ffunction-sections -fdata-sections -I. -DVERSION=\"$(VERSION)\"
LDFLAGS := -Tstandalone-bsd.ld -Wl,--gc-sections -Wl,--relax -nostartfiles

DATA2MEM := data2mem

TARGET      := gcvideo-sw
CRT0        := crt0-bsd.o
OBJFILES    := $(CRT0) main.o osd.o printf.o pad.o vsync.o menu.o \
	modeset_common.o screen_about.o screen_allmodes.o \
	screen_idle.o screen_mainmenu.o screen_osdsettings.o screen_othersettings.o \
	settings.o spiflash.o
BITFILE_IN  := ../HDL/gcvideo_dvi_p2xh/src/toplevel_p2xh.bit
BITFILE_OUT := ../HDL/gcvideo_dvi_p2xh/src/p2xh_output.bit
MIFFILE_OUT := ../HDL/gcvideo_dvi_p2xh/src/zpu_bootrom.mif
BMMFILE     := ../HDL/gcvideo_dvi_p2xh/src/zpu_bootram_bd.bmm

BRAM_SIZE   := 16384

GENDEPFLAGS = -MMD -MP -MF .dep/$(@F).d

# Enable verbose compilation with "make V=1"
ifdef V
 Q :=
 E := @:
else
 Q := @
 E := @echo
endif

all: mif

.PHONY : inject mif

inject: $(TARGET).mem
	$(E) "  DATA2MEM"
	$(Q)$(DATA2MEM) -bm $(BMMFILE) -bt $(BITFILE_IN) -bd $< -o b $(BITFILE_OUT)

mif: $(TARGET).mif
	$(E) "  COPY     $<"
	$(Q)cp $< $(MIFFILE_OUT)

%.mif: %.bin
	$(E) "  BIN2MIF  $<"
	$(Q)$(PERL) ./bin2mif.pl -swapwords 32 $(BRAM_SIZE) $< $@

%.mem: %.bin
	$(E) "  BIN2MEM  $<"
	$(Q)$(PERL) ./bin2mem.pl $< $@

%.bin: %.elf
	$(E) "  BIN      $@"
	$(Q)$(CROSS_PREFIX)objcopy -O binary $< $@

$(TARGET).elf: $(OBJFILES)
	$(E) "  LINK     $@"
	$(Q)$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $^

%.o: %.S
	$(E) "  AS       $<"
	$(Q)$(CC) $(CFLAGS) -c -o $@ $<

%.o: %.c
	$(E) "  CC       $<"
	$(Q)$(CC) $(CFLAGS) $(GENDEPFLAGS) -c -o $@ $<

clean:
	$(E) "  CLEAN"
	$(Q)-rm -f $(TARGET).bin $(TARGET).elf $(TARGET).mem $(TARGET).mif $(OBJFILES)
	$(Q)-rm -f .dep/*
	$(Q)-rmdir .dep

.PRECIOUS : %.bin

-include $(shell mkdir .dep 2>/dev/null) $(wildcard .dep/*)
