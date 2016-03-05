/* GCVideo DVI Firmware

   Copyright (C) 2015-2016, Ingo Korb <ingo@akana.de>
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


   standalone-bsd.ld: Linker script for crt0-bsd.S for ZPU

*/

OUTPUT_FORMAT(elf32-zpu)
ENTRY(_start)

MEMORY {
  vectors (rwx) : ORIGIN = 0x00000000, LENGTH = 1K
  ram     (rwx) : ORIGIN = 0x00000400, LENGTH = 15K
}

SECTIONS {
  .reset_vector 0x0 : {
    KEEP(*(.reset_vector))
  } > vectors

  .memory_regs 0x8 : {
    KEEP(*(.memory_regs))
  } > vectors

  .interrupt_vector 0x20 : {
    KEEP(*(.interrupt_vector))
  } > vectors

  .emulate_loadh 0x40 : {
    KEEP(*(.emulate_loadh))
  } > vectors

  .emulate_storeh 0x60 : { /* currently one byte too long */
    KEEP(*(.emulate_storeh))
  } > vectors

  .startup_remainder 0x100 : { /* use this big gap here */
    KEEP(*(.startup_remainder))
  } > vectors

  .emulate_neg 0x200 : {
    KEEP(*(.emulate_neg))
  } > vectors

  .emulate_loadb 0x260 : {
    KEEP(*(.emulate_loadb))
  } > vectors

  .emulate_storeb 0x280 : {
    KEEP(*(.emulate_storeb))
  } > vectors

  .emulate_div 0x2a0 : {
    KEEP(*(.emulate_div))
  } > vectors

  .emulate_mod 0x2c0 : {
    KEEP(*(.emulate_mod))
  } > vectors

  .emulate_poppcrel 0x320 : {
    KEEP(*(.emulate_poppcrel))
  } > vectors

  .emulate_pushpc 0x360 : {
    KEEP(*(.emulate_pushpc))
  } > vectors

  .emulate_pushspadd 0x3a0 : {
    KEEP(*(.emulate_pushspadd))
  } > vectors

  .emulate_callpcrel 0x3e0 : {
    KEEP(*(.emulate_callpcrel))
  } > vectors

  .text : {
    *(.text)
    *(.text.*)
    __text_end = .;
  } > ram

  .rodata BLOCK(4) : {
    *(.rodata)
    *(.rodata.*)
    __rodata_end = .;
  } > ram

  .data BLOCK(4) : {
    *(.data)
    *(.data.*)
    __data_end = .;
  } > ram

  .bss BLOCK(4) : {
    __bss_start__ = .;
    *(.bss)
    *(.bss.*)
    *(COMMON)
    __bss_end__ = .;
  } > ram

  __heap_start = ALIGN(4);
}
