#!/bin/bash
set -e

#script to process split libraries step in parallel

## Check whether user had supplied -h or --help. If yes display help 

	if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
		echo "
		This script will run the QIIME script,
		split_libraries_fastq.py in parallel.

		Usage (order is important!!):
		split_libraries_parallel.sh <sequence_file> <index_file> <map_file> <threads>
		
		Example:
		split_libraries_parallel.sh rd.fq idx.fq map.txt 12

		Will process sequences from rd.fq using the index reads
		in idx.fq according to the index sequences listed in 
		map.txt.  Ouput will be in a subdirectory called
		split_libraries.  Processing will occur on 12 threads.

		Index lengths are automatically detected.  Quality
		threshold is determined from your akutils config file
		(local first, then global).
		"
		exit 0
	fi 

## If other than 3 arguments supplied, display usage 

	if [[ "$#" -ne 4 ]]; then 
		echo "
		Usage (order is important!!):
		split_libraries_parallel.sh <sequence_file> <index_file> <map_file> <threads>
		"
		exit 1
	fi

## Check for required dependencies:

	scriptdir="$( cd "$( dirname "$0" )" && pwd )"

	echo "
	Checking for required dependencies...
	"

	scriptdir="$( cd "$( dirname "$0" )" && pwd )"


	for line in `cat $scriptdir/akutils_resources/split_libraries_parallel.dependencies.list`; do
	dependcount=`command -v $line 2>/dev/null | wc -w`
		if [[ $dependcount == 0 ]]; then
		echo "
	$line is not in your path.  Dependencies not satisfied.
	Exiting.
	"
		exit 1
		elif [[ $dependcount -ge 1 ]]; then
		echo "	$line is in your path..."
		fi
#	fi
	done
	echo "
	All dependencies satisfied.  Proceeding...
	"

## Define variables

read=($1)
index=($2)
map=($3)
cores=($4)
outdir=split_libraries
date0=`date +%Y%m%d_%I%M%p`
log=$outdir/log_$date0.txt
idxbase=$( basename $index )
rdbase=$( basename $read )
res1=$(date +%s.%N)

## Make output directory

	if [[ ! -d $outdir ]]; then
	mkdir -p $outdir
	else
	echo "
		Output directory already exists.
		Exiting.
	"
	exit 1
	fi

## Split input fastqs with fastq-splitter.pl

	echo "	Splitting input sequences.
	"

	fastq-splitter.pl --n-parts $cores --measure count $index
	fastq-splitter.pl --n-parts $cores --measure count $read

	echo "
	Splitting libraries in parallel.
	"

	for idxpart in `ls $idxbase.part-*` ; do
		part="${idxpart##*.}"
		mkdir $outdir/$part
		mv $idxbase.$part $outdir/$part/
		mv $rdbase.$part $outdir/$part/
		( split_libraries_fastq.py -i $outdir/$part/$rdbase.$part -b $outdir/$part/$idxbase.$part -m $map -o $outdir/$part/ ) &
	done
	wait
## Compile read and index results

	for dirpart in `ls $outdir` ; do
		part=$( basename $dirpart )
		num="${part##*-}"
		sed -i "s/ /00$num /" $outdir/$part/seqs.fna
	done

	cat $outdir/part-*/seqs.fna > $outdir/seqs.fna

## Compile log results

	cat $outdir/part-1/split_library_log.txt > $outdir/split_library_log.temp
	cat $outdir/part-1/histograms.txt > $outdir/histograms.temp


inputs=`cat split_libraries/part-*/split_library_log.txt | grep "Total number of input sequences" | cut -d: -f2 | bc | awk '{s+=$1} END {print s}'`

res2=$(date +%s.%N)
dt=$(echo "$res2 - $res1" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

runtime=`printf "Processed $inputs sequences in %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`

echo "	Workflow steps completed.

	$runtime
"

exit 0


