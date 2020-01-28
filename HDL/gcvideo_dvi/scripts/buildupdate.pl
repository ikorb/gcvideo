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
# buildupdate.pl: script to build a GCVideo updater executable from individual firmwares
#

use File::Temp qw/tempdir/;
use POSIX qw/ceil/;
use warnings;
use strict;
use feature ':5.10';

use constant BLOCKSIZE    => 1024;
use constant LINE_BYTES   => 1250;
use constant SCREEN_LINES => 400;
use constant INFO_PAGE    => 0x10;
use constant TARGET_ADDR  => 0x80800000;
use constant RNG_MULT     => 1103515245;
use constant RNG_ADD      => 12345;
use constant RNG_MOD      => 2**31;
use constant RNG_SHIFT    => 8;

# CRC table and update function translated from pycrc output, model crc-32-mpeg, https://pycrc.org
my @CRC_TABLE = (
    0x00000000, 0x04c11db7, 0x09823b6e, 0x0d4326d9, 0x130476dc, 0x17c56b6b, 0x1a864db2, 0x1e475005,
    0x2608edb8, 0x22c9f00f, 0x2f8ad6d6, 0x2b4bcb61, 0x350c9b64, 0x31cd86d3, 0x3c8ea00a, 0x384fbdbd,
    0x4c11db70, 0x48d0c6c7, 0x4593e01e, 0x4152fda9, 0x5f15adac, 0x5bd4b01b, 0x569796c2, 0x52568b75,
    0x6a1936c8, 0x6ed82b7f, 0x639b0da6, 0x675a1011, 0x791d4014, 0x7ddc5da3, 0x709f7b7a, 0x745e66cd,
    0x9823b6e0, 0x9ce2ab57, 0x91a18d8e, 0x95609039, 0x8b27c03c, 0x8fe6dd8b, 0x82a5fb52, 0x8664e6e5,
    0xbe2b5b58, 0xbaea46ef, 0xb7a96036, 0xb3687d81, 0xad2f2d84, 0xa9ee3033, 0xa4ad16ea, 0xa06c0b5d,
    0xd4326d90, 0xd0f37027, 0xddb056fe, 0xd9714b49, 0xc7361b4c, 0xc3f706fb, 0xceb42022, 0xca753d95,
    0xf23a8028, 0xf6fb9d9f, 0xfbb8bb46, 0xff79a6f1, 0xe13ef6f4, 0xe5ffeb43, 0xe8bccd9a, 0xec7dd02d,
    0x34867077, 0x30476dc0, 0x3d044b19, 0x39c556ae, 0x278206ab, 0x23431b1c, 0x2e003dc5, 0x2ac12072,
    0x128e9dcf, 0x164f8078, 0x1b0ca6a1, 0x1fcdbb16, 0x018aeb13, 0x054bf6a4, 0x0808d07d, 0x0cc9cdca,
    0x7897ab07, 0x7c56b6b0, 0x71159069, 0x75d48dde, 0x6b93dddb, 0x6f52c06c, 0x6211e6b5, 0x66d0fb02,
    0x5e9f46bf, 0x5a5e5b08, 0x571d7dd1, 0x53dc6066, 0x4d9b3063, 0x495a2dd4, 0x44190b0d, 0x40d816ba,
    0xaca5c697, 0xa864db20, 0xa527fdf9, 0xa1e6e04e, 0xbfa1b04b, 0xbb60adfc, 0xb6238b25, 0xb2e29692,
    0x8aad2b2f, 0x8e6c3698, 0x832f1041, 0x87ee0df6, 0x99a95df3, 0x9d684044, 0x902b669d, 0x94ea7b2a,
    0xe0b41de7, 0xe4750050, 0xe9362689, 0xedf73b3e, 0xf3b06b3b, 0xf771768c, 0xfa325055, 0xfef34de2,
    0xc6bcf05f, 0xc27dede8, 0xcf3ecb31, 0xcbffd686, 0xd5b88683, 0xd1799b34, 0xdc3abded, 0xd8fba05a,
    0x690ce0ee, 0x6dcdfd59, 0x608edb80, 0x644fc637, 0x7a089632, 0x7ec98b85, 0x738aad5c, 0x774bb0eb,
    0x4f040d56, 0x4bc510e1, 0x46863638, 0x42472b8f, 0x5c007b8a, 0x58c1663d, 0x558240e4, 0x51435d53,
    0x251d3b9e, 0x21dc2629, 0x2c9f00f0, 0x285e1d47, 0x36194d42, 0x32d850f5, 0x3f9b762c, 0x3b5a6b9b,
    0x0315d626, 0x07d4cb91, 0x0a97ed48, 0x0e56f0ff, 0x1011a0fa, 0x14d0bd4d, 0x19939b94, 0x1d528623,
    0xf12f560e, 0xf5ee4bb9, 0xf8ad6d60, 0xfc6c70d7, 0xe22b20d2, 0xe6ea3d65, 0xeba91bbc, 0xef68060b,
    0xd727bbb6, 0xd3e6a601, 0xdea580d8, 0xda649d6f, 0xc423cd6a, 0xc0e2d0dd, 0xcda1f604, 0xc960ebb3,
    0xbd3e8d7e, 0xb9ff90c9, 0xb4bcb610, 0xb07daba7, 0xae3afba2, 0xaafbe615, 0xa7b8c0cc, 0xa379dd7b,
    0x9b3660c6, 0x9ff77d71, 0x92b45ba8, 0x9675461f, 0x8832161a, 0x8cf30bad, 0x81b02d74, 0x857130c3,
    0x5d8a9099, 0x594b8d2e, 0x5408abf7, 0x50c9b640, 0x4e8ee645, 0x4a4ffbf2, 0x470cdd2b, 0x43cdc09c,
    0x7b827d21, 0x7f436096, 0x7200464f, 0x76c15bf8, 0x68860bfd, 0x6c47164a, 0x61043093, 0x65c52d24,
    0x119b4be9, 0x155a565e, 0x18197087, 0x1cd86d30, 0x029f3d35, 0x065e2082, 0x0b1d065b, 0x0fdc1bec,
    0x3793a651, 0x3352bbe6, 0x3e119d3f, 0x3ad08088, 0x2497d08d, 0x2056cd3a, 0x2d15ebe3, 0x29d4f654,
    0xc5a92679, 0xc1683bce, 0xcc2b1d17, 0xc8ea00a0, 0xd6ad50a5, 0xd26c4d12, 0xdf2f6bcb, 0xdbee767c,
    0xe3a1cbc1, 0xe760d676, 0xea23f0af, 0xeee2ed18, 0xf0a5bd1d, 0xf464a0aa, 0xf9278673, 0xfde69bc4,
    0x89b8fd09, 0x8d79e0be, 0x803ac667, 0x84fbdbd0, 0x9abc8bd5, 0x9e7d9662, 0x933eb0bb, 0x97ffad0c,
    0xafb010b1, 0xab710d06, 0xa6322bdf, 0xa2f33668, 0xbcb4666d, 0xb8757bda, 0xb5365d03, 0xb1f740b4
    );

