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
# xmlgen.pl: Generate Homebrew Channel meta.xml for GCVideo Updater
#

use warnings;
use strict;
use feature ':5.10';

if (scalar(@ARGV) != 2) {
    say "Usage: $0 version output.xml";
    exit 1;
}

my $version = shift;
my $outfile = shift;

my @now = localtime;
my $releasedate = sprintf("%04d%02d%02d120000", $now[5] + 1900, $now[4], $now[3]);

open OUT, ">", $outfile or do {
    say STDERR "ERROR: Unable to open $outfile: $!";
    exit 2;
};

print OUT <<"EOF";
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<app version="1">
  <name>GCVideo-DVI Updater</name>
  <coder>Ingo Korb</coder>
  <version>$version</version>
  <release_date>$releasedate</release_date>
  <short_description>containing GCVideo-DVI $version</short_description>
  <long_description>This program shows noisy data on screen that can be read by GCVideo-DVI's internal flash tool to update its firmware to version $version.</long_description>
</app>
EOF

close OUT;
