#!/bin/bash

## Check whether user had supplied -h or --help. If yes display help 

	if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
		echo "
		Usage:
		txttobiom.sh InputOTUTable.txt

		This script takes a tab-delimited OTU table (maybe you have manipulated
		it in a spreadsheet) and returns the same table in biom format (.biom)
		for further processing in QIIME.  It assumes you are using the version 
		of biom found in a typical QIIME install on a Linux system.  It will
		retain the metadata field \"taxonomy\".

		Input must have either .txt or .csv extension.  If your extensions have
		piled up (say you edited something with a .txt extension in Libre and it
		saved as .txt.csv), ALL of them will be replaced with .biom.  This means
		your filenames must NOT use \".\" as a delimiter!!
		"
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
		Input file must have .txt or .csv extension.  Are you sure you are 
		using a valid tab-delimited input table?  If yes, then change the
		file extension manually and resubmit the input for biom
		conversion.
		"
		exit 1
	fi

## Check if biom format table already exists with the same input name

	if [[ -f "$biomname.biom" ]]; then
		echo "
		A file exists with your input name and .biom extension.  Aborting
		conversion.  Delete the conflicting .biom file or change the name
		of your input file to proceed with txt to biom conversion.
		"
		exit 1
	fi

## Biom convert command

	`biom convert -i $1 -o $biomdir/$biombase.biom --table-type="OTU table" --process-obs-metadata taxonomy --to-hdf5`

	if [[ -f $biomdir/$biombase.biom ]]; then
	echo "
	Succussfully converted $biombase.$biomextension to $biombase.biom
	"
	else
	echo "
	There seems to have been a problem.  Conversion unsuccessful.
	"
	fi


