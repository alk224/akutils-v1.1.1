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
	input=($1)
	minlength=($2)
	maxlength=($3)
	usage=`printf "
Usage (order is important!):
filter_fasta_by_length.sh <input_fasta> <min_length> <max_length>

Input fasta must have valid extension (.fasta, .fa, .fas, .fna).
		"`
	if [[ -z $input ]]; then
		echo "$usage"
		exit 1
	fi
	if [[ ! -s $input ]]; then
		echo "
Check if supplied input is a valid file.
$usage"
		exit 1
	fi
	if [[ "$#" -ne "3" ]]; then
		echo "
Incorrect number of arguments supplied.
$usage"
		exit 1
	fi

## Parse input filename and count reads

	fastaext="${input##*.}"
	inputlines=$(cat $input | wc -l)
	inputseqs=$(echo "$inputlines/2" | bc)
	inputbase=$(basename $input .$fastaext)

## If other than fastq supplied as input, display usage

	if [[ "$fastaext" != "fasta" ]] && [[ "$fastaext" != "fa" ]] && [[ "$fastaext" != "fas" ]] && [[ "$fastaext" != "fna" ]]; then
		echo "
Input file does not have correct fasta extension (.fasta, .fa, .fas, or
.fna).  If you supplied a valid fasta file, change the extension and try
again.
$usage
File supplied as input: $input
"
		exit 1
	fi

## Define directories
  
	filedir=$(dirname $input)

## Filter input

	echo "
Filtering file to retain reads ${minlength}bp-${maxlength}bp.
Input: $filedir/$input ($inputseqs reads).
Output: $filedir/$inputbase.$minlength-$maxlength.$fastaext"
	cat $input | awk -v high=$maxlength -v low=$minlength '{y= i++ % 2 ; L[y]=$0; if(y==1 && length(L[1])<=high) if(y==1 && length(L[1])>=low) {printf("%s\n%s\n",L[0],L[1]);}}' > $filedir/$inputbase.$minlength-$maxlength.$fastaext
	outlines=$(cat $filedir/$inputbase.$minlength-$maxlength.$fastaext | wc -l)
	outseqs=$(echo "$outlines/2" | bc)
	echo "Retained $outseqs reads.
	"

exit 0

