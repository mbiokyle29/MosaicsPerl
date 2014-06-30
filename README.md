MosaicsPerl
===========

Perl module for interfacing with the R package MOSAiCS (http://www.stat.wisc.edu/~keles/Software/mosaics/index.html)

The Mosaics object is very "stateful", it needs to be properly loaded with data to do what you want it to do. To simplify the use of it, it was made to assume alot. For example, if you run: <code>$mos->call_peaks();</code> 
The object assumes you want to call peaks based on the MOSAICS fit object stored in <code>$mos->fit_name</code>, it will fail if that param is not set, however, it is automatically set by running <code>$mos->fit();</code>

Many thanks to the Keles Research Group for making and maintaining MOSAiCS
Many thanks to the maker of  Statistics::R module! (https://github.com/bricas/statistics-r)

MOSAiCS CITATION:
Chung D, Kuan PF and Keles S (2012). mosaics: MOSAiCS (MOdel-based one and two Sample Analysis and Inference for ChIP-Seq). R package version 1.12.0, http://groups.google.com/group/mosaics_user_group. 

Simple Example:
```perl
  # Create a new api object
  # has many attributes, which can all be set at creation, but not many are needed
  # Defaults:
  #   analysis_type => IO
  #   file_format => sam
  #   fragment_size => 200
  #   bin_size => 200
  my $mos = Mosaics->new(out_loc => "./");
  
  # Load chip data
  $mos->chip_file('myChip.sam');
  
  # Load input data
  $mos->input_file('myInput.sam');
  
  # Create bin-level data for chip
  $mos->make_chip_bin();
  
  # Create bin-level data for input
  $mos->make_input_bin();
  
  # Read in bin data
  $mos->read_bins();
  
  # Generate a fit - using defaults
  $mos->fit();
  
  # Generate a fit - custom
  $mos->fit({'truncProb' => .99, 'bgEst' => 'rMOM'});
  
  # Call Peaks
  $mos->call_peaks();
  
  # Export peak list
  $mos->export();
  
  # Get a log of all R command ran
  print $mos->dump_log();
```
