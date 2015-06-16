#!/usr/bin/env bash
#
#  db_format.sh - reformat a QIIME-formatted reference database to include only a certain locus
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

## Check whether user had supplied -h or --help. If yes display help 

	if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
	scriptdir="$( cd "$( dirname "$0" )" && pwd )"
	less $scriptdir/docs/db_format.help
	exit 0
	fi 

## If incorrect number of arguments supplied, display usage 

	if [[ "$#" -le 4 ]] || [[ "$#" -ge 7 ]]; then 
		echo "
Usage (order is important!!):
db_format.sh <input_fasta> <input_taxonomy> <input_primers> <read_length> <output_directory> <input_phylogeny>

	<input_phylogeny> is optional!!
		"
		exit 1
	fi

## Define variables

inrefs=($1)
intax=($2)
primers=($3)
length=($4)
outdir=($5)
intree=($6)
forward=`cat $primers | grep -e "f\s"`
forname=`cat $primers | grep -e "f\s" | cut -f 1`
forcount=`echo $forname | wc -l`
reverse=`cat $primers | grep -e "r\s"`
revname=`cat $primers | grep -e "r\s" | cut -f 1`
revcount=`echo $revname | wc -l`
primercount=$(($forcount+$revcount))
taxfilename=$(basename "$intax")
taxextension="${taxfilename##*.}"
taxname=$(basename $intax .$taxextension)
refsfilename=$(basename "$inrefs")
refsextension="${refsfilename##*.}"
refsname=$(basename $inrefs .$refsextension)
refscount=`cat $intax | wc -l`
date0=`date +%Y%m%d_%I%M%p`
log=$outdir/log_$date0.txt

## Make output directory

	if [[ ! -d $outdir ]]; then
	mkdir -p $outdir

	else
	echo "
Output directory exists.  Attempting to utilize previously generated
data.
	"
	fi

## Log workflow start
	date1=`date "+%a %b %d %I:%M %p %Z %Y"`
	res0=$(date +%s.%N)

	echo "Format database files workflow beginning.
$date1
Input DB contains $refscount sequences.
	"

	echo "
Format database files workflow beginning.
$date1
Input DB contains $refscount sequences
Input references: $inrefs
Input taxonomy: $intax" > $log
	if [[ ! -z $intree ]]; then
echo "Input phylogeny: $intree" >> $log
	fi

## Make subdirectories
	if [[ ! -d $outdir/temp ]]; then
	mkdir -p $outdir/temp
	fi


## Parse nonstandard characters in both inputs
## Script from Tony Walters

	echo "Parsing nonstandard characters from inputs.
	"
	echo "
Parsing nonstandard characters from inputs:
	( parse_nonstandard_chars.py $inrefs > $outdir/temp/${refsname}_clean0.$refsextension ) &
	( parse_nonstandard_chars.py $intax > $outdir/temp/${taxname}_clean.$taxextension ) &
	if [[ ! -z $intree ]]; then
	( parse_nonstandard_chars.py $intree > $outdir/temp/${refsname}_tree_clean.tre ) &
	fi
	wait
" >> $log
	( parse_nonstandard_chars.py $inrefs > $outdir/temp/$refsname\_clean0.$refsextension ) &
	( parse_nonstandard_chars.py $intax > $outdir/temp/$taxname\_clean.$taxextension ) &
	if [[ ! -z $intree ]]; then
	( parse_nonstandard_chars.py $intree > $outdir/temp/$refsname\_tree_clean.tre ) &
	fi
	wait

## Remove square brackets and quotes from taxonomy strings, and remove any text wrapping in the fasta input

	echo "Removing square brackets and quotes from taxonomy strings, and removing
any text wrapping in input fasta.
	"
	echo "
