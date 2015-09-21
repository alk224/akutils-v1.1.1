#!/usr/bin/env bash
#
#  filter_fastq_by_length.sh - Select reads to keep based on size range
#
#  Version 1.0.0 (September 20, 2015)
#
#  Copyright (c) 2015 Andrew Krohn
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
#  This script was inspired by discussion at the following link:
#  https://www.biostars.org/p/62678/

set -e
scriptdir="$( cd "$( dirname "$0" )" && pwd )"

## Check whether user had supplied -h or --help. If yes display help 

	if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
	less $scriptdir/docs/filter_fastq_by_length.help
	exit 0
	fi 

## Read script mode and display usage if incorrect number of arguments supplied

	mode=($1)
	usage=`printf "
Usage (order is important!):
filter_fastq_by_length.sh <mode> <min_length> <max_length> <read1> <read2> <index1> <index2>

	if mode = 1, <read1> only
	if mode = 2, <read1> <read2>
	if mode = 3, <read1> <index1>
	if mode = 4, <read1> <read2> <index1>
	if mode = 5, <read1> <read2> <index1> <index2>
   
		"`
	if [[ -z $mode ]]; then
		echo "$usage"
		exit 1
	fi
	if [[ "$mode" -ge "6" ]]; then
		echo "$usage"
		exit 1
	fi
	if [[ "$mode" == "1" ]] && [[ "$#" -ne "4" ]]; then
		echo "$usage"
		exit 1
	fi
	if [[ "$mode" -eq "2" ]] && [[ "$#" -ne "5" ]]; then
		echo "$usage"
		exit 1
	fi
	if [[ "$mode" -eq "3" ]] && [[ "$#" -ne "5" ]]; then
		echo "$usage"
		exit 1
	fi
	if [[ "$mode" == "4" ]] && [[ "$#" -ne "6" ]]; then
		echo "$usage"
		exit 1
	fi
	if [[ "$mode" == "5" ]] && [[ "$#" -ne "7" ]]; then
		echo "$usage"
		exit 1
	fi

## Define universal variables

	minlength=($2)
	maxlength=($3)
	read1=($4)
	fastqext="${read1##*.}"
	read1lines=$(cat $read1 | wc -l)
	read1seqs=$(echo "$read1lines/4" | bc)
	read1base=$(basename $read1 .$fastqext)

## Define directories
  
	filedir=$(dirname $read1)
#	workdir=$(pwd)
#	res1=$(date +%s.%N)

## Echo selected mode for user
	if [[ "$mode" == "1" ]]; then
	echo "
User selected mode: $mode (one fastq only)"
	fi
	if [[ "$mode" == "2" ]]; then
	echo "
User selected mode: $mode (paired reads only)"
	fi
	if [[ "$mode" == "3" ]]; then
	echo "
User selected mode: $mode (single read with one separate index file)"
	fi
	if [[ "$mode" == "4" ]]; then
	echo "
User selected mode: $mode (paired reads with one separate index file)"
	fi
	if [[ "$mode" == "5" ]]; then
	echo "
User selected mode: $mode (paired reads with two separate index files)"
	fi

## Filter for mode 1

	if [[ "$mode" == "1" ]]; then

	## Define additional variables

	## Filter input
	echo "
Filtering file to retain reads ${minlength}bp-${maxlength}bp.
Input: $filedir/$read1 ($read1seqs reads).
Output: $filedir/$read1base.$minlength-$maxlength.$fastqext"
	cat $read1 | awk -v high=$maxlength -v low=$minlength '{y= i++ % 4 ; L[y]=$0; if(y==3 && length(L[1])<=high) if(y==3 && length(L[1])>=low) {printf("%s\n%s\n%s\n%s\n",L[0],L[1],L[2],L[3]);}}' > $filedir/$read1base.$minlength-$maxlength.$fastqext
	read1outlines=$(cat $filedir/$read1base.$minlength-$maxlength.$fastqext | wc -l)
	read1outseqs=$(echo "$read1outlines/4" | bc)
	echo "Retained $read1outseqs reads.
	"
	fi

## Filter for mode 2

	if [[ "$mode" == "2" ]]; then

	## Define variables
	read2=($5)
	read2ext="${read2##*.}"
	read2lines=$(cat $read2 | wc -l)
	read2seqs=$(echo "$read2lines/4" | bc)
	read2base=$(basename $read2 .$read2ext)

	## Filter input
		echo "
