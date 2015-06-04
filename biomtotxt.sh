#!/usr/bin/env bash
#
#  biomtotxt.sh - Convert a biom-formatted OTU table to tab-delimited
#
#  Version 1.0.0 (June 5, 2015)
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

## Get biom version

	biomver=`biom convert --version`
	biomve=`echo $biomver | cut -d " " -f 4`
	echo "Using biom version $biomve"
	biomv=`echo $biomve | cut -d "." -f 1`

# check whether user had supplied -h or --help. If yes display help 

	if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
	scriptdir="$( cd "$( dirname "$0" )" && pwd )"
	less $scriptdir/docs/biomtotxt.help
	exit 0
	fi 

# if more or less than one arguments supplied, display usage 

	if [  "$#" -ne 1 ] ;
	then 
		echo "
Usage:
biomtotxt.sh <InputBiomTable.biom>
		"
		exit 1
	fi 

#Check if supplied input has .biom extension before proceeding

	if [[ "$1" != *.biom ]]; then
		echo "
Input file must have .biom extension.  Are you sure you are using a
valid biom table from QIIME?
		"
		exit 1
	fi
## Extract OTU table basename for naming txt file output

	biombase=`basename "$1" | cut -d. -f1`
	biomextension="${1##*.}"
	biomname="${1%.*}"
	biomdir=$(dirname $1)

#Check if txt format table already exists with the same input name

	if [[ -f "$biomname.txt" ]]; then
		echo "
A file exists with your input name and .txt extension.  Aborting
conversion.  Delete the conflicting .txt file or change the name of your
input file to proceed with biom to txt conversion.
		"
		exit 1
	fi

#Biom convert command

	if [[ $biomv == 1 ]]; then

		`biom convert -i $1 -o $biomdir/$biombase.txt --header-key taxonomy -b`
		wait
		
		if [[ -s $biomdir/$biombase.txt ]]; then
		echo "
Conversion successful.
Input:  $biombase.$biomextension
Output: $biombase.txt
		"
		else
		echo "
There may have been a problem in your conversion.  Check your input and
try again.
		"
		fi

	fi
	if [[ $biomv == 2 ]]; then

		`biom convert -i $1 -o $biomdir/$biombase.txt --header-key taxonomy --to-tsv --table-type="OTU table"`
		wait
		
		if [[ -s $biomdir/$biombase.txt ]]; then
		echo "
Conversion successful.
Input:  $biombase.$biomextension
Output: $biombase.txt
		"
		else
		echo "
There may have been a problem in your conversion.  Check your input and
try again.
		"
		fi

	fi
exit 0
