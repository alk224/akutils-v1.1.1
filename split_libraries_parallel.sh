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
mapname=$( basename $map )
cores=($4)
outdir=split_libraries
date0=`date +%Y%m%d_%I%M%p`
log=$outdir/log_$date0.txt
idxname=$( basename $index )
idxbase=`basename "$index" | cut -d. -f1`
idxext="${index##*.}"
rdname=$( basename $read )
rdbase=`basename "$read" | cut -d. -f1`
rdext="${read##*.}"
res1=$(date +%s.%N)

## Check input files

	if [[ ! -f $index ]]; then
	echo "	$index is not a valid file.
	Exiting.
	"
	exit 1
	elif [[ ! -f $read ]]; then
	echo "	$read is not a valid file.
	Exiting.
	"
	exit 1
	fi

##Read in variables from config file

	local_config_count=(`ls $1/akutils*.config 2>/dev/null | wc -w`)
	if [[ $local_config_count -ge 1 ]]; then

	config=`ls $1/akutils*.config`

	echo "		Using local akutils config file.
		$config
	"
#	echo "
#	Referencing local akutils config file.
#	$config
#	" >> $log
	else
	global_config_count=(`ls $scriptdir/akutils_resources/akutils*.config 2>/dev/null | wc -w`)
	if [[ $global_config_count -ge 1 ]]; then

	config=`ls $scriptdir/akutils_resources/akutils*.config`

	echo "	Using global akutils config file.
	$config
	"
#	echo "
#	Referencing global akutils config file.
#	$config
#	" >> $log
	fi
	fi

	slqual=(`grep "Split_libraries_qvalue" $config | grep -v "#" | cut -f 2`)

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

	if [[ $idxext != "fastq" ]]; then
	mv $index $idxbase.fastq
	fi
	if [[ $rdext != "fastq" ]]; then
	mv $read $rdbase.fastq
	fi

	## Detect barcode lengths

	if [[ `sed '2q;d' $idxbase.fastq | egrep "\w+" | wc -m` == 13  ]]; then
	barcodetype=(golay_12)
	else
	barcodetype=$((`sed '2q;d' $idxbase.fastq | egrep "\w+" | wc -m`-1))
	fi
	qvalue=$(($slqual+1))
	echo "	Performing split_libraries.py command (q$qvalue)"
	if [[ $barcodetype == "golay_12" ]]; then
	echo " 	12 base Golay index codes detected...
	"
	else
	echo "	$barcodetype base indexes detected...
	"
	fi


	echo "	Splitting input sequences.
	"

	( fastq-splitter.pl --n-parts $cores --measure count $idxbase.fastq ) &
	( fastq-splitter.pl --n-parts $cores --measure count $rdbase.fastq ) &
	wait

	echo "
	Splitting libraries in parallel on $cores cores.
	"

	for idxpart in `ls $idxbase.part-*.fastq` ; do
		part=`ls $idxpart | cut -d. -f2`
		mkdir $outdir/$part
		mv $idxbase.$part.fastq $outdir/$part/
		mv $rdbase.$part.fastq $outdir/$part/
		( split_libraries_fastq.py -i $outdir/$part/$rdbase.$part.fastq -b $outdir/$part/$idxbase.$part.fastq -m $map -o $outdir/$part/ -q $slqual --barcode_type $barcodetype ) &
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

#	cat $outdir/part-1/split_library_log.txt > $outdir/split_library_log.temp
#	cat $outdir/part-1/histograms.txt > $outdir/histograms.temp


inputs=`cat split_libraries/part-*/split_library_log.txt | grep "Total number of input sequences" | cut -d: -f2 | bc | awk '{s+=$1} END {print s}'`
nobarcode=`cat split_libraries/part-*/split_library_log.txt | grep "Barcode not in mapping file" | cut -d: -f2 | bc | awk '{s+=$1} END {print s}'`
shortreads=`cat split_libraries/part-*/split_library_log.txt | grep "Read too short after quality" | cut -d: -f2 | bc | awk '{s+=$1} END {print s}'`
ncount=`cat split_libraries/part-*/split_library_log.txt | grep "Count of N characters exceeds" | cut -d: -f2 | bc | awk '{s+=$1} END {print s}'`
qualdigit=`cat split_libraries/part-*/split_library_log.txt | grep "Illumina quality digit" | cut -d: -f2 | bc | awk '{s+=$1} END {print s}'`
errors=`cat split_libraries/part-*/split_library_log.txt | grep "Barcode errors exceed max" | cut -d: -f2 | bc | awk '{s+=$1} END {print s}'`

idlist=`grep -v "#" $map | cut -f1`
logfile=$outdir/split_libraries_parallel_log.txt

echo > $logfile
echo "Input file paths
Mapping filepath: $mapname
Sequence read filepath: $rdname
Barcode read filepath: $idxname

Total number of input sequences: $inputs
Barcode not in mapping file: $nobarcode
Read too short after quality truncation: $shortreads
Count of N characters exceeds limit: $ncount
Illumina quality digit = 0: $qualdigit
Barcode errors exceed max: $errors

Result summary (after quality filtering)" >> $logfile
	for sampleid in `echo $idlist` ; do
	readcount=`cat split_libraries/part-*/split_library_log.txt | grep $sampleid | cut -f2 | bc | awk '{s+=$1} END {print s}'`
	echo " $sampleid:	$readcount" >> $outdir/counts.temp
	done
	cat $outdir/counts.temp | sort -k2 -r >> $logfile
	outputs=`cat $outdir/counts.temp | sort -k2 -r | cut -f2 | bc | awk '{s+=$1} END {print s}'`

	echo "
Total number of seqs written	$outputs
---
	" >> $logfile

## Cleanup and report on exit

rm $outdir/counts.temp
rm -r $outdir/part-*

res2=$(date +%s.%N)
dt=$(echo "$res2 - $res1" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

runtime=`printf "%d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`

echo "	Workflow steps completed.

	Processed $inputs input sequences, wrote $outputs sequences to seqs.fna.

	Time to complete: $runtime
"
echo "Parallel split libraries ran on $cores cores.
Total runtime: $runtime
" >> $logfile
exit 0

