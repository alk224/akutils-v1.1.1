#!/usr/bin/env bash
#
#  cdiv_for_nonnormalized_tables.sh - Core diversity analysis through QIIME for rarefied OTU table analysis
#
#  Version 0.1.0 (May 29, 2015)
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
	less $scriptdir/docs/cdiv_for_nonnormalized_tables.help
		exit 0
	fi 

## If less than five or more than 6 arguments supplied, display usage 

	if [[ "$#" -le 5 ]] || [[ "$#" -ge 8 ]]; then 
		echo "
Usage (order is important!!):
cdiv_for_nonnormalized_tables.sh <otu_table> <output_dir> <mapping_file> <comma_separated_categories> <rarefaction_depth> <processors_to_use> <tree_file>

	<tree_file> is optional.  Analysis will be nonphylogenetic if no
	tree file is supplied.

		"
		exit 1
	fi

## Define variables

intable=($1)
out=($2)
mapfile=($3)
cats=($4)
depth=($5)
cores=($6)
threads=`expr $6 + 1`
tree=($7)
otuname=$(basename $intable .biom)
outdir=$out/$otuname/
date0=`date +%Y%m%d_%I%M%p`
log=$outdir/log_$date0.txt

## Make output directory and get full working path

	if [[ ! -d $outdir ]]; then
	mkdir -p $outdir
	fi

## Set workflow mode (phylogenetic or nonphylogenetic) and log start

	if [[ -z $tree ]]; then
	mode=nonphylogenetic
	metrics=bray_curtis,binary_chord,chord,hellinger,kulczynski
	else
	mode=phylogenetic
	metrics=bray_curtis,binary_chord,chord,hellinger,kulczynski,unweighted_unifrac,weighted_unifrac
	fi

	echo "
Core diversity workflow started in $mode mode
	"
		date1=`date "+%a %b %I:%M %p %Z %Y"`
	res0=$(date +%s.%N)

echo "Core diversity workflow started in $mode mode" > $log
echo $date1 >> $log

## Make categories temp file

	IN=$cats
	OIFS=$IFS
	IFS=','
	arr=$IN
	echo > $outdir/categories.tempfile
	for x in $arr; do
		echo $x >> $outdir/categories.tempfile
	done
	IFS=$OIFS
	sed -i '/^\s*$/d' $outdir/categories.tempfile

## Summarize input table and add read counts to mapping file
## Removed the add counts to mapping file.  It was initially suggested, but proved to have no practical utility.
## Also, it was creating problems in some user's output.

	if [[ ! -f $outdir/table.biom ]]; then
	cp $intable $outdir/table.biom
	fi

	table=$outdir/table.biom

	if [[ ! -f $outdir/biom_table_summary.txt ]]; then
	echo "
Summarize table command:
	biom summarize-table -i $table -o $outdir/biom_table_summary.txt" >> $log

	biom summarize-table -i $table -o $outdir/biom_table_summary.txt

	fi

	mapbase=$( basename $mapfile .txt )
	
#	if [[ ! -f $outdir/$mapbase.withcounts.txt ]]; then
#		add_counts_to_mapping_file.sh $mapfile $outdir/biom_table_summary.txt
#		mv $mapbase.withcounts.txt $outdir
#	fi

## Single rarefaction

	if [[ ! -f $outdir/table_even$depth.biom ]]; then
	echo "
Single rarefaction command:
	single_rarefaction.py -i $table -o $outdir/table_even$depth.biom -d $depth" >> $log

	echo "Rarefying input table at $depth reads/sample.
	"

	single_rarefaction.py -i $table -o $outdir/table_even$depth.biom -d $depth
	fi

	table=$outdir/table_even$depth.biom

	if [[ ! -f $outdir/biom_table_even$depth\_summary.txt ]]; then
	echo "
Summarize table command:
	biom summarize-table -i $table -o $outdir/biom_table_even${depth}_summary.txt" >> $log

	biom summarize-table -i $table -o $outdir/biom_table_even$depth\_summary.txt

	fi


## Beta diversity

	if [[ ! -d $outdir/bdiv ]]; then

	if [[ "$mode" == phylogenetic ]]; then
	echo "
Parallel beta diversity command:
	parallel_beta_diversity.py -i $outdir/table_even$depth.biom -o $outdir/bdiv/ --metrics $metrics -T  -t $tree --jobs_to_start $cores" >> $log

	echo "Calculating beta diversity distance matrices.
	"

	parallel_beta_diversity.py -i $outdir/table_even$depth.biom -o $outdir/bdiv/ --metrics $metrics -T  -t $tree --jobs_to_start $cores

	elif [[ "$mode" == nonphylogenetic ]]; then
	echo "
Parallel beta diversity command:
	parallel_beta_diversity.py -i $outdir/table_even$depth.biom -o $outdir/bdiv/ --metrics $metrics -T --jobs_to_start $cores" >> $log

	echo "Calculating beta diversity distance matrices.
	"

	parallel_beta_diversity.py -i $outdir/table_even$depth.biom -o $outdir/bdiv/ --metrics $metrics -T --jobs_to_start $cores

	fi

