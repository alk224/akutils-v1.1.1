#!/usr/bin/env bash
#
#  txttobiom.sh - Convert a tab-delimited OTU table to biom format
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


## Check whether user had supplied -h or --help. If yes display help 

	if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
	scriptdir="$( cd "$( dirname "$0" )" && pwd )"
	less $scriptdir/docs/txttobiom.help
	exit 0
	fi

## If more or less than one arguments supplied, display usage 

	if [  "$#" -ne 1 ]; then 
		echo "
Usage:
txttobiom.sh InputOTUTable.txt
		"
		exit 1
	fi 
 
## Extract OTU table basename for naming txt file output

	biombase=`basename "$1" | cut -d. -f1`
	biomextension="${1##*.}"
	biomname="${1%.*}"
	biomdir=$(dirname $1)

## Check if supplied input has .txt or .csv extension

	if [[ $biomextension != txt && $biomextension != csv ]]; then
		echo "
Input file must have .txt or .csv extension.  Are you sure you are using
a valid tab-delimited input table?  If yes, then change the file
extension manually and resubmit the input for biom conversion.
		"
		exit 1
	fi

## Check if biom format table already exists with the same input name

	if [[ -f "$biomname.biom" ]]; then
		echo "
A file exists with your input name and .biom extension.  Aborting
conversion.  Delete the conflicting .biom file or change the name of
your input file to proceed with txt to biom conversion.
		"
		exit 1
	fi

## Biom convert command

	`biom convert -i $1 -o $biomdir/$biombase.biom --table-type="OTU table" --process-obs-metadata taxonomy --to-hdf5`

	if [[ -f $biomdir/$biombase.biom ]]; then
	echo "
Conversion succussful. 
Input:  $biombase.$biomextension
Output: $biombase.biom
	"
	else
	echo "
There seems to have been a problem.  Conversion unsuccessful.
	"
	fi

exit 0
