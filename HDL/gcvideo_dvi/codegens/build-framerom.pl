#!/usr/bin/env perl
#
# GCVideo DVI HDL
# Copyright (C) 2014-2016, Ingo Korb <ingo@akana.de>
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
    # ACR
    # empty
    # empty
    # empty

    "480p full",
    "480p limited",
    "576p full",
    "576p limited",

    "480i full",
    "480i limited",
    "576i full",
    "576i limited",

    "240p full",
    "240p limited",
    "288p full",
    "288p limited",

    # four unused slots, but the generator must output something
    "480p full",
    "480p full",
    "480p full",
    "480p full",

    "480p full 169",
    "480p limited 169",
    "576p full 169",
    "576p limited 169",

    "480i full 169",
    "480i limited 169",
    "576i full 169",
    "576i limited 169",

    "240p full 169",
    "240p limited 169",
    "288p full 169",
    "288p limited 169",
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

sub print_frame {
    my $out    = shift;
    my $offset = shift;
    my @data   = @{shift()};

    for (my $i = 0; $i < @data; $i++) {
        printf $out "      when %4d => Data <= \"%09b\";\n", $i + $offset, $data[$i];
    }
}

# ----

my %frames;
my $curframe;
my $framedata = [0,0,0,0,0];

if (scalar(@ARGV) != 3) {
    say "Usage: $0 infoframes.txt template.vhd output.vhd";
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

# start copying the template to the output file
open TPL, "<", $ARGV[1] or die "Can't open template $ARGV[1]: $!";
open my $out, ">", $ARGV[2] or die "Can't open output $ARGV[2]: $!";

say $out "-- auto-generated from $ARGV[0] and $ARGV[1] on ", scalar(localtime);

while (<TPL>) {
    last if /^%%%/;
    print $out $_;
}

### output when statements for the ROM

# print the ACR packet four times because it may interrupt the other packets
say $out "      ---- Audio Clock Regeneration (x4)";
print_frame($out,  0, bitshuffle($frames{"Audio Clock Regeneration"}));
print_frame($out, 32, bitshuffle($frames{"Audio Clock Regeneration"}));
print_frame($out, 64, bitshuffle($frames{"Audio Clock Regeneration"}));
print_frame($out, 96, bitshuffle($frames{"Audio Clock Regeneration"}));

# print all modes
my $ADDRESS_SCALE = 32 * 4;

my $blocknum = 4; # first four would be 960i/1152i

foreach my $m (@modes) {
    my $address = $blocknum * $ADDRESS_SCALE;

    say $out "\n      ---- $m";

    # AVI
    print_frame($out, $address, bitshuffle($frames{$m}));
    $address += 32;
    # Audio
    say $out "      -- Audio";
    print_frame($out, $address, bitshuffle($frames{"Audio"}));
    $address += 32;
    # SPD
    say $out "      -- SPD";
    print_frame($out, $address, bitshuffle($frames{"Source Product Description"}));

    $blocknum++;
}

# copy the remainder of the template file
while (<TPL>) {
    print $out $_;
}

close $out;
close TPL;
