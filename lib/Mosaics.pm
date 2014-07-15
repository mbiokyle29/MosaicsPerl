package Mosaics;
use Mouse;
use namespace::autoclean;
use Statistics::R;
use Scalar::Util qw(looks_like_number);
use feature qw|switch say|;
use File::Slurp;
use Data::Printer;
use Net::Ping;
use Binder;

# Analysis type for MOSAICS fit
use constant OS => "OS";
use constant TS => "TS";
use constant IO => "IO";

# Required on construction!
has 'out_loc' => (is => 'rw', isa =>'Str', required => 1);

# R stuff (mostly internal)
has 'r_con' => ( is => 'rw', isa => 'Object');
has 'r_log' => ( is => 'rw', isa => 'Str');

# Binder (internal)
has 'binder' => (is => 'rw', isa => 'Object');

# Defaults to IO
has 'analysis_type'  => (
	is => 'rw', 
	isa => 'Str',
	default => 'IO',
	lazy => 1
);

# Defaults to sam
has 'file_format' => (
	is => 'rw', 
	isa => 'Str',
	default => 'sam',
	lazy => 1
);

# BOTH default to 200
has ['fragment_size', 'bin_size' ] => (is => 'rw', isa => 'Int', lazy => 1, default => 200);

# No defaults;
has ['chip_file', 'input_file',  'chip_bin', 'input_bin'] => (is => 'rw', isa => 'Str');
has ['map_score', 'gc_score', 'n_score'] => (is => 'rw', isa => 'Str');
has 'bin_data'  => (is => 'rw', isa => 'Str');
has 'fit_name'  => (is => 'rw', isa => 'Str');
has 'peak_name' => (is => 'rw', isa => 'Str');
has 'data_name' => (is => 'rw', isa => 'Str');

around [qw|chip_file input_file chip_bin input_bin|] => sub {
	my $orig = shift;
	my $self = shift;
	my $file = shift;
	if($file){
		unless(-e $self->out_loc."/$file") { $self->_die("Could not locate $file!"); }
		if($file =~ m/-/)
		{
			$self->_die("Please fix $file so that it does not have dashes, R hates dashes!");
		}
		return $self->$orig($file);
	}
	return $self->$orig();
};

sub BUILD
{
	my $self = shift;
	$self->r_con(Statistics::R->new());
	$self->r_log("R Connection Initialized\n");

	$self->binder(new Binder(base_string => ""));

	# Make sure we are connected before we try to check for updates
	if(&can_ping){	$self->_run_updates();	} else {warn "bioconductor cannot be reached skipping updates"}
	
	$self->_load_libs();
	$self->_set_r_dir($self->out_loc);
}

###############################################################################
# 					Public Methods 										      #
###############################################################################

# Returns a scalar string which holds all the r commands run through this instance
sub dump_log
{
	my $self = shift;
	return $self->r_log;
}

# Sub for constructing a chip bin file
# Returns the name of the new chip bin (and overwrites the data memeber)
# requires: chip_file file_format out_loc fragment_size bin_size
# sets: chip_bin
sub make_chip_bin
{
	my $self = shift;
	$self->_have_chip_input();
	$self->binder->base_string("constructBins(infile=\"(?)\", fileFormat=\"(?)\", outfileLoc=\"(?)\", byChr=FALSE, fragLen=(?), binSize=(?))");
	my $const_bin = $self->binder->bind(
		$self->chip_file, 
		$self->file_format, 
		$self->out_loc, 
		$self->fragment_size, 
		$self->bin_size
	);
	
	if($self->r_con->run($const_bin))
	{
		$self->_log_command($const_bin);
		
		$self->binder->base_string("(?)_fragL(?)_bin(?).txt");
		my $chip_bin = $self->binder->bind(
			$self->chip_file, 
			$self->fragment_size, 
			$self->bin_size
		);

		$self->chip_bin($chip_bin);
		return $chip_bin;
	} else { $self->_die("Could not make chip bin! with $const_bin"); }
}

