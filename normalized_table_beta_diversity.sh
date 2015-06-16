#!/usr/bin/env bash
#
#  normalized_table_beta_diversity.sh - Slave script for cdiv_graphs_and_stats_workflow.sh
# 					to proces normalized beta diversity
#
#  Version 1.0.0 (June 15, 2015)
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

#	if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
#	scriptdir="$( cd "$( dirname "$0" )" && pwd )"
#	less $scriptdir/docs/cdiv_for_normalized_tables.help
#		exit 0
#	fi 

## If less than four or more than five arguments supplied, display usage 

	if [[ "$#" -le 3 ]] || [[ "$#" -ge 6 ]]; then 
		echo "
Incorrect number of arguments passed to normalized_table_beta_diversity.sh
function.  Command as called was:

normalized_table_beta_diversity.sh <normalized_table> <output_dir> <mapping_file> <cores> <optional_tree>
normalized_table_beta_diversity.sh $1 $2 $3 $4 $5 $6 $7 $8 $9

Exiting.
		"
		exit 1
	fi

## Define variables

intable=($1)
outdir=($2)
mapfile=($3)
cores=($4)
threads=$(expr $4 + 1)
tree=($5)
otudir=$(dirname $intable)
otuname=$(basename $intable .biom)

## Find log file

	log=`ls log_cdiv_graphs_and_stats_workflow*.txt | head -1`
	res0=$( date +%s.%N )

## Copy normalized table to output directory

	if [[ ! -f $outdir/OTU_tables/normalized_table.biom ]]; then
	mkdir -p $outdir/OTU_tables/
	cp $intable $outdir/OTU_tables/normalized_table.biom
	fi
	if [[ ! -f $outdir/OTU_tables/normalized_table.summary ]]; then
	cp $otudir/$otuname.summary $outdir/OTU_tables/normalized_table.summary
	fi
	table=$outdir/OTU_tables/normalized_table.biom

## Detect analysis mode

	if [[ -z $tree ]]; then
	analysis=Nonphylogenetic
	metrics=bray_curtis,chord,hellinger,kulczynski
	else
	analysis=Phylogenetic
	metrics=bray_curtis,chord,hellinger,kulczynski,unweighted_unifrac,weighted_unifrac
	fi

	if [[ ! -d $outdir/bdiv_normalized ]]; then
	mkdir $outdir/bdiv_normalized

## Sort OTU table

	if [[ ! -f $outdir/OTU_tables/normalized_table_sorted.biom ]]; then
	echo "
Sort OTU table command:
	sort_otu_table.py -i $table -o $outdir/OTU_tables/normalized_table_sorted.biom" >> $log
	sort_otu_table.py -i $table -o $outdir/OTU_tables/normalized_table_sorted.biom
	fi
	sortedtable=($outdir/OTU_tables/normalized_table_sorted.biom)

## Summarize taxa (yields relative abundance tables)

	if [[ ! -d $outdir/bdiv_normalized/summarized_tables ]]; then
	echo "
Summarize taxa command:
	summarize_taxa.py -i $sortedtable -o $outdir/bdiv_normalized/summarized_tables -L 2,3,4,5,6,7" >> $log
	echo "Summarizing taxonomy by sample and building plots.
	"
	summarize_taxa.py -i $sortedtable -o $outdir/bdiv_normalized/summarized_tables -L 2,3,4,5,6,7
	fi

## Beta diversity

	if [[ "$analysis" == Phylogenetic ]]; then
	echo "
Parallel beta diversity command:
	parallel_beta_diversity.py -i $table -o $outdir/bdiv_normalized/ --metrics $metrics -T  -t $tree --jobs_to_start $cores" >> $log
	echo "Calculating beta diversity distance matrices.
	"
	parallel_beta_diversity.py -i $table -o $outdir/bdiv_normalized/ --metrics $metrics -T  -t $tree --jobs_to_start $cores
	elif [[ "$analysis" == Nonphylogenetic ]]; then
	echo "
Parallel beta diversity command:
	parallel_beta_diversity.py -i $table -o $outdir/bdiv_normalized/ --metrics $metrics -T --jobs_to_start $cores" >> $log
	echo "Calculating beta diversity distance matrices.
	"
	parallel_beta_diversity.py -i $table -o $outdir/bdiv_normalized/ --metrics $metrics -T --jobs_to_start $cores
	fi

