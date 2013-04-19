#!/usr/bin/perl

use strict;
use warnings;

use Verilog::Netlist;
use Verilog::Getopt;

my $opt = new Verilog::Getopt;
#$opt->parameter("+incdir+verilog", "-y", "verilog");

my $nl = new Verilog::Netlist;

$nl->read_file(filename=>$ARGV[0]);

my %buf_rename;

sub buf_rename($)
{
    my ($a) = @_;
    return $buf_rename{$a}  if  exists $buf_rename{$a};
    return $a;
}

#$nl->link();

#$nl->dump;
sub reorder_lut($)
{
    my ($C) = @_;
    #$C->info("LUT");
    $C->params =~ /^\.INIT\(\d+'h([0-9A-F]+)\)$/  or  die;
    my $h = $1;
    $h = '0' . $h  if  length($h) == 1;
    my $bits = scalar reverse unpack "B*", pack "H*", $1;
    #print "Orig '", $1, ' ', $bits, "'\n";
    my %pins;
    my $output;
    for my $X ($C->pins) {
        if ($X->name eq 'O') {
            $output = buf_rename $X->netname;
            next;
        }
        $X->name =~ /^(?:ADR|I)(\d)$/  or  die;
        $pins{buf_rename $X->netname} = $1 + 0;
        #print $1, " ", $X->netname, "\n";
    }
    my @pins = sort keys %pins;
    my @pn = map { $pins{$_} } @pins;
    my $permuted = '';
    for my $bit (0.. (1 << scalar @pins) - 1) {
        my $orig = 0;
        my $m = 1;
        for my $p (@pn) {
            $orig |= 1 << $p  if  $bit & $m;
            $m *= 2;
        }
        $permuted .= substr $bits, $orig, 1;
    }
    my $permhex = uc unpack "H*", pack "B*", scalar reverse $permuted;
    #print "Permuted ", $permuted, " ", "\n";
    #print " $permhex \n";
    #print " $_\n"  for  @pins;
    print "  ", $C->submodname, " #(\n";
    print "    .INIT ( ", length $permuted, "'h$permhex ))\n";
    print "  ", $C->name, "(\n";
    print "    $_\n"  for  @pins;
    print "    .O($output)\n";
    print "  );\n";
}


sub output($)
{
    my ($C) = @_;
    print "  ", $C->submodname, " #(\n";
    print "    ", $C->params, ")\n";
    print "  ", $C->name, "(\n";
    print "  ", $_->name, "(", buf_rename $_->netname, ")\n"
        for  $C->pins_sorted;
    print "  );\n";
}


my %buf_links;


for my $M ($nl->top_modules_sorted) {
    for my $C ($M->cells_sorted) {
        next  unless  $C->submodname =~ /^(?:X_)BUF$/;
        my $input;
        my $output;
        for my $X ($C->pins) {
            $output = $X->netname  if  $X->name eq 'O';
            $input = $X->netname  if  $X->name eq 'I';
        }
        die unless defined $input;
        die unless defined $output;
        $buf_links{$output} = $input;
    }
}

sub transitive_buf_link($)
{
    my ($a) = @_;
    my $b = $a;
    while (1) {
        return $b  if  !exists $buf_links{$b};
        $b = $buf_links{$b};
        return $b  if  !exists $buf_links{$b};
        $b = $buf_links{$b};
        die  if  !exists $buf_links{$a};
        $a = $buf_links{$a};
        die  if  $a eq $b;
    }
}

$buf_rename{$_} = transitive_buf_link $_  for  keys %buf_links;

for my $M ($nl->top_modules_sorted) {
    for my $C ($M->cells_sorted) {
        if ($C->submodname =~ /^(?:X_)?LUT[2-6]$/) {
            reorder_lut $C;
        }
        else {
            output $C;
        }
    }
}
