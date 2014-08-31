# GCVideo #

GCVideo is a small series of devices capable of converting the
GameCube's Digital Video port signals to standard video signals
without using the custom chip in the original component video cable.
There is currently just on device, GCVideo Lite, which outputs analog
RGB or Component video signals.

The schematics and layout are in the [Hardware](Hardware) directory
and the HDL project is in the [HDL](HDL) directory. Each directory
should contain README.md files with further information.

## Mini-FAQ ##

1. I want one, how much is it?<br>
    I do not sell any hardware. Since this is an open-source project,
    other people will probably offer ready-made boards or modding
    services.

1. But why don't you just sell it?<br>
    Building hardware to be sold is a lot of work and requires much
    time that I'd rather use for something more
    interesting. Furthermore, the local laws require quite a bit of
    paperwork and investment to legally sell electronic devices that
    you build and I'd prefer not to deal with all of that.

1. You said your prototype came from OSHPark, so you have at least
    three boards. Can't you sell me one of them?<br>
    No, they're all accounted for already.

1. Why analog instead of HDMI?<br>
    I had this project on my bench for a few months and the HDMI
    version started to suffer from featuritis, so I decided to do an
    analog-output version first to stop people from paying the insane
    prices of the original cables. I have a version of the code that
    runs on an Atlys board (FPGA development board with HDMI outputs)
    that can convert the GameCube's video to HDMI (technically it's
    just DVI), but it is currently suffering from featuritis and lack
    of time for further development. Additionally I'm not confident
    enough in my PCB layout skills to create a board with 135MHz
    high-speed serial signals on it. If any small and cheap Spartan6
    dev board with an HDMI output connector becomes available, I might
    adapt my code to it and release it.

    If you want to try to build an HDMI/DVI-output version of GCVideo
    yourself, just ask me for the code - it needs a bit of cleanup, so
    it's not in the repository yet. If you want to figure it out
    yourself I'll give you the hint that via DVI the monitor can tell
    the difference between black pixels and the blanking area and the
    GameCube rarely outputs the full 720x480/x576 pixel image that is
    in the specs. Some displays don't mind, others refuse to show
    anything.

1. Why did you use that weird Video-DAC, it's a non-stock part at
    Digikey!<br>
    It wasn't when I designed the board some months ago... Instead it
    was the cheapest 24-bit video DAC available. It shouldn't be hard
    to adapt the design to a different DAC as long as it has 24 bit
    parallel input and a single-pumped clock. For YPbPr output, the
    DAC also needs to be able to generate a small offset on the Y line
    so that syncs can be generated below the blanking level.

1. Uh, it says XO2-256 in the schematic, but XO2-640 in the BOM. Which
    is the correct one?<br>
    The original plan was to use an XO2-256, but adding the color
    space conversion for RGB output increased the size of the design
    too much. It was left as an XO2-256 in the schematic to ensure
    only pins available on that chip are used, so a slightly cheaper
    Component-only version can be built.

1. What about linedoubling?<br>
    The FPGA used in the design is the smallest one that could fit
    everything, but it does not have enough BlockRAM available to store
    everything needed to generate a linedoubled picture. There is a
    larger, footprint-compatible FPGA (XO2-1200) available that should
    have enough resources to add at least simple linedoubling. On my
    HDMI prototyping system I have a working linedoubler that takes
    240p/288p to 480p/576p, but I wasn't able to generate a working
    output timing from interlaced input signals. Additionally, simple
    linedoubling doesn't look very good for interlaced signals anyway,
    so the only reason I see to include it would be to increase
    compatibility with devices that accept 480i, but not 240p.

# Licence #

<pre>
Copyright (C) 2014, Ingo Korb &lt;ingo@akana.de&gt;
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
</pre>
