This directory contains the HDL code for GCVideo Lite.

Current features:
* Analog RGB and Component output

There are two precompiled bitstreams in this directory, a `.bit` and a
`.jed` file. Lattice Diamond will accept either one for programming
the internal configuration flash, but that process always fails for me
unless I use the `.jed` file. On the other hand, the quick SRAM upload
requires the `.bit` file, so both have been included.
