#!/usr/bin/env bash
#
#  fastq_length_histogram.sh - Build text histogram of a fastq file
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

set -e
scriptdir="$( cd "$( dirname "$0" )" && pwd )"
input=($1)

## Check whether user had supplied -h or --help. If yes display help 

	if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
	less $scriptdir/docs/fastq_length_histogram.help
	exit 0
	fi

## If no input file supplied, display usage

	usage=`printf "
Usage:
fastq_length_histogram.sh <fastq_file>

Input fastq must have \".fastq\" or \".fq\" extension.
		"`
	if [[ "$#" -ne 1 ]]; then
		echo "$usage"
		exit 1
	fi
	if [[ ! -s "$input" ]]; then
		echo "$usage"
		exit 1
	fi

## Parse input filename and count reads

	fastqext="${input##*.}"
	inputlines=$(cat $input | wc -l)
	inputseqs=$(echo "$inputlines/4" | bc)
	inputbase=$(basename $input .$fastqext)

## If other than fastq supplied as input, display usage

	if [[ "$fastqext" != "fastq" ]] && [[ "$fastqext" != "fq" ]]; then
		echo "
Input file does not have correct fastq extension (.fastq or .fq).  If
you supplied a valid fastq file, change the extension and try again.
$usage
File supplied as input: $input
"
		exit 1
	fi

## Build histogram with awk and bash

	indir=$(dirname $input)
	output=($indir/histogram.$inputbase.$fastqext.txt)
	echo "
Generating read-length histogram.
Input: $input ($inputseqs reads)
Output: $output
"
	cat $input | awk '{if(NR%4==2) print length($1)}' | sort -V | uniq -c > $output
	if [[ -s $output ]]; then
	echo "Histogram successfully produced.
	"
	else
	echo "No histogram produced.  Check your input and try again.
	"
	fi

exit 0