# Sub for constructing an input bin file
# Returns the name of the new input bin (and overwrites the data memeber)
# requires: input_file file_format out_loc fragment_size bin_size
# sets: input_bin
sub make_input_bin
{
	my $self = shift;
	$self->_have_input_input();

	# Build the construct bins command
	$self->binder->base_string("constructBins(infile=\"(?)\", fileFormat=\"(?)\", outfileLoc=\"(?)\", byChr=FALSE, fragLen=(?), binSize=(?))");
	my $const_bin = $self->binder->bind(
		$self->input_file, 
		$self->file_format, 
		$self->out_loc,
		$self->fragment_size,
		$self->bin_size
	);

	if($self->r_con->run($const_bin))
	{
		$self->_log_command($const_bin);
		
		$self->binder->base_string("(?)_fragL(?)_bin(?).txt");
		my $input_bin = $self->binder->bind(
			$self->input_file, 
			$self->fragment_size, 
			$self->bin_size
		);
		
		$self->input_bin($input_bin);
		return $input_bin;
	} else { $self->_die("Could not make input bin! with: $const_bin"); }
}

# Sub for Generating a wiggle file of the current chip data
# No return value, dies on failure
# requires: chip_file file_format out_loc
# sets: n/a
sub make_chip_wiggle
{
	my $self = shift;
	$self->_have_chip_input();
	
	say "Setting base string";
	$self->binder->base_string("generateWig( infile=\"(?)\", fileFormat=\"(?)\", outfileLoc=\"(?)\")") or die "Could not set base string?";
	my $wiggle_command = $self->binder->bind(
		$self->chip_file,
		$self->file_format,
		$self->out_loc
	);
	
	if($self->r_con->run($wiggle_command)) {
		$self->_log_command($wiggle_command);
	} else { $self->_die("Could not generate chip wiggle file! w/ $wiggle_command"); }
} 

# Sub for Generating a wiggle file of the current input data
# No return value, dies on failure
# requires: input_file file_format out_loc
# sets: n/a
sub make_input_wiggle
{
	my $self = shift;
	$self->_have_input_input();

	say "Setting base string";
	$self->binder->base_string("generateWig( infile=\"(?)\", fileFormat=\"(?)\", outfileLoc=\"(?)\")") or die "Could not set base string?";
	my $wiggle_command = $self->binder->bind(
		$self->input_file,
		$self->file_format,
		$self->out_loc
	);

	if($self->r_con->run($wiggle_command)) {
		$self->_log_command($wiggle_command);
	} else { $self->_die("Could not generate input wiggle file! w/ $wiggle_command"); }
}

# Sub for reading in bin level data
# checks for a valid set of bin data depending on analysis type
# 	most basic is: type -> IO and with chip and input data
#	see mosaics docs for more
# requires: varies
# sets: bin_data
sub read_bins
{
	my $self = shift;
	$self->_can_read_bins();
	$self->chip_bin =~ m/^([\w-]+)\..*$/;
	$self->bin_data($1);

	# Set up strings for appending chosen data
	my $read_command = $self->bin_data." <- readBins(";

	# Helper subs generate the R string from existing data + analysis_type
	my $type_string = $self->_readbin_type_string();
	my $files_string = $self->_readbin_file_string();
	$read_command .= $type_string.", ".$files_string.")";

	# Run and log
	if($self->r_con->run($read_command))
	{
		$self->_log_command($read_command);
	} else { $self->_die("Could not read bins! w/ $read_command"); }
}

# Sub for generating a mosaics fit on the current bin data
# 	Extra options can be set via a hash ref
# requires: bin_data analysis
# sets: fit_name
sub fit
{
	my ($self, $opts) = @_;

	# Validate object state
	$self->_can_fit();

	# Build template command
	my $fit_name = $self->bin_data."FIT";
	my $fit_command = $fit_name." <- mosaicsFit(".$self->bin_data.", analysisType = \"".$self->analysis_type."\"";
	
	# Verify and append hash of extra options if exists
	if($opts and $self->_validate_fit_opts($opts))
	{
		my @numeric_opts = qw|meanThres s d truncProb nCore|;
		for my $key (keys(%$opts))
		{
			my $opt_val = $$opts{$key};
			$fit_command .= ", ".$key." = ";
			if($key eq "bgEst") { $fit_command .= "\"".$opt_val."\""; }
			else { $fit_command .= $opt_val; }
		}
	}

	# Close command string run, and then log
	$fit_command .= ")";
	if( $self->r_con->run($fit_command)){
		$self->_log_command($fit_command);
		$self->fit_name($fit_name);
	} else { $self->_die("Could not generate fit w/ $fit_command"); }
}

