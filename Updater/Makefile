# GCVideo DVI Updater
#
# Copyright (C) 2015-2020, Ingo Korb <ingo@akana.de>
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

VERSION := 1.0

ifeq ($(TARGET),gc)
  MACHINE := cube
  TARGET_CFLAGS := -mogc -DTARGET_GC
  TARGET_LIBS := -logc
else ifeq ($(TARGET),wii)
  MACHINE := wii
  TARGET_CFLAGS := -mrvl -DTARGET_WII
  TARGET_LIBS := -lwiiuse -lbte -logc
else
dummy:
	@echo "TARGET variable not specified"
	@echo "Please select a build target using"
	@echo "  \"make TARGET=gc\" or"
	@echo "  \"make TARGET=wii\""
endif

CROSS_PREFIX=$(DEVKITPPC)/bin/powerpc-eabi-
CC := $(CROSS_PREFIX)gcc
LD := $(CROSS_PREFIX)ld
AS := $(CROSS_PREFIX)as
CFLAGS = -Wall -Werror -Os -g -std=gnu99 -ffunction-sections -fdata-sections -I. \
         -DVERSION=\"$(VERSION)\" $(EXTRA_CFLAGS)
LIBS := $(TARGET_LIBS) -lm
LDFLAGS := -Wl,--gc-sections -Wl,--relax -L$(DEVKITPRO)/libogc/lib/$(MACHINE)

OBJDIR := obj-$(TARGET)

BASENAME := gcvupdater
SRCFILES := main.c

GENDEPFLAGS = -MMD -MP -MF .dep/$(@F).d

# Enable verbose compilation with "make V=1"
ifdef V
 Q :=
 E := @:
else
 Q := @
 E := @echo
endif

EXTRA_CFLAGS := -DGEKKO $(TARGET_CFLAGS) -mcpu=750 -meabi -mhard-float -I$(DEVKITPRO)/libogc/include -I$(DEVKITPRO)/libogc/lib/$(MACHINE)

OBJFILES := $(patsubst %,$(OBJDIR)/%,$(SRCFILES:.c=.o))

all: $(OBJDIR)/$(BASENAME).dol

%.dol: %.elf
	$(E) "  ELF2DOL  $@"
	$(Q)elf2dol $< $@

$(OBJDIR)/$(BASENAME).elf: $(OBJFILES)
	$(E) "  LINK     $@"
	$(Q)$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $^ $(LIBS)

$(OBJDIR)/%.o: %.S | $(OBJDIR)
	$(E) "  AS       $<"
	$(Q)$(CC) $(CFLAGS) -c -o $@ $<

$(OBJDIR)/%.o: %.c | $(OBJDIR)
	$(E) "  CC       $<"
	$(Q)$(CC) $(CFLAGS) $(GENDEPFLAGS) -c -o $@ $<

# Create the output directory
$(OBJDIR):
	$(E) "  MKDIR    $(OBJDIR)"
	$(Q)mkdir -p $(OBJDIR)

clean:
	$(E) "  CLEAN"
	$(Q)-rm -f $(OBJDIR)/$(BASENAME).bin $(OBJDIR)/$(BASENAME).elf $(OBJDIR)/$(BASENAME).dol
	$(Q)-rm -f $(OBJDIR)/$(BASENAME).mem $(OBJDIR)/$(BASENAME).mif $(OBJFILES)
	$(Q)-rm -f .dep/*
	$(Q)-rmdir .dep $(OBJDIR)

.PRECIOUS : %.bin

-include $(shell mkdir .dep 2>/dev/null) $(wildcard .dep/*)