sub crc_update {
    my $crc = shift;
    my $data = shift;

    foreach my $ch (split //, $data) {
        my $index = ($crc >> 24) ^ ord($ch) & 0xff;
        $crc = ($CRC_TABLE[$index] ^ ($crc << 8)) & 0xffffffff;
    }

    return $crc;
}

# ---

sub have_exomizer {
    state $gotit;

    if (!defined($gotit)) {
        $gotit = 0;
        no warnings 'exec';

        my $fd;
        open($fd, "-|", "exomizer", "raw", "-?") and do {
            $gotit = 1;
            # discard output
            while (readline $fd) {}
        };
        close $fd;
    }

    return $gotit;
}

sub compress_firmware {
    my $label = shift;
    my $indata = shift;

    # pad to full kbyte
    $indata .= "\xff" x (BLOCKSIZE - 1);
    $indata = substr($indata, 0, int(length($indata) / BLOCKSIZE) * BLOCKSIZE);

    # return uncompressed if exo is not available
    if (!have_exomizer()) {
        my @result;

        for (my $i = 0; $i < length($indata) / BLOCKSIZE; $i++) {
            push @result, pack("Cna*", $i, BLOCKSIZE, substr($indata, $i * BLOCKSIZE, BLOCKSIZE));
        }

        return @result;
    }

    state $tempdir = File::Temp->newdir();
    my @result;
    my $totalsize = 0;

    for (my $i = 0; $i < length($indata) / BLOCKSIZE; $i++) {
        print "$label: compressing chunk ", $i +  1, "/", length($indata) / BLOCKSIZE, "\r";
        open my $uncomp, ">", $tempdir . "/input.bin" or die "Can't open temporary file: $!";
        binmode $uncomp;
        print $uncomp substr($indata, $i * BLOCKSIZE, BLOCKSIZE);
        close $uncomp;

        system("exomizer", "raw", "-q", "-b", "-o", $tempdir . "/output.bin", $tempdir . "/input.bin") == 0
          or do {
              unlink $tempdir . "/input.bin";
              die "Failed to run exomizer";
          };

        open my $compr, "<", $tempdir . "/output.bin" or die "Can't open compressed file: $!";
        binmode $compr;
        my $cdata;
        my $len = sysread $compr, $cdata, 2 * BLOCKSIZE;
        if ($len <= 0) {
            unlink $tempdir . "/input.bin";
            unlink $tempdir . "/output.bin";
            die "Failed to read compressed data: $!";
        }
        close $compr;

        # Workaround for a stupid flasher bug in 3.0-3.0c
        #if ($len >= BLOCKSIZE) {
        #    # compression did not gain anything, replace with original
        #    $cdata = substr($indata, $i * BLOCKSIZE, BLOCKSIZE);
        #}
        if ($len == BLOCKSIZE) {
            # append a dummy byte in front (ignored by decruncher) to
            # make sure the flasher does not think this chunk is uncompressed
            printf "%02x %02x %02x\n\n", ord(substr($cdata, 0, 1)), ord(substr($cdata, 1,1)), ord(substr($cdata, 2, 1));
            $cdata = pack("Ca*", 0, $cdata);

            say "\nnew cdata len: ", length($cdata);
            printf "%02x %02x %02x\n\n", ord(substr($cdata, 0, 1)), ord(substr($cdata, 1,1)), ord(substr($cdata, 2, 1));
        }

        unlink $tempdir . "/input.bin";
        unlink $tempdir . "/output.bin";

        my $outchunk = pack("Cna*", $i, length($cdata), $cdata);
        push @result, $outchunk;
        $totalsize += length($outchunk);
    }
    printf "\n%s: %d chunks, %d/%d bytes (%.2f%%)\n", $label, scalar(@result), $totalsize, length($indata),
      $totalsize * 100.0 / length($indata);

    return @result;
}

