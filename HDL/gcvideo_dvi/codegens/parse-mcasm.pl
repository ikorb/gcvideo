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
# parse-mcasm.pl: Parse the output of mcasm into a VHDL file
#

use warnings;
use strict;
use feature ':5.10';
use Data::Dumper;

my %condbits;
my %fields;
my %signals;
my @data;

sub bin {
    my $str = shift;
    my $val = 0;

    while (length($str) > 0) {
        $val <<= 1;

        if (substr($str, 0, 1) eq "1") {
            $val |= 1;
        }
        $str = substr($str, 1);
    }

    return $val;
}


if (scalar(@ARGV) != 3) {
    say "Usage: $0 mcasmout.txt template.vhd output.vhd";
    exit 1;
}

# parse mcasm output
my $output_bits = 0;

open IN, "<", $ARGV[0] or die "Can't open $ARGV[0]: $!";

while (<IN>) {
    chomp;
    next if $_ eq "";

    if (/^# cond ([^:]+):\s*(\d+)/) {
        $condbits{$1} = 0+$2;
    } elsif (/^# field ([^:]+)\s+([01]+)/) {
        $fields{$1} = { "mask" => bin($2), "signals" => [] };
    } elsif (/^# signal ([^:]+)\s+([01]+)/) {
        $signals{$1} = bin($2);
        $output_bits = length($2) if length($2) > $output_bits;
    } elsif (/^#/) {
        # stats, ignore
    } elsif (/d <= \"([01]+)\" when a=\"([01]+)\"/) {
        my $val  = $1;
        my $addr = bin($2);

        $data[$addr] = $val;
    } elsif (/d <= \"Z/) {
        # VHDL default, ignore
    } elsif (/^Writing/) {
        # progress report, ignore
    } else {
        say STDERR "Unable to parse line $.: >$_<";
        exit 1;
    }
}

close IN;

# find candidates for boolean signals
my %bools;

foreach my $signal (keys %signals) {
    next if $signals{$signal} == 0;
    $bools{$signal} = {"value" => $signals{$signal}};
}

# figure out which signals belong to which field
# (lame-o quadradratic algorithm)
foreach my $field (keys %fields) {
    my $fieldmask = $fields{$field}{mask};
    my $field_lower = lc $field;
    $field_lower =~ s/^([^_]+)_.*/$1/;

    foreach my $signal (keys %signals) {
        if ($signals{$signal} == 0) {
            # Special case, try matching by prefix
            my $sig_lower = lc $signal;
            $sig_lower =~ s/^([^_]+)_.*/$1/;

            if ($field_lower eq $sig_lower) {
                push @{$fields{$field}{signals}}, $signal;
                delete $bools{$signal};
            }

        } elsif ($signals{$signal} & $fieldmask) {
            push @{$fields{$field}{signals}}, $signal;
            delete $bools{$signal};
        }
    }

    # calculate bit numbers from field mask
    my $min_bit = undef;
    my $max_bit = undef;

    for (my $i = 0; $i < $output_bits; $i++) {
        if ($fieldmask & (1 << $i)) {
            $min_bit = $i unless defined($min_bit);
            $max_bit = $i;
        }
    }

    $fields{$field}{minbit} = $min_bit;
    $fields{$field}{maxbit} = $max_bit;
}

# calculate bit number for bools
foreach my $bool (keys %bools) {
    for (my $i = 0; $i < $output_bits; $i++) {
        if ($bools{$bool}{value} & (1 << $i)) {
            $bools{$bool}{bit} = $i;
            last;
        }
    }
}

# start copying the template to the output file
open TPL, "<", $ARGV[1] or die "Can't open template $ARGV[1]: $!";
open OUT, ">", $ARGV[2] or die "Can't open output $ARGV[2]: $!";

say OUT "-- auto-generated from $ARGV[0] and $ARGV[1] on ", scalar(localtime);

while (<TPL>) {
    last if /^%%%/;
    print OUT;
}

### generate VHDL
my $entityname = $ARGV[0];
$entityname =~ s/\..*//;

# typedefs - must be moved to a package manually =(
say OUT "---- Note: type definitions must be moved to a package";
foreach my $field (sort keys %fields) {
    next if $field =~ /value$/i;

    print OUT "-- type ${field}_t is (";
    print OUT join(", ", sort @{$fields{$field}{signals}});
    say OUT ");";
}

# entity
print OUT "\nentity $entityname is
  port (\n";

my @ports = ("Clock: in std_logic",
             "ClockEnable: in boolean",
             sprintf("Address: in natural range 0 to %d", scalar(@data)-1));

foreach my $field (sort keys %fields) {
    # Hack: Fields ending in "value" are output as vector, others as enum
    if ($field =~ /value$/i) {
        push @ports, sprintf("%s: out std_logic_vector(%d downto 0)",
                             $field, $fields{$field}{maxbit} - $fields{$field}{minbit});
    } else {
        push @ports, "$field: out ${field}_t";
    }
}

foreach my $bool (sort {$bools{$b}{bit} <=> $bools{$a}{bit}} keys %bools) {
    push @ports, "$bool: out boolean";
}

say OUT "    ", join(";\n    ", @ports);
say OUT "  );\nend $entityname;";


# architecture
say OUT "\narchitecture Behavioral of $entityname is";
printf OUT "  signal data: std_logic_vector(%d downto 0);\n", $output_bits-1;
say OUT "begin";

# decoder process
say OUT "\nprocess(data)\nbegin";

foreach my $field (sort keys %fields) {
    # Hack: Same as above in the entity output
    if ($field =~ /value$/i) {
        say OUT "  $field <= data($fields{$field}{maxbit} downto $fields{$field}{minbit});\n";
    } else {
        my $len = $fields{$field}{maxbit} - $fields{$field}{minbit} + 1;

        say OUT "  case data($fields{$field}{maxbit} downto $fields{$field}{minbit}) is";

        my @sigs = sort { $signals{$a} <=> $signals{$b} } @{$fields{$field}{signals}};
        foreach my $sig (@sigs) {
            my $sigval = $signals{$sig} >> $fields{$field}{minbit};

            printf OUT "    when \"%0${len}b\" => %s <= %s;\n", $sigval, $field, $sig;
        }
        say OUT "    when others => null;";
        say OUT "  end case;\n";
    }
}

foreach my $bool (sort {$bools{$b}{bit} <=> $bools{$a}{bit}} keys %bools) {
    say OUT "  $bool <= (data($bools{$bool}{bit}) = '1');\n";
}

say OUT "end process;";

# ROM process
say OUT "\nprocess(Clock, ClockEnable)\nbegin";
say OUT "  if rising_edge(Clock) and ClockEnable then";
say OUT "    case address is";

for (my $i = 0; $i < @data; $i++) {
    say OUT "      when $i => data <= \"$data[$i]\";";
}

say OUT "      when others => null;";
say OUT "    end case;";
say OUT "  end if;";
say OUT "end process;";

say OUT "\nend Behavioral;";
                 

# copy the remainder of the template file
while (<TPL>) {
    print OUT;
}

close OUT;
close TPL;
