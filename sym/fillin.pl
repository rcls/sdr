#!/usr/bin/perl

# Usage: fillin <sym>

my %pins;

open my $PINS, '<', 'docs/spartan6slx9tqg144pkg.txt'  or  die $!;

while (<$PINS>) {
    chomp;
    next  unless (/^P(\d+)\s+([0-3]|NA)\s+(\w\w)\s+(\S+)\s*$/);

    my $pin = $1;
    my $name = $4;

    $name =~ s/^IO_//;
    $name =~ s/_[0-3]$//;

    $pins{$pin} = $name;
}

close $PINS  or  die $!;

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
    die "$pin"  unless  $name;

    $acc =~ s/^pinseq=0$/pinseq=$pin/m;
    $acc =~ s/^pinlabel=unknown$/pinlabel=$name/m;

    print $acc;
    $acc = '';
}

print $acc;
