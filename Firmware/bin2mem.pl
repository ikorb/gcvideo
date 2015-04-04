#!/usr/bin/env perl

use warnings;
use strict;
use feature ':5.10';

if (scalar(@ARGV) != 2) {
    say "Usage: $0 in.bin out.mem\n";
    exit 1;
}

open IN,"<",$ARGV[0] or die "Can't open $ARGV[0]: $!";
open OUT,">",$ARGV[1] or die "Can't open $ARGV[1]: $!";

binmode IN;
binmode OUT;

my $buffer;

read(IN,$buffer,(-s $ARGV[0])) or die "Can't read from input: $!";

# pad to word size
while ((length($buffer) % 4) != 0) {
    $buffer .= chr(0);
}

# swap endianness of words
#$buffer = pack("N*", unpack("V*", $buffer));

# swap nibbles
#$buffer = pack("H*", unpack("h*", $buffer));

my $address = 0;
while (length($buffer) > 0) {
    printf OUT "@%08X", $address;

    my $str = substr($buffer, 0, 16);
    for (my $i=0; $i<length($str); $i++) {
	printf OUT " %02X", ord(substr($str, $i, 1));
    }
    print OUT "\n";

    $buffer = substr($buffer, length($str));
    $address += 16;
}

close IN;
close OUT;