Filtering files to retain reads ${minlength}bp-${maxlength}bp.
Input 1: $filedir/$read1 ($read1seqs reads).
Input 2: $filedir/$read2 ($read2seqs reads).
Output 1: $filedir/$read1base.$minlength-$maxlength.$fastqext
Output 2: $filedir/$read2base.$minlength-$maxlength.$fastqext"
	cat $read1 | awk -v high=$maxlength -v low=$minlength '{y= i++ % 2 ; L[y]=$0; if(y==1 && length(L[1])<=high) if(y==1 && length(L[1])>=low) {printf("%s\n%s\n%s\n%s\n",L[0],L[1],L[2],L[3]);}}' > $filedir/$read1base.$minlength-$maxlength.$fastqext
	wait
	read1outlines=$(cat $filedir/$read1base.$minlength-$maxlength.$fastqext | wc -l)
	read1outseqs=$(echo "$read1outlines/4" | bc)
	cat $read2 | awk -v high=$maxlength -v low=$minlength '{y= i++ % 4 ; L[y]=$0; if(y==3 && length(L[1])<=high) if(y==3 && length(L[1])>=low) {printf("%s\n%s\n%s\n%s\n",L[0],L[1],L[2],L[3]);}}' > $filedir/$read2base.$minlength-$maxlength.$fastqext
	wait
	read2outlines=$(cat $filedir/$read2base.$minlength-$maxlength.$fastqext | wc -l)
	read2outseqs=$(echo "$read2outlines/4" | bc)
	echo "Retained $read1outseqs reads from read 1.
Retained $read2outseqs reads from read 2.
	"
		if [[ "$read1outseqs" != "$read2outseqs" ]]; then
		echo "Reconciling read count differences to keep outputs in phase.
		"
		grep -e "^@\w\+:\w\+:\w\+-\w\+:\w\+:\w\+:\w\+:\w\+\s" $filedir/$read1base.$minlength-$maxlength.$fastqext > read1.seq.headers.temp
		grep -e "^@\w\+:\w\+:\w\+-\w\+:\w\+:\w\+:\w\+:\w\+\s" $filedir/$read2base.$minlength-$maxlength.$fastqext > read2.seq.headers.temp
		sed -i 's/^\@//' read1.seq.headers.temp
		sed -i 's/^\@//' read2.seq.headers.temp
		r1string=$(head -1 read1.seq.headers.temp | cut -d" " -f2)
		r2string=$(head -1 read2.seq.headers.temp | cut -d" " -f2)
		sed -i 's/\s\w:\w:\w:\w$//' read1.seq.headers.temp
		sed -i 's/\s\w:\w:\w:\w$//' read2.seq.headers.temp
		grep -Fxf read1.seq.headers.temp read2.seq.headers.temp > seqs.to.keep.temp
		mv $filedir/$read1base.$minlength-$maxlength.$fastqext $filedir/$read1base.$minlength-$maxlength.$fastqext.temp
		mv $filedir/$read2base.$minlength-$maxlength.$fastqext $filedir/$read2base.$minlength-$maxlength.$fastqext.temp
		sed "s/$/ $r1string/" seqs.to.keep.temp > seqs.to.keep.temp.r1
		sed "s/$/ $r2string/" seqs.to.keep.temp > seqs.to.keep.temp.r2
		perl $scriptdir/fastq-filter_extract_reads.pl -r seqs.to.keep.temp.r1 -f $filedir/$read1base.$minlength-$maxlength.$fastqext.temp 1> $filedir/$read1base.$minlength-$maxlength.$fastqext 2>/dev/null
		perl $scriptdir/fastq-filter_extract_reads.pl -r seqs.to.keep.temp.r2 -f $filedir/$read2base.$minlength-$maxlength.$fastqext.temp 1> $filedir/$read2base.$minlength-$maxlength.$fastqext 2>/dev/null
		rm seqs.to.keep.temp
		rm seqs.to.keep.temp.r1
		rm seqs.to.keep.temp.r2
		rm read1.seq.headers.temp
		rm read2.seq.headers.temp
		rm $filedir/$read1base.$minlength-$maxlength.$fastqext.temp
		rm $filedir/$read2base.$minlength-$maxlength.$fastqext.temp
		read1outlines=$(cat $filedir/$read1base.$minlength-$maxlength.$fastqext | wc -l)
		read1outseqs=$(echo "$read1outlines/4" | bc)
		read2outlines=$(cat $filedir/$read2base.$minlength-$maxlength.$fastqext | wc -l)
		read2outseqs=$(echo "$read2outlines/4" | bc)
		echo "After reconciliation:
