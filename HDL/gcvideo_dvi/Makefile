# -*- mode: makefile-gmake -*-
#
# GCVideo DVI HDL
# Copyright (C) 2014-2021, Ingo Korb <ingo@akana.de>
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
# Makefile: Main makefile for GCVideo-DVI FPGA code,
#           bundles main+flasher into a single binary
#

VERSION := 3.1

PROMFILE := gcvideo-dvi-$(TARGET)-$(VERSION)-spirom
PROMTYPE := M25P40
XSVFFILE := gcvideo-dvi-$(TARGET)-$(VERSION)-$(PROMTYPE)-complete.xsvf
PART     := xc3s200a
OBJCOPY  := zpu-elf-objcopy

ifeq ($(TARGET),p2xh-gc)
  # P2XG
  HWID     := 0x50325847
  TOPLEVEL := toplevel_p2xh
  BOARD    := p2xh
  CONSOLE  := GC
else ifeq ($(TARGET),p2xh-wii)
  # P2XW
  HWID     := 0x50325857
  TOPLEVEL := toplevel_p2xh
  BOARD    := p2xh
  CONSOLE  := WII
else ifeq ($(TARGET),shuriken-gc)
  # SHUG
  HWID     := 0x53485547
  TOPLEVEL := toplevel_shuriken
  BOARD    := shuriken
  CONSOLE  := GC
else ifeq ($(TARGET),shuriken-wii)
  # SHUW
  HWID     := 0x53485557
  TOPLEVEL := toplevel_shuriken
  BOARD    := shuriken
  CONSOLE  := WII
else ifeq ($(TARGET),shuriken-v3-gc)
  # SH3G
  HWID     := 0x53483347
  TOPLEVEL := toplevel_shuriken
  BOARD    := shuriken-v3
  CONSOLE  := GC
else ifeq ($(TARGET),shuriken-v3-wii)
  # SH3W
  HWID     := 0x53483357
  TOPLEVEL := toplevel_shuriken
  BOARD    := shuriken-v3
  CONSOLE  := WII
else ifeq ($(TARGET),dual-gc)
  # GCDU
  HWID     := 0x47434455
  TOPLEVEL := toplevel_gcdual
  BOARD    := dualgc
  CONSOLE  := GC
else ifeq ($(TARGET),dual-wii)
  # WIID
  HWID     := 0x57494944
  TOPLEVEL := toplevel_wiidual
  BOARD    := dualwii
  CONSOLE  := WII
else ifeq ($(TARGET),gcplug)
  # PLUG
  HWID     := 0x504c5547
  TOPLEVEL := toplevel_shuriken
  BOARD    := gcplug
  CONSOLE  := GC
else ifeq ($(TARGET),ave-hdmi)
  # HDMI
  HWID     := 0x48444D49
  TOPLEVEL := toplevel_avehdmi
  BOARD    := ave-hdmi
  CONSOLE  := WII
else
dummy:
	@echo "TARGET variable not specified"
	@echo "Please select a build target using \"make TARGET=...\""
	@echo "Valid targets:"
	@echo "  - p2xh-gc"
	@echo "  - p2xh-wii"
	@echo "  - shuriken-gc"
	@echo "  - shuriken-wii"
	@echo "  - shuriken-v3-gc"
	@echo "  - shuriken-v3-wii"
	@echo "  - dual-gc"
	@echo "  - dual-wii"
	@echo "  - gcplug"
  @echo "  - ave-hdmi"
	@false
endif

# Enable verbose compilation with "make V=1"
ifdef V
 Q :=
 E := @:
else
 Q := @
 E := @echo
endif

CONSOLE_LC := $(shell echo $(CONSOLE)|tr A-Z a-z)


all: build/$(PROMFILE)-complete.bin build/$(XSVFFILE) build/$(PROMFILE)-impact.mcs

build/$(XSVFFILE): build/$(PROMFILE)-impact.mcs
	$(E) "---- XSVFGEN  $<"
	$(Q) sed -e "s/%PART%/$(PART)/;s/%MCSFILE%/$(PROMFILE)-impact.mcs/;s/%PROMTYPE%/$(PROMTYPE)/;s/%XSVFFILE%/$(XSVFFILE)/" scripts/impact-genxsvf.cmd > build/genxsvf-$(TARGET).cmd
	$(Q)cd build ; impact -batch genxsvf-$(TARGET).cmd

# note: promgen -r ... generates a corrupt file, objcopy works fine
build/%-complete.bin: build/%-impact.mcs
	$(E) "---- MCS2BIN  $@"
	$(Q)$(OBJCOPY) --gap-fill 0xff -I ihex -O binary $< $@

build/$(PROMFILE)-impact.mcs: build/main-$(TARGET)/$(TOPLEVEL).tagmain build/flasher-$(TARGET)/$(TOPLEVEL).tagflasher build/flasher-$(TARGET)/$(TOPLEVEL).bit
	$(E) "---- PROMGEN  $@"
	$(Q)promgen -spi -u 0 build/flasher-$(TARGET)/$(TOPLEVEL).bit \
		-data_file up 2ffe8 build/flasher-$(TARGET)/$(TOPLEVEL).tagflasher \
		-data_file up 30000 build/main-$(TARGET)/$(TOPLEVEL).tagmain \
		-w -p mcs -o $@

build/%.tagmain: build/%.bin
	$(E) "---- TAG      $@"
	$(Q)scripts/fwtagger-main.pl $(HWID) $(VERSION) $< $@

build/%.tagflasher: build/%.bit
	$(E) "---- TAG      $@"
	$(Q)scripts/writetag-flasher.pl $(HWID) $(VERSION) $@

build/main-$(TARGET)/$(TOPLEVEL).bin: FORCE
	$(E) "---- MAKE main"
	$(Q)$(MAKE) -f scripts/Makefile.common TARGET=$(TARGET) MODULE=main HWID=$(HWID) VERSION=$(VERSION) V=$(V)

build/flasher-$(TARGET)/$(TOPLEVEL).bit: FORCE
	$(E) "---- MAKE main"
	$(Q)$(MAKE) -f scripts/Makefile.common TARGET=$(TARGET) MODULE=flasher HWID=$(HWID) VERSION=$(VERSION) V=$(V)

clean:
	$(E) "---- CLEAN"
	-$(Q)$(MAKE) -f scripts/Makefile.common TARGET=$(TARGET) MODULE=main V=$(V) clean
	-$(Q)$(MAKE) -f scripts/Makefile.common TARGET=$(TARGET) MODULE=flasher V=$(V) clean

printversion:
	@echo $(VERSION)

.PHONY : FORCE all clean printversion dummy

.PRECIOUS : build/%.tagmain build/main-$(TARGET)/$(TOPLEVEL).bin build/flasher-$(TARGET)/$(TOPLEVEL).bit
