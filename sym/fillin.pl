#!/usr/bin/perl

use strict;
use warnings;

# Usage: fillin <def> <sym>

my %pins;

my $path = shift @ARGV;

my $FPGA    = ($path =~ /spartan6/);
my $ADC     = ($path =~ /ads41b49/);
my $SPACED  = ($path =~ /ft2232h/  or  $path =~ /lm49450/);
my $LM3S828 = ($path =~ /LM3S828/);

open my $PINS, '<', $path  or  die $!;

while (<$PINS>) {
    chomp;

    my $pin;
    my $name;

    if ($FPGA  and  /^P(\d+)\s+(?:[0-3]|NA)\s+\w\w\s+(\S+)\s*$/) {
        $pin = $1;
        $name = $2;
        $name =~ s/^IO_//;
        $name =~ s/_[0-3]$//;
    }
    if ($ADC  and  m{^\|?(\d+)\s+([A-Z0-9_/]+)\s+\w+\s*$}) {
        $pin = $1;
        $name = $2;
        $name = 'AVDD_BUF'  if  $pin == 21  and  $name eq 'NC';
        $name =~ s|^D\d+/(D\d+_D\d+[MP])$|$1|;
    }
    if ($SPACED  and  /^(\d+)\s+(\S+)/) {
        $pin = $1;
        $name = $2;
#        print "$pin $name\n";
    }
    if ($LM3S828  and  /^"?(\d+)"?,"?([A-Za-z0-9]+)"?,/) {
        $pin = $1;
        $name = $2;
        $name = "$pins{$pin}/$name"  if  exists $pins{$pin};
    }

    $pins{$pin} = $name  if  defined $pin;
}

close $PINS  or  die $!;

#print STDERR "$_\t$pins{$_}\n"  for  sort { $a <=> $b } keys %pins;

my $acc = '';

while (<>) {
    $acc .= $_;

    next  unless  /^\}$/;

    unless ($acc =~ /^pinnumber=(\d+)$/m) {
        print $acc;
        $acc = '';
        next;
    }

    my $pin = $1;
    my $name = $pins{$pin};
    unless ($name) {
        print STDERR "Pin $pin is unknown.\n";
        print $acc;
        $acc = '';
        next;
    }

    $acc =~ s/^pinseq=0$/pinseq=$pin/m;
    $acc =~ s/^pinlabel=unknown$/pinlabel=$name/m;

    print $acc;
    $acc = '';
}

print $acc;
