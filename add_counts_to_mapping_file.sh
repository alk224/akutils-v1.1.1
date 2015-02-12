#!/bin/bash
set -e

## Check whether user had supplied -h or --help. If yes display help 

	if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
		echo "
		This script will take an input QIIME-formatted mapping
		file plus a biom table summary and add the read counts
		from the summary to the second to last column in the
		mapping file.  The samples in both files must correspond!

		Usage (order is important!!):
		add_counts_to_mapping_file.sh <mapping_file> <biom_summary_file>
		
		Example:
		add_counts_to_mapping_file.sh my.map.txt biom.summary.file

		Will take the input mapping file (my.map.txt) and summary
		from biom summarize-table (biom.summary.file), extract
		read counts for each sample from the biom summary, and add
		them to a new file called my.map.withcounts.txt.

		Note: Input mapping file MUST end with .txt
		"
		exit 0
	fi 

## If more or less than two arguments supplied, display usage 

	if [[ "$#" -ne 2 ]]; then 
		echo "
		Usage (order is important!!):
		add_counts_to_mapping_file.sh <mapping_file> <biom_summary_file>

		"
		exit 1
	fi

## Check if mapping file has .txt extension

	if [[ $1 != *.txt ]]; then
	echo "
		Mapping file extension is not .txt.  Please fix and try again.
		Exiting.
	"
	exit 1
	fi

## Define basename of mapping infile
	mapbase=$(basename $1 .txt)

## Check if output already exists

	if [[ -f $mapbase.withcounts.txt ]]; then
	echo "
		Expected output already exists ($mapbase.withcounts.txt).
		Exiting.
	"
	exit 1
	fi

## Count fields in mapping infile
	fieldcount=`awk -F"\t" '{print NF;exit}' $1`

## Get counts from OTU table summary based on sampleID list (preserves order)
	echo > counts.temp
	for sample in `grep -v "#" $1 | cut -f 1`; do
		grep $sample $2 | sed -e "s/$sample: //g" >> counts.temp
	done

## Delete any empty lines and add header
	sed -i '/^\s*$/d' counts.temp
	sed -i '1iReadCounts' counts.temp

## Check that counts and mapping files have same number of lines
	countlines=`cat counts.temp | wc -l`
	countmap=`cat $1 | wc -l`

	if [[ "$countlines" != "$countmap" ]]; then
	echo "
		Your mapping file has a different number of samples than your OTU summary.
		Ensure the samples found in each are consistent and try again.  
		Exiting.
		"
	rm counts.temp
	exit 1
	fi

## Get second to last field number
	penultimate=$(($fieldcount-1))

## Make temporary mapping file without Description field
	cut -f-$penultimate $1 > map.temp

## Add in read counts
	paste map.temp counts.temp > map.withcounts.temp

## Add Description back in
	cut -f $fieldcount $1 > map.description.temp
	paste map.withcounts.temp map.description.temp > $mapbase.withcounts.txt

## Remove temp files
	rm map.temp map.withcounts.temp counts.temp map.description.temp

## Report success
	echo "
		Sample counts added to new mapping file in second to last column.
		New file: $mapbase.withcounts.txt
		Column name: ReadCounts
	"

