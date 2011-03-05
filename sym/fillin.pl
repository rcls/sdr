#!/usr/bin/perl

# Usage: fillin <def> <sym>

my %pins;

my $defpath = shift @ARGV;

open my $PINS, '<', $defpath  or  die $!;

while (<$PINS>) {
    chomp;

    my $pin = $1;
    my $name = $2;

    if (/^P(\d+)\s+(?:[0-3]|NA)\s+\w\w\s+(\S+)\s*$/) {
        $pin = $1;
        $name = $2;
        $name =~ s/^IO_//;
        $name =~ s/_[0-3]$//;
    }
    elsif (m{^\|?(\d+)\s+([A-Z0-9_/]+)\s+\w+\s*$}) {
        $pin = $1;
        $name = $2;
        $name = 'AVDD_BUF'  if  $pin == 21  and  $name eq 'NC';
        $name =~ s|^D\d+/(D\d+_D\d+[MP])$|$1|;
    }
    else {
        next;
    }

    $pins{$pin} = $name;
}

close $PINS  or  die $!;

#print "$_\t$pins{$_}\n"  for  sort { $a <=> $b } keys %pins;

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