Retained $read1outseqs reads from read 1.
Retained $read2outseqs reads from read 2.
	"
		fi
	fi

## Filter for mode 3

	if [[ "$mode" == "3" ]]; then

	## Define variables
	index=($5)
	indexext="${index##*.}"
	indexlines=$(cat $index | wc -l)
	indexseqs=$(echo "$indexlines/4" | bc)
	indexbase=$(basename $index .$indexext)

	## Filter input
		echo "
Filtering files to retain reads ${minlength}bp-${maxlength}bp.
Input 1: $filedir/$read1 ($read1seqs reads).
Input 2: $filedir/$index ($indexseqs reads).
Output 1: $filedir/$read1base.$minlength-$maxlength.$fastqext
Output 2: $filedir/$indexbase.$minlength-$maxlength.$fastqext"
	cat $read1 | awk -v high=$maxlength -v low=$minlength '{y= i++ % 4 ; L[y]=$0; if(y==3 && length(L[1])<=high) if(y==3 && length(L[1])>=low) {printf("%s\n%s\n%s\n%s\n",L[0],L[1],L[2],L[3]);}}' > $filedir/$read1base.$minlength-$maxlength.$fastqext
	wait
	read1outlines=$(cat $filedir/$read1base.$minlength-$maxlength.$fastqext | wc -l)
	read1outseqs=$(echo "$read1outlines/4" | bc)
	grep -e "^@\w\+:\w\+:\w\+-\w\+:\w\+:\w\+:\w\+:\w\+\s" $filedir/$read1base.$minlength-$maxlength.$fastqext > seqs.to.keep.temp
	sed -i 's/^\@//' seqs.to.keep.temp
	perl $scriptdir/fastq-filter_extract_reads.pl -r seqs.to.keep.temp -f $index 1> $filedir/$indexbase.$minlength-$maxlength.$fastqext 2>/dev/null 
	indexoutlines=$(cat $filedir/$indexbase.$minlength-$maxlength.$fastqext | wc -l)
	indexoutseqs=$(echo "$indexoutlines/4" | bc)
	echo "Retained $read1outseqs reads from read 1.
Retained $indexoutseqs reads from index 1.
	"
	rm seqs.to.keep.temp
	fi

## Filter for mode 4

	if [[ "$mode" == "4" ]]; then

	## Define variables
	read2=($5)
	read2ext="${read2##*.}"
	read2lines=$(cat $read2 | wc -l)
	read2seqs=$(echo "$read2lines/4" | bc)
	read2base=$(basename $read2 .$read2ext)
	index=($6)
	indexext="${index##*.}"
	indexlines=$(cat $index | wc -l)
	indexseqs=$(echo "$indexlines/4" | bc)
	indexbase=$(basename $index .$indexext)

	## Filter input
		echo "
Filtering files to retain reads ${minlength}bp-${maxlength}bp.
Input 1: $filedir/$read1 ($read1seqs reads).
Input 2: $filedir/$read2 ($read2seqs reads).
Input 3: $filedir/$index ($indexseqs reads).
Output 1: $filedir/$read1base.$minlength-$maxlength.$fastqext
Output 2: $filedir/$read2base.$minlength-$maxlength.$fastqext
Output 3: $filedir/$indexbase.$minlength-$maxlength.$fastqext"
	cat $read1 | awk -v high=$maxlength -v low=$minlength '{y= i++ % 4 ; L[y]=$0; if(y==3 && length(L[1])<=high) if(y==3 && length(L[1])>=low) {printf("%s\n%s\n%s\n%s\n",L[0],L[1],L[2],L[3]);}}' > $filedir/$read1base.$minlength-$maxlength.$fastqext
	wait
	read1outlines=$(cat $filedir/$read1base.$minlength-$maxlength.$fastqext | wc -l)
	read1outseqs=$(echo "$read1outlines/4" | bc)
	cat $read2 | awk -v high=$maxlength -v low=$minlength '{y= i++ % 4 ; L[y]=$0; if(y==3 && length(L[1])<=high) if(y==3 && length(L[1])>=low) {printf("%s\n%s\n%s\n%s\n",L[0],L[1],L[2],L[3]);}}' > $filedir/$read2base.$minlength-$maxlength.$fastqext
	wait
	read2outlines=$(cat $filedir/$read2base.$minlength-$maxlength.$fastqext | wc -l)
	read2outseqs=$(echo "$read2outlines/4" | bc)
	echo "Retained $read1outseqs reads from read 1.
