#!/bin/bash
set -e

## check whether user had supplied -h or --help. If yes display help 

	if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
		echo "
		This script takes paired end fastq files with a separate
		index read (3 input files) and joins the paired end reads
		where possible while keeping all reads in phase.  This is
		crucial for downstream use in certain applications (e.g.
		as inputs to QIIME).				

		Output will be 2 files, an index file (idx.fq) and a read
		file (rd.fq).

		Usage (order is important!!):
		Single_indexed_fqjoin_workflow.sh <IndexFastq> <Read1Fastq> <Read2Fastq> <IndexLength> <Fastq-join options>

		Example:
		Single_indexed_fqjoin_workflow.sh index1.fq read1.fq read2.fq 12 -m 30 -p 10

		This example is joining fastq files read1.fq and read2.fq 
		while keeping reads in sync with index1.fq.  The index read 
		is 12 bases long, and it is calling options to the fastq-join
		command as -m 30 (minimum overlap of 30 bases) and -p 10
		(10 percent allowable mismatch).

		Requires the following dependencies to run:
		1) ea-utils (https://code.google.com/p/ea-utils/)
		2) Fastx toolkit (http://hannonlab.cshl.edu/fastx_toolkit/)
		
		Citing ea-utils: Erik Aronesty (2011). ea-utils: Command-line tools for processing biological sequencing data; http://code.google.com/p/ea-utils
		"
		exit 0
	fi 

## if less than three arguments supplied, display usage 

	if [  "$#" -le 3 ] ;
	then 
		echo "
		Usage (order is important!!):
		Single_indexed_fqjoin_workflow.sh <IndexFastq> <Read1Fastq> <Read2Fastq> <IndexLength> <Fastq-join options>
		"
		exit 1
	fi



## Define output directory and check to see it already exists

	outdir=fastq-join_output
	if [[ -d fastq-join_output/ ]]; then
		echo "
		Output directory already exists ($outdir).  
		Aborting workflow.
		"
		exit 1
	else
		mkdir $outdir
	fi

## Log start of workflow

	date0=`date +%Y%m%d_%I%M%p`
	log=($outdir/fastq-join_workflow_$date0.log)

	echo "
		Single-indexed read joining workflow starting."

	echo "
Single-indexed read joining workflow starting" >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	res1=$(date +%s.%N)

## Set start of read data for fastx_trimmer steps

	readno=$(($4+1))

## Concatenate index1 in front of read1

	echo "
		Concatenating index and first read."
	echo "
Concatenation:" >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
#	echo "	paste -d '' <(echo; sed -n '1,${n;p;}' $1 | sed G) $2 | sed '/^$/d' > $outdir/i1r1.fq" >> $log

paste -d '' <(echo; sed -n '1,${n;p;}' $1 | sed G) $2 | sed '/^$/d' > $outdir/i1r1.fq
	wait

## Fastq-join command

	echo "
		Joining reads."

	echo "
Joining command:" >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "	fastq-join ${@:5} $outdir/i1r1.fq $3 -o $outdir/temp.%.fq" >> $log

	echo "
Fastq-join results:" >> $log
	fastq-join ${@:5} $outdir/i1r1.fq $3 -o $outdir/temp.%.fq >> $log

	wait

## Split index and read data from successfully joined reads

	echo "
		Splitting read and index data from
		successfully joined data."

	echo "
Split index and read commands:" >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "	fastx_trimmer -l $4 -i $outdir/temp.join.fq -o $outdir/idx.fq -Q 33" >> $log
	echo "	fastx_trimmer -f $readno -i $outdir/temp.join.fq -o $outdir/rd.fq -Q 33" >> $log

	( fastx_trimmer -l $4 -i $outdir/temp.join.fq -o $outdir/idx.fq -Q 33 ) &
	( fastx_trimmer -f $readno -i $outdir/temp.join.fq -o $outdir/rd.fq -Q 33 ) &
	wait

## Remove temp files

	echo "
		Removing temporary files..."

	echo "
Removing temporary files (raw join data, unjoined reads, concatenated indexes)." >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	rm $outdir/temp.*.fq
	rm $outdir/i1r1*.fq

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

echo "
		Joining workflow steps completed.

		$runtime
"
echo "
---

All workflow steps completed.  Hooray!" >> $log
date "+%a %b %I:%M %p %Z %Y" >> $log
echo "
$runtime 
" >> $log