## Rename output files

	for dm in $outdir/bdiv_normalized/*_table.txt; do
	dmbase=$( basename $dm _table.txt )
	mv $dm $outdir/bdiv_normalized/$dmbase\_dm.txt
	done

## Principal coordinates and NMDS commands

	echo "
Principal coordinates and NMDS commands:" >> $log
	echo "Constructing PCoA and NMDS coordinate files.
	"
	for dm in $outdir/bdiv_normalized/*_dm.txt; do
	dmbase=$( basename $dm _dm.txt )
	echo "	principal_coordinates.py -i $dm -o $outdir/bdiv_normalized/$dmbase\_pc.txt
	nmds.py -i $dm -o $outdir/bdiv_normalized/$dmbase\_nmds.txt" >> $log
	principal_coordinates.py -i $dm -o $outdir/bdiv_normalized/$dmbase\_pc.txt >/dev/null 2>&1 || true
	nmds.py -i $dm -o $outdir/bdiv_normalized/$dmbase\_nmds.txt >/dev/null 2>&1 || true
	done

## Make 3D emperor plots

	echo "
Make emperor commands:" >> $log
	echo "Generating 3D PCoA plots.
	"
	for pc in $outdir/bdiv_normalized/*_pc.txt; do
	pcbase=$( basename $pc _pc.txt )
	echo "	make_emperor.py -i $pc -o $outdir/bdiv_normalized/$pcbase\_emperor_pcoa_plot/ -m $mapfile --add_unique_columns --ignore_missing_samples" >> $log
	make_emperor.py -i $pc -o $outdir/bdiv_normalized/$pcbase\_emperor_pcoa_plot/ -m $mapfile --add_unique_columns --ignore_missing_samples >/dev/null 2>&1 || true
	done
	fi

## Make 2D plots

	if [[ ! -d $outdir/bdiv_normalized/2D_bdiv_plots ]]; then
	echo "
Make 2D plots commands:" >> $log
	echo "Generating 2D PCoA plots.
	"
	for pc in $outdir/bdiv_normalized/*_pc.txt; do
	while [ $( pgrep -P $$ |wc -w ) -ge ${threads} ]; do 
	sleep 1
	done
	echo "	make_2d_plots.py -i $pc -m $mapfile -o $outdir/bdiv_normalized/2D_bdiv_plots" >> $log
	( make_2d_plots.py -i $pc -m $mapfile -o $outdir/bdiv_normalized/2D_bdiv_plots >/dev/null 2>&1 || true ) &
	done

	fi
wait

## Anosim and permanova stats

	if [[ ! -f $outdir/bdiv_normalized/permanova_results_collated.txt ]] || [[ ! -f $outdir/bdiv_normalized/anosim_results_collated.txt ]]; then
echo > $outdir/bdiv_normalized/permanova_results_collated.txt
echo > $outdir/bdiv_normalized/anosim_results_collated.txt
echo "
Compare categories commands:" >> $log
	echo "Calculating one-way ANOSIM and PERMANOVA statsitics from distance
matrices.
	"
	for line in `cat cdiv_temp/categories.tempfile`; do
		for dm in $outdir/bdiv_normalized/*_dm.txt; do
		method=$( basename $dm _dm.txt )
		echo "	compare_categories.py --method permanova -i $dm -m $mapfile -c $line -o $outdir/bdiv_normalized/permanova_temp/$line/$method/" >> $log
		compare_categories.py --method permanova -i $dm -m $mapfile -c $line -o $outdir/bdiv_normalized/permanova_temp/$line/$method/
		echo "Category: $line" >> $outdir/bdiv_normalized/permanova_results_collated.txt
		echo "Method: $method" >> $outdir/bdiv_normalized/permanova_results_collated.txt
		cat $outdir/bdiv_normalized/permanova_temp/$line/$method/permanova_results.txt >> $outdir/bdiv_normalized/permanova_results_collated.txt
		echo "" >> $outdir/bdiv_normalized/permanova_results_collated.txt

		echo "	compare_categories.py --method anosim -i $dm -m $mapfile -c $line -o $outdir/bdiv_normalized/anosim_temp/$line/$method/" >> $log
		compare_categories.py --method anosim -i $dm -m $mapfile -c $line -o $outdir/bdiv_normalized/anosim_temp/$line/$method/
		echo "Category: $line" >> $outdir/bdiv_normalized/anosim_results_collated.txt
		echo "Method: $method" >> $outdir/bdiv_normalized/anosim_results_collated.txt
		cat $outdir/bdiv_normalized/anosim_temp/$line/$method/anosim_results.txt >> $outdir/bdiv_normalized/anosim_results_collated.txt
		echo "" >> $outdir/bdiv_normalized/anosim_results_collated.txt
		done
done

	fi

## Distance boxplots for each category

	boxplotscount=`ls $outdir/bdiv_normalized/*_boxplots 2>/dev/null | wc -l`
	if [[ $boxplotscount == 0 ]]; then
	echo "
Make distance boxplots commands:" >> $log
	echo "Generating distance boxplots.
	"
	for line in `cat cdiv_temp/categories.tempfile`; do
	while [ $( pgrep -P $$ |wc -w ) -ge ${threads} ]; do 
	sleep 1
	done
		for dm in $outdir/bdiv_normalized/*dm.txt; do
		dmbase=$( basename $dm _dm.txt )

		echo "	make_distance_boxplots.py -d $outdir/bdiv_normalized/$dmbase\_dm.txt -f $line -o $outdir/bdiv_normalized/$dmbase\_boxplots/ -m $mapfile -n 999" >> $log
		( make_distance_boxplots.py -d $outdir/bdiv_normalized/$dmbase\_dm.txt -f $line -o $outdir/bdiv_normalized/$dmbase\_boxplots/ -m $mapfile -n 999 >/dev/null 2>&1 || true ) &
		done
	done
	fi
wait

## Make biplots

	if [[ ! -d $outdir/bdiv_normalized/biplots ]]; then
	echo "
Make biplots commands:" >> $log
	echo "Generating PCoA biplots.
	"
	mkdir $outdir/bdiv_normalized/biplots
	for pc in $outdir/bdiv_normalized/*_pc.txt; do
	pcmethod=$( basename $pc _pc.txt )
	mkdir $outdir/bdiv_normalized/biplots/$pcmethod
		for level in $outdir/bdiv_normalized/summarized_tables/normalized_table_sorted_*.txt; do
		L=$( basename $level .txt )
		echo "	make_emperor.py -i $pc -m $mapfile -o $outdir/bdiv_normalized/biplots/$pcmethod/$L -t $level --add_unique_columns --ignore_missing_samples" >> $log
		make_emperor.py -i $pc -m $mapfile -o $outdir/bdiv_normalized/biplots/$pcmethod/$L -t $level --add_unique_columns --ignore_missing_samples >/dev/null 2>&1 || true
		done
	done
	fi

## Run supervised learning on data using supplied categories

	if [[ ! -d $outdir/bdiv_normalized/SupervisedLearning ]]; then
	mkdir $outdir/bdiv_normalized/SupervisedLearning
	echo "Running supervised learning analysis.
	"

	for category in `cat cdiv_temp/categories.tempfile`; do
	supervised_learning.py -i $table -m $mapfile -c $category -o $outdir/bdiv_normalized/SupervisedLearning/$category --ntree 1000
	done
	fi

## Cleanup
	if [[ -d $outdir/bdiv_normalized/permanova_temp ]]; then
	rm -r $outdir/bdiv_normalized/permanova_temp
	fi
	if [[ -d $outdir/bdiv_normalized/anosim_temp ]]; then
	rm -r $outdir/bdiv_normalized/anosim_temp
	fi
	if [[ -f log.txt ]]; then
	rm log.txt
	fi

## Log workflow end

	res1=$( date +%s.%N )
	dt=$( echo $res1 - $res0 | bc )
	dd=$( echo $dt/86400 | bc )
	dt2=$( echo $dt-86400*$dd | bc )
	dh=$( echo $dt2/3600 | bc )
	dt3=$( echo $dt2-3600*$dh | bc )
	dm=$( echo $dt3/60 | bc )
	ds=$( echo $dt3-60*$dm | bc )

	runtime=`printf "Function runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`

echo "Normalized beta diversity analysis completed!
$runtime
"
echo "
Normalized beta diversity analysis completed!
$runtime
" >> $log

exit 0
