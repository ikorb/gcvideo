# GCVideo DVI firmware updater #

This directory contains the console application for updating
the firmware of a GCVideo 3.x-based device. It is basically
just an image viewer that gets injected with the firmware
data by the `build-updater.pl` script in the HDL directory.

To build it, you need to have devkitPro with the devkitPPC
toolchain and libraries for Gamecube and/or Wii installed
on your system. The included Makefile assumes that the usual
environment variables are set pointing to devkitPro's
directories.

To build the updater for GameCube, use `make TARGET=gc` and
to build it for Wii, use `make TARGET=wii`. Precompiled binaries
are included in the repository for convenience.
