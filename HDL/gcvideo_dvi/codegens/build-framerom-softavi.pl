#!/usr/bin/env perl
#
# GCVideo DVI HDL
# Copyright (C) 2014-2020, Ingo Korb <ingo@akana.de>
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
# THE POSSIBILITY OF SUCH DAMAGE.
#
# build-framerom.pl: Generate a VHDL Infoframe-ROM from input file
#

use warnings;
use strict;
use feature ':5.10';
use Data::Dumper;
no warnings 'portable';  # Support for 64-bit ints required

my @modes = ( # order matters!
    # non-AVI frames
    "Audio Clock Regeneration 48042",
    "Source Product Description",
    "Audio",
    "empty",

    # same, but for Wii
    "Audio Clock Regeneration 48000",
    "empty",
    "empty",
    "empty",

    # four slots filled in software
    "empty", # 256 - RGB full range 4:3
    "empty", # 288 - RGB limited range 4:3
    "empty", # 320 - YCbCr 4:4:4 4:3
    "empty", # 352 - YCbCr 4:2:2 4:3

    # four slots filled in software
    "empty", # 384 - RGB full range 16:9
    "empty", # 416 - RGB limited range 16:9
    "empty", # 448 - YCbCr 4:4:4 16:9
    "empty", # 480 - YCbCr 4:2:2 16:9

    );

# ----

sub bitshuffle {
    my @subs = @{shift()};
    my $header = shift(@subs);

    $header <<= 4; # align to the end of the buffer

    my @outwords;

    for (my $i = 0; $i < 28; $i++) {
        my $word = 0;

        $word |= (1 << 0) if $header  & (1 << $i);

        $word |= (1 << 1) if $subs[0] & (1 << (2*$i));
        $word |= (1 << 2) if $subs[0] & (2 << (2*$i));

        $word |= (1 << 3) if $subs[1] & (1 << (2*$i));
        $word |= (1 << 4) if $subs[1] & (2 << (2*$i));

        $word |= (1 << 5) if $subs[2] & (1 << (2*$i));
        $word |= (1 << 6) if $subs[2] & (2 << (2*$i));

        $word |= (1 << 7) if $subs[3] & (1 << (2*$i));
        $word |= (1 << 8) if $subs[3] & (2 << (2*$i));

        push @outwords, $word;
    }

    return \@outwords;
}

sub convert_frame {
    my $out    = shift;
    my $offset = shift;
    my $romcontent = shift;
    my @data   = @{shift()};

    for (my $i = 0; $i < @data; $i++) {
        $$romcontent[$i + $offset] = sprintf("%09b", $data[$i]);
    }
}

# ----

my %frames;
my $curframe;
my $framedata = [0,0,0,0,0];

if (scalar(@ARGV) != 2) {
    say "Usage: $0 infoframes.txt output.mif";
    exit 1;
}

# read input file
open IN, "<", $ARGV[0] or die "Can't open $ARGV[0]: $!";

while (<IN>) {
    chomp;

    next if /^#/;

    if ($_ eq "") {
        if (defined($curframe)) {
            $frames{$curframe} = $framedata;
            $framedata = [0,0,0,0,0];
        }
        $curframe = undef;
        next;
    }

    if (!defined($curframe)) {
        /^([^:]+)/ and $curframe = $1;
    } else {
        if (/^H: ([0-9a-f]+)/i) {
            $$framedata[0] = hex $1;
        } elsif (/^([0-3]): ([0-9a-f]+)/i) {
            $$framedata[1 + $1] = hex $2;
        } else {
            say "Unparseable entry on line $.: >$_<";
            exit 2;
        }
    }
}

if (defined($curframe)) {
    $frames{$curframe} = $framedata;
}

close IN;

# write to output
open my $out, ">", $ARGV[1] or die "Can't open output $ARGV[1]: $!";

my $ADDRESS_SCALE = 32;
my $blocknum = 0;
my @romcontent;

foreach my $m (@modes) {
    my $address = $blocknum * $ADDRESS_SCALE;

    convert_frame($out, $address, \@romcontent, bitshuffle($frames{$m}));
    $address += 32;
    $blocknum++;
}

# extend to a power of two
while (scalar(@romcontent) & (scalar(@romcontent) - 1)) {
    push @romcontent, "000000000";
}

for (my $i = 0; $i < scalar(@romcontent); $i++) {
    if (!defined($romcontent[$i])) {
        say $out "000000000";
    } else {
        say $out $romcontent[$i];
    }
}

close $out;
