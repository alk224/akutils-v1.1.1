#!/usr/bin/env bash
set -e

## should add a threads variable to allow multithreading during alignment
## Right now it is hard-coded to allow 4 threads during mafft alignment and I'm not sure it's working correctly

## a script to extract sequences from a rep set based on OTU table

## want to assess the number of L7 taxa, the number of OTUs, report OTUs/per taxa average
## as well as OTUs per each taxon

## need to build a master sequence list, and an alignment for taxa made up of multiple OTUs

## Check whether user had supplied -h or --help. If yes display help 

	if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
		echo "
		This script will look for a file of representative sequences
		that is named *rep_set.fna and extract sequences against
		an OTU table that you supply.  The representative sequence
		set must match the supplied OTU table.  This script also 
		relies on the presence of a taxa_plots directory which contains
		taxa-summarized .txt-format OTU table at the L7 level.
		This is automatically generated in QIIME core_diversity
		workflow and in akutils cdiv workflows. If you run this
		script inside an akutils cdiv workflow output directory,
		rerun the workflow to build the output from this script
		into the cdiv workflow html output.

		Usage (order is important!!):
		match_reads_to_taxonomy.sh <otu_table> <threads>
		
		Example:
		match_reads_to_taxonomy.sh OTU_table.biom 4

		"
		exit 0
	fi 

# if more or less than one arguments supplied, display usage 

	if [  "$#" -ne 2 ] ;
	then 
		echo "
		Usage (order is important!!):
		match_reads_to_taxonomy.sh <otu_table> <threads>
		"
		exit 1
	fi 

table1=$1
tablename=$(basename $table1 .biom)
fullpath=`readlink -f $table1`
outdir=$(dirname $fullpath)
threads=$2

## check that only 1 rep set file is present

rep_set_count=`ls $outdir | grep "rep_set.fna" | wc -l`

if [[ $rep_set_count == 0 ]]; then
	echo "
	No rep set file is present.  To extract OTU sequences,
	move the appropriate rep set file into the core diversity
	workflow output directory and rerun the workflow.  Only
	one rep set file may be present, and it MUST be named
	thusly (where * is any characters):

	*rep_set.fna

	abc
	"
	exit 1
fi
if [[ $rep_set_count -ge 2 ]]; then
	echo "
	More than one rep set file is present.  Leave only the 
	appropriate rep set file into the core diversity
	workflow output directory and rerun the workflow.  Only
	one rep set file may be present, and it MUST be named
	thusly (where * is any characters):

	*rep_set.fna
	"
	exit 1
fi

rep_set=`ls $outdir | grep "rep_set.fna"`

## convert rarefied OTU table to .txt

if [[ ! -f $outdir/$tablename.txt ]]; then
	biomtotxt.sh $1 &>/dev/null
fi
table=$outdir/$tablename.txt

## get column from OTU table that contains the taxonomy string

taxa_column=`awk -v outdir="$outdir" -v table="$table" '{ for(i=1;i<=NF;i++){if ($i ~ /taxonomy/) {print i}}}' $table`
alt_taxa_column=`expr $taxa_column - 1`

## sort OTU table by taxonomy

if [[ ! -f $outdir/$tablename\_sorted_by_taxonomy.txt ]]; then
	head -2 $outdir/$tablename.txt | tail -1 > $outdir/$tablename\_sorted_by_taxonomy.txt
	tail -n +3 $outdir/$tablename.txt | sort -k$taxa_column >> $outdir/$tablename\_sorted_by_taxonomy.txt
fi

## make list of OTUs from sorted table

if [[ ! -f $outdir/$tablename\_sorted_by_taxonomy_otu_list.txt ]]; then
	grep -v "#" $outdir/$tablename\_sorted_by_taxonomy.txt | cut -f1 > $outdir/$tablename\_sorted_by_taxonomy_otu_list.txt
fi

## Check for outputs

if [[ ! -d $outdir/Representative_sequences ]]; then
	mkdir $outdir/Representative_sequences
fi

