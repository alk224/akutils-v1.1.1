#!/usr/bin/env bash
#set -e

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

## Get second to last field number
	penultimate=$(($fieldcount-1))

## Make temporary files without Description field and with just sampleids plus description
	cut -f-$penultimate $1 > map.temp
	cut -f 1,$fieldcount $1 > map1.temp

## Make temp files (sampleids from mapfile, summaryids from summaryfile, counts from summaryfile)

	grep -v "#" $1 | cut -f 1 > sampleids.temp
	sed -i '/^\s*$/d' sampleids.temp

	echo > summaryids.temp
	for sample in `cat sampleids.temp`; do 
	grep -w $sample $2 | cut -d ":" -f 1 >> summaryids.temp
	done
	sed -i '/^\s*$/d' summaryids.temp

	echo > counts.temp
	for sample in `cat sampleids.temp`; do
		grep -w $sample $2 | sed -e "s/$sample: //g" >> counts.temp
	done

## Delete any empty lines and add header
	sed -i '/^\s*$/d' counts.temp
	sed -i '1iReadCounts' counts.temp

## Check that counts and mapping files have same number of lines
	summaryno=`cat summaryids.temp | wc -l`
	sampleno=`cat sampleids.temp | wc -l`


	if [[ $summaryno != $sampleno ]]; then

		echo > samplediffs.temp
		for sample in `cat sampleids.temp`; do
		tempvar=`grep $sample summaryids.temp`
			if [[ -z $tempvar ]]; then
			echo $sample >> samplediffs.temp
			fi
			sed -i '/^\s*$/d' samplediffs.temp
		done

		for diff in `cat samplediffs.temp`; do
		sed -i "/$diff/d" map.temp
		sed -i "/$diff/d" map1.temp
		done

	fi

## Add in read counts
	paste map.temp counts.temp > map.withcounts.temp

## Add Description back in
	cut -f 2 map1.temp > map.description.temp
	paste map.withcounts.temp map.description.temp > $mapbase.withcounts.txt

## Remove temp files
	rm counts.temp map.description.temp map.temp map.withcounts.temp map1.temp samplediffs.temp sampleids.temp summaryids.temp

## Report success
	echo "
		Sample counts added to new mapping file in second to last column.
		New file: $mapbase.withcounts.txt
		Column name: ReadCounts
	"

