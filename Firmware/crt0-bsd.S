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


   crt0-bsd.S: BSD-licensed crt0/premain replacement for ZPU

   Note: This is only suitable for a ZPUFlex with all
         optional features turned ON.
         It also requires a suitable linker script that defines
         a section for each emulated instruction.

*/

        ;;  convenience macros for saving restoring the pseudo regs
        ;; fixed addresses force gas to emit only one-byte im insns
        ;; -- r2 r1 r0
        .macro save_memregs
        im      8
        load
        im      12
        load
        im      16
        load
        .endm

        ;; r2 r1 r0 --
        .macro restore_memregs
        im      16
        store
        im      12
        store
        im      8
        store
        .endm



        /* ---- reset vector ---- */
        .section ".reset_vector", "ax"

        .global _start
_start:
        im      clearbss
        poppc


        /* ---- pseudo registers in memory ---- */
        /* assumed to be at address 8/12/16 by save_memregs/restore_memregs */
        .section ".memory_regs", "aw"

        .global _memreg
_memreg:
        .long   0               ; 8
        .long   0               ; 12
        .long   0               ; 16
        .long   0xffff          ; 20 - constant for masks

        /* ---- interrupt vector ---- */
        .section ".interrupt_vector", "ax"

        ;; interrupt handler
        .weak irq_handler
        .set  irq_handler, _infinite_loop
        
_interrupt_handler:
        save_memregs
        im      irq_handler
        call
        restore_memregs
        poppc

        ;; default handler: endless loop
_infinite_loop:
        im      _infinite_loop
        poppc


        /* ---- emulation instructions ---- */

        ;; -- loadh --
        .section ".emulate_loadh", "ax"
_emulate_loadh:
        ;; load data from word address
        loadsp  4               ; [addr ret addr]
        im      ~2              ; [~2 addr ret addr]
        and                     ; [maskaddr ret addr]
        load                    ; [fval ret addr]

        ;; mask bit 1 of address to determine high/low halfword
        loadsp  8               ; [addr fullval ret addr]
        not                     ; [naddr fullval ret addr]
        im      2               ; [2 naddr fval ret addr]
        and                     ; [offset[0/2] fval ret addr]
        im      3               ; [3 offset[0/2] fval ret addr]
        ashiftleft              ; [shift[0/16] fval ret addr]

        ;; move value to bottom (will either shift down or do nothing)
        lshiftright             ; [shiftedval ret addr]
        ;; mask lower 16 bits
        im      0xffff          ; [0xffff shiftedval ret addr]
        and                     ; [val ret addr]
        ;; store into result slot and return
        storesp 8               ; [ret val]
        poppc


        ;; -- storeh --
        .section ".emulate_storeh", "ax"
_emulate_storeh:
        ;; calculate the number of bits to shift the value
        loadsp  4               ; [addr ret addr val]
        not                     ; invert (big endian)
        im      2               ;
        and                     ; [offset[0/2] ret addr val]
        im      3
        ashiftleft              ; [shift ret addr val]

        ;; load current content of word address
        loadsp  8
        im      ~2
        and                     ; [wordaddr shift ret addr val]
        loadsp  0               ; [wordaddr wordaddr shift ret addr val]
        storesp 16              ; rewrite addr to wordaddr
        load                    ; [ramval shift ret waddr val]

        ;; mask unused part of ramval
        im      20
        load                    ; [0xffff ramval shift ...]
        loadsp  8
        ashiftleft              ; [mask ramval shift ret waddr val]
        not
        and                     ; [mramval shift ret waddr val]

        ;; add in the new value
        loadsp  16              ; [val mramval shift ret ...]
        im      20
        load
        and
        loadsp  8
        ashiftleft              ; [shiftval mramval shift ret ...]
        or                      ; [newramval shift ret waddr val]

        ;; store at word address
        loadsp  12
        store                   ; [shift ret waddr val]

        ;; drop remaining values and return
        storesp 0               ; [ret waddr val]
        storesp 8               ; [waddr ret]
        storesp 0               ; [ret]
        poppc


        ;; -- neg --
        ;; [ret value]
        .section ".emulate_neg", "ax"
_emulate_neg:
        loadsp  4               ; [value ret value]
        not                     ; [notval ret value]
        im      1
        add                     ; [negval ret value]
        storesp 8               ; [ret value]
        poppc


        ;; -- loadb --
        ;; [ret addr] -> [value]
        .section ".emulate_loadb", "ax"
_emulate_loadb:
        ;; load data from word address
        loadsp  4               ; [addr ret addr]
        im      ~3
        and
        load                    ; [fullval ret addr]

        ;; calculate the shift value
        loadsp  8               ; [addr fullval ret addr]
        not
        im      3
        and                     ; [offset[0-3] fullval ret addr]
        im      3
        ashiftleft              ; [shift[0/8/16/24] fullval ret addr]

        ;; shift target byte down and mask lowest byte
        lshiftright
        im      0xff
        and                     ; [val ret addr]

        ;; store in result slot and return
        storesp 8               ; [ret val]
        poppc


        ;; -- storeb --
        .section ".emulate_storeb", "ax"