sub binpack {
    # simple first fit descending implementation, usually good enough
    # first byte of output bin is the number of data segments in it
    my $maxbytes = shift;
    my @data = sort { length($a) <=> length($b) } @_;
    my @bins;

    while (scalar(@data) > 0) {
        my $curdata = pop @data;
        my $found = 0;

        foreach my $bin (@bins) {
            if (length($bin) + length($curdata) <= $maxbytes) {
                $bin .= $curdata;
                $found = 1;
                substr($bin, 0, 1) = chr(ord(substr($bin, 0, 1)) + 1);
                last;
            }
        }

        if (!$found) {
            push @bins, "\x01" . $curdata;
        }
    }

    return @bins;
}

sub encode_7bit {
    my $indata = shift;
    my @inwords = unpack("n*", $indata);
    my @outwords;
    my $bitbuffer = 0;
    my $bits_needed = 7;

    # split length into two 7-bit parts without worrying about the upper bits
    my $wordlen = (length($indata) + 1) >> 1;
    my $enclen = ($wordlen & 0x7f) | (($wordlen << 1) & 0x7f00);
    # note: adding 0x5040 here because GCVideo subtracts 0x10 from luma
    push @outwords, $enclen + 0x5040;

    my @curwords;

    while (scalar(@inwords) > 0) {
        my $curword = shift(@inwords);
        $bitbuffer >>= 1;

        # store bits 0 and 8 seperately from the others
        $bitbuffer |= ($curword & 0x0101) << 6;

        push @curwords, (($curword >> 1) & 0x7f7f) + 0x5040;
        $bits_needed -= 1;

        # spill collected data after every 7 words
        if ($bits_needed == 0) {
            push @outwords, $bitbuffer + 0x5040;
            push @outwords, @curwords;
            @curwords = ();
            $bitbuffer = 0;
            $bits_needed = 7;
        }
    }

    # store remainder if last block wasn't full
    if ($bits_needed != 7) {
        $bitbuffer >>= $bits_needed;
        push @outwords, $bitbuffer + 0x5040;
        push @outwords, @curwords;
    }

    return pack("n*", @outwords);
}

