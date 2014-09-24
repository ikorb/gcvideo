This directory contains the HDL code for GCVideo Lite.

Current features:
* Analog RGB and Component output

There are three precompiled bitstreams in this directory, a `.bit`, a
`.jed` and a `.svf` file. Lattice Diamond will accept either one for programming
the internal configuration flash, but that process always fails for me
unless I use the `.jed` file. On the other hand, the quick SRAM upload
requires the `.bit` file, so both have been included. The `.svf` file
is useful for programming the chip with non-Lattice tools which
support SVF playback, e.g. Xilinx' Impact.

