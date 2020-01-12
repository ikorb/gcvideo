# GCVideo DVI #

## Introduction ##

GCVideo DVI interfaces from the signals on the Digital Video Port of the
Gamecube to a DVI video signal. It targets a few FPGA boards specially developed
for it by third parties as well as the Pluto IIx HDMI FPGA board from
[KNJN](http://www.knjn.com). The available features may differ depending on the
board.

For those who don't mind extremely fine pitch soldering, it is also possible to
use GCVideo in a Wii.

## Features ##

- direct digital video output with no analog intermediate for best quality
- optional linedoubler to convert 240p/288p/480i/576i modes to 480p/576p
- optional scanline overlay with selectable strength hybrid factor
- SPDIF digital audio output
- user-friendly on-screen configuration
- on-screen menus controlled with a Gamecube controller or an IR
    remote control
- (certain boards only) auxillary analog video output

## Limitations ##

- Linedoubling of 480i/576i modes looks very ugly. If your display
    accepts these modes directly, it is recommended to not use
    linedoubling for them.
- The primary target of the project is the DVI output, the analog output (if
  available) is purely a "bonus feature". Some DVI output settings may disable
  certain analog output options.
- Although GCVideo tries to make the output signal as standards-compliant as
  possible, some homebrew software uses video parameters that are too far away
  from normal video standards to correct them. Such homebrew software may not
  work with some displays.
- GCVideo does not attempt to read the capabilities of the display, so it is
  possible to set the output to something that the display does not support,
  resulting in a corrupted or no picture.

## Requirements ##

- A suitable FPGA board, this documentation assumes the Pluto IIx HDMI. If you
  use a custom board specifically designed for GCVideo DVI, please check with
  your supplier for additional information.
- programmer suitable for the Pluto board board, e.g. KNJN TXDI interface or a
  JTAG programmer with software that can handle a Spartan 3A
- For Pluto IIx board revisions D or earlier: 100 ohm resistor,
  watt rating does not matter

## Directory structure ##

There are five subdirectories:

- `src` contains the VHDL sources and Xilinx ISE project files
- `bin` contains the synthesized bit stream in various formats
- `doc` contains a few images showing the necessary connections
- `codegens` contains two code generators that generate VHDL source
    for two ROMs in the enhanced DVI encoder
- `scripts` contains various scripts used during the build process

## Programming the Pluto IIx HDMI ##

The Pluto IIx HDMI board can be programmed either before or after
installation. Programming it before installation requires an external
power supply, programming it after installation may make it harder to
access the required pins.

One possible way to program the board is to use one of the TXDI
interfaces available from KNJN and their FPGAconf program. This also
requires an RS232 port ("COM port"), although there is at least one
TXDI interface that integrates an RS232-to-USB converter.
Unfortunately FPGAconf does not support writing straight binary files
to the board, the current recommended way is to use a faked bitstream
from (this Github
issue)[https://github.com/ikorb/gcvideo/issues/24#issuecomment-573460301]
and use the integrated firmware updater to install a later release if
needed. In FPGAconf,
you need to use the "Program boot-PROM" button and select the
`gcvideo-dvi-3.0-p2xhgc-fpgaconf.bit` (or p2xhwii) file from the issue
linked above.

Another option to program the board is over the JTAG pins. This is
only recommended for advanced users and requires a JTAG interface with
software that is either able to use indirect programming of an SPI
flash chip connected to a Spartan 3A (e.g. Xilinx's own Impact) or
that can play an SVF file. This way of programming the SPI flash on
the board requires the `gcvideo-dvi-p2xh-gc-X.Y-spirom-impact.mcs` or
`gcvideo-dvi-p2xh-gc-X.Y-M25P40-complete.xsvf` files in the `bin`
subdirectory,
depending on the software you use. The SVF file has been created
assuming that there is a M25P40 chip on the board. KNJN does not
specify which chip they ship, only that it will be at least 4 MBit in
size - if your board has a different flash chip (located on the bottom
side), contact me and I'll try to generate an SVF for it if it's
supported by Xilinx' tools.

KNJN now also sells a version of the board preprogrammed with
GCVideo-DVI, which is probably the easier option for normal users.

## Connecting the Pluto board to a Wii ##

Use of GCVideo-DVI on a Wii is not recommended since the installation
requires very fine-pitch soldering. The connection information is
available in a [separate file](README-Wii.md) if you want to try anyway.

Please note that you need to use the Wii-specific firmware files if you
install the board in a Wii instead of a Gamecube.

## Connecting the Pluto board to a Gamecube ##

Multiple connections need to be made from the Gamecube to the Pluto
IIx HDMI board to connect all the signals and power lines necessary to
convert the video signal. The image below shows roughly where each of
the connections need to be made on the Pluto board (click for a larger
version):

[![Preview of Pluto IIx HDMI connection diagram](doc/connections-thumb.jpg)](doc/connections.jpg)

### Power ###

The Pluto IIx HDMI board must be connected as described below to the
digital video connector of the Gamecube. In addition to the signals
available on that connector, it also needs to be powered from the 5V
power rail of the Gamecube, which is not available on the digital
video port. Instead, 5V can be sourced from the internal power
connector as shown in the image below:

![5V points on the GC power connector](doc/gc-power-5v.jpg)

Either of the marked pins (they are already connected together on the
Gamecube's board) must be connected to the *VUNREG* solder pad on the Pluto
board. If the image is unclear, the two 5V pins of the power connector
are the two pins closest to the heat sink.

### DDC power ###

Early revisions of the Pluto IIx HDMI board had a design flaw that reduced its
compatibility with various displays significantly. As far as I know, this has
fixed in board revision E or higher. If you have a revision E board, you need
to bridge the pads pads marked in [this document](https://www.knjn.com/docs/Pluto-IIx%20HDMI%20rev.%20E.pdf)
to enable an identification signal on the HDMI port that is used by some
displays to detect if an input is used.

Unfortunately, Pluto IIx-HDMI board revisions D and earlier need a bit more
work. You need to connect a 100 ohm resistor from the solder pad
behind the HDMI connector (labelled *DDC +5V* on the bottom) to the
*VUNREG* pin at the side of the board. Please make absolutely sure that
you do not create a short between *VUNREG* and *VCC* when you do this as
this will likely destroy both the FPGA board and the Gamecube it is
attached to.

Without this resistor (or equivalently, bridging the pads on newer boards),
most of my monitors and other devices with an HDMI input claimed that they
were receiving no signal from the Pluto board, even though it was actually
generating a valid video signal.

Some users have reported that most of their TVs did not recognize the
signal from the Pluto board with the 100 ohm resistor installed. If
you also suffer from this problem, please check that the resistor you
installed is really a 100 ohm resistor and not a 100 kiloohm
resistor.

### Gamecube digital port ###

Most of the connections from the Gamecube's digital video port are
made to the contact row opposite of the HDMI connector. Since
connectors for the digital video port are unfortunately not available,
the connections need to be made by soldering to the Gamecube's main
board. The image below shows the pin numbering of the digital video
connector as viewed from the bottom(!) of the board. If you have
decided to desolder that connector and connect the signals from the
top instead, you should find the numbers "1", "2", "21" and "22" in
the silkscreen near the connector which can be used as a guide instead.

![Pin numbering on the bottom side of the digital video connector](doc/gcdv-bottom-pins.jpg)

13 signals need to be connected from the digital video port to the
Pluto board. Please make sure that the wires are kept short as you are
dealing with high-speed digital signals here. The pins on the Pluto
board are labelled on both the top and bottom sides.

Gamecube DV   | Pluto         | Signal
------------- | ------------- | -------------
1             | 20            | Cable detect
3             | 19            | Color select
4             | GND           | Ground (recommended point: next to VUNREG/VCC)
7             | 16            | VData 0
9             | 15            | VData 1
10            | 13            | VData 2
12            | 12            | VData 3
13            | 10            | VData 4
15            | 9             | VData 5
16            | 6             | VData 6
18            | 5             | VData 7
19            | 98            | LRCK
20            | GND           | Ground (recommended point: next to 89)
21            | 3             | AData
22            | 4             | BCLK
2             | 89            | 54 MHz

Please note that the last signal in that table is not on the same edge
of the Pluto board as the others. It is a rather fast clock signal and
it is strongly recommended to route it separately from the other wires
as bundling them up can lead to flickering pixels.


### Controller ###

To read the controller buttons, another wire must be connected from
the FPGA board to the Gamecube. The recommended connection point for
this is on the bottom of the Cube's PCB, it must be connected
to *pin 94* on the Pluto FPGA board.

[![Preview of Controller point](doc/gc-controller-thumb.jpg)](doc/gc-controller.jpg)

If you do not want to wire up the controller, e.g. if you want to use
an IR remote for navigating the OSD, please connect *pin 94* of the
Pluto board to a GND pad.

### SPDIF output ###

The SPDIF output is on *pin 78*. It is **not** suitable for direct connection
to a coaxial SPDIF input.

To connect the SPDIF pin to your audio device without killing the
FPGA, please use either one of the buffer circuits shown
[here](http://www.hardwarebook.info/S/PDIF_output) or use a
3.3V-compatible optical Toslink transmitter, for example a Lite-On
LTDL-TX12P03, Everlight PLT133 or something from the Toshiba TOTX series.

Please note that due to hardware constraints the SPDIF signal has a
small amount of jitter. In my tests this has not resulted in any
compatibility or audio-quality problems, but if you happen to
encounter a device that has issues with the SPDIF signal generated by
GCVideo, there is probably not much that can be done about it.


### IR receiver and IR button ###

The OSD of GCVideo can be controlled either with a Gamecube controller
or with an infrared remote that uses the NEC protocol (same one as
supported by OSSC). The buttons used by GCVideo can be freely chosen,
as long as the remote supports this protocol.

To use this functionality, two pieces of additional hardware are
needed: A button (momentary contact, normally open) and an IR receiver
module that can operate at 3.3V. It has been successfully
tested with an OS-Opto OS-838G as well as a Vishay TSOP4838 IR
receiver module, but it should also work with similar 3-pin IR
receivers that are meant for receiving consumer IR signals with a
modulation frequency between 36 and 40 kHz.

Such a receiver module needs power for its internal circuits. A
convenient place to power it from are the pads labelled "GND" and
"VCC" near the short edge of the Pluto board. Please make sure to read
the data sheet of your IR receiver module to figure out which of its
pin are used to power it. The third pin is the data output, which
needs to be connected to *pin 85* on the Pluto board.

In addition to the IR receiver module, a simple button is required
which connects between *GND* and *pin 83* on the Pluto board, which
will be called "IR button" in this manual. This button allows you to
choose which buttons of your IR remote you want to use to control
GCVideo without getting in a chicken-and-egg situation.

By holding down the IR button while turning on the console, you can force
the firmware flasher to start looking for an update instead of handing
over control to the main firmware.

## OSD ##

GCVideo-DVI features an on-screen display for configuring its numerous
settings which can be navigated using a Gamecube controller in port 1
or an infrared remote if a suitable receiver is connected.

The operation of the OSD can be found in the
[Firmware README.md](../../Firmware/README.md) file.

## Possible issues ##

1. The enhanced DVI mode may not be compatible with all displays,
    especially if they expect pure DVI signals.

2. Some displays do not expect to receive consumer video-style timings
    (as opposed to computer-style timings)
    as a DVI signal, which may result in various display problems.
    Enabling enhanced DVI mode may or may not help. Alternatively, you
    can try enabling the line-doubler for any modes that your display
    refuses to accept, although the signal timing is still not
    completely identical to a computer video signal.

3. If your display completely refuses to accept the signal generated
    on the Pluto IIx board, you may have a problem with the 100 ohm
    DDC resistor (see section "DDC resistor" above). In some cases
    this can be fixed by using a wire instead of a resistor, although
    this is not recommended unless absolutely neccessary.

If everything is wired correctly, at least one of the two LEDs on the
Pluto board should blink at a regular rate. The second LED also blinks
(at a different rate) in the Gamecube version or shows the current
console mode (Wii or Gamecube) in the Wii version.
If neither of them is blinking, check all the wiring and also
make sure that the board is actually programmed.

The blink pattern of the LEDs is based on both the master 54MHz clock
and the VSync signal. With two heartbeat LEDs, one of them shows
the presence of the 54MHz clock by pulsing approximately 3 times per
second with a short on/long off pattern. The second LED shows the
presence of a VSync signal (decoded from the digital video bus) by
blinking at about 0.5 Hz with an NTSC video signal or slightly slower
with a PAL signal - this means that it should be on for about one
second, then off for about one second and so forth.

For boards that have only a single LED (currently the dual-output
versions), it only shows the quick pulsing of the clock heartbeat
pattern.

### XRGB Mini ###

If possible, avoid connecting the output of GCVideo DVI to the HDMI
inputs of an XRGB Mini. Although you will usually get a picture, the
XRGB Mini seems to show various issues with the signal from GCVideo
DVI. For example, the image may be shifted to the far left of the
screen with no option to adjust it.

With certain games the switch from interlaced to progressive mode when
the game boots causes the XRGB Mini to misdetect the new video mode,
halving the horizontal resolution (360x480 instead of
720x480). Switching to a different input and back should trigger a
re-detection of the input video mode and usually results in the
correct resolution. Enabling enhanced DVI mode may also fix this issue.

### Elgato Game Capture HD ###

When the linedoubler is enabled for 480i/576i modes and scanlines are
enabled, the Elgato Game Capture HD shows reduced color saturation in
every second captured frame. The amount of desaturation depends on the
strength of the scanlines, up to a fully black-and-white picture if
the maximum scanline strength is used.

### Other issues ###

Notes about other issues will be added as time permits.


## Running synthesis ##

GCVideo-DVI cannot be built using the Xilinx ISE Project Navigator,
is has to be built using the included Makefile and Perl scripts.
This process has only been tested on Linux and requires GNU Make
as well as Perl 5.10 or later in addition to Xilinx ISE version 14.7.
Forthermore, you will need a version of zpu-gcc to build the firmware,
please check the [Firmware README](../../Firmware/README.md) for details.

If you want to modify certain parts of GCVideo-DVI, you may need
additional tools. It is recommended (but not required) to have
[exomizer](https://bitbucket.org/magli143/exomizer/wiki/Home)
installed to create a firmware updater. The build process should work
without it, but the resulting updater is much smaller if exomizer is
available. It has only been tested using version 3.0.2 and it may or may
not work with later versions.

The build process of GCVideo-DVI creates two bitstreams (one for the flasher,
one for the main firmware) and combines them into one binary file ready
for flashing to the SPI memory chip using either a direct flashing tool,
an XSVF player or Xilinx Impact. To run it, ensure that the Xilinx
synthesis tools are reachable via the `PATH` environment variable and
use `make CONFIG=...` in the `gcvideo_dvi` directory to start the process.
You need to supply a target configuration (board+console) using the
`CONFIG=` parameter. Currently, there are 8 supported target configurations:
- `p2xh-gc`: Pluto IIx-HDMI board for installation in a Gamecube
- `p2xh-wii`: same, but for Wii
- `shuriken-gc`: Shuriken Video board for installation in a Gamecube
- `shuriken-wii`: same, but for Wii
- `shuriken-v3-gc`: Shuriken Video v3 board for installation in a Gamecube
- `shuriken-v3-wii`: same, but for Wii
- `dual-gc`: GC Dual board
- `dual-wii`: Wii Dual board

The output as well as all temporary files will be stored in
the subdirectory `build`. If you want to build all target configurations,
you can use the `build-all.sh` script in the same directory as this README.
It creates release-ready zip files for each configuration in the
`binaries` subdirectory. Furthermore, `build-updater.sh` is available to
build a firmware updater from the individual firmware binaries.


## Firmware sources ##

The firmware sources can be found in the [Firmware](../../Firmware)
directory at the top level of the repository.


## Alternative target boards ##

GCVideo-DVI should be easily portable to other FPGA boards that have a
DVI or HDMI connector directly connected to the FPGA's pins and use a
Spartan 3A-200 (or larger) or a Spartan 6 (necessary size unknown,
probably a 9 minimum). Ports to FPGAs from other vendors should be
possible, only the clock generator and DDR outputs use Xilinx-specific
components.

At least one alternative board has been designed, the [Shuriken
Video](http://www.retro-system.com/shuriken%20video.htm). It
features a smaller footprint which is optimized for mounting it so
that it sticks out of the original digital video connector hole of the
Gamecube. The developer has used a smaller FPGA to keep the costs
down, but when fitted with a Spartan 3A-200, the full version of
GCVideo-DVI can run on it and presynthesized bitstreams are available.


## Note about modifications ##

The firmware update process identifies a compatible update using a 4 byte
identification code, e.g. "P2XG" for the p2xh-gc target. If you plan to
release a board that requires a bitstream that is not compatible with one
of the existing boards, please add your own target configuration to the
top-level `Makefile` and choose a different identification code (HWID).
This ensures that users do not accidentally flash an incompatible bit stream
to their board, possibly bricking it. Identification codes should consist
of four ASCII characters. All existing ones use G as the last character if
they target a Gamecube and W if they target a Wii, but this is just a
guideline and not a strict requirement.

If everything works as planned, just changing the HWID should be enough
to build a compatible flasher and firmware image. To include it into
the updater alongside the other firmware versions, you'll also need to
edit `build-all.sh` and `build-updater.sh`.

Also, please consider contributing any bug fixes or changes back to the
original project.


## 3D printed mount ##

A mount has been designed for the Pluto-IIx board by
[Collingall](https://www.thingiverse.com/collingall/about) on Thingiverse.
[Download the file here.](https://www.thingiverse.com/thing:2332094).
If you're looking for somewhere to get it printed, some users have mentioned
[Shapeways](https://shapeways.com) as a low-cost, high-quality source.

In order to use the mount, you'll need to desolder the digital video port,
and remove the back flap on the disc drive shielding.
The easiest way to remove the back flap is to pry it out flat
with pliers and then bend it back an forth along the fold.
You should be able to get a nice clean break and
it will leave room to mount the board in place of the digital connector.


## Theory of Operation ##

FIXME: Actually write this section


## Credits ##

Thanks to:

- Mike Field for releasing his [DVI encoder](http://hamsterworks.co.nz/mediawiki/index.php/Dvid_test) under an open-source license
- bobrocks95 on gc-forever for pointing me towards the Pluto IIx HDMI board
- Artemio for his incredible [240p test suite](http://junkerhq.net/xrgb/index.php/240p_test_suite)
    which has been extremely
    useful for quickly switching between modes during development
- Nintendo for filing such a detailed patent for their console
- Alastair M. Robinson for the ZPUFlex core
- meneerbeer on the gc-video forums for suggesting the 16:9 option and a simple
    fix that reduces occasional image corruption
- Antti Siponen for his hdmi_proto project, which was really useful
    for figuring out many details about data transmission during blanking
- Andrew "bunnie" Huang for releasing the NeTV code, which was a
    very helpful code base for hacking a simple DVI signal analyzer
- Alexios Chouchoulas for [mcasm](http://www.bedroomlan.org/projects/mcasm)
- Magnus Lind for his great compression tool [exomizer](https://bitbucket.org/magli143/exomizer/wiki/Home)
- Borti and others for working out the formulas for good-looking hybrid scanlines