sub scramble {
    my $rngstate = shift;
    my $data = shift;
    my $scrambled = "";

    for (my $i = 0; $i < length($data); $i++) {
        $rngstate = (RNG_MULT * $rngstate + RNG_ADD) % RNG_MOD;
        my $randval = ($rngstate >> RNG_SHIFT) & 0xff;
        $scrambled .= chr(ord(substr($data, $i, 1)) ^ $randval);
    }

    return $scrambled;
}

sub encode_line {
    my $linedata = shift;
    my $linenum = shift;
    my $pagenum = shift;

    $linedata .= "\x80" if length($linedata) & 1; # pad to multiple of 2

    my $crc = crc_update(0xffffffff, pack("CC", $linenum, $pagenum));
    $crc = crc_update($crc, $linedata);

    my $seed = ($linenum << 8) + $pagenum;
    my $scrambled = scramble($seed, pack("Na*", $crc, $linedata));
    if (length($scrambled) - 4 != length($linedata)) {
        printf STDERR "LEN MISMATCH: %d %d\n", length($scrambled) - 4, length($linedata);
    }

    my $encoded = pack("nCCa*", 0x65aa, $linenum + 0x10, $pagenum, encode_7bit($scrambled));
    my @paddata = unpack("n*", scramble($seed, "\x00" x (1440 - length($encoded))));
    for (my $i = 0; $i < scalar(@paddata); $i++) {
        $paddata[$i] = ($paddata[$i] & 0x7f7f) + 0x5040;
    }
    my $padding = pack("n*", @paddata);

    return $encoded . $padding;
}

sub parse_updater {
    my $filename = shift;

    open IN, "<", $filename or do {
        say STDERR "ERROR: Unable to open $filename: $!";
        exit 2;
    };
    binmode IN;

    my $data;
    my $len = sysread(IN, $data, -s $filename);
    if (!defined($len) || $len < 0) {
        say STDERR "ERROR: Unable to read $filename: $!";
        exit 2;
    }
    close IN;

    my @sectionoffset  = unpack("N11", substr($data, 0,    18 * 4));
    my @sectionaddress = unpack("N11", substr($data, 0x48, 18 * 4));
    my @sectionlength  = unpack("N11", substr($data, 0x90, 18 * 4));
    my ($bssaddress, $bsslength) = unpack("N2", substr($data, 0xd8, 2 * 4));

    # check if any section overlaps the target address
    my $ok = 1;

    if (TARGET_ADDR >= $bssaddress && TARGET_ADDR < $bssaddress + $bsslength) {
        $ok = 0;
    }

    for (my $i = 0; $i < scalar(@sectionoffset); $i++) {
        if ($sectionaddress[$i] > 0 && $sectionlength[$i] > 0 &&
            TARGET_ADDR >= $sectionaddress[$i] &&
            TARGET_ADDR <  $sectionaddress[$i] + $sectionlength[$i]) {
            $ok = 0;
            last;
        }
    }

    if (!$ok) {
        say STDERR "ERROR: $filename is not suitable as updater, target address in use.";
        exit 2;
    }

    # look for a free data section
    my $targetsection;
    for (my $i = 7; $i < scalar(@sectionoffset); $i++) {
        if ($sectionaddress[$i] == 0 && $sectionlength[$i] == 0) {
            $targetsection = $i;
            last;
        }
    }

    if (!defined($targetsection)) {
        say STDERR "ERROR: $filename is not suitable as updater, no free data section.";
        exit 2;
    }

    return ($data, $targetsection);
}

# ---

if (scalar(@ARGV) < 2) {
    say "Usage: $0 updater.dol output.dol firmware.bin [firmware2.bin ...]";
    exit 1;
}


if (!have_exomizer()) {
    # due to a bug in flashers from 3.0-3.0c, chunks must always be compressed
    say STDERR "exomizer not available, cannot proceed";
    exit 2;
}

my $updater_in  = shift;
my $updater_out = shift;

my ($updaterdol, $targetsection) = parse_updater($updater_in);

my %firmwares;
my $commonversion;

STDOUT->autoflush(1);

