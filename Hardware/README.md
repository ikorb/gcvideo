This directory contains the KiCAD projects for the GCVideo boards.
Each directory has a subdirectory called `gerber` which contains
the final Gerber format files used for manufacturing with a naming
scheme suitable for submission to OSHPark. Each directory has a file
`BOM.csv` which lists the required parts and their Digikey part
numbers and its own README with more details about the board.

There is currently only one variant of the board available:

* gcvideo_lite_09

    This directory contains the project for the 0.9 version of the
    GCVideo Lite board. It is known to be working, although not 
    without issues. Known issues for this board are slightly too small
    drill holes on some of the connectors, IC footprints that are hard
    to hand-solder and an always-connected "component cable connected"
    pin which causes some homebrew applications to switch into 480p
    mode by default.

    The hardware is based on a Lattice MachXO2 FPGA and has analog
    outputs, both RGB and YPbPr/Component are possible and seperate
    H/V/CSync signals are available.
