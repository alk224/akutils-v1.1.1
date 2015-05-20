#!/bin/bash
set -e

## Check whether user had supplied -h or --help. If yes display help 

	if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
		echo "
		This script will process a normalized OTU table in
		a statistically admissible way (without rarefying).
		Output will be the same as with the core diversity
		analysis in qiime, but also including biplots, 2d
		PCoA plots, and collated statistical outputs for
		input categories for permanova and anosim.

		Usage (order is important!!):
		cdiv_for_normalized_tables.sh <otu_table> <output_dir> <mapping_file> <comma_separated_categories> <rarefaction_depth> <processors_to_use> <tree_file>

		<tree_file> is optional.  Analysis will be nonphylogenetic 
		if no tree file is supplied.
		
		Example:
		cdiv_for_normalized_tables.sh CSS_table.biom core_div map.txt Site,Date 1000 12 phylogeny.tre

		Will process the table, CSS_table.biom using the mapping
		file, map.txt, and categories Site and Date through the
		workflow on 12 cores with phylogenetic and nonphylogenetic
		metrics against the tree, phylogeny.tre.  Alpha diversity
		will be assessed at a depth of 1000 reads.  Output will be
		in a subdirectory called core_div.

		Phylogenetic metrics: weighted_unifrac
		Nonphylogenetic metrics: bray_curtis, chord, hellinger, kulczynski

		It is important that your input table be properly
		filtered before running this workflow, or your output
		may be of questionable quality.  Minimal filtering
		might include removal of low-count samples, singleton
		OTUs, and abundance-based OTU filtering at some level
		(e.g. 0.005%).
		"
		exit 0
	fi 

## If less than five or more than 6 arguments supplied, display usage 

	if [[ "$#" -le 5 ]] || [[ "$#" -ge 8 ]]; then 
		echo "
		Usage (order is important!!):
		cdiv_for_normalized_tables.sh <otu_table> <output_dir> <mapping_file> <comma_separated_categories> <rarefaction_depth> <processors_to_use> <tree_file>

		<tree_file> is optional.  Analysis will be nonphylogenetic 
		if no tree file is supplied.

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

## Make output directory

	if [[ ! -d $outdir ]]; then
	mkdir -p $outdir
	fi

## Set workflow mode (phylogenetic or nonphylogenetic) and log start

	if [[ -z $tree ]]; then
	mode=nonphylogenetic
	metrics=bray_curtis,chord,hellinger,kulczynski
	else
	mode=phylogenetic
	metrics=bray_curtis,chord,hellinger,kulczynski,weighted_unifrac
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

## Beta diversity

	if [[ ! -d $outdir/bdiv ]]; then

	if [[ "$mode" == phylogenetic ]]; then
	echo "
Parallel beta diversity command:
	parallel_beta_diversity.py -i $table -o $outdir/bdiv/ --metrics $metrics -T  -t $tree --jobs_to_start $cores" >> $log

	echo "		Calculating beta diversity distance matrices.
	"

	parallel_beta_diversity.py -i $table -o $outdir/bdiv/ --metrics $metrics -T  -t $tree --jobs_to_start $cores

	elif [[ "$mode" == nonphylogenetic ]]; then
	echo "
Parallel beta diversity command:
	parallel_beta_diversity.py -i $table -o $outdir/bdiv/ --metrics $metrics -T --jobs_to_start $cores" >> $log

	echo "		Calculating beta diversity distance matrices.
	"

	parallel_beta_diversity.py -i $table -o $outdir/bdiv/ --metrics $metrics -T --jobs_to_start $cores

	fi

