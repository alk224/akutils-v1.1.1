#!/usr/bin/env bash
#
#  unwrap_fasta.sh - Remove text wrapping from a fasta file
#
#  Version 1.1.1 (July 1, 2015)
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
#set -x

## Defaults used by infer_from() function, below
EXT=fasta
TAG=_unwrapped

## Check whether user had supplied -h or --help. If yes display help

	if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
	scriptdir=$( cd $( dirname "$0" ) && pwd )
	less $scriptdir/docs/unwrap_fasta.help
	exit 0
	fi

# if less than one argument supplied or $1 doesn't exist, display usage

	if [  "$#" -lt 1 -o ! -f "$1" ]; then
		scriptname=$( basename "$0" )
		echo "
Usage (order is important!!):

  $scriptname <inseq> [<outseq>]


  If <outseq> is omitted, output filename is inferred from input:

    $scriptname sequences.$EXT  # -> sequences${TAG}.$EXT
		" >&2
		exit 1
	fi

## Functions

infer_from() {
	# See https://stackoverflow.com/a/965072 and
	# http://man.cx/bash#heading14 ("Parameter Expansion")
	path=$( dirname "$1" )
	filename=${1##*/}
	ext=${filename##*.}
	if [ "$ext" == "$filename" ]; then
		ext=$EXT                  # default to global $EXT
	else
		filename=${filename%.*}   # strip (final) extension
	fi
	echo "$path/${filename}${TAG}.${ext}"
}

## Define variables

inseqs=$1
outseqs=${2:-$(infer_from "$1")}

## Awk script

	awk '
		{if ($1 ~ /^>/ || $0 ~ /^[A-Z]?$/) {
			# Leave FASTA deflines, IUPAC ambiguity characters, and empty
			# lines intact (part of the NIH dbSNP "ss" record format; see
			# ftp://ftp.ncbi.nih.gov/snp/00readme.txt)
			print n $0;
			n = "";
		} else {
			# Remove spaces and newlines from non-headers
			gsub(" ", "", $0);
			printf "%s", $0;
			n = "\n";
		}}
		END { printf "%s", n; }
	' $inseqs > $outseqs
	wait

exit 0
