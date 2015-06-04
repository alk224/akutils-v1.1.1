#!/usr/bin/env bash
#
#  concatenate_fastqs.sh - combine two congruent fastq files
#
#  Version 1.0 (June 5, 2015)
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

## Simple command to concatenate two fastqs
## This is useful for keeping reads in phase while performing some other function
##
## Example command:
## paste -d '' <(echo; sed -n '1,${n;p;}' $1 | sed G) $2 | sed '/^$/d' > $1$2.fq


# check whether user had supplied -h or --help. If yes display help 

	if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
	scriptdir="$( cd "$( dirname "$0" )" && pwd )"
	less $scriptdir/docs/concatenate_fastqs.help
		exit 0
	fi 

# if other than two arguments supplied, display usage 

	if [  "$#" -ne 2 ] ;
	then 
		echo "
Usage (order is important):
concatenate_fastqs.sh fastq1 fastq2
		"
		exit 1
	fi 


## Extract fastq basename, extension, and directory for output naming and file direction

	base1=`basename "$1" | cut -d. -f1`
	base2=`basename "$2" | cut -d. -f1`
	fqextension="${1##*.}"
	fqname1="${1%.*}"
	fqname1="${2%.*}"
	fqdir=$(dirname $1)

## concatenation command

	echo "
Concatenating $1 in front of $2
	"

	paste -d '' <(echo; sed -n '1,${n;p;}' $1 | sed G) $2 | sed '/^$/d' > $base1\_$base2.fq
	wait

	echo "Concatenation completed.
fastq1: $1
fastq2: $1
output: ${base1}_$base2.$fqextension
	"
exit 0