## Rename output files

	for dm in $outdir/bdiv/*_table_even$depth.txt; do
	dmbase=$( basename $dm _table_even$depth.txt )
	mv $dm $outdir/bdiv/$dmbase\_dm.txt
	done

## Principal coordinates and NMDS commands
	echo "
Principal coordinates and NMDS commands:" >> $log

	echo "Constructing PCoA and NMDS coordinate files.
	"

	for dm in $outdir/bdiv/*_dm.txt; do
	dmbase=$( basename $dm _dm.txt )
	echo "	principal_coordinates.py -i $dm -o $outdir/bdiv/$dmbase\_pc.txt
	nmds.py -i $dm -o $outdir/bdiv/$dmbase\_nmds.txt" >> $log
	principal_coordinates.py -i $dm -o $outdir/bdiv/$dmbase\_pc.txt >/dev/null 2>&1 || true
	nmds.py -i $dm -o $outdir/bdiv/$dmbase\_nmds.txt >/dev/null 2>&1 || true
	done

## Make emperor
	echo "
Make emperor commands:" >> $log

	echo "Generating 3D PCoA plots.
	"

	for pc in $outdir/bdiv/*_pc.txt; do
	pcbase=$( basename $pc _pc.txt )
	echo "	make_emperor.py -i $pc -o $outdir/bdiv/$pcbase\_emperor_pcoa_plot/ -m $mapfile --add_unique_columns --ignore_missing_samples" >> $log
	make_emperor.py -i $pc -o $outdir/bdiv/$pcbase\_emperor_pcoa_plot/ -m $mapfile --add_unique_columns --ignore_missing_samples >/dev/null 2>&1 || true
	done

	fi

## Anosim and permanova stats

	if [[ ! -f $outdir/permanova_results_collated.txt ]] || [[ ! -f $outdir/anosim_results_collated.txt ]]; then

echo > $outdir/permanova_results_collated.txt
echo > $outdir/anosim_results_collated.txt
echo "
Compare categories commands:" >> $log

	echo "Calculating one-way ANOSIM and PERMANOVA statsitics from distance
matrices.
	"

	for line in `cat $outdir/categories.tempfile`; do
		for dm in $outdir/bdiv/*_dm.txt; do
		method=$( basename $dm _dm.txt )
		echo "	compare_categories.py --method permanova -i $dm -m $mapfile -c $line -o $outdir/permanova_temp/$line/$method/" >> $log
		compare_categories.py --method permanova -i $dm -m $mapfile -c $line -o $outdir/permanova_temp/$line/$method/
		echo "Category: $line" >> $outdir/permanova_results_collated.txt
		echo "Method: $method" >> $outdir/permanova_results_collated.txt
		cat $outdir/permanova_temp/$line/$method/permanova_results.txt >> $outdir/permanova_results_collated.txt
		echo "" >> $outdir/permanova_results_collated.txt

		echo "	compare_categories.py --method anosim -i $dm -m $mapfile -c $line -o $outdir/anosim_temp/$line/$method/" >> $log
		compare_categories.py --method anosim -i $dm -m $mapfile -c $line -o $outdir/anosim_temp/$line/$method/
		echo "Category: $line" >> $outdir/anosim_results_collated.txt
		echo "Method: $method" >> $outdir/anosim_results_collated.txt
		cat $outdir/anosim_temp/$line/$method/anosim_results.txt >> $outdir/anosim_results_collated.txt
		echo "" >> $outdir/anosim_results_collated.txt
		done
done

	fi

## Multiple rarefactions

	alphastepsize=$(($depth/10))

        if [[ "$mode" == phylogenetic ]]; then
	alphametrics=PD_whole_tree,chao1,observed_species,shannon
        elif [[ "$mode" == nonphylogenetic ]]; then
	alphametrics=chao1,observed_species,shannon
	fi

	if [[ ! -d $outdir/arare_max$depth ]]; then

	echo "
Multiple rarefaction command:
	parallel_multiple_rarefactions.py -T -i $table -m 10 -x $depth -s $alphastepsize -o $outdir/arare_max$depth/rarefaction/ -O $cores" >> $log

	echo "Performing mutiple rarefactions for alpha diversity
analysis.
	"

	parallel_multiple_rarefactions.py -T -i $table -m 10 -x $depth -s $alphastepsize -o $outdir/arare_max$depth/rarefaction/ -O $cores

## Alpha diversity
        if [[ "$mode" == phylogenetic ]]; then
	alphametrics=PD_whole_tree,chao1,observed_species,shannon
	echo "
Alpha diversity command:
	parallel_alpha_diversity.py -T -i $outdir/arare_max$depth/rarefaction/ -o $outdir/arare_max$depth/alpha_div/ -t $tree -O $cores -m $alphametrics" >> $log

	echo "Calculating alpha diversity.
	"

	parallel_alpha_diversity.py -T -i $outdir/arare_max$depth/rarefaction/ -o $outdir/arare_max$depth/alpha_div/ -t $tree -O $cores -m $alphametrics

        elif [[ "$mode" == nonphylogenetic ]]; then
	alphametrics=chao1,observed_species,shannon
	echo "
Alpha diversity command:
        parallel_alpha_diversity.py -T -i $outdir/arare_max$depth/rarefaction/ -o $outdir/arare_max$depth/alpha_div/ -O $cores -m $alphametrics" >> $log

	echo "Calculating alpha diversity.
	"

        parallel_alpha_diversity.py -T -i $outdir/arare_max$depth/rarefaction/ -o $outdir/arare_max$depth/alpha_div/ -O $cores -m $alphametrics
	fi

	fi

## Make alpha metrics temp file

	echo > $outdir/arare_max$depth/alpha_metrics.tempfile
	IN=$alphametrics
	OIFS=$IFS
	IFS=','
	arr=$IN
	for x in $arr; do
		echo $x >> $outdir/arare_max$depth/alpha_metrics.tempfile
	done
	IFS=$OIFS
	sed -i '/^\s*$/d' $outdir/arare_max$depth/alpha_metrics.tempfile

## Make 2D plots in background

	if [[ ! -d $outdir/2D_bdiv_plots ]]; then

	echo "
Make 2D plots commands:" >> $log

	echo "Generating 2D PCoA plots.
	"

	for pc in $outdir/bdiv/*_pc.txt; do
	while [ $( pgrep -P $$ |wc -w ) -ge ${threads} ]; do 
	sleep 1
	done
	echo "	make_2d_plots.py -i $pc -m $mapfile -o $outdir/2D_bdiv_plots" >> $log
	( make_2d_plots.py -i $pc -m $mapfile -o $outdir/2D_bdiv_plots >/dev/null 2>&1 || true ) &
	done

	fi
wait

## Collate alpha

	if [[ ! -d $outdir/arare_max$depth/alpha_div_collated/ ]]; then

	echo "
Collate alpha command:
	collate_alpha.py -i $outdir/arare_max$depth/alpha_div/ -o $outdir/arare_max$depth/alpha_div_collated/" >> $log
	collate_alpha.py -i $outdir/arare_max$depth/alpha_div/ -o $outdir/arare_max$depth/alpha_div_collated/

	rm -r $outdir/arare_max$depth/rarefaction/ $outdir/arare_max$depth/alpha_div/

## Make rarefaction plots

	echo "
Make rarefaction plots command:
	make_rarefaction_plots.py -i $outdir/arare_max$depth/alpha_div_collated/ -m $mapfile -o $outdir/arare_max$depth/alpha_rarefaction_plots/" >> $log

	echo "Generating alpha rarefaction plots.
	"

	make_rarefaction_plots.py -i $outdir/arare_max$depth/alpha_div_collated/ -m $mapfile -o $outdir/arare_max$depth/alpha_rarefaction_plots/

## Alpha diversity stats

	echo "
Compare alpha diversity commands:" >> $log

	echo "Calculating alpha diversity statistics.
	"

	for file in $outdir/arare_max$depth/alpha_div_collated/*.txt; do
	filebase=$( basename $file .txt )
	echo "compare_alpha_diversity.py -i $file -m $mapfile -c $cats -o $outdir/arare_max$depth/alpha_compare_parametric -t parametric -p fdr" >> $log
	compare_alpha_diversity.py -i $file -m $mapfile -c $cats -o $outdir/arare_max$depth/compare_$filebase\_parametric -t parametric -p fdr
	echo "compare_alpha_diversity.py -i $file -m $mapfile -c $cats -o $outdir/arare_max$depth/alpha_compare_nonparametric -t nonparametric -p fdr" >> $log
	compare_alpha_diversity.py -i $file -m $mapfile -c $cats -o $outdir/arare_max$depth/compare_$filebase\_nonparametric -t nonparametric -p fdr
	done

	fi

## Sort OTU table

	if [[ ! -d $outdir/taxa_plots ]]; then

	echo "
Sort OTU table command:
	sort_otu_table.py -i $outdir/table_even$depth.biom -o $outdir/taxa_plots/table_sorted.biom" >> $log
	mkdir $outdir/taxa_plots
	sort_otu_table.py -i $outdir/table_even$depth.biom -o $outdir/taxa_plots/table_sorted.biom
	sortedtable=($outdir/taxa_plots/table_sorted.biom)

## Summarize taxa (yields relative abundance tables)

	echo "
Summarize taxa command:
	summarize_taxa.py -i $sortedtable -o $outdir/taxa_plots/ -L 2,3,4,5,6,7" >> $log

	echo "Summarizing taxonomy by sample and building plots.
	"

	summarize_taxa.py -i $sortedtable -o $outdir/taxa_plots/ -L 2,3,4,5,6,7

## Plot taxa summaries

	echo "
Plot taxa summaries command:
	plot_taxa_summary.py -i $outdir/taxa_plots/table_sorted_L2.txt,$outdir/taxa_plots/table_sorted_L3.txt,$outdir/taxa_plots/table_sorted_L4.txt,$outdir/taxa_plots/table_sorted_L5.txt,$outdir/taxa_plots/table_sorted_L6.txt,$outdir/taxa_plots/table_sorted_L7.txt -o $outdir/taxa_plots/taxa_summary_plots/ -c bar" >> $log
	plot_taxa_summary.py -i $outdir/taxa_plots/table_sorted_L2.txt,$outdir/taxa_plots/table_sorted_L3.txt,$outdir/taxa_plots/table_sorted_L4.txt,$outdir/taxa_plots/table_sorted_L5.txt,$outdir/taxa_plots/table_sorted_L6.txt,$outdir/taxa_plots/table_sorted_L7.txt -o $outdir/taxa_plots/taxa_summary_plots/ -c bar

	fi

## Taxa summaries for each category

	for line in `cat $outdir/categories.tempfile`; do
	if [[ ! -d $outdir/taxa_plots_$line ]]; then

	echo "Building taxonomy plots for category: $line.
	"

	echo "
Summarize taxa commands by category $line:
	collapse_samples.py -m $mapfile -b $outdir/table_even$depth.biom --output_biom_fp $outdir/taxa_plots_$line/$line\_otu_table.biom --output_mapping_fp $outdir/taxa_plots_$line/$line_map.txt --collapse_fields $line
	sort_otu_table.py -i $outdir/taxa_plots_$line/$line\_otu_table.biom -o $outdir/taxa_plots_$line/$line\_otu_table_sorted.biom
	summarize_taxa.py -i $outdir/taxa_plots_$line/$line\_otu_table_sorted.biom -o $outdir/taxa_plots_$line/ -a
	plot_taxa_summary.py -i $outdir/taxa_plots_$line/$line\_otu_table_sorted_L2.txt,$outdir/taxa_plots_$line/$line\_otu_table_sorted_L3.txt,$outdir/taxa_plots_$line/$line\_otu_table_sorted_L4.txt,$outdir/taxa_plots_$line/$line\_otu_table_sorted_L5.txt,$outdir/taxa_plots_$line/$line\_otu_table_sorted_L6.txt,$outdir/taxa_plots_$line/$line\_otu_table_sorted_L7.txt -o $outdir/taxa_plots_$line/taxa_summary_plots/ -c bar,pie" >> $log

	mkdir $outdir/taxa_plots_$line

	collapse_samples.py -m $mapfile -b $outdir/table_even$depth.biom --output_biom_fp $outdir/taxa_plots_$line/$line\_otu_table.biom --output_mapping_fp $outdir/taxa_plots_$line/$line_map.txt --collapse_fields $line
	
	sort_otu_table.py -i $outdir/taxa_plots_$line/$line\_otu_table.biom -o $outdir/taxa_plots_$line/$line\_otu_table_sorted.biom

	summarize_taxa.py -i $outdir/taxa_plots_$line/$line\_otu_table_sorted.biom -o $outdir/taxa_plots_$line/ -L 2,3,4,5,6,7 -a

	plot_taxa_summary.py -i $outdir/taxa_plots_$line/$line\_otu_table_sorted_L2.txt,$outdir/taxa_plots_$line/$line\_otu_table_sorted_L3.txt,$outdir/taxa_plots_$line/$line\_otu_table_sorted_L4.txt,$outdir/taxa_plots_$line/$line\_otu_table_sorted_L5.txt,$outdir/taxa_plots_$line/$line\_otu_table_sorted_L6.txt,$outdir/taxa_plots_$line/$line\_otu_table_sorted_L7.txt -o $outdir/taxa_plots_$line/taxa_summary_plots/ -c bar,pie
	fi
	done

## Make OTU heatmaps
## Time consuming and of questionable utility most of the time

	if [[ ! -d $outdir/heatmaps ]]; then

	echo "Building heatmaps.
	"

	mkdir $outdir/heatmaps

	make_otu_heatmap.py -i $outdir/table_even$depth.biom -o $outdir/heatmaps/otu_heatmap_unsorted.pdf --absolute_abundance --color_scheme YlOrRd

	for line in `cat $outdir/categories.tempfile`; do
	while [ $( pgrep -P $$ |wc -w ) -ge ${threads} ]; do 
	sleep 1
	done
	make_otu_heatmap.py -i $outdir/table_even$depth.biom -o $outdir/heatmaps/otu_heatmap_$line.pdf --absolute_abundance --color_scheme YlOrRd -c $line -m $mapfile
	done

	fi

## Distance boxplots for each category

	boxplotscount=$( ls $outdir/bdiv/*_boxplots 2>/dev/null | wc -l )

	if [[ $boxplotscount = 0 ]]; then

	echo "
Make distance boxplots commands:" >> $log

	echo "Generating distance boxplots.
	"

	for line in `cat $outdir/categories.tempfile`; do
	while [ $( pgrep -P $$ |wc -w ) -ge ${threads} ]; do 
	sleep 1
	done
		for dm in $outdir/bdiv/*dm.txt; do
		dmbase=$( basename $dm _dm.txt )

		echo "	make_distance_boxplots.py -d $outdir/bdiv/$dmbase\_dm.txt -f $line -o $outdir/bdiv/$dmbase\_boxplots/ -m $mapfile -n 999" >> $log
		( make_distance_boxplots.py -d $outdir/bdiv/$dmbase\_dm.txt -f $line -o $outdir/bdiv/$dmbase\_boxplots/ -m $mapfile -n 999 >/dev/null 2>&1 || true ) &
		done

	done

	wait
	fi

## Group significance for each category (Kruskal-Wallis and nonparametric ttest)

	kwtestcount=$(ls $outdir/KruskalWallis/kruskalwallis_* 2> /dev/null | wc -l)

	if [[ $kwtestcount == 0 ]]; then

	echo "
Group significance commands:" >> $log
	if [[ ! -d $outdir/KruskalWallis ]]; then
	mkdir $outdir/KruskalWallis
	fi

	if [[ ! -f $outdir/table_even$depth\_relativized.biom ]]; then
	echo "
Relativizing OTU table:
	relativize_otu_table.py -i $outdir/table_even${depth}.biom" >> $log
	relativize_otu_table.py -i $outdir/table_even$depth.biom >/dev/null 2>&1 || true
	fi

	echo "Calculating Kruskal-Wallis test statistics when possible.
	"

for line in `cat $outdir/categories.tempfile`; do
	if [[ ! -f $outdir/KruskalWallis/kruskalwallis_$line\_OTU.txt ]]; then
	while [ $( pgrep -P $$ |wc -w ) -ge ${threads} ]; do 
	sleep 1
	done
	echo "	group_significance.py -i $outdir/table_even${depth}_relativized.biom -m $mapfile -c $line -o $outdir/KruskalWallis/kruskalwallis_${line}_OTU.txt -s kruskal_wallis" >> $log
	( group_significance.py -i $outdir/table_even${depth}_relativized.biom -m $mapfile -c $line -o $outdir/KruskalWallis/kruskalwallis_$line\_OTU.txt -s kruskal_wallis ) >/dev/null 2>&1 || true &
	fi
done
wait
for line in `cat $outdir/categories.tempfile`; do
	if [[ ! -f $outdir/KruskalWallis/kruskalwallis_$line\_L2.txt ]]; then
	while [ $( pgrep -P $$ |wc -w ) -ge ${threads} ]; do 
	sleep 1
	done
	echo "	group_significance.py -i $outdir/taxa_plots/table_sorted_L2.biom -m $mapfile -c $line -o $outdir/KruskalWallis/kruskalwallis_${line}_L2.txt -s kruskal_wallis" >> $log
	( group_significance.py -i $outdir/taxa_plots/table_sorted_L2.biom -m $mapfile -c $line -o $outdir/KruskalWallis/kruskalwallis_$line\_L2.txt -s kruskal_wallis ) >/dev/null 2>&1 || true &
	fi
done
wait
for line in `cat $outdir/categories.tempfile`; do
	if [[ ! -f $outdir/KruskalWallis/kruskalwallis_$line\_L3.txt ]]; then
	while [ $( pgrep -P $$ |wc -w ) -ge ${threads} ]; do 
	sleep 1
	done
	echo "	group_significance.py -i $outdir/taxa_plots/table_sorted_L3.biom -m $mapfile -c $line -o $outdir/KruskalWallis/kruskalwallis_${line}_L3.txt -s kruskal_wallis" >> $log
	( group_significance.py -i $outdir/taxa_plots/table_sorted_L3.biom -m $mapfile -c $line -o $outdir/KruskalWallis/kruskalwallis_$line\_L3.txt -s kruskal_wallis ) >/dev/null 2>&1 || true &
	fi
done
wait
for line in `cat $outdir/categories.tempfile`; do
	if [[ ! -f $outdir/KruskalWallis/kruskalwallis_$line\_L4.txt ]]; then
	while [ $( pgrep -P $$ |wc -w ) -ge ${threads} ]; do 
	sleep 1
	done
	echo "	group_significance.py -i $outdir/taxa_plots/table_sorted_L4.biom -m $mapfile -c $line -o $outdir/KruskalWallis/kruskalwallis_${line}_L4.txt -s kruskal_wallis" >> $log
	( group_significance.py -i $outdir/taxa_plots/table_sorted_L4.biom -m $mapfile -c $line -o $outdir/KruskalWallis/kruskalwallis_$line\_L4.txt -s kruskal_wallis ) >/dev/null 2>&1 || true &
	fi
done
wait
for line in `cat $outdir/categories.tempfile`; do
	if [[ ! -f $outdir/KruskalWallis/kruskalwallis_$line\_L5.txt ]]; then
	while [ $( pgrep -P $$ |wc -w ) -ge ${threads} ]; do 
	sleep 1
	done
	echo "	group_significance.py -i $outdir/taxa_plots/table_sorted_L5.biom -m $mapfile -c $line -o $outdir/KruskalWallis/kruskalwallis_${line}_L5.txt -s kruskal_wallis" >> $log
	( group_significance.py -i $outdir/taxa_plots/table_sorted_L5.biom -m $mapfile -c $line -o $outdir/KruskalWallis/kruskalwallis_$line\_L5.txt -s kruskal_wallis ) >/dev/null 2>&1 || true &
	fi
done
wait
for line in `cat $outdir/categories.tempfile`; do
	if [[ ! -f $outdir/KruskalWallis/kruskalwallis_$line\_L6.txt ]]; then
	while [ $( pgrep -P $$ |wc -w ) -ge ${threads} ]; do 
	sleep 1
	done
	echo "	group_significance.py -i $outdir/taxa_plots/table_sorted_L6.biom -m $mapfile -c $line -o $outdir/KruskalWallis/kruskalwallis_${line}_L6.txt -s kruskal_wallis" >> $log
	( group_significance.py -i $outdir/taxa_plots/table_sorted_L6.biom -m $mapfile -c $line -o $outdir/KruskalWallis/kruskalwallis_$line\_L6.txt -s kruskal_wallis ) >/dev/null 2>&1 || true &
	fi
done
wait
for line in `cat $outdir/categories.tempfile`; do
	if [[ ! -f $outdir/KruskalWallis/kruskalwallis_$line\_L7.txt ]]; then
	while [ $( pgrep -P $$ |wc -w ) -ge ${threads} ]; do 
	sleep 1
	done
	echo "	group_significance.py -i $outdir/taxa_plots/table_sorted_L7.biom -m $mapfile -c $line -o $outdir/KruskalWallis/kruskalwallis_${line}_L7.txt -s kruskal_wallis" >> $log
	( group_significance.py -i $outdir/taxa_plots/table_sorted_L7.biom -m $mapfile -c $line -o $outdir/KruskalWallis/kruskalwallis_$line\_L7.txt -s kruskal_wallis ) >/dev/null 2>&1 || true &
	fi
done
fi
wait

#	ttestcount=$(ls $outdir/Nonparametric_ttest/nonparametric_ttest_* 2> /dev/null | wc -l)

#	if [[ $ttestcount == 0 ]]; then

	if [[ ! -d $outdir/Nonparametric_ttest ]]; then
	mkdir $outdir/Nonparametric_ttest
#	fi

	if [[ ! -f $outdir/table_even$depth\_relativized.biom ]]; then
	echo "
Relativizing OTU table:
	relativize_otu_table.py -i $outdir/table_even${depth}.biom" >> $log
	relativize_otu_table.py -i $outdir/table_even$depth.biom >/dev/null 2>&1 || true
	fi

	echo "Calculating nonparametric T-test statistics when possible.
	"

for line in `cat $outdir/categories.tempfile`; do
	if [[ ! -f $outdir/Nonparametric_ttest/nonparametric_ttest_$line\_OTU.txt ]]; then
	while [ $( pgrep -P $$ |wc -w ) -ge ${threads} ]; do 
	sleep 1
	done
	echo "	group_significance.py -i $outdir/table_even${depth}_relativized.biom -m $mapfile -c $line -o $outdir/Nonparametric_ttest/nonparametric_ttest_${line}_OTU.txt -s nonparametric_t_test" >> $log
	( group_significance.py -i $outdir/table_even${depth}_relativized.biom -m $mapfile -c $line -o $outdir/Nonparametric_ttest/nonparametric_ttest_$line\_OTU.txt -s nonparametric_t_test ) >/dev/null 2>&1 || true &
	fi
done
wait
for line in `cat $outdir/categories.tempfile`; do
	if [[ ! -f $outdir/Nonparametric_ttest/nonparametric_ttest_$line\_L2.txt ]]; then
	while [ $( pgrep -P $$ |wc -w ) -ge ${threads} ]; do 
	sleep 1
	done
	echo "	group_significance.py -i $outdir/taxa_plots/table_sorted_L2.biom -m $mapfile -c $line -o $outdir/Nonparametric_ttest/nonparametric_ttest_${line}_L2.txt -s nonparametric_t_test" >> $log
	( group_significance.py -i $outdir/taxa_plots/table_sorted_L2.biom -m $mapfile -c $line -o $outdir/Nonparametric_ttest/nonparametric_ttest_$line\_L2.txt -s nonparametric_t_test ) >/dev/null 2>&1 || true &
	fi
done
wait
for line in `cat $outdir/categories.tempfile`; do
	if [[ ! -f $outdir/Nonparametric_ttest/nonparametric_ttest_$line\_L3.txt ]]; then
	while [ $( pgrep -P $$ |wc -w ) -ge ${threads} ]; do 
	sleep 1
	done
	echo "	group_significance.py -i $outdir/taxa_plots/table_sorted_L3.biom -m $mapfile -c $line -o $outdir/Nonparametric_ttest/nonparametric_ttest_${line}_L3.txt -s nonparametric_t_test" >> $log
	( group_significance.py -i $outdir/taxa_plots/table_sorted_L3.biom -m $mapfile -c $line -o $outdir/Nonparametric_ttest/nonparametric_ttest_$line\_L3.txt -s nonparametric_t_test ) >/dev/null 2>&1 || true &
	fi
done
wait
for line in `cat $outdir/categories.tempfile`; do
	if [[ ! -f $outdir/Nonparametric_ttest/nonparametric_ttest_$line\_L4.txt ]]; then
	while [ $( pgrep -P $$ |wc -w ) -ge ${threads} ]; do 
	sleep 1
	done
	echo "	group_significance.py -i $outdir/taxa_plots/table_sorted_L4.biom -m $mapfile -c $line -o $outdir/Nonparametric_ttest/nonparametric_ttest_${line}_L4.txt -s nonparametric_t_test" >> $log
	( group_significance.py -i $outdir/taxa_plots/table_sorted_L4.biom -m $mapfile -c $line -o $outdir/Nonparametric_ttest/nonparametric_ttest_$line\_L4.txt -s nonparametric_t_test ) >/dev/null 2>&1 || true &
	fi
done
wait
for line in `cat $outdir/categories.tempfile`; do
	if [[ ! -f $outdir/Nonparametric_ttest/nonparametric_ttest_$line\_L5.txt ]]; then
	while [ $( pgrep -P $$ |wc -w ) -ge ${threads} ]; do 
	sleep 1
	done
	echo "	group_significance.py -i $outdir/taxa_plots/table_sorted_L5.biom -m $mapfile -c $line -o $outdir/Nonparametric_ttest/nonparametric_ttest_${line}_L5.txt -s nonparametric_t_test" >> $log
	( group_significance.py -i $outdir/taxa_plots/table_sorted_L5.biom -m $mapfile -c $line -o $outdir/Nonparametric_ttest/nonparametric_ttest_$line\_L5.txt -s nonparametric_t_test ) >/dev/null 2>&1 || true &
	fi
done
wait
for line in `cat $outdir/categories.tempfile`; do
	if [[ ! -f $outdir/Nonparametric_ttest/nonparametric_ttest_$line\_L6.txt ]]; then
	while [ $( pgrep -P $$ |wc -w ) -ge ${threads} ]; do 
	sleep 1
	done
	echo "	group_significance.py -i $outdir/taxa_plots/table_sorted_L6.biom -m $mapfile -c $line -o $outdir/Nonparametric_ttest/nonparametric_ttest_${line}_L6.txt -s nonparametric_t_test" >> $log
	( group_significance.py -i $outdir/taxa_plots/table_sorted_L6.biom -m $mapfile -c $line -o $outdir/Nonparametric_ttest/nonparametric_ttest_$line\_L6.txt -s nonparametric_t_test ) >/dev/null 2>&1 || true &
	fi
done
wait
for line in `cat $outdir/categories.tempfile`; do
	if [[ ! -f $outdir/Nonparametric_ttest/nonparametric_ttest_$line\_L7.txt ]]; then
	while [ $( pgrep -P $$ |wc -w ) -ge ${threads} ]; do 
	sleep 1
	done
	echo "	group_significance.py -i $outdir/taxa_plots/table_sorted_L7.biom -m $mapfile -c $line -o $outdir/Nonparametric_ttest/nonparametric_ttest_${line}_L7.txt -s nonparametric_t_test" >> $log
	( group_significance.py -i $outdir/taxa_plots/table_sorted_L7.biom -m $mapfile -c $line -o $outdir/Nonparametric_ttest/nonparametric_ttest_$line\_L7.txt -s nonparametric_t_test ) >/dev/null 2>&1 || true &
	fi
done
fi
wait

## Make biplots

	if [[ ! -d $outdir/biplots ]]; then
	echo "
Make biplots commands:" >> $log

	echo "Generating PCoA biplots.
	"

	mkdir $outdir/biplots
	for pc in $outdir/bdiv/*_pc.txt; do
	pcmethod=$( basename $pc _pc.txt )
	mkdir $outdir/biplots/$pcmethod

		for level in $outdir/taxa_plots/table_sorted_*.txt; do
		L=$( basename $level .txt )
		echo "	make_emperor.py -i $pc -m $mapfile -o $outdir/biplots/$pcmethod/$L -t $level --add_unique_columns --ignore_missing_samples" >> $log
		make_emperor.py -i $pc -m $mapfile -o $outdir/biplots/$pcmethod/$L -t $level --add_unique_columns --ignore_missing_samples >/dev/null 2>&1 || true
		done
	done

	fi

## Run supervised learning on data using supplied categories

	if [[ ! -d $outdir/SupervisedLearning ]]; then
	mkdir $outdir/SupervisedLearning

	echo "Running supervised learning analysis.
	"

	for category in `cat $outdir/categories.tempfile`; do
	supervised_learning.py -i $outdir/table_even$depth.biom -m $mapfile -c $category -o $outdir/SupervisedLearning/$category --ntree 1000
	done
	fi

## Make rank abundance plots

	if [[ ! -d $outdir/RankAbundance ]]; then
	mkdir $outdir/RankAbundance

	echo "Generating rank abundance plots.
	"

	( plot_rank_abundance_graph.py -i $outdir/table_even$depth.biom -o $outdir/RankAbundance/rankabund_xlog-ylog.pdf -s "*" -n ) &
	( plot_rank_abundance_graph.py -i $outdir/table_even$depth.biom -o $outdir/RankAbundance/rankabund_xlinear-ylog.pdf -s "*" -n -x ) &
	( plot_rank_abundance_graph.py -i $outdir/table_even$depth.biom -o $outdir/RankAbundance/rankabund_xlog-ylinear.pdf -s "*" -n -y ) &
	( plot_rank_abundance_graph.py -i $outdir/table_even$depth.biom -o $outdir/RankAbundance/rankabund_xlinear-ylinear.pdf -s "*" -n -x -y ) &
	fi

wait

## Run match_reads_to_taxonomy if rep set present
## Automatically find merged_rep_set.fna file from existing akutils workflows

if [[ ! -d $outdir/Representative_sequences ]]; then

	intable_path=`readlink -f $intable`
	intable_dir=`dirname $intable_path`

	rep_set_count=`ls $outdir | grep "rep_set.fna" | wc -l`
	if [[ $rep_set_count == 0 ]]; then
		merged_rep_set_count=`ls $intable_dir | grep "merged_rep_set.fna" | wc -l`
		if [[ $merged_rep_set_count == 1 ]]; then
		cp $intable_dir/merged_rep_set.fna $outdir
		fi
	fi

	rep_set_count=`ls $outdir | grep "rep_set.fna" | wc -l`

	if [[ $rep_set_count == 1 ]]; then

	echo "Extracting sequencing data for each taxon and performing
mafft alignments.
	"

	match_reads_to_taxonomy.sh $outdir/table_even$depth.biom $threads >/dev/null 2>&1 || true

	else
	echo "Skipping match_reads_to_taxonomy.sh step.  Add the rep_set.fna file for
this data to the below directory and rerun this cdiv workflow to
generate this output.  For help, run:
	match_reads_to_taxonomy.sh --help

	$outdir
	"
	fi
fi

## Make html files
	##sequences and alignments
	if [[ -d $outdir/Representative_sequences ]]; then

echo "<html>
<head><title>QIIME results</title></head>
<body>
<p><h2> akutils core diversity workflow for non-normalized OTU tables </h2><p>
<a href=\"https://github.com/alk224/akutils\" target=\_blank\"><h3> https://github.com/alk224/akutils </h3></a><p>
<table border=1>
<p><h3> Sequences by taxonomy </h3><p>
<tr colspan=2 align=center bgcolor=#e8e8e8><td colspan=2 align=center> Unaligned sequences </td></tr>" > $outdir/sequences_by_taxonomy.html

	for taxonid in `cat $outdir/Representative_sequences/L7_taxa_list.txt | cut -f1`; do
	otu_count=`grep -Fw "$taxonid" $outdir/Representative_sequences/L7_taxa_list.txt | cut -f2`

	if [[ -f $outdir/Representative_sequences/L7_sequences_by_taxon/${taxonid}.fasta ]]; then
echo "<tr><td><font size="1"><a href=\"./Representative_sequences/L7_sequences_by_taxon/${taxonid}.fasta\" target=\"_blank\"> ${taxonid} </a></font></td><td> $otu_count OTUs </td></tr>" >> $outdir/sequences_by_taxonomy.html
	fi
	done

echo "<tr colspan=2 align=center bgcolor=#e8e8e8><td colspan=2 align=center> Aligned sequences (mafft) </td></tr>" >> $outdir/sequences_by_taxonomy.html

	for taxonid in `cat $outdir/Representative_sequences/L7_taxa_list.txt | cut -f1`; do
	otu_count=`grep -Fw "$taxonid" $outdir/Representative_sequences/L7_taxa_list.txt | cut -f2`

	if [[ -f $outdir/Representative_sequences/L7_sequences_by_taxon_alignments/${taxonid}/${taxonid}_aligned.aln ]]; then
echo "<tr><td><font size="1"><a href=\"./Representative_sequences/L7_sequences_by_taxon_alignments/${taxonid}/${taxonid}_aligned.aln\" target=\"_blank\"> ${taxonid} </a></font></td><td> $otu_count OTUs </td></tr>" >> $outdir/sequences_by_taxonomy.html
	fi
	done

	fi

	##master html
	if [[ ! -f $outdir/index.html ]]; then

	echo "Building html output file.
$outdir/index.html
	"
	else
	echo "Rebuilding html output file.
$outdir/index.html
	"
	fi

logfile=`basename $log`

echo "<html>
<head><title>QIIME results</title></head>
<body>
<a href=\"http://www.qiime.org\" target=\"_blank\"><img src=\"http://qiime.org/_static/wordpressheader.png\" alt=\"www.qiime.org\"\"/></a><p>
<h2> akutils core diversity workflow for non-normalized OTU tables </h2><p>
<a href=\"https://github.com/alk224/akutils\" target=\_blank\"><h3> https://github.com/alk224/akutils </h3></a><p>
<table border=1>
<tr colspan=2 align=center bgcolor=#e8e8e8><td colspan=2 align=center> Run Summary Data </td></tr>
<tr><td> Master run log </td><td> <a href=\" $logfile \" target=\"_blank\"> $logfile </a></td></tr>
<tr><td> BIOM table statistics </td><td> <a href=\"./biom_table_even${depth}_summary.txt\" target=\"_blank\"> biom_table_even${depth}_summary.txt </a></td></tr>" > $outdir/index.html

	if [[ -f $outdir/Representative_sequences/L7_taxa_list.txt ]] && [[ -f $outdir/Representative_sequences/otus_per_taxon_summary.txt ]]; then
	tablename=$(basename $table .biom)
	Total_OTUs0=`cat $outdir/$tablename.txt | wc -l`
	Total_OTUs=`expr $Total_OTUs0 - 2`
	Total_taxa=`cat $outdir/Representative_sequences/L7_taxa_list.txt | wc -l`
	Mean_OTUs=`grep mean $outdir/Representative_sequences/otus_per_taxon_summary.txt | cut -f2`
	Median_OTUs=`grep median $outdir/Representative_sequences/otus_per_taxon_summary.txt | cut -f2`
	Max_OTUs=`grep max $outdir/Representative_sequences/otus_per_taxon_summary.txt | cut -f2`
	Min_OTUs=`grep min $outdir/Representative_sequences/otus_per_taxon_summary.txt | cut -f2`

echo "
<tr colspan=2 align=center bgcolor=#e8e8e8><td colspan=2 align=center> Sequencing data by L7 taxon </td></tr>
<tr><td> Total OTU count </td><td align=center> $Total_OTUs </td></tr>
<tr><td> Total L7 taxa count </td><td align=center> $Total_taxa </td></tr>
<tr><td> Mean OTUs per L7 taxon </td><td align=center> $Mean_OTUs </td></tr>
<tr><td> Median OTUs per L7 taxon </td><td align=center> $Median_OTUs </td></tr>
<tr><td> Maximum OTUs per L7 taxon </td><td align=center> $Max_OTUs </td></tr>
<tr><td> Minimum OTUs per L7 taxon </td><td align=center> $Min_OTUs </td></tr>
<tr><td> Aligned and unaligned sequences </td><td> <a href=\"./sequences_by_taxonomy.html\" target=\"_blank\"> sequences_by_taxonomy.html </a></td></tr>" >> $outdir/index.html
	fi

echo "
<tr colspan=2 align=center bgcolor=#e8e8e8><td colspan=2 align=center> Taxonomic Summary Results (by sample) </td></tr>
<tr><td> Taxa summary bar plots </td><td> <a href=\"./taxa_plots/taxa_summary_plots/bar_charts.html\" target=\"_blank\"> bar_charts.html </a></td></tr>" >> $outdir/index.html

	for line in `cat $outdir/categories.tempfile`; do
echo "
<tr colspan=2 align=center bgcolor=#e8e8e8><td colspan=2 align=center> Taxonomic summary results (by $line) </td></tr>
<tr><td> Taxa summary bar plots </td><td> <a href=\"./taxa_plots_$line/taxa_summary_plots/bar_charts.html\" target=\"_blank\"> bar_charts.html </a></td></tr>
<tr><td> Taxa summary pie plots </td><td> <a href=\"./taxa_plots_$line/taxa_summary_plots/pie_charts.html\" target=\"_blank\"> pie_charts.html </a></td></tr>" >> $outdir/index.html
	done

echo "
<tr colspan=2 align=center bgcolor=#e8e8e8><td colspan=2 align=center> Group Significance Results (Kruskal-Wallis - nonparametric ANOVA) <br><br> All mean values are percent of total counts by sample (relative OTU abundances) </td></tr>" >> $outdir/index.html

	for line in `cat $outdir/categories.tempfile`; do
	if [[ -f $outdir/KruskalWallis/kruskalwallis_${line}_OTU.txt ]]; then
echo "<tr><td> Kruskal-Wallis results - ${line} - OTU level </td><td> <a href=\"./KruskalWallis/kruskalwallis_${line}_OTU.txt\" target=\"_blank\"> kruskalwallis_${line}_OTU.txt </a></td></tr>" >> $outdir/index.html
	fi
	done

	for line in `cat $outdir/categories.tempfile`; do
	if [[ -f $outdir/KruskalWallis/kruskalwallis_${line}_L7.txt ]]; then
echo "<tr><td> Kruskal-Wallis results - ${line} - species level (L7) </td><td> <a href=\"./KruskalWallis/kruskalwallis_${line}_L7.txt\" target=\"_blank\"> kruskalwallis_${line}_L7.txt </a></td></tr>" >> $outdir/index.html
	fi
	done

	for line in `cat $outdir/categories.tempfile`; do
	if [[ -f $outdir/KruskalWallis/kruskalwallis_${line}_L6.txt ]]; then
echo "<tr><td> Kruskal-Wallis results - ${line} - genus level (L6) </td><td> <a href=\"./KruskalWallis/kruskalwallis_${line}_L6.txt\" target=\"_blank\"> kruskalwallis_${line}_L6.txt </a></td></tr>" >> $outdir/index.html
	fi
	done

	for line in `cat $outdir/categories.tempfile`; do
	if [[ -f $outdir/KruskalWallis/kruskalwallis_${line}_L5.txt ]]; then
echo "<tr><td> Kruskal-Wallis results - ${line} - family level (L5) </td><td> <a href=\"./KruskalWallis/kruskalwallis_${line}_L5.txt\" target=\"_blank\"> kruskalwallis_${line}_L5.txt </a></td></tr>" >> $outdir/index.html
	fi
	done

	for line in `cat $outdir/categories.tempfile`; do
	if [[ -f $outdir/KruskalWallis/kruskalwallis_${line}_L4.txt ]]; then
echo "<tr><td> Kruskal-Wallis results - ${line} - order level (L4) </td><td> <a href=\"./KruskalWallis/kruskalwallis_${line}_L4.txt\" target=\"_blank\"> kruskalwallis_${line}_L4.txt </a></td></tr>" >> $outdir/index.html
	fi
	done

	for line in `cat $outdir/categories.tempfile`; do
	if [[ -f $outdir/KruskalWallis/kruskalwallis_${line}_L3.txt ]]; then
echo "<tr><td> Kruskal-Wallis results - ${line} - class level (L3) </td><td> <a href=\"./KruskalWallis/kruskalwallis_${line}_L3.txt\" target=\"_blank\"> kruskalwallis_${line}_L3.txt </a></td></tr>" >> $outdir/index.html
	fi
	done

	for line in `cat $outdir/categories.tempfile`; do
	if [[ -f $outdir/KruskalWallis/kruskalwallis_${line}_L2.txt ]]; then
echo "<tr><td> Kruskal-Wallis results - ${line} - phylum level (L2) </td><td> <a href=\"./KruskalWallis/kruskalwallis_${line}_L2.txt\" target=\"_blank\"> kruskalwallis_${line}_L2.txt </a></td></tr>" >> $outdir/index.html
	fi
	done

echo "
<tr colspan=2 align=center bgcolor=#e8e8e8><td colspan=2 align=center> Group Significance Results (Nonparametric T-test, 1000 permutations) <br><br> Results only generated when comparing two groups <br><br> All mean values are percent of total counts by sample (relative OTU abundances) </td></tr>" >> $outdir/index.html

	for line in `cat $outdir/categories.tempfile`; do
	if [[ -f $outdir/Nonparametric_ttest/nonparametric_ttest_${line}_OTU.txt ]]; then
echo "<tr><td> Nonparametric T-test results - ${line} - OTU level </td><td> <a href=\"./Nonparametric_ttest/nonparametric_ttest_${line}_OTU.txt\" target=\"_blank\"> nonparametric_ttest_${line}_OTU.txt </a></td></tr>" >> $outdir/index.html
	fi
	done

	for line in `cat $outdir/categories.tempfile`; do
	if [[ -f $outdir/Nonparametric_ttest/nonparametric_ttest_${line}_L7.txt ]]; then
echo "<tr><td> Nonparametric T-test results - ${line} - species level (L7) </td><td> <a href=\"./Nonparametric_ttest/nonparametric_ttest_${line}_L7.txt\" target=\"_blank\"> nonparametric_ttest_${line}_L7.txt </a></td></tr>" >> $outdir/index.html
	fi
	done

	for line in `cat $outdir/categories.tempfile`; do
	if [[ -f $outdir/Nonparametric_ttest/nonparametric_ttest_${line}_L6.txt ]]; then
echo "<tr><td> Nonparametric T-test results - ${line} - genus level (L6) </td><td> <a href=\"./Nonparametric_ttest/nonparametric_ttest_${line}_L6.txt\" target=\"_blank\"> nonparametric_ttest_${line}_L6.txt </a></td></tr>" >> $outdir/index.html
	fi
	done

	for line in `cat $outdir/categories.tempfile`; do
	if [[ -f $outdir/Nonparametric_ttest/nonparametric_ttest_${line}_L5.txt ]]; then
echo "<tr><td> Nonparametric T-test results - ${line} - family level (L5) </td><td> <a href=\"./Nonparametric_ttest/nonparametric_ttest_${line}_L5.txt\" target=\"_blank\"> nonparametric_ttest_${line}_L5.txt </a></td></tr>" >> $outdir/index.html
	fi
	done

	for line in `cat $outdir/categories.tempfile`; do
	if [[ -f $outdir/Nonparametric_ttest/nonparametric_ttest_${line}_L4.txt ]]; then
echo "<tr><td> Nonparametric T-test results - ${line} - order level (L4) </td><td> <a href=\"./Nonparametric_ttest/nonparametric_ttest_${line}_L4.txt\" target=\"_blank\"> nonparametric_ttest_${line}_L4.txt </a></td></tr>" >> $outdir/index.html
	fi
	done

	for line in `cat $outdir/categories.tempfile`; do
	if [[ -f $outdir/Nonparametric_ttest/nonparametric_ttest_${line}_L3.txt ]]; then
echo "<tr><td> Nonparametric T-test results - ${line} - class level (L3) </td><td> <a href=\"./Nonparametric_ttest/nonparametric_ttest_${line}_L3.txt\" target=\"_blank\"> nonparametric_ttest_${line}_L3.txt </a></td></tr>" >> $outdir/index.html
	fi
	done

	for line in `cat $outdir/categories.tempfile`; do
	if [[ -f $outdir/Nonparametric_ttest/nonparametric_ttest_${line}_L2.txt ]]; then
echo "<tr><td> Nonparametric T-test results - ${line} - phylum level (L2) </td><td> <a href=\"./Nonparametric_ttest/nonparametric_ttest_${line}_L2.txt\" target=\"_blank\"> nonparametric_ttest_${line}_L2.txt </a></td></tr>" >> $outdir/index.html
	fi
	done

echo "
<tr colspan=2 align=center bgcolor=#e8e8e8><td colspan=2 align=center> Alpha Diversity Results </td></tr>
<tr><td> Alpha rarefaction plots </td><td> <a href=\"./arare_max$depth/alpha_rarefaction_plots/rarefaction_plots.html\" target=\"_blank\"> rarefaction_plots.html </a></td></tr>" >> $outdir/index.html

	for category in `cat $outdir/categories.tempfile`; do
	for metric in `cat $outdir/arare_max$depth/alpha_metrics.tempfile`; do
echo "<tr><td> Alpha diversity statistics ($category, $metric, parametric) </td><td> <a href=\"./arare_max$depth/compare_${metric}_parametric/${category}_stats.txt\" target=\"_blank\"> ${category}_stats.txt </a></td></tr>
<tr><td> Alpha diversity boxplots ($category, $metric, parametric) </td><td> <a href=\"./arare_max$depth/compare_${metric}_parametric/${category}_boxplots.pdf\" target=\"_blank\"> ${category}_boxplots.pdf </a></td></tr>
<tr><td> Alpha diversity statistics ($category, $metric, nonparametric) </td><td> <a href=\"./arare_max$depth/compare_${metric}_nonparametric/${category}_stats.txt\" target=\"_blank\"> ${category}_stats.txt </a></td></tr>
<tr><td> Alpha diversity boxplots ($category, $metric, nonparametric) </td><td> <a href=\"./arare_max$depth/compare_${metric}_nonparametric/${category}_boxplots.pdf\" target=\"_blank\"> ${category}_boxplots.pdf </a></td></tr>" >> $outdir/index.html
	done
	done

echo "
<tr colspan=2 align=center bgcolor=#e8e8e8><td colspan=2 align=center> Beta Diversity Results </td></tr>
<tr><td> Anosim results </td><td> <a href=\"anosim_results_collated.txt\" target=\"_blank\"> anosim_results_collated.txt </a></td></tr>
<tr><td> Permanova results </td><td> <a href=\"permanova_results_collated.txt\" target=\"_blank\"> permanova_results_collated.txt </a></td></tr>" >> $outdir/index.html

	for dm in $outdir/bdiv/*_dm.txt; do
	dmbase=`basename $dm _dm.txt`
	for line in `cat $outdir/categories.tempfile`; do

echo "<tr><td> Distance boxplots (${dmbase}) </td><td> <a href=\"./bdiv/${dmbase}_boxplots/${line}_Distances.pdf\" target=\"_blank\"> ${line}_Distances.pdf </a></td></tr>
<tr><td> Distance boxplots statistics (${dmbase}) </td><td> <a href=\"./bdiv/${dmbase}_boxplots/${line}_Stats.txt\" target=\"_blank\"> ${line}_Stats.txt </a></td></tr>" >> $outdir/index.html

	done

echo "<tr><td> 3D PCoA plot (${dmbase}) </td><td> <a href=\"./bdiv/${dmbase}_emperor_pcoa_plot/index.html\" target=\"_blank\"> index.html </a></td></tr>
<tr><td> 2D PCoA plot (${dmbase}) </td><td> <a href=\"./2D_bdiv_plots/${dmbase}_pc_2D_PCoA_plots.html\" target=\"_blank\"> index.html </a></td></tr>" >> $outdir/index.html
echo "<tr><td> Distance matrix (${dmbase}) </td><td> <a href=\"./bdiv/${dmbase}_dm.txt\" target=\"_blank\"> ${dmbase}_dm.txt </a></td></tr>
<tr><td> Principal coordinate matrix (${dmbase}) </td><td> <a href=\"./bdiv/${dmbase}_pc.txt\" target=\"_blank\"> ${dmbase}_pc.txt </a></td></tr>
<tr><td> NMDS coordinates (${dmbase}) </td><td> <a href=\"./bdiv/${dmbase}_nmds.txt\" target=\"_blank\"> ${dmbase}_nmds.txt </a></td></tr>" >> $outdir/index.html

	done

echo "
<tr colspan=2 align=center bgcolor=#e8e8e8><td colspan=2 align=center> Rank Abundance Plots (relative abundances) </td></tr> 
<tr><td> Rank abundance (xlog-ylog) </td><td> <a href=\"RankAbundance/rankabund_xlog-ylog.pdf\" target=\"_blank\"> rankabund_xlog-ylog.pdf </a></td></tr>
<tr><td> Rank abundance (xlinear-ylog) </td><td> <a href=\"RankAbundance/rankabund_xlinear-ylog.pdf\" target=\"_blank\"> rankabund_xlinear-ylog.pdf </a></td></tr>
<tr><td> Rank abundance (xlog-ylinear) </td><td> <a href=\"RankAbundance/rankabund_xlog-ylinear.pdf\" target=\"_blank\"> rankabund_xlog-ylinear.pdf </a></td></tr>
<tr><td> Rank abundance (xlinear-ylinear) </td><td> <a href=\"RankAbundance/rankabund_xlinear-ylinear.pdf\" target=\"_blank\"> rankabund_xlinear-ylinear.pdf </a></td></tr>" >> $outdir/index.html

echo "
<tr colspan=2 align=center bgcolor=#e8e8e8><td colspan=2 align=center> OTU Heatmaps </td></tr>
<tr><td> OTU heatmap (unsorted) </td><td> <a href=\"heatmaps/otu_heatmap_unsorted.pdf\" target=\"_blank\"> otu_heatmap_unsorted.pdf </a></td></tr>" >> $outdir/index.html
	for line in `cat $outdir/categories.tempfile`; do
echo "<tr><td> OTU heatmap (${line}) </td><td> <a href=\"heatmaps/otu_heatmap_${line}.pdf\" target=\"_blank\"> otu_heatmap_${line}.pdf </a></td></tr>" >> $outdir/index.html
	done

echo "
<tr colspan=2 align=center bgcolor=#e8e8e8><td colspan=2 align=center> Supervised Learning (out of bag) </td></tr>" >> $outdir/index.html
	for category in `cat $outdir/categories.tempfile`; do
echo "<tr><td> Summary (${category}) </td><td> <a href=\"SupervisedLearning/${category}/summary.txt\" target=\"_blank\"> summary.txt </a></td></tr>
<tr><td> Mislabeling (${category}) </td><td> <a href=\"SupervisedLearning/${category}/mislabeling.txt\" target=\"_blank\"> mislabeling.txt </a></td></tr>
<tr><td> Confusion Matrix (${category}) </td><td> <a href=\"SupervisedLearning/${category}/confusion_matrix.txt\" target=\"_blank\"> confusion_matrix.txt </a></td></tr>
<tr><td> CV Probabilities (${category}) </td><td> <a href=\"SupervisedLearning/${category}/cv_probabilities.txt\" target=\"_blank\"> cv_probabilities.txt </a></td></tr>
<tr><td> Feature Importance Scores (${category}) </td><td> <a href=\"SupervisedLearning/${category}/feature_importance_scores.txt\" target=\"_blank\"> feature_importance_scores.txt </a></td></tr>" >> $outdir/index.html
	done

echo "
<tr colspan=2 align=center bgcolor=#e8e8e8><td colspan=2 align=center> Biplots </td></tr>" >> $outdir/index.html

	for dm in $outdir/bdiv/*_dm.txt; do
	dmbase=`basename $dm _dm.txt`
	for level in $outdir/biplots/$dmbase/table_sorted_*/; do
	lev=`basename $level`
	Lev=`echo $lev | sed 's/table_sorted_//'`
	Level=`echo $Lev | sed 's/L/Level /'`


echo "<tr><td> PCoA biplot, ${Level} (${dmbase}) </td><td> <a href=\"biplots/${dmbase}/table_sorted_${Lev}/index.html\" target=\"_blank\"> index.html </a></td></tr>" >> $outdir/index.html

	done
	done


## Tidy up

	if [[ -f $outdir/categories.tempfile ]]; then
	rm $outdir/categories.tempfile
	fi
	if [[ -f $outdir/arare_max$depth/alpha_metrics.tempfile ]]; then
	rm $outdir/arare_max$depth/alpha_metrics.tempfile
	fi
	if [[ -d $outdir/anosim_temp ]]; then
	rm -r $outdir/anosim_temp
	fi
	if [[ -d $outdir/permanova_temp ]]; then
	rm -r $outdir/permanova_temp
	fi
	if [[ -d $outdir/ReadCount_temp ]]; then
	rm -r $outdir/ReadCount_temp
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

	runtime=`printf "Total runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`

echo "
Core diversity workflow completed!
$runtime
"
echo "
		Core diversity workflow completed!
		$runtime
" >> $log

exit 0
