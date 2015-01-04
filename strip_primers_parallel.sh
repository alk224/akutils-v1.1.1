#!/bin/bash
set -e

# check whether user had supplied -h or --help . If yes display help 
	if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
		echo "
		Usage (order is important!):
		strip_primers_parallel <fastq1> <fastq2> <rev/comp primers as fasta> <threads to use>

		Resulting files will be output to a subdirectory called fastq-mcf_out.

		This script parallelizes adapter stripping using the fastq-mcf utility from ea-utils.
		For this to work, you must have installed (and in your path) ea-utils and NGSutils.
		This script is intended for Ubuntu 14.04.  I can't help you if you have problems!!

		Importantly, this script trims primers from input fastqs without removing any sequence
		reads which is important if you need to pass an associated index file against them next
		for demultiplexing purposes (eg for QIIME processing of amplicon data).

		Rev/comp primers fasta file should contain somthing like this:
		>515F-1
		TTACCGCGGCTGCTGGCAC
		>515F-2
		TTACCGCGGCGGCTGGCAC
		>806R-1
		ATTAGATACCCTTGTAGTCC
		>806R-2
		ATTAGAAACCCTTGTAGTCC
		>806R-3
		ATTAGATACCCCTGTAGTCC
		"
		exit 0
	fi

# if other than four arguments supplied, display usage 
	if [  $# -ne 4 ]; then 
		echo "
		Usage (order is important!):
		strip_primers_parallel <fastq1> <fastq2> <rev/comp primers as fasta> <threads to use>

		Resulting files will be output to the same directory.
		"
		exit 1
	fi 
  
		#Determine number of sequences in input file 

		echo "
		Reading input files...
		"

		fastqlines=$(cat $1 | wc -l)
		fastqseqs=$(($fastqlines/4))
		corelines=$(($fastqseqs/$4))
		digits=$(grep -o \. <<<$corelines | wc -l)

## set working directory, move there, and check for existing outputs

	workdir=$(pwd)
	cd $workdir

	if [[ ! -d $workdir/fastq-mcf_out ]]; then

		mkdir $workdir/fastq-mcf_out

	else
		echo "		Directory fastq-mcf_output exists.
		Deleting contents and filtering data.
		"
		rm -r fastq-mcf_out/*

	fi

		outdir=$workdir/fastq-mcf_out

	if [ "$digits" -lt "4" ]; then

		echo "		Your fastq input has fewer than 10,000 sequences.  
		Processing on a single core only.
		"

		#extract filename bases for output naming purposes
		fastq1base=`basename "$1" | cut -d. -f1`
		fastq2base=`basename "$2" | cut -d. -f1`
		#fastq-mcf command (single process)
		`fastq-mcf -0 -t 0.0001 $3 $1 $2 -o $outdir/$fastq1base.mcf.fq -o $outdir/$fastq2base.mcf.fq > $outdir/fastq-mcf.log`
	else
		echo "
		Processing on $4 threads...
		"

		# make temp dir
		mkdir $outdir/mcf-temp
		#make log file to compile all logged removals into
		echo > $outdir/fastq-mcf.log

		#use fastqutils command (NGSutils) to split fastq files according to desired processing level		
		`fastqutils split $1 $outdir/mcf-temp/r1.temp $4`
		`fastqutils split $2 $outdir/mcf-temp/r2.temp $4`
		wait

	#Parallel processing of fastq-mcf commands in background
	for splitseq in $outdir/mcf-temp/r1.*.fastq; do	
		( splitbase=$(basename $splitseq .fastq)
		splitbase2=$(echo $splitbase | sed 's/r1/r2/g')
		fastq-mcf -0 -t 0.0001 $3 $outdir/mcf-temp/$splitbase.fastq $outdir/mcf-temp/$splitbase2.fastq -o $outdir/mcf-temp/$splitbase.mcf.fastq -o $outdir/mcf-temp/$splitbase2.mcf.fastq >> $outdir/fastq-mcf.log ) &
	done
	wait

	#Cat results together
		cat $outdir/mcf-temp/r1.temp.*.mcf.fastq > $outdir/r1.mcf.fastq
		cat $outdir/mcf-temp/r2.temp.*.mcf.fastq > $outdir/r2.mcf.fastq
		wait
	#Remove temp files
		rm -r $outdir/mcf-temp
	fi
		echo "		Processing complete.  Filtered data is found in the 
		following output files:
		
		$outdir/r1.mcf.fastq
		$outdir/r2.mcf.fastq

		Details can be found in $outdir/fastq-mcf.log

		"

