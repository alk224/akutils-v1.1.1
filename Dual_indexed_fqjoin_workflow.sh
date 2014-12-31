#!/bin/bash
set -e

## check whether user had supplied -h or --help. If yes display help 

	if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
		echo "
		This script takes paired end fastq files with two separate
		index reads (4 input files) and joins the paired end reads
		where possible while keeping all reads in phase.  This is
		crucial for downstream use in certain applications (e.g.
		as inputs to QIIME).				

		Output will be 2 files, an index file (idx.fq) and a read
		file (rd.fq).  The index will be a concatenation of the
		two index reads such that the resulting sequence will be:
			<index1seq><index2seq>

		Usage (order is important!!):
		Dual_indexed_fqjoin_workflow.sh <Index1Fastq> <Index2Fastq> <Read1Fastq> <Read2Fastq> <IndexLength> <Fastq-join options>

		Example:
		Dual_indexed_fqjoin_workflow.sh index1.fq index2.fq read1.fq read2.fq 16 -m 30 -p 10

		This example is joining fastq files read1.fq and read2.fq 
		while keeping reads in sync with index1.fq.  The index
		reads are each 8 bases long, and it is calling options to
		the fastq-join command as -m 30 (minimum overlap of 30
		bases) and -p 10 (10 percent allowable mismatch).

		Requires the following dependencies to run:
		1) ea-utils (https://code.google.com/p/ea-utils/)
		2) Fastx toolkit (http://hannonlab.cshl.edu/fastx_toolkit/)
		
		Citing ea-utils: Erik Aronesty (2011). ea-utils: Command-line tools for processing biological sequencing data; http://code.google.com/p/ea-utils
		"
		exit 0
	fi 

## if less than four arguments supplied, display usage 

	if [  "$#" -le 4 ] ;
	then 
		echo "
		Usage (order is important!!):
		Dual_indexed_fqjoin_workflow.sh <Index1Fastq> <Index2Fastq> <Read1Fastq> <Read2Fastq> <IndexLength> <Fastq-join options>

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

	echo "
---

Dual indexed read joining workflow.

---

Concatenation step beginning..." > $outdir/fastq-join_stdout.txt
	date >> $outdir/fastq-join_stdout.txt

	echo "
Dual indexed read joining workflow.

Concatenation steps beginning...
"

## Set start of read data for fastx_trimmer steps

	readno=$(($5+1))

## Concatenate index1 in front of index2

	paste -d '' <(echo; sed -n '1,${n;p;}' $1 | sed G) $2 | sed '/^$/d' > $outdir/i1i2.fq
	wait

## Concatenate indexes in front of read1

	paste -d '' <(echo; sed -n '1,${n;p;}' $outdir/i1i2.fq | sed G) $3 | sed '/^$/d' > $outdir/i1i2r1.fq
	wait

## Log concatenation completion

	echo "Concatenations completed.

Joining in progress..."

	echo "Concatenations completed" >> $outdir/fastq-join_stdout.txt
	date >> $outdir/fastq-join_stdout.txt
	echo "
---" >> $outdir/fastq-join_stdout.txt

## Fastq-join command

	echo "
Joining command as issued: 
fastq-join ${@:6} $outdir/i1i2r1.fq $4 -o $outdir/temp.%.fq" >> $outdir/fastq-join_stdout.txt

	echo "
Fastq-join results:" >> $outdir/fastq-join_stdout.txt
	fastq-join ${@:6} $outdir/i1i2r1.fq $4 -o $outdir/temp.%.fq >> $outdir/fastq-join_stdout.txt

	wait

## Log join completion

	echo "
Fastq-join step completed.

Splitting index and read files...
"
	echo "
Fastq-join step completed" >> $outdir/fastq-join_stdout.txt
	date >> $outdir/fastq-join_stdout.txt
	echo "
---" >> $outdir/fastq-join_stdout.txt

## Split index from successfully joined reads

	echo "
Index trimming command as issued: 
fastx_trimmer -l $5 -i $outdir/temp.join.fq -o $outdir/idx.fq -Q 33

Read trimming command as issued: 
fastx_trimmer -f $readno -i $outdir/temp.join.fq -o $outdir/rd.fq -Q 33
	" >> $outdir/fastq-join_stdout.txt

## Split index from successfully joined reads in background

	( fastx_trimmer -l $5 -i $outdir/temp.join.fq -o $outdir/idx.fq -Q 33
	wait
	echo "Index read is finished" >> $outdir/fastq-join_stdout.txt
	date >> $outdir/fastq-join_stdout.txt 
	echo "
---
	" >> $outdir/fastq-join_stdout.txt ) &

## Split read data from successfully joined reads in background

	( fastx_trimmer -f $readno -i $outdir/temp.join.fq -o $outdir/rd.fq -Q 33
	wait
	echo "Joined sequences read is finished" >> $outdir/fastq-join_stdout.txt
	date >> $outdir/fastq-join_stdout.txt
	echo "
---
	" >> $outdir/fastq-join_stdout.txt ) &
	wait

## Remove temp files

	echo "Removing temporary files..."

	echo "Removing temporary files (raw join data, unjoined reads, concatenated indexes).
" >> $outdir/fastq-join_stdout.txt
	rm $outdir/temp.*.fq
	rm $outdir/i1i2*.fq

## Log end of workflow

	echo "Joining workflow is completed!" >> $outdir/fastq-join_stdout.txt
	date >> $outdir/fastq-join_stdout.txt
	echo "
---
	" >> $outdir/fastq-join_stdout.txt
	echo "
	Joining workflow is completed.
	See output file for joining details.

	$outdir/fastq-join_stdout.txt
	"

