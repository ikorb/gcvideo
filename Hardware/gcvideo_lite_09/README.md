# GCVideo Lite 0.9 #

This is the first prototype GCVideo Lite board with analog outputs in
RGB and Component/YPbPr formats, revision 0.9. This revision has a few
minor annoyances, but has proven to work.

## Connectors ##

The board has five connectors and one jumper: The main signal and
power input is the 11x2 connector P1 which connects to the GameCube
Digital Video port. The 6x1 connector on the side is the JTAG
connector which is needed to program the FPGA on the board. Signal
outputs are on the 5x1 and 4x1 connectors. There is also a 2x2
connector labelled "spare" next to the P1 and JTAG connectors which
at this time is mostly unused except for one pin that outputs an SPDIF
audio signal.

The single jumper on the board is located next to the JTAG connector
and consists of two solder pads. If these pads are bridged, the FPGA
will output RGB signals, if they are open it will output component
signals. 

### P1 (11x2) ###

The board is connected to the GameCube's digital video port using the
pins of the P1 connector. Since the original connector in the GameCube
is proprietary and no alternative is known, this needs to be done
using wires. It is strongly recommended to keep these wires as short
as possible since one of them is a 54MHz clock signal. Be absolutely
sure to not connect or bridge anything to pin 5 (+12V) - an accidental
short between that pin and any of the data lines will instantly fry
the Gamecube.

The pins of the P1 connector on the GCVideo Lite board correspond 1:1
with the pins of the GC's digital video connector, pin 1 is marked
with a square instead of a round pad. [This
site](http://gamesx.com/wiki/doku.php?id=av:nintendodigitalav) shows
the pin numbering directly on the connector. Alternatively, if you
look at the bottom of the GameCube's main PCB with the video
connectors facing away from you, pin 1 of the DV connector should be
the bottom right pin, pin 2 the one above it. There are also numbers
for the outermost pins marked besides the connector on the top side.

I have no idea what your options are if you have a later-model
GameCube where Nintendo removed the digital AV port.

### JTAG (6x1) ###

The FPGA has an internal configuration memory which is blank when it
is delivered from the factory. To program the FPGA, you need a
JTAG interface suitable for use with Lattice's software - I use a
clone of the HW-USBN-2A cable, but the software also supports a
parallel port cable (no idea about the pinout) or FT2232D-based USB
devices (look for Lattice application note AN8082 for the schematic).

On the software side, the FPGA can be programmed using the Lattice
Diamond software package. Although it may appear a bit large at about
1.5 GByte download size, this is quite small compared to similar
packages from other FPGA vendors. ;)
If programming the internal configuration flash of the XO2 fails, try
the .jed file instead of the .bit file.

### Video (5x1) ###

The video output connector is the 5x1 connector on the side of the
board. Pin 1 is marked using a square instead of a round pad and
outputs the R (RGB) or Pr (Component, red plug) signal. Pins 2 and 4
are ground pins. Pin 3 (the middle one) outputs the G (RGB) or Y
(Component, green plug) signal, Pin 5 outputs the B (RGB) or Pb
(Component, blue plug) signal. There is also a tiny label hidden
between the resistors and capacitors saying "B-G-R" which uses "-" as
a shorthand for ground.

### Sync (4x1) ###

The GCVideo Lite board has a dedicated connector for sync signals. You
can ignore it if you only want to output Component video, but it is
required if you want to use RGB. The pins are labelled "C V H -" on
the sikscreen. The "-" pin is ground, "V" and "H" are vertical and
horizontal sync signals and "C" is a composite sync signal. The
composite sync signal should be directly usable e.g. for connections
to SCART televisions or scalers like an XRGB Mini that need a
composite sync while the V- and H-Sync signals can be used for VGA
inputs - but remember that the GameCube outputs 15kHz video during
startup and not every game supports 480p!

While the hardware could support RGB with Sync-on-Green, this is
currently not implemented.

### Spare (2x2) ###

The 2x2 pin group marked "Spare" in the corner of the group is unused
except for the square pin next to P1. This pin is used to output an
SPDIF audio signal. For more information on interfacing this signal to
an SPDIF receiver, please check the [README.md of the gcvideo_lite HDL
project](../../HDL/gcvideo_lite/README.md).

Please do not connect this pin directly to a coaxial SPDIF input, the
feature was added after the board was designed and there is no
protection on this pin.


## Building ##

The PCB uses four layers, so it is not suitable for etching at home,
but there are many prototyping services available that offer small
runs of a PCB. The prototype has been ordered from
[OSHPark](http://www.oshpark.com) and the zip file with the data they
require has been included in the repository.

The values of the parts are marked within their footprint in rather
tiny letters, alternatively you can look at the [BOM.csv](BOM.csv)
file for the value corresponding to each of the component references.

## Audio ##

There are currently two options for the audio signal from the Gamecube
when GCVideo Lite is used as the video encoder. The first option is to
use the audio signals from the analog AV port as usual. The second
option is to use the SPDIF encoder implemented in GCVideo Lite. The
[README.md of the gcvideo_lite HDL
project](../../HDL/gcvideo_lite/README.md) has more information about
connecting this signal - since it was added after the board was
designed, no protection is present on the signal and a direct
connection to an SPDIF input may destroy the FPGA.

## Known issues ##

* The drill holes for the JTAG and output video/sync connectors are
    slightly too small to fit standard 2.54mm pitch pin headers.
* The pads of the two ICs (from KiCADs standard footprint library) are
    meant for reflow soldering, not hand soldering. It is still
    possdo not need to use ible to hand-solder these chips, but it takes a lot of
    patience.
* The "component cable connected" pin is always active, which causes
    some homebrew applications to switch into 480p mode by
    default. This can be problematic for users of SD-only monitors,
    but since the board must be connected to the cube using wires
    anyway, leaving out the connection of pin 1 (or adding a switch in
    that line) can fix this issue.
* Trace width could be increased for some of the supply traces on the
    top and bottom layers.
* Vias are a bit large-ish.

## Other Systems ##

With a different program in the FPGA it is be possible to use the
same board to provide RGB and/or Component outputs for an N64, see
the [gcvideo_lite_n64](../gcvideo_lite_n64/README.md) directory for
details.

Measurements on a Wii board indicate that thare is an internal video
data bus that may use the same signals as the GameCube's digital video
port, but since the Wii already supports Component video natively
there isn't much reason to actually use this board on a Wii. It may
need some hardware changes as the Wii uses 1.8V signal levels instead
of the 3.3V seen on a GameCube.
