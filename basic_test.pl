#!/usr/bin/perl
use warnings;
use strict;
use Test::Simple tests => 10;
use Mosaics;

my $example_chip = "chip.sam";
my $example_input = "input.sam";

my $mosaics;
ok($mosaics = Mosaics->new(), 'created object right');

ok($mosaics->chip_file($example_chip), 'Setting example chip..');
ok($mosaics->input_file($example_input), 'Setting example input..');
ok($mosaics->analysis_type("IO"), "setting analysis type to IO");
ok($mosaics->file_format("sam"), "setting format to sam");
ok($mosaics->chip_file() eq $example_chip, 'Chip is set');
ok($mosaics->input_file() eq $example_input, 'input is set');
ok($mosaics->dump_log(), "printing log");

#ok($mosaics->make_chip_wiggle(), 'making wiggle');
#ok($mosaics->make_input_wiggle(), 'making wiggle');
ok($mosaics->make_chip_bin(), 'making bin');
ok($mosaics->make_input_bin(), 'making bin');
ok($mosaics->read_bins(), 'reading bins!');
ok($mosaics->fit(), 'FITTING');
ok($mosaics->call_peaks(), 'calling peaks');
ok($mosaics->export(), 'exporting peaks');