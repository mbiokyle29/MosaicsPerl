#!/usr/bin/perl
# Script to generate and run an R Script to analyize CHiP Seq data with MOSAICS
# Requires --dir flag ! and nessecary data (IO, GC STUFF)
use warnings;
use strict;
use Getopt::Long;
use lib "lib/";
use Mosaics;
use feature qw|say|;
use Data::Printer;
my ( $type, $chip_file, $input_file,
	$map_score, $gc_score, $n_score, $chip_bin,
	$input_bin, $dir
);

# defaults
my $fragment_length = 200;
my $bin_size = 200;
my $format = "sam";

GetOptions (
	"type=s" => \$type,
	"chip=s" => \$chip_file,
	"format=s" => \$format,
	"input=s" => \$input_file,
	"map=s" => \$map_score,
	"gc=s" => \$gc_score,
	"n=s" => \$n_score,
	"cbin=s" => \$chip_bin,
	"ibin=s" => \$input_bin,
	"frag=i" => \$fragment_length,
	"bin=i" => \$bin_size,
	"dir=s" => \$dir,
);
unless($dir) { die "Working dir is required!"; }
unless($chip_bin or $chip_file) { die "chip bin or file are required!"; 
}

my $mos = Mosaics->new(out_loc => $dir);

# Set everything that was given as args
if($dir)		{ $mos->out_loc($dir);           }
if($chip_file)  { $mos->chip_file($chip_file);   }
if($chip_bin)   { $mos->chip_bin($chip_bin); say "setting chip bin";  }
if($input_file) { $mos->input_file($input_file); }
if($input_bin)  { $mos->input_bin($input_bin);   }
if($map_score)  { $mos->map_score($map_score);   }
if($gc_score)   { $mos->gc_score($gc_score);     }
if($n_score)    { $mos->n_score($n_score);       }

# Get the bins made if not given
if($input_file and not $input_bin){ $mos->make_input_bin(); }
unless($chip_bin) { $mos->make_chip_bin(); }

# Read the bins
$mos->read_bins();
$mos->fit();
$mos->call_peaks();
$mos->export();
$mos->export({type => 'txt'});
$mos->save_state();
say $mos->dump_log();