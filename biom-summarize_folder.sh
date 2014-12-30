#!/bin/bash
set -e

# check whether user had supplied -h or --help. If yes display help 

	if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
		echo "
		Usage:
		biom-summarize_folder.sh <folder path>

		For a given input folder, this script will attempt to summarize all biom-
		formatted OTU tables (extension .biom) contained therein.
		"
		exit 0
	fi


# if more or less than one arguments supplied, display usage 

	if [  "$#" -ne 1 ] ;
	then 
		echo "
		Usage:
		biom-summarize_folder.sh <folder path>
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
   				`biom summarize-table -i $sumdir/$biombase.biom -o $sumdir/$biombase.summary`
				echo "Summarizing $biombase.biom"
			fi		
		done
		echo "
		Done
		"
	fi