# Sub for calling peaks on the set fit object
# Extra options can be set via a hash ref
# requires: fit_name
# sets: peak_name
sub call_peaks
{
	my ($self, $opts) = @_;
	my $peak_name = $self->bin_data."PEAK";
	my $peak_command = $peak_name." <- mosaicsPeak(".$self->fit_name;
	
	if($opts and $self->_validate_peak_opts($opts))
	{
		for my $key (keys(%$opts))
		{
			my $opt_val = $$opts{$key};
			if($key eq "signalModel"){
				$peak_command .= ", signalModel = \"".$opt_val."\"";
			} else {
				$peak_command .= ", $key = $opt_val";
			}
		}
	}

	$peak_command .= ")";
	if($self->r_con->run($peak_command)){
		$self->_log_command($peak_command);
		$self->peak_name($peak_name);
	} else { $self->_die("Could not call peaks! w/ $peak_command"); }
}

# Sub for exporting the current peak list
# Defaults to outputting bed files
# Extra options can be set via a hash ref
# requires: peak_name 
# sets: n/a
sub export
{
	my ($self, $opts) = @_;
	$self->_can_export($self);
	my $type = "bed";
	my $file_name = $self->peak_name;
	if($opts and $self->_validate_export_opts($opts))
	{
		if(exists($$opts{'type'})) {
			$type = $$opts{'type'};
		}
		if(exists($$opts{'filename'})) {
			$file_name = $$opts{'filename'};
		}
	}
	$file_name .= ".$type";
	$self->binder->base_string("export((?), type = \"(?)\", filename = \"(?)\")");
	my $export_command = $self->binder->bind($self->peak_name, $type, $file_name);
	
	if($self->r_con->run($export_command)){
		$self->_log_command($export_command);
	} else {
		$self->_die("Could not export peak list w/ $export_command");
	}
}

# Sub for saving the current R img to file
# Default the file name unless data_name is set
sub save_r_image
{
	my $self = shift;
	
	unless($self->data_name)
	{
		$self->data_name("MosaicsRData_".$self->bin_data."_".time);
	}
	
	my $save_r_command = "save.image(file=\"".$self->data_name."\")";
	
	$self->r_con->run($save_r_command);
	$self->_log_command($save_r_command);
	return $self->out_loc.$self->data_name;
}

# Sub for saving the current R img to file
# Default the file name unless data_name is set
sub load_r_image
{
	my $self = shift;
	my $image_file = shift;
	my $load_command;
	p($image_file);
	# Try kinda hard to find the r image file
	if(-e $image_file) {
		$load_command = "load(\"$image_file\")";
	} elsif (-e $self->out_loc."$image_file") {
		$load_command = "load(\"".$self->out_loc."$image_file\")";
	} else { $self->_die("Could not find r image file: $image_file in current dir or set out loc"); }

	# Load the file if found
	$self->r_con->run($load_command);
	$self->_log_command($load_command);
}

# Sub for saving the current object state to a config file
# 	which can be loaded back up with the load_state method
#	also automatically saves the R image
# requires: bin_data - for name of output file
sub save_state
{
	my $self = shift;

	# Save all params or zero them
	my %save_state =
	(
		out_loc       => ($self->out_loc || 0),
		analysis_type => ($self->analysis_type || 0),
		file_format   => ($self->file_format || 0),
		bin_data      => ($self->bin_data || 0),
		chip_bin      => ($self->chip_bin || 0),
		chip_file     => ($self->chip_file || 0),
		fit_name      => ($self->fit_name || 0),
		input_bin     => ($self->input_bin || 0),
		input_file    => ($self->input_file || 0),
		fragment_size => ($self->fragment_size || 0),
		bin_size      => ($self->bin_size || 0),
		map_score     => ($self->map_score || 0),
		gc_score      => ($self->gc_score || 0),
		n_score       => ($self->n_score || 0),
		fit_name      => ($self->fit_name || 0),
		peak_name     => ($self->peak_name || 0),
		data_name     => ($self->data_name || 0)
	);

	# Save R file, returns filename
	my $r_file = $self->save_r_image();
	my $state_file = $self->out_loc."MosaicsObj_".$self->bin_data."_".time;

	# Print each key->val pair to file
	for my $key (keys(%save_state))
	{
		my $line = "$key\t$save_state{$key}\n";
		append_file($state_file, $line);
	}

	# Add the special R file line at the end
	my $r_line = "RFILE\t$r_file";
	append_file($state_file, $r_line);

	# return the name of state file and report it
	print "Mosaics Object saved too: $state_file \n";
	return $state_file;
}

