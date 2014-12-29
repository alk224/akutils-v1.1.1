#!/bin/bash

# if more or less than one arguments supplied, display usage 

	if [  "$#" -ne 1 ] ;
	then 
		echo "
		Usage:
		biomtotxt.sh InputBiomTable.biom
		"
		exit 1
	fi 
 
# check whether user had supplied -h or --help. If yes display help 

	if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
		echo "
		Usage:
		biomtotxt.sh InputBiomTable

		This script takes an OTU table produced in QIIME (biom format) and returns
		the same table in tab-delimited format (.txt).  It assumes you are using
		the version of biom found in a typical QIIME install on a Linux system.
		"
		exit 0
	fi 

#Check if supplied input has .biom extension before proceeding

	if [[ "$1" != *.biom ]]; then
		echo "
		Input file must have .biom extension.  Are you sure you are using a valid
		biom table from QIIME?
		"
		exit 1
	fi

#Extract biom table basename for naming txt file output

	biombase=$(basename $1 .biom)

#Biom convert command

	`biom convert -i $1 -o $biombase.txt --header-key taxonomy -b`

