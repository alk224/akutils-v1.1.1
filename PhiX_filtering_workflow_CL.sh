#!/bin/bash
set -e

## Check whether user had supplied -h or --help. If yes display help 

	if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
		echo "
*********************************************************************
 
This script will take raw fastq data from a MiSeq run with single
indexing, strip PhiX reads, and join your data together.  You will
be provided with joined fastqs for both the filtered and unfiltered
data.  You will also be provided with accurate quantities of reads
that are either PhiX or your data.  This may be useful for
estimation of mixed cluster rates and therefore to provide a
meaningful level of filtering on a per-experiment basis.  Keep in
mind that excessive filtering will increase your type II error rate
(false negatives) while underfiltering increases type I rates
(false positives).

Running this script assumes you have already done the following:

1) Installed and have a functioning ea-utils in your path as this
workflow calls both fastq-multx and fastq-join.

https://code.google.com/p/ea-utils/

You should cite ea-utils for being such a kick-ass utility:

Erik Aronesty (2011). ea-utils: Command-line tools for processing biological sequencing data; http://code.google.com/p/ea-utils

2) Installed and have a functioning fastx-toolkit in your path as
this workflow calls fastx_trimmer.

http://hannonlab.cshl.edu/fastx_toolkit/

I'm not certain if/how to cite this excellent package except as a
website (as of 12/26/14).

3) Installed and have a functioning smalt in your path as this is
the utility used for searching your data for PhiX174 contamination.

https://www.sanger.ac.uk/resources/software/smalt/

4) Run smalt to generate an index of the PhiX genome for searching
during this workflow.  Use this command:

smalt index -k 11 -s 1 phix-k11-s1 <sourcefasta>

Download the reference sequence for PhiX used during Illumina
sequencing here (dowload as fasta):

http://www.ncbi.nlm.nih.gov/nucleotide/NC_001422

5) Have a barcodes file that fastq-multx will accept.  See the
ea-utils website for more and better documentation, but below is a
small sample.  File contains no headers, but headers are provided
here for illustrative purposes.

Index sequences must be in the CORRECT ORIENTATION!!  If you have
a QIIME mapping file with reverse complemented indexes (you have
to pass --rev_comp_mapping_barcodes during demultiplexing), you can
copy all the sequences from a column if you open your map in Excel
or Libre, and paste it into the below website and it will return
all sequences in columnar format which you can paste into another
sheet containing your sample names and category columns.

http://arep.med.harvard.edu/labgc/adnan/projects/Utilities/revcomp.html

UniqueSampleName	IndexSequence	Category
sample1	ACGTTCTAGGCT	experiment
sample2	CGGGATTCTATT	experiment
sample3	TTCGGATTCTAC	experiment
sample4	GACTTAGCCTAT	experiment

6) Have a functioning version of QIIME installed and working for you.
Not a small task, but if you are reading this far into this
particular document, you probably already know what you are doing.
This workflow calls the filter_fasta.py command for stripping
PhiX reads from your data.

