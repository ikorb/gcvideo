#!/usr/bin/env perl

use warnings;
use strict;
use feature ':5.10';

my $swap_words = 0;

if (scalar(@ARGV) != 0 && $ARGV[0] eq "-swapwords") {
    shift;
    $swap_words = 1;
}

if (scalar(@ARGV) != 4) {
    say "Usage: $0 [-swapwords] width size in.bin out.mem";
    exit 1;
}

my $width = 0+shift;
my $size = 0+shift;

open IN,"<",$ARGV[0] or die "Can't open $ARGV[0]: $!";
open OUT,">",$ARGV[1] or die "Can't open $ARGV[1]: $!";

binmode IN;
binmode OUT;

my $buffer;

read(IN,$buffer,(-s $ARGV[0])) or die "Can't read from input: $!";

# pad to expected size
while (length($buffer) != $size) {
    $buffer .= chr(0);
}

$buffer = pack("N*", unpack("V*", $buffer)) if $swap_words;

while (length($buffer) > 0) {
    my $str = substr($buffer, 0, $width/8);

    for (my $i = $width-1; $i>= 0; $i--) {
	if (vec($str, $i, 1)) {
	    print OUT "1";
	} else {
	    print OUT "0";
	}
    }
    print OUT "\n";

    $buffer = substr($buffer, length($str));
}

close IN;
close OUT;
