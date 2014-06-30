#!/usr/bin/perl
use warnings;
use strict;
use lib "/home/kyle/lab/MosaicsPerl/lib/";
use Mosaics;
use Test::Simple tests => 18;


my $example_chip = "chipToSmall.sam";
my $example_input = "inputToSmall.sam";

my $mosaics;
ok($mosaics = Mosaics->new(out_loc => "/home/kyle/lab/MosaicsPerl/example-data"), 'created object right');
ok($mosaics->analysis_type("IO"), "setting analysis type to IO");
ok($mosaics->chip_file($example_chip), 'Setting example chip..');
ok($mosaics->input_file($example_input), 'Setting example input..');
ok($mosaics->file_format("sam"), "setting format to sam");
ok($mosaics->chip_file() eq $example_chip, 'Chip is set');
ok($mosaics->input_file() eq $example_input, 'input is set');
ok($mosaics->dump_log(), "printing log");
ok($mosaics->make_chip_wiggle(), 'making wiggle');
ok($mosaics->make_input_wiggle(), 'making wiggle');
ok($mosaics->make_chip_bin(), 'making bin');
ok($mosaics->make_input_bin(), 'making bin');
ok($mosaics->chip_bin("chip.sam_fragL200_bin200.txt"), 'Manually setting the chip bin file');
ok($mosaics->input_bin("input.sam_fragL200_bin200.txt"), 'Manually settign the input bin file');
ok($mosaics->read_bins(), 'reading bins!');
ok($mosaics->fit(), 'FITTING');
ok($mosaics->call_peaks(), 'calling peaks');
ok($mosaics->export({type => 'txt'}), 'exporting peaks');
print $mosaics->dump_log;