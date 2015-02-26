#!/bin/bash
set -e

# check whether user had supplied -h or --help . If yes display help 
	if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
		echo "
		Usage (order is important!):
		strip_primers_parallel <rev/comp_primers> <threads> <read1> <read2> <index1> <index2>

		<index2> is optional.

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

## If other than five or six arguments supplied, display usage

	if [[ $# -le 4 ]] || [[ $# -ge 7 ]]; then 
		echo "
		Usage (order is important!):
		strip_primers_parallel <rev/comp_primers> <threads> <read1> <read2> <index1> <index2>

		<index2> is optional.

		Resulting files will be output to a subdirectory called fastq-mcf_out.
		"
		exit 1
	fi 
  
	workdir=$(pwd)
	res1=$(date +%s.%N)

## Check for output directory

	if [[ ! -d $workdir/fastq-mcf_out ]]; then

		mkdir -p $workdir/fastq-mcf_out

	else
		echo "		
		Directory fastq-mcf_output exists.
		Attempting to use previously generated files.
		"
	fi

	outdir=$workdir/fastq-mcf_out
	primers=($1)
	cores=($2)
	read1=($3)
	read2=($4)
	index1=($5)
	index2=($6)
	read1name=$( basename $read1 )
	read1base=`basename "$read1" | cut -d. -f1`
	read1ext="${read1##*.}"
	read2name=$( basename $read2 )
	read2base=`basename "$read2" | cut -d. -f1`
	read2ext="${read2##*.}"
	index1name=$( basename $index1 )
	index1base=`basename "$index1" | cut -d. -f1`
	index1ext="${read1##*.}"
	if [[ ! -z $index2 ]]; then
	index2name=$( basename $index2 )
	index2base=`basename "$index2" | cut -d. -f1`
	index2ext="${read2##*.}"
	fi
	date0=`date +%Y%m%d_%I%M%p`
	log=($outdir/fastq-mcf_$date0.log)

## Check input files

	if [[ ! -f $index1 ]]; then
	echo "	$index1 is not a valid file.
	Exiting.
	"
	exit 1
	elif [[ ! -f $read1 ]]; then
	echo "	$read1 is not a valid file.
	Exiting.
	"
	exit 1
	elif [[ ! -f $read2 ]]; then
	echo "	$read2 is not a valid file.
	Exiting.
	"
	exit 1
	fi
	if [[ ! -z $index2 ]]; then
	if [[ ! -f $index2 ]]; then
	echo "	$index2 is not a valid file.
	Exiting.
	"
	exit 1
	fi
	fi

## Check for required dependencies:

	scriptdir="$( cd "$( dirname "$0" )" && pwd )"

	echo "		Checking for required dependencies...
	"

	scriptdir="$( cd "$( dirname "$0" )" && pwd )"


	for line in `cat $scriptdir/akutils_resources/strip_primers.dependencies.list`; do
	dependcount=`command -v $line 2>/dev/null | wc -w`
		if [[ $dependcount == 0 ]]; then
		echo "
		$line is not in your path.  Dependencies not satisfied.
		Exiting.
		"
		exit 1
		else
		if [[ $dependcount -ge 1 ]]; then
		echo "		$line is in your path..."
		fi
		fi
	done
	echo "		All dependencies satisfied.  Proceeding...
	"

## Set working directory

	if [[ ! -d $outdir ]]; then
		mkdir -p $outdir
	else
		echo "		Directory fastq-mcf_output exists.
		Deleting contents and filtering data.
		"
		rm -r fastq-mcf_out
		mkdir -p $outdir
	fi

## Parallel processing steps

	echo "		Processing on $cores threads...
	"

	if [[ $read1ext != "fastq" ]]; then
	mv $read1 $read1base.fastq
	fi
	if [[ $read2ext != "fastq" ]]; then
	mv $read2 $read2base.fastq
	fi
	if [[ $index1ext != "fastq" ]]; then
	mv $index1 $index1base.fastq
	fi
	if [[ ! -z $index2 ]]; then
	if [[ $index2ext != "fastq" ]]; then
	mv $index2 $index2base.fastq
	fi
	fi

	#Use fasta-splitter.pl to split fastq files according to desired processing level
	echo "		Splitting input sequences.
	"

	( fastq-splitter.pl --n-parts $cores --measure count $read1base.fastq ) &
	( fastq-splitter.pl --n-parts $cores --measure count $read2base.fastq ) &
	wait

	echo "
		Stripping primers from data.
	"

	for rd1part in `ls $read1base.part-*.fastq` ; do
		part=`ls $rd1part | cut -d. -f2`
		mkdir $outdir/$part
		mv $read1base.$part.fastq $outdir/$part/
		mv $read2base.$part.fastq $outdir/$part/
		( fastq-mcf -0 -t 0.0001 $primers $outdir/$part/$read1base.$part.fastq $outdir/$part/$read2base.$part.fastq -o $outdir/$part/$read1base.$part.mcf.fastq -o $outdir/$part/$read2base.$part.mcf.fastq >> $log ) &
	done
	wait

	#Cat results together
		cat $outdir/part-*/$read1base.part-*.mcf.fastq > $outdir/$read1base.mcf.fastq
		cat $outdir/part-*/$read2base.part-*.mcf.fastq > $outdir/$read2base.mcf.fastq
		wait

## Check for and remove empty fastq records

#	echo "
#Filtering empty fastq records from input files." >> $log
#date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "		Filtering empty fastq records from input files.
	"

		emptycount=`grep -e "^$" $outdir/$read1base.mcf.fastq | wc -l`

		if [[ $emptycount != 0 ]]; then

		grep -B 1 -e "^$" $outdir/$read1base.mcf.fastq > $outdir/empty.fastq.records
#		grep -B 1 -e "^$" $outdir/$read2base.mcf.fastq >> $outdir/empty.fastq.records
		sed -i '/^\s*$/d' $outdir/empty.fastq.records
		sed -i '/^\+/d' $outdir/empty.fastq.records
		sed -i '/^\--/d' $outdir/empty.fastq.records
		sed -i 's/^\@//' $outdir/empty.fastq.records
		empties=`cat $outdir/empty.fastq.records | wc -l`
#	echo "
#Found $empties empty fastq records." >> $log
	echo "		Found $empties empty fastq records.
	"

		( filter_fasta.py -f $outdir/$read1base.mcf.fastq -o $outdir/$read1base.noprimers.fastq -s $outdir/empty.fastq.records -n ) &
		( filter_fasta.py -f $outdir/$read2base.mcf.fastq -o $outdir/$read2base.noprimers.fastq -s $outdir/empty.fastq.records -n ) &
		( filter_fasta.py -f $index1base.fastq -o $outdir/$index1base.noprimers.fastq -s $outdir/empty.fastq.records -n ) &
		if [[ ! -z $index2 ]]; then
		( filter_fasta.py -f $index2base.fastq -o $outdir/$index2base.noprimers.fastq -s $outdir/empty.fastq.records -n ) &
		fi
		wait
		fi

## Remove temp files
	rm -r $outdir/part-*
	rm $outdir/$read1base.mcf.fastq
	rm $outdir/$read2base.mcf.fastq
	rm $outdir/empty.fastq.records

## Log end of workflow

res2=$(date +%s.%N)
dt=$(echo "$res2 - $res1" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

runtime=`printf "Total runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`

echo "		Strip primers workflow steps completed.

		$runtime
"
echo "
---

All workflow steps completed.  Hooray!" >> $log
date "+%a %b %I:%M %p %Z %Y" >> $log
echo "
$runtime 
" >> $log