Rep_seqs_file_count=`ls $outdir/Representative_sequences/ | wc -l`
if [[ Rep_seqs_file_count -ge 1 ]]; then
	rm -r $outdir/Representative_sequences/*
fi

## Build sequence file, adding taxonomy string to fasta header

for otuid in `cat $outdir/$tablename\_sorted_by_taxonomy_otu_list.txt`; do 
	grep -A 1 -e ">$otuid\s" $outdir/$rep_set >> $outdir/Representative_sequences/$tablename\_rep_sequences.fasta
	sed -i "/^>$otuid\s/ s/$otuid\s/$otuid\t/" $outdir/Representative_sequences/$tablename\_rep_sequences.fasta
	otuid_tax_string0=`grep -e "$otuid\s" $outdir/$tablename\_sorted_by_taxonomy.txt | cut -f$alt_taxa_column`
	otuid_tax_string1=`echo $otuid_tax_string0 | sed "s/; /__/g"`
	otuid_tax_string=`echo $otuid_tax_string1 | sed "s/ /_/g"`
	sed -i "/^>$otuid\t/ s/$/\t$otuid_tax_string/" $outdir/Representative_sequences/$tablename\_rep_sequences.fasta
done

## Build taxonomy list from L7 table and L7 table with matching taxonomy strings

cp $outdir/taxa_plots/table_sorted_L7.txt $outdir/Representative_sequences/L7_table0.txt
grep "#OTU ID" $outdir/Representative_sequences/L7_table0.txt > $outdir/Representative_sequences/L7_table.txt
grep -v "#" $outdir/Representative_sequences/L7_table0.txt | sed "s/;/__/g" | sed "s/ /_/g" >> $outdir/Representative_sequences/L7_table.txt
rm $outdir/Representative_sequences/L7_table0.txt

grep -v "#" $outdir/Representative_sequences/L7_table.txt | cut -f1 | sed "s/;/__/g" | sed "s/ /_/g" > $outdir/Representative_sequences/L7_taxa_list.txt

## Add number of OTUs to second column of taxa list

for taxid in `cat $outdir/Representative_sequences/L7_taxa_list.txt`; do
	num_otus=`grep -c -e "\s$taxid$" $outdir/Representative_sequences/$tablename\_rep_sequences.fasta`
	sed -i "/^$taxid$/ s/$/\t${num_otus}/" $outdir/Representative_sequences/L7_taxa_list.txt
done

## Build taxon-specific multi-fasta files

mkdir -p $outdir/Representative_sequences/L7_sequences_by_taxon
for taxid in `cat $outdir/Representative_sequences/L7_taxa_list.txt | cut -f1`; do
	
	grep -A 1 -e "\s$taxid$" $outdir/Representative_sequences/$tablename\_rep_sequences.fasta > $outdir/Representative_sequences/L7_sequences_by_taxon/$taxid.fasta
done

## Mafft alignments for taxa with multiple reads per OTU -- copy single representative reads

mkdir -p $outdir/Representative_sequences/L7_sequences_by_taxon_alignments
for taxid in `cat $outdir/Representative_sequences/L7_taxa_list.txt | cut -f1`; do
	otu_count=`grep -e "^$taxid\s" $outdir/Representative_sequences/L7_taxa_list.txt | cut -f2`
	if [[ $otu_count -le 1 ]]; then
	mkdir $outdir/Representative_sequences/L7_sequences_by_taxon_alignments/$taxid
	cp $outdir/Representative_sequences/L7_sequences_by_taxon/$taxid.fasta $outdir/Representative_sequences/L7_sequences_by_taxon_alignments/$taxid/$taxid\_aligned.fasta
	echo "
Single representative sequence for this taxon.  Skipping alignment.
	" > $outdir/Representative_sequences/L7_sequences_by_taxon_alignments/$taxid/$taxid\_log.txt
	elif [[ $otu_count -ge 2 ]]; then
	mkdir $outdir/Representative_sequences/L7_sequences_by_taxon_alignments/$taxid
	mafft --localpair --maxiterate 1000 --quiet --nuc --reorder --treeout --clustalout --thread $threads $outdir/Representative_sequences/L7_sequences_by_taxon/$taxid.fasta > $outdir/Representative_sequences/L7_sequences_by_taxon_alignments/$taxid/$taxid\_aligned.aln #&>$outdir/Representative_sequences/L7_sequences_by_taxon_alignments/$taxid/$taxid\_log.txt
	fi
done

## Generate summary stats

	if [[ ! -f $outdir/Representative_sequences/otus_per_taxon_summary.txt ]]; then
		workdir=$(pwd)
		cd $outdir/Representative_sequences/
		otu_summary_stats.r $outdir/Representative_sequences/L7_taxa_list.txt
		cd $workdir
	fi
 







