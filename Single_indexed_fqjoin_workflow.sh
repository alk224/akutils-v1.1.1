#!/usr/bin/env bash
#
#  Single_indexed_fqjoin_workflow.sh - Fastq-join workflow for single-indexed MiSeq data
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
	scriptdir="$( cd "$( dirname "$0" )" && pwd )"
	less $scriptdir/docs/Single_indexed_fqjoin_workflow.help
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

## Check for required dependencies:

	scriptdir="$( cd "$( dirname "$0" )" && pwd )"

#echo "
#Checking for required dependencies...
#"
#
#for line in `cat $scriptdir/akutils_resources/fastqjoin_workflow.dependencies.list`; do
#	dependcount=`command -v $line 2>/dev/null | wc -w`
#	if [[ $dependcount == 0 ]]; then
#	echo "
#		$line is not in your path.  Dependencies not satisfied.
#		Exiting.
#	"
#	exit 1
#	else
#	if [[ $dependcount -ge 1 ]]; then
#	echo "		$line is in your path..."
#	fi
#	fi
#done
#echo "
#All dependencies satisfied.  Proceeding...
#"

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
Splitting read and index data from successfully joined data."

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
Removing temporary files."

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
Joining workflow steps completed.  Hooray!
$runtime
"
echo "
---

All workflow steps completed.  Hooray!" >> $log
date "+%a %b %I:%M %p %Z %Y" >> $log
echo "
$runtime 
" >> $log

exit 0
