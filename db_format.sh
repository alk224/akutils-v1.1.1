#!/usr/bin/env bash
set -e

## Check whether user had supplied -h or --help. If yes display help 

	if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
		echo "
		This script will take an input reference fasta, an
		associated taxonomy file already formatted for use
		with QIIME, and a pair of primers (degenerate OK)
		and produces three pairs of fasta and taxonomy files
		as outputs:
			1) read1 (for use with read 1 only)
			2) read2 (for use with read 2 only)
			3) full amplicon (for use with joined data)

		Usage (order is important!!):
		db_format.sh <input_fasta> <input_taxonomy> <input_primers> <read_length> <output_directory>

		<input_primers> must be formatted for Primer Prospector
		and contain no more than two primers.
		example:
		515f	GTGCCAGCMGCCGCGGTAA
		806r	GGACTACHVGGGTWTCTAAT

		Notes: Primer suffixes (f and r) are essential.  Primer
		sequences are supplied 5->3 prime.  Database fasta must
		be correctly oriented with respect to primer direction.
		Input files can have only ONE \".\" character immediately
		preceeding the file extension or this workflow will fail.
		
		Example:
		db_format.sh greengenes_97repset.fasta greengenes_97tax.txt 515-806.txt 150 16S_v4_db

		Will take representative sequences and associated taxonomy
		file for greengenes97 and use the primer file 515-806.txt
		to produce a set of database files for use with v4 amplicons
		generated with 515f and 806r in paired end 2x150 mode.
		Output will be placed in a directory called 16S_v4_db.

		Please cite Primer Prospector if you find this utility 
		useful.

PrimerProspector: de novo design and taxonomic analysis of PCR primers. William A. Walters, J. Gregory Caporaso, Christian L. Lauber, Donna Berg-Lyons, Noah Fierer, and Rob Knight. Bioinformatics (2011) 27(8): 1159-1161.
		"
		exit 0
	fi 

## If more or less than 5 arguments supplied, display usage 

	if [[ "$#" -le 4 ]] || [[ "$#" -ge 6 ]]; then 
		echo "
		Usage (order is important!!):
		db_format.sh <input_fasta> <input_taxonomy> <input_primers> <read_length> <output_directory>
		"
		exit 1
	fi

## Define variables

inrefs=($1)
intax=($2)
primers=($3)
length=($4)
outdir=($5)
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
		Output directory exists.  Attempting to utilize
		previously generated data.
	"
	fi

## Log workflow start
	date1=`date "+%a %b %I:%M %p %Z %Y"`
	res0=$(date +%s.%N)

	echo "
		Format database files workflow beginning.
		$date1
		Input DB contains $refscount sequences
	"

	echo "
Format database files workflow beginning.
$date1
Input DB contains $refscount sequences" > $log

## Remove any leading or training whitespaces and heck if input DB is sorted congruently

	( sed 's/^[ \t]*//;s/[ \t]*$//' $intax > ${outdir}/${taxname}_clean.${taxextension} ) &
	( sed 's/^[ \t]*//;s/[ \t]*$//' $inrefs > ${outdir}/${refsname}_clean.${refsextension} ) &
	wait

	cleantax=${outdir}/${taxname}_clean.${taxextension}
	cleanrefs=${outdir}/${refsname}_clean.${refsextension}

	cat $cleanrefs | awk '{if (substr($0,1,1)==">"){if (p){print "\n";} print $0} else printf("%s",$0);p++;}END{print "\n"}' > $outdir/refs_nowraps.temp
	sed '/^$/d' $outdir/refs_nowraps.temp > $cleanrefs
	rm $outdir/refs_nowraps.temp

	head -1000 $cleantax | cut -f 1 > $outdir/sorttest.tax.headers.temp
	head -2000 $cleanrefs | grep ">" | sed 's/>//' > $outdir/sorttest.refs.headers.temp
	diffcount=`diff -d $outdir/sorttest.tax.headers.temp $outdir/sorttest.refs.headers.temp | wc -l`
	rm $outdir/sorttest.tax.headers.temp $outdir/sorttest.refs.headers.temp

	if [[ $diffcount == 0 ]]; then
	echo "		Input DB is properly sorted.
	"
	refs=$inrefs
	tax=$intax

	else
	echo "		Reference and taxonomy files are not in
		the same order.  Sorting inputs before
		continuing.  This can take a while.
	"
	cat $cleantax | sort -k1 > $outdir/${taxname}_clean_sorted.${taxextension}
	cleansortedtax=$outdir/${taxname}_clean_sorted.${taxextension}

	echo > $outdir/${refsname}_clean_sorted.${refsextension}
	cleansortedrefs=$outdir/${refsname}_clean_sorted.${refsextension}

	for line in `cat $cleansortedtax | cut -f 1`; do
	grep -m 1 -w -A 1 ">$line" $cleanrefs >> $cleansortedrefs
	sed -i '/^\s*$/d' $cleansortedrefs
	done
	echo "		DB sorted and leading and trailing whitespaces
		removed.
	"
	rm $cleantax $cleanrefs
	refs=$cleansortedrefs
	tax=$cleansortedtax
	fi

## Analyze primers

	if [[ ! -d $outdir/analyze_primers_out ]]; then
	mkdir -p $outdir/analyze_primers_out
	echo "		Generating primer hits files.
		Forward primer: $forward
		Reverse primer: $reverse
	"
	echo "Forward primer: $forward
Reverse primer: $reverse

Analyze primers command:
	analyze_primers.py -f $refs -P $primers -o $outdir/analyze_primers_out" >> $log
	analyze_primers.py -f $refs -P $primers -o $outdir/analyze_primers_out

	else
	echo "		Primer hits files previously generated."
	if [[ $forcount == 1 ]]; then
	echo "		Forward primer: $forward"
	fi
	if [[ $revcount == 1 ]]; then
	echo "		Reverse primer: $reverse"
	fi
	echo ""
	fi

## Get amplicons and reads

	ampout=$outdir/get_amplicons_and_reads_out

	if [[ ! -d $ampout ]]; then
	fhitsfile=`ls $outdir/analyze_primers_out/*f_*_hits.txt`
	rhitsfile=`ls $outdir/analyze_primers_out/*r_*_hits.txt`

	if [[ $primercount == 2 ]]; then
	

	echo "
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

	echo "
Database stats:" >> $log
	for fasta in $ampout/*.fasta; do
	fastabase=$( basename $fasta .fasta )

	grep ">" $fasta | sed "s/>//" > $ampout/${fastabase}_seqids.txt
		for line in $( cat $ampout/$fastabase\_seqids.txt ); do
		grep -w -m 1 "$line" $tax >> $ampout/${fastabase}_taxonomy.txt
		done
	seqnumber=`cat $ampout/${fastabase}_taxonomy.txt | wc -l`
	echo "	DB for $fastabase formatted with $seqnumber references" >> $log
	echo "		DB for $fastabase formatted with $seqnumber references"
	done

## Cleanup and report output

	rm $ampout/*seqids.txt
	mv $ampout/* $outdir
	rmdir $ampout

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