Retained $read2outseqs reads from read 2.
	"
		if [[ "$read1outseqs" != "$read2outseqs" ]]; then
		echo "Reconciling read count differences to keep outputs in phase.
		"
		grep -e "^@\w\+:\w\+:\w\+-\w\+:\w\+:\w\+:\w\+:\w\+\s" $filedir/$read1base.$minlength-$maxlength.$fastqext > read1.seq.headers.temp
		grep -e "^@\w\+:\w\+:\w\+-\w\+:\w\+:\w\+:\w\+:\w\+\s" $filedir/$read2base.$minlength-$maxlength.$fastqext > read2.seq.headers.temp
		sed -i 's/^\@//' read1.seq.headers.temp
		sed -i 's/^\@//' read2.seq.headers.temp
		r1string=$(head -1 read1.seq.headers.temp | cut -d" " -f2)
		r2string=$(head -1 read2.seq.headers.temp | cut -d" " -f2)
		sed -i 's/\s\w:\w:\w:\w$//' read1.seq.headers.temp
		sed -i 's/\s\w:\w:\w:\w$//' read2.seq.headers.temp
		grep -Fxf read1.seq.headers.temp read2.seq.headers.temp > seqs.to.keep.temp
		mv $filedir/$read1base.$minlength-$maxlength.$fastqext $filedir/$read1base.$minlength-$maxlength.$fastqext.temp
		mv $filedir/$read2base.$minlength-$maxlength.$fastqext $filedir/$read2base.$minlength-$maxlength.$fastqext.temp
		sed "s/$/ $r1string/" seqs.to.keep.temp > seqs.to.keep.temp.r1
		sed "s/$/ $r2string/" seqs.to.keep.temp > seqs.to.keep.temp.r2
		perl $scriptdir/fastq-filter_extract_reads.pl -r seqs.to.keep.temp.r1 -f $filedir/$read1base.$minlength-$maxlength.$fastqext.temp 1> $filedir/$read1base.$minlength-$maxlength.$fastqext 2>/dev/null
		perl $scriptdir/fastq-filter_extract_reads.pl -r seqs.to.keep.temp.r2 -f $filedir/$read2base.$minlength-$maxlength.$fastqext.temp 1> $filedir/$read2base.$minlength-$maxlength.$fastqext 2>/dev/null
		perl $scriptdir/fastq-filter_extract_reads.pl -r seqs.to.keep.temp.r1 -f $index 1> $filedir/$indexbase.$minlength-$maxlength.$fastqext 2>/dev/null 
		rm seqs.to.keep.temp
		rm seqs.to.keep.temp.r1
		rm seqs.to.keep.temp.r2
		rm read1.seq.headers.temp
		rm read2.seq.headers.temp
		rm $filedir/$read1base.$minlength-$maxlength.$fastqext.temp
		rm $filedir/$read2base.$minlength-$maxlength.$fastqext.temp
		read1outlines=$(cat $filedir/$read1base.$minlength-$maxlength.$fastqext | wc -l)
		read1outseqs=$(echo "$read1outlines/4" | bc)
		read2outlines=$(cat $filedir/$read2base.$minlength-$maxlength.$fastqext | wc -l)
		read2outseqs=$(echo "$read2outlines/4" | bc)
		indexoutlines=$(cat $filedir/$indexbase.$minlength-$maxlength.$fastqext | wc -l)
		indexoutseqs=$(echo "$indexoutlines/4" | bc)
		echo "After reconciliation:
