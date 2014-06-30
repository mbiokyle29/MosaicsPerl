#!/usr/bin/perl
use warnings;
use strict;
use lib "/home/kyle/lab/MosaicsPerl/lib/";
use Mosaics;
use Test::Simple tests => 18;


my $example_chip = "chipToSmall.sam";
my $example_input = "inputToSmall.sam";
my $bad_chip = "fashdasda.sam";

my $mosaics;
ok($mosaics = Mosaics->new(out_loc => "/home/kyle/lab/MosaicsPerl/example-data"), 'created object right');
ok()