_emulate_storeb:
        ;; calculate the number of bits to shift the value
        loadsp  4               ; [addr ret addr val]
        not                     ; invert (big endian)
        im      3               ;
        and                     ; [offset[0-3] ret addr val]
        im      3
        ashiftleft              ; [shift ret addr val]

        ;; load current content of word address
        loadsp  8
        im      ~3
        and                     ; [wordaddr shift ret addr val]
        loadsp  0               ; [wordaddr wordaddr shift ret addr val]
        storesp 16              ; rewrite addr to wordaddr
        load                    ; [ramval shift ret waddr val]

        ;; mask unused part of ramval
        im      0xff            ; [0xff ramval shift ...]
        loadsp  8               ; [shift 0xff ramval shift ...]
        ashiftleft              ; [mask ramval shift ret waddr val]
        not
        and                     ; [mramval shift ret waddr val]

        ;; add in the new value
        loadsp  16              ; [val mramval shift ret ...]
        im      0xff
        and
        loadsp  8
        ashiftleft              ; [shiftval mramval shift ret ...]
        or                      ; [newramval shift ret waddr val]

        ;; store at word address
        loadsp  12
        store                   ; [shift ret waddr val]

        ;; drop remaining values and return
        storesp 0               ; [ret waddr val]
        storesp 8               ; [waddr ret]
        storesp 0               ; [ret]
        poppc


        ;; -- div --
        ;; [ret a b] -> [a/b]
        .section ".emulate_div", "ax"
_emulate_div:
        save_memregs
        loadsp  20              ; [b r2 r1 r0 ret a b]
        loadsp  20              ; [a b r2 r1 r0 ret a b]
        im      __divsi3
        call                    ; [a b r2 r1 r0 ret a b]
        im      _memreg
        load                    ; [a/b a b r2 r1 r0 ret a b]
        storesp 8*4             ; [a b r2 r1 r0 ret a a/b]
        storesp 0
        storesp 0               ; [r2 r1 r0 ret a a/b]
        restore_memregs         ; [ret a a/b]
        storesp 4               ; [re a/b]
        poppc


        ;; -- mod --
        ;; [ret a b] -> [a%b]
        .section ".emulate_mod", "ax"
_emulate_mod:
        save_memregs
        loadsp  20              ; [b r2 r1 r0 ret a b]
        loadsp  20              ; [a b r2 r1 r0 ret a b]
        im      __modsi3
        call                    ; [a b r2 r1 r0 ret a b]
        im      _memreg
        load                    ; [a%b a b r2 r1 r0 ret a b]
        storesp 8*4             ; [a b r2 r1 r0 ret a a%b]
        storesp 0
        storesp 0               ; [r2 r1 r0 ret a a%b]
        restore_memregs         ; [ret a a%b]
        storesp 4               ; [re a%b]
        poppc


        ;; -- poppcrel --
        ;; [ret offset] -> []
        .section ".emulate_poppcrel", "ax"
_emulate_poppcrel:
        add
        im      -1
        add
        poppc
        
        
        ;; -- pushpc --
        .section ".emulate_pushpc", "ax"
_emulate_pushpc:
        loadsp  0               ; copy return address [ret ret]
        loadsp  0               ; copy again to modify it [ret ret ret]
        im      -1              ; [-1 ret ret ret]
        add                     ; [ret-1 ret ret]
        storesp 8               ; [ret ret-1]
        poppc


        ;; -- pushspadd --
        ;; [ret offset] -> [offset*4 + sp]
        .section ".emulate_pushspadd", "ax"
_emulate_pushspadd:
        pushsp                  ; [sp-4 ret offset]
        im      4               ; adjust for return address
        add                     ; [sp ret offset]
        loadsp  8               ; [offset sp ret offset]
        im      2
        ashiftleft
        add                     ; [adjsp ret offset]
        storesp 8               ; [ret adjsp]
        poppc


        ;; -- callpcrel --
        ;; [ret reladdr]
        .section ".emulate_callpcrel", "ax"
_emulate_callpcrel:
        loadsp  0               ; [ret ret reladdr]
        im      -1
        add                     ; [ret-1 ret reladdr]
        addsp   8               ; [targaddr ret reladdr]
        loadsp  4               ; [ret targaddr ret reladdr]
        storesp 12              ; [targaddr ret ret]
        storesp 4               ; [targaddr ret]
        poppc
        

        /* ---- remaining startup --- */

        .section ".startup_remainder", "ax"
        ;; clear BSS
clearbss:
        im      __bss_start__   ; ptr
bssloop:
        loadsp  0               ; ptr ptr
        im      __bss_end__     ; end ptr ptr
        sub                     ; diff ptr
        impcrel bssdone         ; relpc diff ptr
        eqbranch                ; ptr
        im      0               ; 0 ptr
        loadsp  4               ; ptr 0 ptr
        store                   ; ptr
        im      4               ; 4 ptr
        add                     ; newptr
        im      bssloop         ; bssloop newptr
        poppc

bssdone:
        im      main            ; main newptr
        storesp 4               ; main
        call
        im      _infinite_loop
        poppc

        .end
