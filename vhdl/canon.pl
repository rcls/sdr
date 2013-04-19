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
my %skip;

sub buf_rename($)
{
    my ($a) = @_;
    return $buf_rename{$a}  if  exists $buf_rename{$a};
    return $a;
}

my %buffer_lut;

for my $L (1..6) {
    for my $I (0.. $L-1) {
        my $s = join '', map { ($_ & (1<<$I)) ? '1' : '0' } 0.. (1<<$L)-1;
        $buffer_lut{$s} = $I;
    }
}

#$nl->link();

#$nl->dump;
sub reorder_lut($)
{
    my ($C) = @_;
    #$C->info("LUT");
    $C->params =~ /\.INIT\((\d+)'h([0-9A-F]+)\)/  or  die $C->name . "\n";
    my $len = $1;
    my $h = $2;
    $h = '0' . $h  if  length($h) == 1;
    my $bits = scalar reverse unpack "B*", pack "H*", $h;
    $bits = substr $bits, 0, $len;
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


sub detect_lut_buffer($)
{
    my ($C) = @_;
    #$C->info("LUT");
    $C->params =~ /\.INIT\((\d+)'h([0-9A-F]+)\)/  or  die $C->name . "\n";
    my $len = $1;
    my $h = $2;
    $h = '0' . $h  if  length($h) == 1;
    my $bits = scalar reverse unpack "B*", pack "H*", $h;
    $bits = substr $bits, 0, $len;

    $C->submodname =~ /LUT(\d+)$/  or  die;
    my $width = $1;
    die  unless 1 << $width == length $bits;

    # Get output and list of inputs.
    my $output;
    my @input;
    for my $X ($C->pins) {
        $output = $X->netname  if  $X->name eq 'O';
        $input[$1] = buf_rename $X->netname  if  $X->name =~ /^(?:ADR|I)(\d+)/;
    }
    my $effective = '';
    for my $I (0 .. length($bits) - 1) {
        my $II = $I;
        for my $B (0 .. $width - 1) {
            $II |= (1 << $B)  if  $input[$B] eq "1'b1";
            $II &= ~(1 << $B)  if  $input[$B] eq "1'b0";
        }
        $effective .= substr $bits, $II, 1;
    }

    return  unless  exists $buffer_lut{$effective};

    $buf_rename{$output} = $input[$buffer_lut{$effective}];
    $skip{$C->name} = 1;
}


sub output($)
{
    my ($C) = @_;
    print "  ", $C->submodname, " #(\n";
    my $params = $C->params;
    $params =~ s/\.LOC\("[^"]*"\),? *//;
    print "    ", $params, ")\n";
    print "  ", $C->name, "(\n";
    for my $P ($C->pins_sorted) {
        my @nets = ($P->netname);
        @nets = split /,/, $1  if  $P->netname =~ /\{(.*)\}/;
        $_ = buf_rename $_  for  @nets;
        print "  ", $P->name, "(", join(',', @nets), ")\n";
    }
    print "  );\n";
}


sub record_buf($)
{
    my ($C) = @_;
    my $input;
    my $output;
    for my $X ($C->pins) {
        $output = $X->netname  if  $X->name eq 'O';
        $input = $X->netname  if  $X->name eq 'I';
    }
    die unless defined $input;
    die unless defined $output;
    $buf_rename{$output} = $input;
    $skip{$C->name} = 1;
}

sub record_const($$)
{
    my ($C, $n) = @_;
    my $output;
    for my $X ($C->pins) {
        $output = $X->netname  if  $X->name eq 'O';
    }
    die unless defined $output;
    $buf_rename{$output} = $n;
    $skip{$C->name} = 1;
}


for my $M ($nl->top_modules_sorted) {
    for my $C ($M->cells_sorted) {
        record_buf $C  if  $C->submodname =~ /^(?:X_)BUF$/;
        record_const $C, "1'b1"  if  $C->submodname =~ /^(X_)?ONE$/;
        record_const $C, "1'b0"  if  $C->submodname =~ /^(X_)?ZERO$/;
    }
}


for my $M ($nl->top_modules_sorted) {
    for my $C ($M->cells_sorted) {
        detect_lut_buffer $C  if  $C->submodname =~ /^(X_)?LUT\d$/;
    }
}

sub transitive_buf_link($)
{
    my ($a) = @_;
    my $b = $a;
    while (1) {
        return $b  if  !exists $buf_rename{$b};
        $b = $buf_rename{$b};
        return $b  if  !exists $buf_rename{$b};
        $b = $buf_rename{$b};
        die  if  !exists $buf_rename{$a};
        $a = $buf_rename{$a};
        die  if  $a eq $b;
    }
}

$buf_rename{$_} = transitive_buf_link $_  for  keys %buf_rename;

# Detect MUX2 being used as a buffer.
for my $M ($nl->top_modules_sorted) {
    for my $C ($M->cells_sorted) {
        next  unless  $C->submodname =~ /^(X_)MUX2$/;
        my %pins;
        $pins{$_->name} = $_->netname  for  $C->pins;
        exists $pins{IA}  or  die;
        exists $pins{IB}  or  die;
        exists $pins{SEL}  or  die;
        exists $pins{O}  or  die;
        my $sel = buf_rename $pins{SEL};
        $buf_rename{$pins{O}} = $pins{IA}  if  $sel eq "1'b0";
        $buf_rename{$pins{O}} = $pins{IB}  if  $sel eq "1'b1";
        $skip{$C->name} = 1  if  $sel eq "1'b0"  or  $sel eq "1'b1";
    }
}


# Try and get rid of all _nnnn suffixes.
my %denumber;
for my $M ($nl->top_modules_sorted) {
    for my $C ($M->nets_sorted) {
        my $n = $C->name;
        next  if  exists  $buf_rename{$n};
        next  unless $n =~ /^(.*_)\d+ *$/;
        my $nn = $1 . "###";
        if (exists $denumber{$nn}) {
            $denumber{$nn} = '';
        }
        else {
            $denumber{$nn} = $n;
        }
    }
}
for (keys %denumber) {
    $buf_rename{$denumber{$_}} = $_  if  $denumber{$_} ne '';
}

$buf_rename{$_} = transitive_buf_link $_  for  keys %buf_rename;

for my $M ($nl->top_modules_sorted) {
    for my $C ($M->cells_sorted) {
        next  if  $skip{$C->name};
        if ($C->submodname =~ /^(?:X_)?LUT\d$/) {
            reorder_lut $C;
        }
        else {
            output $C;
        }
    }
}
