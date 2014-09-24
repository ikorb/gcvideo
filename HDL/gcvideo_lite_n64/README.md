This directory contains the HDL code for using the GCVideo Lite board
as an N64 DAC. The code is based on the documentation of the N64DAC
project by Tim Worthington, found [here](http://members.optusnet.com.au/eviltim/n64rgb/n64rgb.html).

Current features:
* Analog RGB and Component output

There are three precompiled bitstreams in this directory, a `.bit`, a
`.jed` and a `.svf` file. Lattice Diamond will accept either one for programming
the internal configuration flash, but that process always fails for me
unless I use the `.jed` file. On the other hand, the quick SRAM upload
requires the `.bit` file, so both have been included. The `.svf` file
is useful for programming the chip with non-Lattice tools which
support SVF playback, e.g. Xilinx' Impact.

To connect the GCVideo Lite board to the N64, please refer to the
pinout diagrams at [Tim's page](http://members.optusnet.com.au/eviltim/n64rgb/n64rgb.html)
and connect the signals to the following pins of connector P1 on the
GCVideo Lite board - pins not mentioned are left unconnected:

<pre> 2  CLOCK
 3  DSYNC
 4  GND
 7  D0
 9  D1
10  D2
12  D3
13  D4
15  D5
16  D6
17  +3.3V
18  D7
20  GND</pre>

The RGB select jumper pads can be used to choose between RGB and
Component video. All three sync signals on pin header P3 are available
in either mode.
