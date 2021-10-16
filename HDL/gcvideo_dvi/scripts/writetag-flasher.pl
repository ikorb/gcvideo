#!/usr/bin/env perl
#
# GCVideo DVI HDL
# Copyright (C) 2014-2021, Ingo Korb <ingo@akana.de>
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
# writetag-flasher.pl: Trivial script to write the marker+hwid
#                      for the updater to a file
#

use strict;
use warnings;
use feature ':5.10';

if (scalar(@ARGV) != 3) {
    say "Usage: $0 hwid version tag.bin";
    exit 1;
}

my $hwid = hex($ARGV[0]);
my $version = $ARGV[1];

if (length($version) > 8) {
    say STDERR "ERROR: Version string \"$version\" is too long";
    exit 2;
}

open OUT,">",$ARGV[2] or do {
    say STDERR "ERROR: Cannot open $ARGV[2]: $!";
    exit 2;
};

print OUT pack("a8a12N", $version, "GCVUpdater10", $hwid);
close OUT;