Retained $read1outseqs reads from read 1.
Retained $read2outseqs reads from read 2.
Retained $indexoutseqs reads from index.
	"
		else
		grep -e "^@\w\+:\w\+:\w\+-\w\+:\w\+:\w\+:\w\+:\w\+\s" $filedir/$read1base.$minlength-$maxlength.$fastqext > seqs.to.keep.temp
		perl $scriptdir/fastq-filter_extract_reads.pl -r seqs.to.keep.temp -f $index 1> $filedir/$indexbase.$minlength-$maxlength.$fastqext 2>/dev/null
		rm seqs.to.keep.temp
		indexoutlines=$(cat $filedir/$indexbase.$minlength-$maxlength.$fastqext | wc -l)
		indexoutseqs=$(echo "$indexoutlines/4" | bc)
		echo "Retained $indexoutseqs reads from index.
		"
		fi
	fi

## Filter for mode 5

	if [[ "$mode" == "5" ]]; then

	## Define variables
	read2=($5)
	read2ext="${read2##*.}"
	read2lines=$(cat $read2 | wc -l)
	read2seqs=$(echo "$read2lines/4" | bc)
	read2base=$(basename $read2 .$read2ext)
	index1=($6)
	index1ext="${index1##*.}"
	index1lines=$(cat $index1 | wc -l)
	index1seqs=$(echo "$index1lines/4" | bc)
	index1base=$(basename $index1 .$index1ext)
	index2=($7)
	index2ext="${index2##*.}"
	index2lines=$(cat $index2 | wc -l)
	index2seqs=$(echo "$index2lines/4" | bc)
	index2base=$(basename $index2 .$index2ext)

	## Filter input
		echo "
Filtering files to retain reads ${minlength}bp-${maxlength}bp.
Input 1: $filedir/$read1 ($read1seqs reads).
Input 2: $filedir/$read2 ($read2seqs reads).
Input 3: $filedir/$index1 ($index1seqs reads).
Input 4: $filedir/$index2 ($index2seqs reads).
Output 1: $filedir/$read1base.$minlength-$maxlength.$fastqext
Output 2: $filedir/$read2base.$minlength-$maxlength.$fastqext
Output 3: $filedir/$index1base.$minlength-$maxlength.$fastqext
Output 4: $filedir/$index2base.$minlength-$maxlength.$fastqext"
	cat $read1 | awk -v high=$maxlength -v low=$minlength '{y= i++ % 4 ; L[y]=$0; if(y==3 && length(L[1])<=high) if(y==3 && length(L[1])>=low) {printf("%s\n%s\n%s\n%s\n",L[0],L[1],L[2],L[3]);}}' > $filedir/$read1base.$minlength-$maxlength.$fastqext
	wait
	read1outlines=$(cat $filedir/$read1base.$minlength-$maxlength.$fastqext | wc -l)
	read1outseqs=$(echo "$read1outlines/4" | bc)
	cat $read2 | awk -v high=$maxlength -v low=$minlength '{y= i++ % 4 ; L[y]=$0; if(y==3 && length(L[1])<=high) if(y==3 && length(L[1])>=low) {printf("%s\n%s\n%s\n%s\n",L[0],L[1],L[2],L[3]);}}' > $filedir/$read2base.$minlength-$maxlength.$fastqext
	wait
	read2outlines=$(cat $filedir/$read2base.$minlength-$maxlength.$fastqext | wc -l)
	read2outseqs=$(echo "$read2outlines/4" | bc)
	echo "Retained $read1outseqs reads from read 1.
