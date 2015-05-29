#!/usr/bin/env bash
#
#  Dual_indexed_fqjoin_workflow.sh - Fastq-join workflow for dual-indexed MiSeq data
#
#  Version 0.1.0 (May 29, 2015)
#
#  Copyright (c) 2014-2015 Andrew Krohn
#
#  This software is provided 'as-is', without any express or implied
#  warranty. In no event will the authors be held liable for any damages
#  arising from the use of this software.
#
#  Permission is granted to anyone to use this software for any purpose,
#  including commercial applications, and to alter it and redistribute it
#  freely, subject to the following restrictions:
#
#  1. The origin of this software must not be misrepresented; you must not
#     claim that you wrote the original software. If you use this software
#     in a product, an acknowledgment in the product documentation would be
#     appreciated but is not required.
#  2. Altered source versions must be plainly marked as such, and must not be
#     misrepresented as being the original software.
#  3. This notice may not be removed or altered from any source distribution.
#

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

## Check for required dependencies:

	scriptdir="$( cd "$( dirname "$0" )" && pwd )"

echo "
		Checking for required dependencies...
"

scriptdir="$( cd "$( dirname "$0" )" && pwd )"


for line in `cat $scriptdir/akutils_resources/fastqjoin_workflow.dependencies.list`; do
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
echo "
		All dependencies satisfied.  Proceeding...
"

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
		Dual-indexed read joining workflow starting."

	echo "
Dual-indexed read joining workflow starting" >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	res1=$(date +%s.%N)

## Set start of read data for fastx_trimmer steps

	readno=$(($5+1))

## Concatenate index1 in front of index2

	echo "
		Concatenating indices and first read."
	echo "
First concatenation:" >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
#	echo "	paste -d '' <(echo; sed -n '1,${n;p;}' $1 | sed G) $2 | sed '/^$/d' > $outdir/i1i2.fq" >> $log

	`paste -d '' <(echo; sed -n '1,${n;p;}' $1 | sed G) $2 | sed '/^$/d' > $outdir/i1i2.fq`
	wait

## Concatenate indexes in front of read1

	echo "
Second concatenation:" >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
#	echo "	paste -d '' <(echo; sed -n '1,${n;p;}' $outdir/i1i2.fq | sed G) $3 | sed '/^$/d' > $outdir/i1i2r1.fq"

	`paste -d '' <(echo; sed -n '1,${n;p;}' $outdir/i1i2.fq | sed G) $3 | sed '/^$/d' > $outdir/i1i2r1.fq`
	wait

## Fastq-join command

	echo "
		Joining reads."

	echo "
Joining command:" >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "	fastq-join ${@:6} $outdir/i1i2r1.fq $4 -o $outdir/temp.%.fq" >> $log

	echo "
Fastq-join results:" >> $log
	fastq-join ${@:6} $outdir/i1i2r1.fq $4 -o $outdir/temp.%.fq >> $log

	wait

## Split index and read data from successfully joined reads

	echo "
		Splitting read and index data from
		successfully joined data."

	echo "
Split index and read commands:" >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "	fastx_trimmer -l $5 -i $outdir/temp.join.fq -o $outdir/idx.fq -Q 33" >> $log
	echo "	fastx_trimmer -f $readno -i $outdir/temp.join.fq -o $outdir/rd.fq -Q 33" >> $log

	( fastx_trimmer -l $5 -i $outdir/temp.join.fq -o $outdir/idx.fq -Q 33 ) &
	( fastx_trimmer -f $readno -i $outdir/temp.join.fq -o $outdir/rd.fq -Q 33 ) &
	wait

## Remove temp files

	echo "
		Removing temporary files..."

	echo "
Removing temporary files (raw join data, unjoined reads, concatenated indexes)." >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	rm $outdir/temp.*.fq
	rm $outdir/i1i2*.fq

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

