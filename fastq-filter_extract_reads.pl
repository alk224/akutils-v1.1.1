#!/usr/bin/env perl

=head1 NAME

fastq-filter_extract_reads.pl - Splits fastq file based on read ids in a list 

=head1 SYNOPSIS

fastq-filter_extract_reads.pl -r read_ids.txt -f sequence_reads.fastq [-help] 

 Required arguments:
    -r        File listing read ids, one per line
    -f        Fastq file (with each sequence reprensented in four lines)

 Options:
    -help -h  Help
    
 Example usage:
    fastq-filter_extract_reads.pl -r read_ids.txt -f sequence_reads.fastq \
       1> reads_in_file.fastq 2> reads_not_in_file.fastq

=head1 DESCRIPTION

Read in a list of read identifiers and a Fastq file.  If the read id is in the list, the fastq record is printed to STDOUT, otherwise it is printed to STDERR 
	
=head1 AUTHOR

Lance Parsons <lparsons@princeton.edu>

=head1 LICENSE

This script is licensed by the Simplified BSD License
See LICENSE.TXT and <http://www.opensource.org/licenses/bsd-license>

Copyright (c) 2011, Lance Parsons
All rights reserved.

=cut

use strict;
use Getopt::Long;
use Pod::Usage;

# Variables set in response to command line arguments
# (with defaults)

my $needsHelp = '';
my $readidfilename;
my $fastqfilename;

my $options_okay = &Getopt::Long::GetOptions(
	'readids|r=s' => \$readidfilename,
	'fastq|f=s'   => \$fastqfilename,
	'help|h'      => \$needsHelp
);

# Check to make sure options are specified correctly and files exist
&check_opts();

my %readids;
open( my $readidfile, "<", $readidfilename );
while (<$readidfile>) {
	chomp();
	$readids{$_} = '';
}

open( my $fastqfile, "<", $fastqfilename );
while (<$fastqfile>) {
	chomp();
	my $line = $_;
	if ( $line =~ /^@/ ) {
		$line =~ s/^@//;
		my $output = *STDOUT;
		if ( !exists( $readids{$line} ) ) {
			$output = *STDERR;
		}
		print {$output}( "@" . $line . "\n" );
		$line = <$fastqfile>;
		print {$output}($line);
		$line = <$fastqfile>;
		print {$output}($line);
		$line = <$fastqfile>;
		print {$output}($line);
	}
}

# Check for problem with the options or if user requests help
sub check_opts {
	if ($needsHelp) {
		pod2usage( -verbose => 2 );
	}

	if ( !$options_okay ) {
		pod2usage(
			-exitval => 2,
			-verbose => 1,
			-message => "Error specifying options."
		);
	}
	if ( !-e $readidfilename ) {
		pod2usage(
			-exitval => 2,
			-verbose => 1,
			-message => "Cannot read id list from file: '$readidfilename!'\n"
		);
	}
	if ( !-e $fastqfilename ) {
		pod2usage(
			-exitval => 2,
			-verbose => 1,
			-message => "Cannot read fastq file: '$fastqfilename!'\n"
		);
	}
}