while (scalar(@ARGV) > 0) {
    my $inname = shift @ARGV;

    open IN, "<", $inname or do {
        say STDERR "ERROR: Unable to open $inname: $!";
        exit 2;
    };
    binmode IN;

    my $data;
    my $readlen = sysread(IN, $data, -s $inname);
    close IN;

    if (!defined($readlen) || $readlen < 0) {
        say STDERR "ERROR: Unable to read $inname: $!";
        exit 2;
    }

    if ($readlen > 256 * BLOCKSIZE) {
        say STDERR "ERROR: $inname is larger than 256 blocks";
        exit 2;
    }

    my ($hwid, $length, $crc, $version) = unpack("NNNa8", $data);

    if ($hwid == 0xffffffff || $length == 0xffffffff || $crc == 0xffffffff) {
        say STDERR "ERROR: $inname has an invalid header";
        exit 2;
    }

    if (exists $firmwares{$hwid}) {
        printf STDERR "ERROR: $inname has duplicate hardware id 0x%08x\n", $hwid;
        exit 2;
    }

    if (defined($commonversion)) {
        if ($version ne $commonversion) {
            say STDERR "ERROR: $inname has mismatching version $version, expected $commonversion";
            exit 2;
        }
    } else {
        $commonversion = $version;
    }

    my @blocks = compress_firmware($inname, $data);
    my @lines = binpack(LINE_BYTES, @blocks);
    my $page = scalar(keys %firmwares) + INFO_PAGE + 1;

    say "$inname: fitted into ", scalar(@lines), " lines";

    for (my $i = 0; $i < scalar(@lines); $i++) {
        $lines[$i] = encode_line($lines[$i], $i, $page);
    }

    $firmwares{$hwid} = {
        version => $version,
        data    => $data,
        lines   => \@lines,
        page    => $page
    };
}

# construct infoline
my $infoline = pack("n", scalar(keys %firmwares));
my $totallines = 0;

foreach my $hwid (sort keys %firmwares) {
    $infoline .= pack("Nnna8",
                      $hwid,
                      scalar(@{$firmwares{$hwid}->{lines}}),
                      $firmwares{$hwid}->{page},
                      $firmwares{$hwid}->{version});

    $totallines += scalar(@{$firmwares{$hwid}->{lines}});

    if (length($infoline) > LINE_BYTES) {
        # 76 firmwares in one package should be enough for anyone
        say STDERR "Maximum info line size exceeded, add less firmware variants!";
        exit(2);
    }
}

if ($totallines * 1440 > 8 * 1024 * 1024) {
    printf STDERR "WARNING: Output data block will be excessively large (%.1f MiB)\n",
      $totallines * 1440.0 / 1024.0 / 1024.0;
}

# interleave data from all firmwares
my @lines;
while ($totallines > 0) {
    foreach my $hwid (keys %firmwares) {
        if (scalar(@{$firmwares{$hwid}->{lines}}) > 0) {
            push @lines, shift(@{$firmwares{$hwid}->{lines}});
            $totallines--;
        }
    }
}

# build final screens
my $screencount = ceil(scalar(@lines) / (SCREEN_LINES - 2));
my $lines_per_screen = ceil(scalar(@lines) / $screencount);

my @screens;
for (my $i = 0; $i < $screencount; $i++) {
    my $screen = encode_line($infoline, 0, 0x10);
    $screen .= $screen; # replicate infoline so it appears in both fields

    for (my $j = 0; $j < $lines_per_screen; $j++) {
        my $line = $lines[$i * $lines_per_screen + $j];
        $line = "\x80" x 1440 if !defined($line);
        $screen .= $line;
    }

    push @screens, $screen;
}

# build data header
my $outdata = pack("a8a8N", "gcvupd10", $commonversion, scalar(@screens));

my @offsets;
my $curoffset = length($outdata) / 4 + scalar(@screens) + 1;

push @offsets, $curoffset;

foreach my $screen (@screens) {
    $curoffset += length($screen) / 4;
    push @offsets, $curoffset;
}

$outdata .= pack("N*", @offsets);

# add screens to output data
foreach my $screen (@screens) {
    $outdata .= $screen;
}

# patch updater and write to file
$updaterdol .= "\x00" while length($updaterdol) % 4; # pad to word size

substr($updaterdol, $targetsection * 4, 4) = pack("N", length($updaterdol));
substr($updaterdol, $targetsection * 4 + 0x48, 4) = pack("N", TARGET_ADDR);
substr($updaterdol, $targetsection * 4 + 0x90, 4) = pack("N", length($outdata));

open OUT, ">", $updater_out or do {
    say STDERR "ERROR: Unable to write to $updater_out: $!";
    exit 2;
};

print OUT $updaterdol,$outdata;
close OUT;
