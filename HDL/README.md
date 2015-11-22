This directory contains the HDL project for the FPGA on the GCVideo
board. There are currently three project subdirectories:

* gcvideo_lite

    This directory contains the HDL sources for the GCVideo Lite
    hardware (using an XO2-640) and a Lattice Diamond project for
    building it.

* gcvideo_lite_n64

    This directory contains the HDL sources and Diamond project for
    using the GCVideo Lite hardware as a DAC for the Nintendo 64.

* gcvideo_dvi

    This directory contains the HDL sources and Xilinx ISE project for
    a DVI-output version of GCVideo. It can currently run on the Pluto
    IIx HDMI board as well as Shuriken Video.
    Please see the [README.md](gcvideo_dvi/README.md) file
    in there for more details.
