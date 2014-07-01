#!/usr/bin/perl
use warnings;
use strict;
use lib "../lib/";
use Mosaics;
use Test::Simple tests => 9;
use Data::Printer;

my $mosaics;
ok($mosaics = Mosaics->new( 
	out_loc => '/home/kyle/lab/MosaicsPerl/example-data/',
));

ok($mosaics->chip_bin("chip.sam_fragL200_bin200.txt"), 'Manually setting the chip bin file');
ok($mosaics->input_bin("input.sam_fragL200_bin200.txt"), 'Manually settign the input bin file');
ok($mosaics->out_loc eq "/home/kyle/lab/MosaicsPerl/example-data/", "Out loc is right!");
ok($mosaics->read_bins(), 'reading bins');
ok(my $state_file = $mosaics->save_state(), 'Saving state file');
ok(my $mos_two = Mosaics->new(
	out_loc => '/home/kyle/lab/MosaicsPerl/example-data/',
), 'Creating second!');
ok($mos_two->load_state($state_file), 'loading state');
ok($mos_two->fit(), 'fitting from saved state bin');