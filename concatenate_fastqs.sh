#!/usr/bin/env bash

## Simple command to concatenate two fastqs
## This is useful for keeping reads in phase while performing some other function
##
##Example command:
## paste -d '' <(echo; sed -n '1,${n;p;}' $1 | sed G) $2 | sed '/^$/d' > $1$2.fq


# check whether user had supplied -h or --help. If yes display help 

	if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
		echo "
		Usage (order is important):
		dev-concatenate_fastqs.sh fastq1 fastq2

		This script takes a pair of fastq files and concatenates them inline.
		Files must be fastq format.  Extension is unimportant.
		"
		exit 0
	fi 

# if other than two arguments supplied, display usage 

	if [  "$#" -ne 2 ] ;
	then 
		echo "
		Usage (order is important):
		dev-concatenate_fastqs.sh fastq1 fastq2
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

		New file will be called ${base1}_$base2.$fqextension
	"

	paste -d '' <(echo; sed -n '1,${n;p;}' $1 | sed G) $2 | sed '/^$/d' > $base1\_$base2.fq
	wait

	echo "		Concatenation completed.
	"