# Sub for loading an object state from a config file
#	and also loads the R image listed in the config file
# sets: Whatever is in the config file
sub load_state
{
	my $self = shift;
	my $state_file = shift;
	my @states = read_file($state_file);
	foreach my $state_line (@states)
	{
		my ($atter, $value) = split("\t", $state_line);
		chomp($atter); chomp($value);
		print "$atter -> $value\n";
		if($value and ($atter !~ m/^RFILE/))
		{
			$self->$atter($value);
		} elsif ($value and $atter eq "RFILE") {
			$self->load_r_image($value);
			$self->_log_command("Loaded State file: $value");
		}
	}
	return 1;
}

###############################################################################
# 					Private Methods 										  #
###############################################################################

## Validate opts hash for fit
sub _validate_fit_opts
{
	my $self = shift;
	my $opts = shift;
	unless(ref($opts) eq "HASH") { $self->_die("Opts parameter for fit is not a hashref!  $opts"); }

	my @valid_opts = qw|bgEst meanThres s d truncProb parallel nCore|;
	my @numeric_opts = qw|meanThres s d truncProb nCore|;
	my @valid_bgEst_values = qw|matchLow rMOM automatic|;
	my @boolean_opts = qw|parallel|;
	
	for my $key (keys(%$opts))
	{
		my $opt_val = $$opts{$key};
		unless($key ~~ @valid_opts) { $self->_die("Invalid option $key in opts hash for mosasicsFit command"); }
		
		if($key eq "bgEst") { 
			unless($opt_val ~~ @valid_bgEst_values) { $self->_die("Invalid bgEst value: $opt_val"); } 
		}
		
		if($key ~~ @numeric_opts) {
		unless(&looks_like_number($opt_val)) { $self->_die("Invalid $key value: $opt_val ! must be numeric"); }
		}

		if($key ~~ @boolean_opts) {
			unless($opt_val ~~ qw|TRUE FALSE|) { $self->_die("Invalid $key value: $opt_val ! must be boolean (TRUE FALSE)"); }
		}
	}
	return 1;
}

## Validate opts hash for peaks
sub _validate_peak_opts
{
	my $self = shift;
	my $opts = shift;
	unless(ref($opts) eq "HASH") { $self->_die("Opts parameter for peak is not a hashref!"); }

	my @valid_opts = qw|signalModel FDR binsize maxgap minsize thres|;
	for my $key (keys(%$opts))
	{
		my $opt_val = $$opts{$key};
		if($key eq "signalModel" and not($opt_val ~~ ("1S", "2S"))){
			$self->_die("signalModel value: $opt_val is invalid! Either 1S or 2S");
		}
		else{
			unless(&looks_like_number($opt_val)) {
				$self->_die("$key value: $opt_val is invalid! Must be numeric");
			}
		}
	}
	return 1;
}

## Validate opts hash for export
sub _validate_export_opts
{
	my $self = shift;
	my $opts = shift;
	unless(ref($opts) eq "HASH") { $self->_die("Opts parameter for export is not a hashref!"); }
	my @export_params = qw|type filename|;
	my @type_values = qw|txt bed gff|;
	for my $key (keys(%$opts))
	{
		my $opt_val = $$opts{$key};
		unless ($key ~~ @export_params) { $self->_die("$key is not a parameter for export!"); }
		if($key eq "type") {
			unless ($opt_val ~~ @type_values) { $self->_die("$opt_val is not a valid file type for export (txt bed gff)"); }
		}
	}
	return 1;
}

