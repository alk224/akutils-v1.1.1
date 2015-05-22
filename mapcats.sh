#!/usr/bin/env bash
set -e

## Check whether user had supplied -h or --help. If yes display help 

	if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
		echo "
		This script reads a QIIME-formatted mapping file and returns
		the names of metadata categories.  This can be useful if
		preparing to run diversity analyses.

		Usage:
		mapcats.sh <mappingfile>
		
		"
		exit 0
	fi 

## If other than one argument supplied, display usage 

	if [  "$#" -ne 1 ] ;
	then 
		echo "
		Usage:
		mapcats.sh <mappingfile>

		"
		exit 1
	fi

## Read and display mapping categories

echo "
Mapping file: $1
Categories:" `grep "#" $1 | cut -f 2-100 | sed 's/\t/,/g'`
echo ""

