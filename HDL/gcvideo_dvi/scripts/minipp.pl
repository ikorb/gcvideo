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
# minipp.pl: Simple cpp-like file preprocessor
#
# Supports:
#   #ifdef <symbol>
#   #ifndef <symbol>
#   #else
#   #endif
#

use warnings;
use strict;
use feature ':5.10';

my %symbols;
my @files;

if (scalar(@ARGV) == 0) {
    say "Usage: $0 [-DFOO ...] infile [infile2 ...]";
    exit 1;
}

foreach my $arg (@ARGV) {
    if ($arg =~ /^-D(.+)/) {
        $symbols{$1} = 1;
    } else {
        if (!-r $arg) {
            say STDERR "ERROR: File $arg is not readable";
            exit 2;
        }
        push @files, $arg;
    }
}

my @actives = 1;

foreach my $fname (@files) {
    open IN, "<", $fname or die "Can't open file $fname: $!";
    while (<IN>) {
        if (/^\s*#\s*ifdef\s+(\S+)/) {
            push @actives, (exists($symbols{$1}) ? 1 : 0);
        } elsif (/^\s*#\s*ifndef\s+(\S+)/) {
            push @actives, (exists($symbols{$1}) ? 0 : 1);
        } elsif (/^\s*#\s*else/) {
            $actives[-1] = !$actives[-1];
        } elsif (/^\s*#\s*endif/) {
            if (scalar(@actives) == 1) {
                say STDERR "ERROR: Unmatched endif found in $fname line $.";
                exit 2;
            }
            pop @actives;
        } else {
            my $doshow = 1;
            foreach my $a (@actives) {
                $doshow = $doshow && $a;
            }
            if ($doshow) {
                print $_;
            }
        }
    }
    close IN;
}

if (scalar(@actives) != 1) {
    say STDERR "ERROR: Missing #endif somewhere";
    exit 2;
}