## Compare set data memebers to analysis type
## Varify we can safely run readBins in MOSAICS
sub _can_read_bins
{
	my $self = shift;
	unless($self->analysis_type) { $self->_die("Cannot read bins without analysis_type being set!"); }
	unless($self->chip_bin)      { $self->_die("Cannot read bins without chip_bin file being set!"); }
	given($self->analysis_type)
	{
		when(OS) 
		{
			# Needs M + GC + N for OS
			unless($self->map_score and $self->gc_score and $self->n_score) {
				$self->_die("Cannot read bins in OS (one sample) mode without GC+M+N score incorporated!");
			}
		}
		when(TS) {
			unless($self->input_bin) { $self->_die("Cannot read bins in two sample mode without input bin set"); }
		}
		when(IO) {
			unless($self->input_bin) { $self->_die("Cannot read bins in io mode without input bin set"); }
		}
	}
}

# Internal validation Methods
## Sub for constructing an input Bin
sub _have_chip_input
{
	my $self = shift;
	unless($self->file_format) { $self->_die("Cannot perform without a file format set!");              }
	unless($self->chip_file)   { $self->_die("Cannot perform without a chip_file, please initialize!"); }
}

# Internal validation Methods
## Sub for constructing an input Bin
sub _have_input_input
{
	my $self = shift;
	unless($self->file_format)  { $self->_die("Cannot perform without a file format set!");               }
	unless($self->input_file)   { $self->_die("Cannot perform without a input_file, please initialize!"); }
}

## R Library functions ##
sub _run_updates
{
	my $self = shift;
	my $connect = 'source("http://bioconductor.org/biocLite.R")';
	my $upgrader = 'biocLite()';
	my @commands = ($connect, $upgrader);
	eval { $self->r_con->run(@commands); };
	if ($@) 
	{
		warn "Update command failed! Probably network connectivity.";
		return 1;
	}
	$self->_log_command($_) for @commands;
}

sub _load_libs
{
	my $self = shift;
	my $parallel = "library(parallel)";
	my $mosaics = "library(mosaics)";
	my @commands = ($parallel, $mosaics);
	$self->r_con->run(@commands) or $self->_die("Cannot load R libs");
	$self->_log_command($_) for @commands;
}

### Logging function to track all R commands ran
sub _log_command
{
	my ($self, $entry) = @_;
	my $current = $self->r_log;
	$current .=  $entry."\n";
	$self->r_log($current);
}

sub _readbin_type_string
{
	my $self = shift;
	my $type_string = "type=c(\"chip\"";

	if($self->input_bin) { $type_string .= ", \"input\""; }
	if($self->map_score) { $type_string .= ", \"M\"";     }
	if($self->n_score)   { $type_string .= ", \"N\"";     }
	if($self->gc_score)  { $type_string .= ", \"GC\"";    }
	$type_string .= ")";
	return $type_string;
}

sub _readbin_file_string
{
	my $self = shift;
	my $file_string = "fileName=c(\"".$self->chip_bin."\"";

	if($self->input_bin) { $file_string .= ", \"".$self->input_bin."\""; }
	if($self->map_score) { $file_string .= ", \"".$self->map_score."\""; }
	if($self->n_score)   { $file_string .= ", \"".$self->n_score."\"";   }
	if($self->gc_score)  { $file_string .= ", \"".$self->gc_score."\"";  }
	$file_string .= ")";
	return $file_string;
}

sub _can_fit
{
	my $self = shift;
	unless ($self->analysis_type and $self->bin_data) {
		die "Cannot run fit command without analysis_type and bin_data set";
	}
}

sub _can_export
{
	my $self = shift;
	unless ($self->peak_name) { $self->_die("Cannot export peaks without a set peak object"); }
}

sub _set_r_dir
{
	my $self = shift;
	my $dir = shift;
	my $set_dir = "setwd(\"".$dir."\")";
	$self->r_con->run($set_dir);
	$self->_log_command($set_dir);
}

sub _die {
	my $self = shift;
	my $message = shift;
	say "Mosaics instance encountered the following error:";
	say "$message";
	say "Saving object state and R data";
	$self->save_state();
	say "R LOG:";
	say $self->dump_log();
	say "Object Dump:";
	p($self);
	die;
}

sub can_ping
{
	my $addr = "www.bioconductor.org";
	my $pinger = Net::Ping->new();
	if($pinger->ping($addr)) {
		return 1;
	} else {
		return -1;
	}
}

__PACKAGE__->meta->make_immutable;
1;