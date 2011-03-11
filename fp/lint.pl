#!/usr/bin/perl

use strict;
use warnings;

sub lint($$$$$$)
{
    my ($thick, $clear, $mask, $name, $number, $flags) = @_;

    s/^\s+//;

    print "$_ : mask is not 600\n"  if  $mask != $thick + 600;
    print "$_ : clear is not 2000\n"  if  $clear != 2000;
    print "$_ : name v. number\n"  if  $name ne $number;
}

sub lint_pin($$$$)
{
    my ($thick, $clear, $mask, $drill) = @_;
    print "$_ : annulus is small\n"  if  $thick - $drill < 1016;
}


my $n = qr/-?\d+/;

while(<>) {
    chomp;
    if (/Pad\[($n) ($n) ($n) ($n) ($n) ($n) ($n) "(\d*)" "(\d*)" "(.*")\]/) {
        lint $5, $6, $7, $8, $9, $10;
    }
    elsif (/Pin\[($n) ($n) ($n) ($n) ($n) ($n) "(\d*)" "(\d*)" "(.*")\]/) {
        lint $3, $4, $5, $7, $8, $9;
        lint_pin $3, $4, $5, $6;
    }
    else {
        die $_ if  /Pad|Pin/;
    }
}