Retained $read2outseqs reads from read 2.
	"
		if [[ "$read1outseqs" != "$read2outseqs" ]]; then
		echo "Reconciling read count differences to keep outputs in phase.
		"
		grep -e "^@\w\+:\w\+:\w\+-\w\+:\w\+:\w\+:\w\+:\w\+\s" $filedir/$read1base.$minlength-$maxlength.$fastqext > read1.seq.headers.temp
		grep -e "^@\w\+:\w\+:\w\+-\w\+:\w\+:\w\+:\w\+:\w\+\s" $filedir/$read2base.$minlength-$maxlength.$fastqext > read2.seq.headers.temp
		sed -i 's/^\@//' read1.seq.headers.temp
		sed -i 's/^\@//' read2.seq.headers.temp
		r1string=$(head -1 read1.seq.headers.temp | cut -d" " -f2)
		r2string=$(head -1 read2.seq.headers.temp | cut -d" " -f2)
		sed -i 's/\s\w:\w:\w:\w$//' read1.seq.headers.temp
		sed -i 's/\s\w:\w:\w:\w$//' read2.seq.headers.temp
		grep -Fxf read1.seq.headers.temp read2.seq.headers.temp > seqs.to.keep.temp
		mv $filedir/$read1base.$minlength-$maxlength.$fastqext $filedir/$read1base.$minlength-$maxlength.$fastqext.temp
		mv $filedir/$read2base.$minlength-$maxlength.$fastqext $filedir/$read2base.$minlength-$maxlength.$fastqext.temp
		sed "s/$/ $r1string/" seqs.to.keep.temp > seqs.to.keep.temp.r1
		sed "s/$/ $r2string/" seqs.to.keep.temp > seqs.to.keep.temp.r2
		perl $scriptdir/fastq-filter_extract_reads.pl -r seqs.to.keep.temp.r1 -f $filedir/$read1base.$minlength-$maxlength.$fastqext.temp 1> $filedir/$read1base.$minlength-$maxlength.$fastqext 2>/dev/null
		perl $scriptdir/fastq-filter_extract_reads.pl -r seqs.to.keep.temp.r2 -f $filedir/$read2base.$minlength-$maxlength.$fastqext.temp 1> $filedir/$read2base.$minlength-$maxlength.$fastqext 2>/dev/null
		perl $scriptdir/fastq-filter_extract_reads.pl -r seqs.to.keep.temp.r1 -f $index1 1> $filedir/$index1base.$minlength-$maxlength.$fastqext 2>/dev/null
		perl $scriptdir/fastq-filter_extract_reads.pl -r seqs.to.keep.temp.r2 -f $index2 1> $filedir/$index2base.$minlength-$maxlength.$fastqext 2>/dev/null
		rm seqs.to.keep.temp
		rm seqs.to.keep.temp.r1
		rm seqs.to.keep.temp.r2
		rm read1.seq.headers.temp
		rm read2.seq.headers.temp
		rm $filedir/$read1base.$minlength-$maxlength.$fastqext.temp
		rm $filedir/$read2base.$minlength-$maxlength.$fastqext.temp
		read1outlines=$(cat $filedir/$read1base.$minlength-$maxlength.$fastqext | wc -l)
		read1outseqs=$(echo "$read1outlines/4" | bc)
		read2outlines=$(cat $filedir/$read2base.$minlength-$maxlength.$fastqext | wc -l)
		read2outseqs=$(echo "$read2outlines/4" | bc)
		index1outlines=$(cat $filedir/$index1base.$minlength-$maxlength.$fastqext | wc -l)
		index1outseqs=$(echo "$index1outlines/4" | bc)
		index2outlines=$(cat $filedir/$index2base.$minlength-$maxlength.$fastqext | wc -l)
		index2outseqs=$(echo "$index2outlines/4" | bc)
		echo "After reconciliation:
Retained $read1outseqs reads from read 1.
Retained $read2outseqs reads from read 2.
Retained $index1outseqs reads from index 1.
Retained $index2outseqs reads from index 2.
	"
		else
		grep -e "^@\w\+:\w\+:\w\+-\w\+:\w\+:\w\+:\w\+:\w\+\s" $filedir/$read1base.$minlength-$maxlength.$fastqext > seqs.to.keep.temp.r1
		grep -e "^@\w\+:\w\+:\w\+-\w\+:\w\+:\w\+:\w\+:\w\+\s" $filedir/$read2base.$minlength-$maxlength.$fastqext > seqs.to.keep.temp.r2
		perl $scriptdir/fastq-filter_extract_reads.pl -r seqs.to.keep.temp.r1 -f $index1 1> $filedir/$index1base.$minlength-$maxlength.$fastqext 2>/dev/null
		perl $scriptdir/fastq-filter_extract_reads.pl -r seqs.to.keep.temp.r2 -f $index2 1> $filedir/$index2base.$minlength-$maxlength.$fastqext 2>/dev/null
		rm seqs.to.keep.temp.r1
		rm seqs.to.keep.temp.r2
		index1outlines=$(cat $filedir/$index1base.$minlength-$maxlength.$fastqext | wc -l)
		index1outseqs=$(echo "$index1outlines/4" | bc)
		index2outlines=$(cat $filedir/$index2base.$minlength-$maxlength.$fastqext | wc -l)
		index2outseqs=$(echo "$index2outlines/4" | bc)
		echo "Retained $index1outseqs reads from index 1.
Retained $index2outseqs reads from index 2.
		"
		fi
	fi

exit 0

