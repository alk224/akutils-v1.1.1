#!/usr/bin/env bash
#
#  unwrap_fasta.sh - Remove text wrapping from a fasta file
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

## Check whether user had supplied -h or --help. If yes display help 

	if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
	scriptdir="$( cd "$( dirname "$0" )" && pwd )"
	less $scriptdir/docs/unwrap_fasta.help
	exit 0
	fi 

# if more or less than one arguments supplied, display usage 

	if [  "$#" -ne 2 ] ;
	then 
		echo "
Usage (order is important!!):
unwrap_fasta.sh sequences.fasta sequences_unwrapped.fasta
		"
		exit 1
	fi 

## Define variables

inseqs=$1
outseqs=$2

## Awk script

	awk '!/^>/ { printf "%s", $0; n = "\n" } 
	/^>/ { print n $0; n = "" }
	END { printf "%s", n }
	' $inseqs > $outseqs
	wait

exit 0