Removing square brackets and quotes from taxonomy strings, and removing
any text wrapping in input fasta.
	( sed -i -e \"s/\[//g\" -e \"s/\]//g\" -e \"s/'//g\" -e \"s/\"//g\" $outdir/temp/${taxname}_clean.$taxextension ) &
	( unwrap_fasta.sh $outdir/temp/${refsname}_clean0.$refsextension $outdir/temp/${refsname}_clean.$refsextension ) &
	wait
" >> $log
	( sed -i -e "s/\[//g" -e "s/\]//g" -e "s/'//g" -e "s/\"//g" $outdir/temp/$taxname\_clean.$taxextension ) &
#	( sed -i -e "s/\[//g" -e "s/\]//g" -e "s/'//g" -e "s/\"//g" $outdir/temp/$refsname\_tree_clean.tre ) &
	( unwrap_fasta.sh $outdir/temp/$refsname\_clean0.$refsextension $outdir/temp/$refsname\_clean.$refsextension ) &
	wait

## Remove any leading or trailing whitespacesheck if input DB is sorted congruently

	echo "Removing any leading or trailing whitespaces from inputs.
	"
	echo "
Removing any leading or trailing whitespaces from inputs.
	( sed -i 's/^[ \t]*//;s/[ \t]*$//' $outdir/temp/${taxname}_clean.$taxextension ) &
	( sed -i 's/^[ \t]*//;s/[ \t]*$//' $outdir/temp/${refsname}_clean.$refsextension ) &
	wait
	sed -i '/^$/d' $outdir/temp/${refsname}_clean.$refsextension
	rm $outdir/temp/${refsname}_clean0.$refsextension
" >> $log
	( sed -i 's/^[ \t]*//;s/[ \t]*$//' $outdir/temp/$taxname\_clean.$taxextension ) &
	( sed -i 's/^[ \t]*//;s/[ \t]*$//' $outdir/temp/$refsname\_clean.$refsextension ) &
	wait
	sed -i '/^$/d' $outdir/temp/$refsname\_clean.$refsextension

	rm $outdir/temp/$refsname\_clean0.$refsextension

## Check if input DB is sorted congruently

#	echo "	Checking if taxonomy and sequence files are sorted
#	"

	tax=$outdir/temp/$taxname\_clean.$taxextension
	refs=$outdir/temp/$refsname\_clean.$refsextension
#	tree=$outdir/temp/$refsname\_tree_clean.tre

#	cat $cleanrefs | awk '{if (substr($0,1,1)==">"){if (p){print "\n";} print $0} else printf("%s",$0);p++;}END{print "\n"}' > $outdir/refs_nowraps.temp

#	head -10000 $cleantax | cut -f 1 > $outdir/sorttest.tax.headers.temp
#	head -20000 $cleanrefs | grep ">" | sed 's/>//' > $outdir/sorttest.refs.headers.temp
#	diffcount=`diff -d $outdir/sorttest.tax.headers.temp $outdir/sorttest.refs.headers.temp | wc -l`
#	rm $outdir/sorttest.tax.headers.temp $outdir/sorttest.refs.headers.temp

#	if [[ $diffcount == 0 ]]; then
#	echo "		Input DB is properly sorted.
#	"
#	refs=$inrefs
#	tax=$intax

#	else
#	echo "		Reference and taxonomy files are not in
#		the same order.  Sorting inputs before
#		continuing.  This can take a while.
#	"
#	cat $cleantax | sort -k1 > $outdir/${taxname}_clean_sorted.${taxextension}
#	cleansortedtax=$outdir/${taxname}_clean_sorted.${taxextension}
#
#	echo > $outdir/${refsname}_clean_sorted.${refsextension}
#	cleansortedrefs=$outdir/${refsname}_clean_sorted.${refsextension}

#	for line in `cat $cleansortedtax | cut -f 1`; do
#	grep -m 1 -w -A 1 ">$line" $cleanrefs >> $cleansortedrefs
#	sed -i '/^\s*$/d' $cleansortedrefs
#	done
#	echo "		DB sorted and leading and trailing whitespaces
#		removed.
#	"
#	rm $cleantax $cleanrefs
#	refs=$cleansortedrefs
#	tax=$cleansortedtax
#	fi

## Analyze primers

	if [[ ! -d $outdir/analyze_primers_out ]]; then
	mkdir -p $outdir/analyze_primers_out
	echo "Generating primer hits files.
Forward primer: $forward
Reverse primer: $reverse
	"
	echo "
Generating primer hits files.
Forward primer: $forward
Reverse primer: $reverse

Analyze primers command:
	analyze_primers.py -f $refs -P $primers -o $outdir/analyze_primers_out" >> $log
	analyze_primers.py -f $refs -P $primers -o $outdir/analyze_primers_out

	else
	echo "	Primer hits files previously generated."
	echo "
Primer hits files previously generated." >> $log
	if [[ $forcount == 1 ]]; then
	echo "	Forward primer: $forward"
	echo "Forward primer: $forward" >> $log
	fi
	if [[ $revcount == 1 ]]; then
	echo "	Reverse primer: $reverse"
	echo "Reverse primer: $reverse" >> $log
	fi
	echo ""
	fi

## Get amplicons and reads

	ampout=$outdir/get_amplicons_and_reads_out

	if [[ ! -d $ampout ]]; then
	fhitsfile=`ls $outdir/analyze_primers_out/*f_*_hits.txt`
	rhitsfile=`ls $outdir/analyze_primers_out/*r_*_hits.txt`

	if [[ $primercount == 2 ]]; then
	
	echo "Generating in silico reads and amplicons.
	"
	echo "
Generating in silico reads and amplicons.

Get amplicons and reads command (both primers):
	get_amplicons_and_reads.py -f $refs -i $fhitsfile:$rhitsfile -o $ampout -t 100 -d p -R $length" >> $log
	get_amplicons_and_reads.py -f $refs -i $fhitsfile:$rhitsfile -o $ampout -t 100 -d p -R $length -m 75

	## Remove reads from paired analysis
	rm $ampout/${forname}_${revname}_f_${length}_reads.fasta
	rm $ampout/${forname}_${revname}_r_${length}_reads.fasta

	## Produce DBs for each primer separately (more complete this way)

	echo "
Get amplicons and reads command (primer $forname):
	get_amplicons_and_reads.py -f $refs -i $fhitsfile -o $ampout -t 100 -d p -R $length -m 75" >> $log
	get_amplicons_and_reads.py -f $refs -i $fhitsfile -o $ampout -t 100 -d p -R $length -m 75
	rm $ampout/${forname}_amplicons.fasta
	rm $ampout/${forname}_r_${length}_reads.fasta
	mv $ampout/${forname}_f_${length}_reads.fasta $ampout/${forname}_${length}_reads.fasta

	echo "
Get amplicons and reads command (primer $revname):
	get_amplicons_and_reads.py -f $refs -i $rhitsfile -o $ampout -t 100 -d p -R $length -m 75" >> $log
	get_amplicons_and_reads.py -f $refs -i $rhitsfile -o $ampout -t 100 -d p -R $length -m 75
	rm $ampout/${revname}_amplicons.fasta
	rm $ampout/${revname}_f_${length}_reads.fasta
	mv $ampout/${revname}_r_${length}_reads.fasta $ampout/${revname}_${length}_reads.fasta

	elif [[ $forcount == 1 ]]; then

	echo "	get_amplicons_and_reads.py -f $refs -i $fhitsfile -o $ampout -t 100 -d f -R $length" >> $log
	get_amplicons_and_reads.py -f $refs -i $fhitsfile -o $ampout -t 75 -d f -R $length

	elif [[ $revcount == 1 ]]; then

	echo "	get_amplicons_and_reads.py -f $refs -i $rhitsfile -t 100 -d r -R $length" >> $log
	get_amplicons_and_reads.py -f $refs -i $rhitsfile -o $ampout -t 75 -d r -R $length

	fi
	fi

## Format taxonomy according to each new fasta

	echo "Formatting new taxononmy files according to in silico results.
	"
	echo "
Formatting new taxononmy files according to in silico results." >> $log
	echo "
Database stats:" >> $log
	for fasta in $ampout/*.fasta; do
	fastabase=`basename $fasta .fasta`
	echo > $ampout/${fastabase}_seqids.txt
	grep ">" $fasta | sed "s/>//" >> $ampout/${fastabase}_seqids.txt
	sed -i '/^$/d' $ampout/${fastabase}_seqids.txt
	done

	ampliconids=`ls $ampout/${forname}_${revname}_amplicons_seqids.txt`
	forwardids=`ls $ampout/${forname}_*_reads_seqids.txt`
	reverseids=`ls $ampout/${revname}_*_reads_seqids.txt`
	
	for seqid_file in `ls $ampout/*_seqids.txt`; do
	seqid_base=`basename $seqid_file _seqids.txt`
	echo > $ampout/${seqid_base}_taxonomy.txt
	#for line in `cat $seqid_file`; do
		grep -Ff $seqid_file $tax >> $ampout/${seqid_base}_taxonomy.txt
	#	( grep -e "^$line$" $tax >> $ampout/${seqid_base}_taxonomy.txt ) &
	#	NPROC=$(($NPROC+1))
	#	if [ "$NPROC" -ge 64 ]; then
	#		wait
	#	NPROC=0
	#	fi
	#done
	sed -i '/^$/d' $ampout/${seqid_base}_taxonomy.txt
	taxnumber=`cat $ampout/${seqid_base}_taxonomy.txt | wc -l`
	echo "DB for $seqid_base formatted with $taxnumber/$refscount references" >> $log
	echo "DB for $seqid_base formatted with $taxnumber/$refscount references"
	done
	wait

## Build composite fasta by combining in silico amplicons, in silico read1, in silico read2 (in this order)
## This improves formatted database completeness for some databases such as UNITE

	amplicon_fasta=`ls $ampout/*_amplicons.fasta`
	amp_count=`cat $ampout/${forname}_${revname}_amplicons_seqids.txt | wc -l`
	forward_fasta=`ls $ampout/${forname}_${length}_reads.fasta`
	for_count=`cat $ampout/${forname}_${length}_reads_seqids.txt | wc -l`
	reverse_fasta=`ls $ampout/${revname}_${length}_reads.fasta`
	rev_count=`cat $ampout/${revname}_${length}_reads_seqids.txt | wc -l`

	if [[ $amp_count -ne $for_count ]]; then

	cat $ampliconids > $ampout/${forname}_${revname}_composite_seqids.txt
	compids=$ampout/${forname}_${revname}_composite_seqids.txt
	grep -A 1 -Ff $ampliconids $amplicon_fasta > $ampout/${forname}_${revname}_composite.fasta
	comp_seqs=$ampout/${forname}_${revname}_composite.fasta

	grep -v -Ff $ampliconids $forwardids > $ampout/read1ids_minus_ampliconids.txt
	read1ids=$ampout/read1ids_minus_ampliconids.txt
	read1_count=`cat $read1ids | wc -l`

	grep -A 1 -Ff $read1ids $forward_fasta >> $ampout/${forname}_${revname}_composite.fasta
	cat $compids $read1ids > $ampout/amp_plus_read1_ids.txt

#	if [[ -s $ampout/amp_plus_read1_ids.txt ]]; then
	grep -v -Ff $ampout/amp_plus_read1_ids.txt $reverseids > $ampout/read2ids_minus_others.txt >/dev/null 2>&1 || true
#	fi

	read2ids=$ampout/read2ids_minus_others.txt
	if [[ -s $read2ids ]]; then
		grep -A 1 -Ff $read2ids $reverse_fasta > $ampout/read2_sequences.fasta
		read2seqs=$ampout/read2_sequences.fasta
		adjust_seq_orientation.py -i $read2seqs -r
		mv read2_sequences_rc.fasta $ampout
		cat $ampout/read2_sequences_rc.fasta >> $comp_seqs
		rm $read2seqs
		rm $ampout/read2_sequences_rc.fasta
		read2_count=`cat $read2ids | wc -l`
	fi

		# Set read2 count variable if none used
		if [[ -z $read2_count ]]; then
		read2_count="0"
		fi

	cat $read1ids >> $compids
	cat $read2ids >> $compids
	sed -i '/^$/d' $compids

	if [[ -s $compids ]]; then
		grep -Ff $compids $tax >> $ampout/${forname}_${revname}_composite_taxonomy.txt
#		NPROC=$(($NPROC+1))
#		if [ "$NPROC" -ge 64 ]; then
#			wait
#		NPROC=0
#		fi
#	done
	fi
	sed -i '/^$/d' $ampout/${forname}_${revname}_composite_taxonomy.txt
	taxnumber=`cat $ampout/${forname}_${revname}_composite_taxonomy.txt | wc -l`
	echo "DB for ${forname}_${revname}_composite formatted with $taxnumber/$refscount references
Composite database contains:
$amp_count in silico amplicons
$read1_count in silico forward reads (${length}bp)
$read2_count in silico reverse reads (${length}bp)" >> $log
	echo "DB for ${forname}_${revname}_composite formatted with $taxnumber/$refscount references

Composite database contains:
$amp_count in silico amplicons
$read1_count in silico forward reads (${length}bp)
$read2_count in silico reverse reads (${length}bp)"
	echo ""
	else
	echo "Formatted database is complete.  Not generating a composite database.
	"
	echo "
Formatted database is complete.  Not generating a composite database." >> $log
	fi

## Filter input phylogeny to produce trees for each output

	if [[ ! -z $intree ]]; then
	
	echo "Filtering input phylogeny against formatted databases
	"
	echo "
Filtering input phylogeny against formatted databases

	( filter_tree.py -i $intree -o $ampout/${seqid_base}_tree.tre -t $ampout/${seqid_base}_taxonomy.txt ) &" >> $log

	for seqid_file in `ls $ampout/*_seqids.txt`; do
	seqid_base=`basename $seqid_file _seqids.txt`
	
	( filter_tree.py -i $intree -o $ampout/${seqid_base}_tree.tre -t $ampout/${seqid_base}_taxonomy.txt ) &
		NPROC=$(($NPROC+1))
		if [ "$NPROC" -ge 64 ]; then
			wait
		NPROC=0
		fi
	done
	fi
	wait

## Cleanup and report output

	mv $ampout/*.fasta $outdir/
	mv $ampout/*_taxonomy.txt $outdir/
	if [[ ! -z $intree ]]; then
	mv $ampout/*_tree.tre $outdir/
	fi
	rm -r $ampout
	rm -r $outdir/temp

## Log workflow end

	res1=$( date +%s.%N )
	dt=$( echo $res1 - $res0 | bc )
	dd=$( echo $dt/86400 | bc )
	dt2=$( echo $dt-86400*$dd | bc )
	dh=$( echo $dt2/3600 | bc )
	dt3=$( echo $dt2-3600*$dh | bc )
	dm=$( echo $dt3/60 | bc )
	ds=$( echo $dt3-60*$dm | bc )

	runtime=`printf "Total runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`

	echo "
Database formatting complete.
$runtime
	"
	echo "
Database formatting complete.
$runtime
	" >> $log

exit 0