Happy PhiX filtering!!		

		Usage (order is important):
		PhiX_filtering_single_index_CL.sh <read1> <read2> <index1> <indexlength> <barcodes> <indexerrors> <smaltindex> <smaltcores> <overlap> <mismatch>

		Requires the following dependencies to run (cite as necessary):
		1) QIIME 1.8.0 or later (qiime.org)
		2) ea-utils (https://code.google.com/p/ea-utils/)
		3) Fastx toolkit (http://hannonlab.cshl.edu/fastx_toolkit/)
		4) Smalt (https://www.sanger.ac.uk/resources/software/smalt/)
		
		"
		exit 0
	fi 

## If more or less than ten arguments supplied, display usage 

	if [  "$#" != 10 ] ;
	then 
		echo "
		Usage (order is important):
		PhiX_filtering_single_index_CL.sh <read1> <read2> <index1> <indexlength> <barcodes> <indexerrors> <smaltindex> <smaltcores> <overlap> <mismatch>

		"
		exit 1
	fi

## Define inputs based on order
	read1=($1)
	read2=($2)
	index1=($3)
	indexlength=($4)
	barcodes=($5)
	indexerrors=($6)
	smaltindex=($7)
	cores=($8)
	overlap=($9)
	mismatch=($10)
	outdir=PhiX_screen

## Check to see if requested output directory exists

	if [[ -d $outdir ]]; then
		dirtest=$([ "$(ls -A $outdir)" ] && echo "Not Empty" || echo "Empty")
		echo "
		Output directory already exists ($outdir).  Deleting any contents
		prior to beginning workflow.
		"
		if [[ "$dirtest" == "Not Empty" ]]; then
		`rm -r $outdir/*`
		fi
	else
		mkdir $outdir
	fi


## Set working directory
	home=$(pwd)

## Remove file extension if necessary from supplied smalt index for smalt command and get directory
	smaltbase=`basename "$smaltindex" | cut -d. -f1`
	smaltdir=$(dirname $smaltindex)

## Set index position for fastx_trimmer command
	readno=$(expr $indexlength + 1)

## Make output directory for fastq-multx command
	mkdir $outdir/fastq-multx_output

## Log workflow start
echo "
---

Phix filtering plus read joining workflow beginning..." > $outdir/PhiX_filtering_workflow_log.txt
date >> $outdir/PhiX_filtering_workflow_log.txt
echo "
---" >> $outdir/PhiX_filtering_workflow_log.txt

echo "		Performing initial demultiplexing with fastq-multx...
"

## Log fastq-multx command
echo "
Fastq-multx command as issued:
fastq-multx -m $indexerrors -x -B $barcodes $index1 $read1 $read2 -o $outdir/fastq-multx_output/index.%.fq -o $outdir/fastq-multx_output/read1.%.fq -o $outdir/fastq-multx_output/read2.%.fq > $outdir/fastq-multx_output/multx_log.txt
" >> $outdir/PhiX_filtering_workflow_log.txt


## Fastq-multx command:
	fastq-multx -m $indexerrors -x -B $barcodes $index1 $read1 $read2 -o $outdir/fastq-multx_output/index1.%.fq -o $outdir/fastq-multx_output/read1.%.fq -o $outdir/fastq-multx_output/read2.%.fq > $outdir/fastq-multx_output/multx_log.txt


## Log multx completion
echo "
		Demultiplexing step complete.  
		Concatenating sample data and deleting unmatched
		sequences to save space.
"
echo "
Fastq-multx step completed." >> $outdir/PhiX_filtering_workflow_log.txt
date >> $outdir/PhiX_filtering_workflow_log.txt
echo "
---" >> $outdir/PhiX_filtering_workflow_log.txt

## Remove unmatched sequences to save space (comment this out if you need to inspect them)
	rm $outdir/fastq-multx_output/*unmatched.fq

## Cat together multx results (3 threads in parallel)
	( cat $outdir/fastq-multx_output/index1.*.fq > $outdir/fastq-multx_output/index1.fastq ) &
	( cat $outdir/fastq-multx_output/read1.*.fq > $outdir/fastq-multx_output/read1.fastq ) &
	( cat $outdir/fastq-multx_output/read2.*.fq > $outdir/fastq-multx_output/read2.fastq ) &
	wait

## Define read files
	idx=$outdir/fastq-multx_output/index1.fastq
	rd1=$outdir/fastq-multx_output/read1.fastq
	rd2=$outdir/fastq-multx_output/read2.fastq

## Remove demultiplexed components of read files (comment out if you need them, but they take up a lot of space)
	rm $outdir/fastq-multx_output/*.fq
	mkdir $outdir/smalt_output
	wait

## Log start of smalt command
echo "		Starting search of demultiplexed data for PhiX contamination 
			with smalt...
"
echo "
Smalt search of demultiplexed data beginning." >> $outdir/PhiX_filtering_workflow_log.txt
date >> $outdir/PhiX_filtering_workflow_log.txt
echo "
Smalt command as issued:
smalt map -n $cores -O -f sam:nohead -o $outdir/smalt_output/phix.mapped.sam $smaltdir/$smaltbase $rd1 $rd2
" >> $outdir/PhiX_filtering_workflow_log.txt
wait

## Smalt command (mapping Phix reads in order to filter out and assess contamination levels)
	smalt map -n $cores -O -f sam:nohead -o $outdir/smalt_output/phix.mapped.sam $smaltdir/$smaltbase $rd1 $rd2
	wait

#use grep to identify reads that are non-phix (in parallel)
#	cd $outdir/smalt_output/
#	split -n l/$cores --additional-suffix=.log phix.mapped.sam
#	wait
#	cd $home

#	for splitseqfile in $outdir/smalt_output/*.log; do
#		( splitseqbase=$(basename $splitseqfile .log)
#		egrep "\w+:\w+:\w+-\w+:\w+:\w+:\w+:\w+\s77" $splitseqfile > $outdir/smalt_output/$splitseqbase.grep ) &
#	done
#	wait

## Cat grep results togther
#	cat $outdir/smalt_output/*.grep > $outdir/smalt_output/phix.unmapped.sam

egrep "\w+:\w+:\w+-\w+:\w+:\w+:\w+:\w+\s77" $outdir/smalt_output/phix.mapped.sam > $outdir/smalt_output/phix.unmapped.sam

	wait

## Remove temporary files (grep results, split up sam file from smalt command)
	rm $outdir/smalt_output/*.grep
	rm $outdir/smalt_output/*.log
	wait

## Use filter_fasta.py to filter contaminating sequences out prior to joining
	( filter_fasta.py -f $outdir/fastq-multx_output/index1.fastq -o $outdir/smalt_output/index.phixfiltered.fq -s $outdir/smalt_output/phix.unmapped.sam ) &
	( filter_fasta.py -f $outdir/fastq-multx_output/read1.fastq -o $outdir/smalt_output/read1.phixfiltered.fq -s $outdir/smalt_output/phix.unmapped.sam ) &
	( filter_fasta.py -f $outdir/fastq-multx_output/read2.fastq -o $outdir/smalt_output/read2.phixfiltered.fq -s $outdir/smalt_output/phix.unmapped.sam ) &
	wait

## Arithmetic and variable definitions to report PhiX contamintaion levels
	totalseqs1=$(cat $outdir/smalt_output/phix.mapped.sam | wc -l)
	nonphixseqs1=$(cat $outdir/smalt_output/index.phixfiltered.fq | wc -l)
	totalseqs=$(($totalseqs1/2))
	nonphixseqs=$(($nonphixseqs1/4))
	phixseqs=$(($totalseqs-$nonphixseqs))
	nonphix100seqs=$(($nonphixseqs*100))
	datapercent=$(($nonphix100seqs/$totalseqs))
	contampercent=$((100-$datapercent))
	read1unmap=$(egrep "\w+:\w+:\w+-\w+:\w+:\w+:\w+:\w+\s4" $outdir/smalt_output/read1.phix.mapped.sam | wc -l)
	read1map=$(($totalseqs-$read1unmap))

## Log results of PhiX filtering
echo "
Found $read1map total demultiplexed read pairs in your sequence data.
Your demultiplexed data contains sample data at this percentage: $datapercent ($nonphixseqs out of $totalseqs total read pairs).
Your demultiplexed data contains PhiX contamination at this percentage: $contampercent ($phixseqs PhiX174-containing read pairs).

PhiX filtering step completed." >> $outdir/PhiX_filtering_workflow_log.txt
date >> $outdir/PhiX_filtering_workflow_log.txt
echo "
---" >> $outdir/PhiX_filtering_workflow_log.txt
echo "
		PhiX filtering step completed.  
		Concatenation steps beginning...
"

## Mkdir to contain fastq-join outputs
	mkdir $outdir/fastq-join_output

## Log concatenation start
echo "
Concatenating index reads to forward reads" >> $outdir/PhiX_filtering_workflow_log.txt
date >> $outdir/PhiX_filtering_workflow_log.txt

## Concatenate index1 in front of read1 (filtered and unfiltered data in parallel - 2 threads)
	( paste -d '' <(echo; sed -n '1,${n;p;}' $outdir/smalt_output/index.phixfiltered.fq | sed G) $outdir/smalt_output/read1.phixfiltered.fq | sed '/^$/d' > $outdir/fastq-join_output/i1r1.phixfiltered.fq ) &
	( paste -d '' <(echo; sed -n '1,${n;p;}' $outdir/fastq-multx_output/index1.fastq | sed G) $outdir/fastq-multx_output/read1.fastq | sed '/^$/d' > $outdir/fastq-multx_output/i1r1.unfiltered.fq ) &
wait

## Log concatenation completion
echo "
Concatenation steps completed." >> $outdir/PhiX_filtering_workflow_log.txt
date >> $outdir/PhiX_filtering_workflow_log.txt
echo "
---
" >> $outdir/PhiX_filtering_workflow_log.txt
echo "		Concatenations completed.  
		Fastq-join steps beginning...
"

## fastq-join commands and logging

echo "Fastq-join commands as issued: 

Filtered data:
fastq-join -p $mismatch -m $overlap -r $outdir/fastq-join_output/fastq-join.report.filtered.log $outdir/fastq-join_output/i1r1.phixfiltered.fq $outdir/smalt_output/read2.phixfiltered.fq -o $outdir/fastq-join_output/phixfiltered.%.fastq

Unfiltered data:
fastq-join -p $mismatch -m $overlap -r $outdir/fastq-join_output/fastq-join.report.unfiltered.log $outdir/fastq-join_output/i1r1.unfiltered.fq $outdir/smalt_output/read2.phixfiltered.fq -o $outdir/fastq-join_output/unfiltered.%.fastq
" >> $outdir/PhiX_filtering_workflow_log.txt

echo "Fastq-join results (Filtered data):" >> $outdir/PhiX_filtering_workflow_log.txt

## fastq-join (filtered data)
	fastq-join -p $mismatch -m $overlap $outdir/fastq-join_output/i1r1.phixfiltered.fq $outdir/smalt_output/read2.phixfiltered.fq -o $outdir/fastq-join_output/phixfiltered.%.fastq >> $outdir/PhiX_filtering_workflow_log.txt
echo "
Fastq-join results (Unfiltered data):" >> $outdir/PhiX_filtering_workflow_log.txt

## fastq-join (unfiltered data)
fastq-join -p $mismatch -m $overlap $outdir/fastq-multx_output/i1r1.unfiltered.fq $outdir/fastq-multx_output/read2.fastq -o $outdir/fastq-join_output/unfiltered.%.fastq >> $outdir/PhiX_filtering_workflow_log.txt
wait

## Arithmetic and variable definitions to assess joining success rates
	joinedlines=$(cat $outdir/fastq-join_output/phixfiltered.join.fastq | wc -l)
	joinedseqs=$(($joinedlines/4))
	joined100seqs=$(($joinedseqs*100))
	joinedpercent=$(($joined100seqs/$totalseqs))
	joinedunlines=$(cat $outdir/fastq-join_output/unfiltered.join.fastq | wc -l)
	joinedunseqs=$(($joinedunlines/4))
	joined100unseqs=$(($joinedunseqs*100))
	joinedunpercent=$(($joined100unseqs/$totalseqs))
	phixinflation=$(($joinedunseqs-$joinedseqs))
	phix100inflation=$(($phixinflation*100))
	inflationpercent=$(($phix100inflation/$joinedseqs))
	quotient=($phixseqs/$read1map)
	decimal=$(echo "scale=10; ${quotient}" | bc)

## Log joining success and fastq-join completion
echo "
Read joining success was achieved at $joinedpercent percent (filtered data).
Read joining success was achieved at $joinedunpercent percent (unfiltered data).

Fastq-join steps completed" >> $outdir/PhiX_filtering_workflow_log.txt
date >> $outdir/PhiX_filtering_workflow_log.txt
echo "		Fastq-join steps completed.  
		Fastx-trimmer commands starting...
"

## Log results and instructions for how to proceed given the results
echo "
---

PhiX would have contributed $phixinflation reads (out of $phixseqs total PhiX reads among your demultiplexed data) to your dataset had you joined reads without filtering (an inflation of $inflationpercent percent).

You can cautiously estimate sample-to-sample contamination as a result of mixed clusters by dividing $phixseqs into $read1map." >> $outdir/PhiX_filtering_workflow_log.txt
echo "Then subtract OTU counts on a PER SAMPLE basis at the resulting percentage (expressed as a decimal here): $decimal" >> $outdir/PhiX_filtering_workflow_log.txt
echo "
To do this, convert your raw biom table (do not even subtract singletons/doubetons yet) to text (see below for instructions specific to qiime 1.8) and manipulate it in a spreadsheet.  For every sample, sum the total sequencing counts.  Multiply this by $decimal, and subtract this amount from every OTU bin.  Use an if function to set the new count to zero (in a separate worksheet) if the result is negative, and convert the result back to biom

Converting biom to txt:
biom convert -i otu_table.biom -o otu_table.txt --header-key taxonomy -b

Converting txt to biom:
biom convert -i filtered_otu_table.txt -o filtered_otu_table.biom --table-type=\"OTU table\" --process-obs-metadata taxonomy

---" >> $outdir/PhiX_filtering_workflow_log.txt

#log fastx_trimmer commands
echo "
Fastx_trimmer commands as issued (filtered data):
fastx_trimmer -l $indexlength -i $outdir/fastq-join_output/phixfiltered.join.fastq -o $outdir/idx.filtered.join.fq -Q 33
fastx_trimmer -f $readno -i $outdir/fastq-join_output/phixfiltered.join.fastq -o $outdir/rd.filtered.join.fq -Q 33" >> $outdir/PhiX_filtering_workflow_log.txt
echo "
Fastx_trimmer commands as issued (unfiltered data):
fastx_trimmer -l $indexlength -i $outdir/fastq-join_output/unfiltered.join.fastq -o $outdir/idx.unfiltered.join.fq -Q 33
fastx_trimmer -f $readno -i $outdir/fastq-join_output/unfiltered.join.fastq -o $outdir/rd.unfiltered.join.fq -Q 33" >> $outdir/PhiX_filtering_workflow_log.txt

#split indexes from successfully joined reads (4 threads, 2 index, 2 reads)
	( fastx_trimmer -l $indexlength -i $outdir/fastq-join_output/phixfiltered.join.fastq -o $outdir/idx.filtered.join.fq -Q 33 ) &
	( fastx_trimmer -l $indexlength -i $outdir/fastq-join_output/unfiltered.join.fastq -o $outdir/idx.unfiltered.join.fq -Q 33 ) &

#split read data from successfully joined reads
	( fastx_trimmer -f $readno -i $outdir/fastq-join_output/phixfiltered.join.fastq -o $outdir/rd.filtered.join.fq -Q 33 ) &
	( fastx_trimmer -f $readno -i $outdir/fastq-join_output/unfiltered.join.fastq -o $outdir/rd.unfiltered.join.fq -Q 33 ) &
	wait

## Lof fastx_trimmer completion
echo "
Trimming steps completed"  >> $outdir/PhiX_filtering_workflow_log.txt
date >> $outdir/PhiX_filtering_workflow_log.txt
echo "		Trimming completed.  
		Removing excess large files...
"

## Remove excess files that can take up a lot of space.
## Comment out any lines here that are deleting the files you are interested in.

rm $outdir/fastq-join_output/unfiltered.join.fastq
rm $outdir/fastq-join_output/unfiltered.un1.fastq
rm $outdir/fastq-join_output/unfiltered.un2.fastq
rm $outdir/fastq-multx_output/i1r1.unfiltered.fq
wait

rm $outdir/fastq-join_output/i1r1.phixfiltered.fq
rm $outdir/smalt_output/index.phixfiltered.fq
rm $outdir/smalt_output/phix.unmapped.sam
rm $outdir/fastq-join_output/phixfiltered.join.fastq
rm $outdir/fastq-join_output/phixfiltered.un1.fastq
rm $outdir/fastq-join_output/phixfiltered.un2.fastq
rm $outdir/smalt_output/read1.phixfiltered.fq
rm $outdir/smalt_output/read2.phixfiltered.fq
rm $outdir/smalt_output/phix.mapped.sam
rm $outdir/fastq-multx_output/*.fastq
rmdir $outdir/smalt_output/
rmdir $outdir/fastq-join_output/

## Log script completion
echo "
---

Filtering/joining workflow is completed!" >> $outdir/PhiX_filtering_workflow_log.txt
date >> $outdir/PhiX_filtering_workflow_log.txt
echo "
---


" >> $outdir/PhiX_filtering_workflow_log.txt

echo "		Joining workflow is completed.
		See output file, $outdir/PhiX_filtering_workflow_log.txt
		for joining details.
"

