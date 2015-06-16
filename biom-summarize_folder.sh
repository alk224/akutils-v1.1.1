#!/usr/bin/env bash
#
#  biom-summarize_folder.sh - Summarize an entire folder of biom tables at once
#
#  Version 1.1.0 (June 16, 2015)
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

# check whether user had supplied -h or --help. If yes display help 

	if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
	scriptdir="$( cd "$( dirname "$0" )" && pwd )"
	less $scriptdir/docs/biom-summarize_folder.help
	exit 0
	fi


# if more or less than one arguments supplied, display usage 

	if [  "$#" -ne 1 ] ;
	then 
		echo "
Usage:
biom-summarize_folder.sh <folder path>

biom-summarize_folder.sh --help for more details.
		"
		exit 1
	fi 

#Check if input folder actually contains files with .biom extension before proceeding

	workdir=$(pwd)
	cd $1
	sumdir=$(pwd)
	cd $workdir
	countbiom=`ls $sumdir/*.biom 2> /dev/null | wc -l`
	if [[ $countbiom == 0 ]]; then

		## Error message if no biom tables present
		echo "
No files exist with .biom extension within the supplied directory.
Aborting biom summarization commands.  Check that you supplied the
correct directory to the command.
		"
		exit 1

	else

		echo "
		$countbiom biom files found in directory:

		$sumdir
		"

#Summarize biom files loop

		for biomfile in $sumdir/*.biom; do
   		biombase=$(basename $biomfile .biom)

#check if summary already exists
			if [[ -f $1/$biombase.summary ]]; then
				echo "Skipping $biombase.biom as this table has already been summarized."
			else
   				echo "Summarizing $biombase.biom"
				`biom summarize-table -i $sumdir/$biombase.biom -o $sumdir/$biombase.summary`
			fi		
		done
		echo "
		Done
		"
	fi
exit 0
