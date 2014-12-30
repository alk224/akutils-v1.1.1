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

	echo "
---

Single indexed read joining workflow.

---

Concatenation step beginning..." > $outdir/fastq-join_stdout.txt
	date >> $outdir/fastq-join_stdout.txt

	echo "
Single indexed read joining workflow.

Concatenation step beginning...
"

## Set start of read data for fastx_trimmer steps

	readno=$(($4+1))

echo "
Concatenating index read onto first read...
"

## Concatenate index1 in front of read1

	paste -d '' <(echo; sed -n '1,${n;p;}' $1 | sed G) $2 | sed '/^$/d' > $outdir/i1r1.fq
	wait

## Log concatenation completion

	echo "Concatenation completed" >> $outdir/fastq-join_stdout.txt
	date >> $outdir/fastq-join_stdout.txt
	echo "
---" >> $outdir/fastq-join_stdout.txt

## Fastq-join command

	echo "
Joining command as issued: 
fastq-join ${@:5} $outdir/i1r1.fq $3 -o $outdir/temp.%.fq" >> $outdir/fastq-join_stdout.txt

	echo "
Fastq-join results:" >> $outdir/fastq-join_stdout.txt
	fastq-join ${@:5} $outdir/i1r1.fq $3 -o $outdir/temp.%.fq >> $outdir/fastq-join_stdout.txt

	wait

	echo "
Fastq-join step completed" >> $outdir/fastq-join_stdout.txt
	date >> $outdir/fastq-join_stdout.txt
	echo "
---" >> $outdir/fastq-join_stdout.txt

#split index from successfully joined reads

	echo "
Index trimming command as issued: 
fastx_trimmer -l $4 -i $outdir/temp.join.fq -o $outdir/idx.fq -Q 33

Read trimming command as issued: 
fastx_trimmer -f $readno -i $outdir/temp.join.fq -o $outdir/rd.fq -Q 33
	" >> $outdir/fastq-join_stdout.txt

## Split index from successfully joined reads in background

	( fastx_trimmer -l $4 -i $outdir/temp.join.fq -o $outdir/idx.fq -Q 33
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

	echo "Removing temporary files (raw join data, plus unjoined reads)
" >> $outdir/fastq-join_stdout.txt
	rm $outdir/temp.*.fq

## Log end of workflow

	echo "Joining workflow is completed!" >> $outdir/fastq-join_stdout.txt
	date >> $outdir/fastq-join_stdout.txt
	echo "
---
	" >> $outdir/fastq-join_stdout.txt
	echo "Joining workflow is completed.
	See output file, $outdir/fastq-join_stdout.txt for joining details.

	"