## Rename output files

	for dm in $outdir/bdiv/*_table.txt; do
	dmbase=$( basename $dm _table.txt )
	mv $dm $outdir/bdiv/$dmbase\_dm.txt
	done

## Principal coordinates and NMDS commands
	echo "
Principal coordinates and NMDS commands:" >> $log

	echo "		Constructing PCoA and NMDS coordinate files.
	"

	for dm in $outdir/bdiv/*_dm.txt; do
	dmbase=$( basename $dm _dm.txt )
	echo "	principal_coordinates.py -i $dm -o $outdir/bdiv/$dmbase\_pc.txt
	nmds.py -i $dm -o $outdir/bdiv/$dmbase\_nmds.txt" >> $log
	principal_coordinates.py -i $dm -o $outdir/bdiv/$dmbase\_pc.txt >/dev/null 2>&1 || true
	nmds.py -i $dm -o $outdir/bdiv/$dmbase\_nmds.txt >/dev/null 2>&1 || true
	done

## Make emperor plots

	echo "
Make emperor commands:" >> $log

	echo "		Generating 3D PCoA plots.
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

	echo "		Calculating one-way ANOSIM and PERMANOVA statsitics from distance matrices.
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

## Make 2D plots in background

	if [[ ! -d $outdir/2D_bdiv_plots ]]; then

	echo "
Make 2D plots commands:" >> $log

	echo "		Generating 2D PCoA plots.
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

## Sort OTU table

	if [[ ! -d $outdir/taxa_plots ]]; then

	echo "
Sort OTU table command:
	sort_otu_table.py -i $table -o $outdir/taxa_plots/table_sorted.biom" >> $log
	mkdir $outdir/taxa_plots
	sort_otu_table.py -i $table -o $outdir/taxa_plots/table_sorted.biom
	sortedtable=($outdir/taxa_plots/table_sorted.biom)

## Summarize taxa (yields relative abundance tables)

	echo "
Summarize taxa command:
	summarize_taxa.py -i $sortedtable -o $outdir/taxa_plots/ -L 2,3,4,5,6,7" >> $log

	echo "		Summarizing taxonomy by sample and building plots.
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

	echo "		Building taxonomy plots for category: $line.
	"

	echo "
Summarize taxa commands by category $line:
	collapse_samples.py -m $mapfile -b $table --output_biom_fp $outdir/taxa_plots_$line/$line\_otu_table.biom --output_mapping_fp $outdir/taxa_plots_$line/$line_map.txt --collapse_fields $line
	sort_otu_table.py -i $outdir/taxa_plots_$line/$line\_otu_table.biom -o $outdir/taxa_plots_$line/$line\_otu_table_sorted.biom
	summarize_taxa.py -i $outdir/taxa_plots_$line/$line\_otu_table_sorted.biom -o $outdir/taxa_plots_$line/
	plot_taxa_summary.py -i $outdir/taxa_plots_$line/$line\_otu_table_sorted_L2.txt,$outdir/taxa_plots_$line/$line\_otu_table_sorted_L3.txt,$outdir/taxa_plots_$line/$line\_otu_table_sorted_L4.txt,$outdir/taxa_plots_$line/$line\_otu_table_sorted_L5.txt,$outdir/taxa_plots_$line/$line\_otu_table_sorted_L6.txt,$outdir/taxa_plots_$line/$line\_otu_table_sorted_L7.txt -o $outdir/taxa_plots_$line/taxa_summary_plots/ -c bar,pie" >> $log

	mkdir $outdir/taxa_plots_$line

	collapse_samples.py -m $mapfile -b $table --output_biom_fp $outdir/taxa_plots_$line/$line\_otu_table.biom --output_mapping_fp $outdir/taxa_plots_$line/$line_map.txt --collapse_fields $line
	
	sort_otu_table.py -i $outdir/taxa_plots_$line/$line\_otu_table.biom -o $outdir/taxa_plots_$line/$line\_otu_table_sorted.biom

	summarize_taxa.py -i $outdir/taxa_plots_$line/$line\_otu_table_sorted.biom -o $outdir/taxa_plots_$line/ -L 2,3,4,5,6,7

	plot_taxa_summary.py -i $outdir/taxa_plots_$line/$line\_otu_table_sorted_L2.txt,$outdir/taxa_plots_$line/$line\_otu_table_sorted_L3.txt,$outdir/taxa_plots_$line/$line\_otu_table_sorted_L4.txt,$outdir/taxa_plots_$line/$line\_otu_table_sorted_L5.txt,$outdir/taxa_plots_$line/$line\_otu_table_sorted_L6.txt,$outdir/taxa_plots_$line/$line\_otu_table_sorted_L7.txt -o $outdir/taxa_plots_$line/taxa_summary_plots/ -c bar,pie
	fi
	done

## Make OTU heatmaps

	if [[ ! -d $outdir/heatmaps ]]; then

	echo "		Building heatmaps.
	"

	mkdir $outdir/heatmaps

	( make_otu_heatmap.py -i $table -o $outdir/heatmaps/otu_heatmap_unsorted.pdf --absolute_abundance --color_scheme YlOrRd ) &

	for line in `cat $outdir/categories.tempfile`; do
	while [ $( pgrep -P $$ |wc -w ) -ge ${threads} ]; do 
	sleep 1
	done
	( make_otu_heatmap.py -i $table -o $outdir/heatmaps/otu_heatmap_$line.pdf --absolute_abundance --color_scheme YlOrRd -c $line -m $mapfile ) &
	done

	fi
wait

## Distance boxplots for each category

	boxplotscount=$( ls $outdir/bdiv/*_boxplots 2>/dev/null | wc -l )

	if [[ $boxplotscount = 0 ]]; then

	echo "
Make distance boxplots commands:" >> $log

	echo "		Generating distance boxplots.
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

	fi
wait

## Group significance for each category

	kwtestcount=$(ls $outdir/KruskalWallis/kruskalwallis_* 2> /dev/null | wc -l)

	if [[ $kwtestcount == 0 ]]; then

	echo "
Group significance commands:" >> $log
	if [[ ! -d $outdir/KruskalWallis ]]; then
	mkdir $outdir/KruskalWallis
	fi

	echo "		Calculating Kruskal-Wallis test statistics when possible.
	"

for line in `cat $outdir/categories.tempfile`; do
	if [[ ! -f $outdir/KruskalWallis/kruskalwallis_$line\_OTU.txt ]]; then
	while [ $( pgrep -P $$ |wc -w ) -ge ${threads} ]; do 
	sleep 1
	done
	echo "	group_significance.py -i $outdir/table_even$depth.biom -m $mapfile -c $line -o $outdir/KruskalWallis/kruskalwallis_${line}_OTU.txt -s kruskal_wallis" >> $log
	( group_significance.py -i $outdir/table_even$depth.biom -m $mapfile -c $line -o $outdir/KruskalWallis/kruskalwallis_$line\_OTU.txt -s kruskal_wallis ) >/dev/null 2>&1 || true &
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

	ttestcount=$(ls $outdir/Nonparametric_ttest/nonparametric_ttest_* 2> /dev/null | wc -l)

	if [[ $ttestcount == 0 ]]; then

	if [[ ! -d $outdir/Nonparametric_ttest ]]; then
	mkdir $outdir/Nonparametric_ttest
	fi

	echo "		Calculating nonparametric T-test statistics when possible.
	"

for line in `cat $outdir/categories.tempfile`; do
	if [[ ! -f $outdir/Nonparametric_ttest/nonparametric_ttest_$line\_OTU.txt ]]; then
	while [ $( pgrep -P $$ |wc -w ) -ge ${threads} ]; do 
	sleep 1
	done
	echo "	group_significance.py -i $outdir/table_even$depth.biom -m $mapfile -c $line -o $outdir/Nonparametric_ttest/nonparametric_ttest_${line}_OTU.txt -s nonparametric_t_test" >> $log
	( group_significance.py -i $outdir/table_even$depth.biom -m $mapfile -c $line -o $outdir/Nonparametric_ttest/nonparametric_ttest_$line\_OTU.txt -s nonparametric_t_test ) >/dev/null 2>&1 || true &
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

	echo "		Generating PCoA biplots.
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

	echo "		Running supervised learning analysis.
	"

	for category in `cat $outdir/categories.tempfile`; do
	supervised_learning.py -i $table -m $mapfile -c $category -o $outdir/SupervisedLearning/$category --ntree 1000
	done
	fi

## Make rank abundance plots

	if [[ ! -d $outdir/RankAbundance ]]; then
	mkdir $outdir/RankAbundance

	echo "		Generating rank abundance plots.
	"

	( plot_rank_abundance_graph.py -i $table -o $outdir/RankAbundance/rankabund_xlog-ylog.pdf -s "*" -n -a ) &
	( plot_rank_abundance_graph.py -i $table -o $outdir/RankAbundance/rankabund_xlinear-ylog.pdf -s "*" -n -x -a ) &
	( plot_rank_abundance_graph.py -i $table -o $outdir/RankAbundance/rankabund_xlog-ylinear.pdf -s "*" -n -y -a ) &
	( plot_rank_abundance_graph.py -i $table -o $outdir/RankAbundance/rankabund_xlinear-ylinear.pdf -s "*" -n -x -y -a ) &
	fi

## Make html file

	if [[ ! -f $outdir/index.html ]]; then

	echo "		Building html output file.
		$outdir/index.html
	"
	else
	echo "		Rebuilding html output file.
		$outdir/index.html
	"
	fi

logfile=`basename $log`

echo "<html>
<head><title>QIIME results</title></head>
<body>
<a href=\"http://www.qiime.org\" target=\"_blank\"><img src=\"http://qiime.org/_static/wordpressheader.png\" alt=\"www.qiime.org\"\"/></a><p>
<h2> akutils core diversity workflow for normalized OTU tables </h2><p>
<a href=\"https://github.com/alk224/akutils\" target=\_blank\"><h3> https://github.com/alk224/akutils </h3></a><p>
<table border=1>
<tr colspan=2 align=center bgcolor=#e8e8e8><td colspan=2 align=center> Run Summary Data </td></tr>
<tr><td>Master run log</td><td> <a href=\" $logfile \" target=\"_blank\"> $logfile </a></td></tr>
<tr><td> BIOM table statistics </td><td> <a href=\"./biom_table_summary.txt\" target=\"_blank\"> biom_table_summary.txt </a></td></tr>" > $outdir/index.html



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
<tr colspan=2 align=center bgcolor=#e8e8e8><td colspan=2 align=center> Group Significance Results (Kruskal-Wallis - nonparametric ANOVA) </td></tr>" >> $outdir/index.html

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
<tr colspan=2 align=center bgcolor=#e8e8e8><td colspan=2 align=center> Group Significance Results (Nonparametric T-test, 1000 permutations) <br><br> Results only generated when comparing two groups </td></tr>" >> $outdir/index.html

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
<tr colspan=2 align=center bgcolor=#e8e8e8><td colspan=2 align=center> Rank Abundance Plots (absolute abundances) </td></tr> 
<tr><td> Rank abundance (xlog-ylog) </td><td> <a href=\"RankAbundance/rankabund_xlog-ylog.pdf\" target=\"_blank\"> rankabund_xlog-ylog.pdf </a></td></tr>
<tr><td> Rank abundance (xlinear-ylog) </td><td> <a href=\"RankAbundance/rankabund_xlinear-ylog.pdf\" target=\"_blank\"> rankabund_xlinear-ylog.pdf </a></td></tr>
<tr><td> Rank abundance (xlog-ylinear) </td><td> <a href=\"RankAbundance/rankabund_xlog-ylinear.pdf\" target=\"_blank\"> rankabund_xlog-ylinear.pdf </a></td></tr>
<tr><td> Rank abundance (xlinear-ylinear) </td><td> <a href=\"RankAbundance/rankabund_xlinear-ylinear.pdf\" target=\"_blank\"> rankabund_xlinear-ylinear.pdf </a></td></tr>" >> $outdir/index.html

echo "
<tr colspan=2 align=center bgcolor=#e8e8e8><td colspan=2 align=center> OTU Heatmaps </td></tr>
<tr><td> OTU heatmap (unsorted) </td><td> <a href=\"heatmaps/otu_heatmap_unsorted.pdf\" target=\"_blank\"> otu_heatmap_unsorted.pdf </a></td></tr>" >> $outdir/index.html
	for line in `cat $outdir/categories.tempfile`; do
echo "<tr><td> OTU heatmap (${line}) </td><td> <a href=\"heatmaps/otu_heatmap_${line}.pdf\" target=\"_blank\"> heatmaps/otu_heatmap_${line}.pdf </a></td></tr>" >> $outdir/index.html
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


