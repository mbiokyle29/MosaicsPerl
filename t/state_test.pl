#!/usr/bin/perl
use warnings;
use strict;
use lib "../lib/";
use Mosaics;
use Test::Simple tests => 6;

my $mosaics;
ok($mosaics = Mosaics->new( 
	out_loc => '/home/kyle/lab/MosaicsPerl/example-data',

));

ok($mosaics->chip_bin("chip.sam_fragL200_bin200.txt"), 'Manually setting the chip bin file');
ok($mosaics->input_bin("input.sam_fragL200_bin200.txt"), 'Manually settign the input bin file');
ok($mosaics->out_loc eq "/home/kyle/lab/MosaicsPerl/example-data", "Out loc is right!");
ok($mosaics->read_bins(), 'reading bins');
ok($mosaics->save_state(), 'Saving state file');