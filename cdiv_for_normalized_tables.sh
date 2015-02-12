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

## Summarize input table

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

## Beta diversity

	if [[ ! -d $outdir/bdiv ]]; then

	if [[ "$mode" == phylogenetic ]]; then
	echo "
Parallel beta diversity command:
	parallel_beta_diversity.py -i $table -o $outdir/bdiv/ --metrics $metrics -T  -t $tree --jobs_to_start $cores" >> $log
	parallel_beta_diversity.py -i $table -o $outdir/bdiv/ --metrics $metrics -T  -t $tree --jobs_to_start $cores

	elif [[ "$mode" == nonphylogenetic ]]; then
	echo "
Parallel beta diversity command:
	parallel_beta_diversity.py -i $table -o $outdir/bdiv/ --metrics $metrics -T --jobs_to_start $cores" >> $log
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

	for dm in $outdir/bdiv/*_dm.txt; do
	dmbase=$( basename $dm _dm.txt )
	echo "	principal_coordinates.py -i $dm -o $outdir/bdiv/$dmbase\_pc.txt
	nmds.py -i $dm -o $outdir/bdiv/$dmbase\_nmds.txt" >> $log
	principal_coordinates.py -i $dm -o $outdir/bdiv/$dmbase\_pc.txt
	nmds.py -i $dm -o $outdir/bdiv/$dmbase\_nmds.txt
	done

## Make emperor
	echo "
Make emperor commands:" >> $log

	for pc in $outdir/bdiv/*_pc.txt; do
	pcbase=$( basename $pc _pc.txt )
	echo "	make_emperor.py -i $pc -o $outdir/bdiv/$pcbase\_emperor_pcoa_plot/ -m $mapfile" >> $log
	make_emperor.py -i $pc -o $outdir/bdiv/$pcbase\_emperor_pcoa_plot/ -m $mapfile
	done

	fi

## Anosim and permanova stats

	if [[ ! -f $outdir/permanova_results_collated.txt ]] || [[ ! -f $outdir/anosim_results_collated.txt ]]; then

echo > $outdir/permanova_results_collated.txt
echo > $outdir/anosim_results_collated.txt
echo "
Compare categories commands:" >> $log

	for line in `cat $outdir/categories.tempfile`; do
		for dm in $outdir/bdiv/*_dm.txt; do
		method=$( basename $dm .txt )
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

	if [[ ! -d $outdir/arare_max$depth ]]; then

	echo "
Multiple rarefaction command:
	parallel_multiple_rarefactions.py -T -i $table -m 5 -x $depth -s 99 -o $outdir/arare_max$depth/rarefaction/ -O $cores" >> $log
	parallel_multiple_rarefactions.py -T -i $table -m 5 -x $depth -s 99 -o $outdir/arare_max$depth/rarefaction/ -O $cores

## Alpha diversity
        if [[ "$mode" == phylogenetic ]]; then
	alphametrics=PD_whole_tree,chao1,observed_species,shannon
	echo "
Alpha diversity command:
	parallel_alpha_diversity.py -T -i $outdir/arare_max$depth/rarefaction/ -o $outdir/arare_max$depth/alpha_div/ -t $tree -O $cores -m $alphametrics" >> $log
	parallel_alpha_diversity.py -T -i $outdir/arare_max$depth/rarefaction/ -o $outdir/arare_max$depth/alpha_div/ -t $tree -O $cores -m $alphametrics

        elif [[ "$mode" == nonphylogenetic ]]; then
	alphametrics=chao1,observed_species,shannon
	echo "
Alpha diversity command:
        parallel_alpha_diversity.py -T -i $outdir/arare_max$depth/rarefaction/ -o $outdir/arare_max$depth/alpha_div/ -O $cores -m $alphametrics" >> $log
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
	for pc in $outdir/bdiv/*_pc.txt; do
	echo "	make_2d_plots.py -i $pc -m $mapfile -o $outdir/2D_bdiv_plots" >> $log
	( make_2d_plots.py -i $pc -m $mapfile -o $outdir/2D_bdiv_plots ) &
	done

	fi

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
	make_rarefaction_plots.py -i $outdir/arare_max$depth/alpha_div_collated/ -m $mapfile -o $outdir/arare_max$depth/alpha_rarefaction_plots/

## Alpha diversity stats

	echo "
Compare alpha diversity commands:" >> $log
	for file in $outdir/arare_max$depth/alpha_div_collated/*.txt; do
	filebase=$( basename $file .txt )
	echo "compare_alpha_diversity.py -i $file -m $mapfile -c $cats -o $outdir/arare_max150/alpha_compare_parametric -t parametric -p fdr" >> $log
	compare_alpha_diversity.py -i $file -m $mapfile -c $cats -o $outdir/arare_max150/compare_$filebase\_parametric -t parametric -p fdr
	echo "compare_alpha_diversity.py -i $file -m $mapfile -c $cats -o $outdir/arare_max150/alpha_compare_nonparametric -t nonparametric -p fdr" >> $log
	compare_alpha_diversity.py -i $file -m $mapfile -c $cats -o $outdir/arare_max150/compare_$filebase\_nonparametric -t nonparametric -p fdr
	done

	fi

## Sort OTU table

	if [[ ! -d $outdir/taxa_plots ]]; then

	echo "
Sort OTU table command:
	sort_otu_table.py -i $table -o $outdir/taxa_plots/table_sorted.biom" >> $log
	mkdir $outdir/taxa_plots
	sort_otu_table.py -i $table -o $outdir/taxa_plots/table_sorted.biom
	sortedtable=($outdir/taxa_plots/table_sorted.biom)

## Summarize taxa

	echo "
Summarize taxa command:
	summarize_taxa.py -i $sortedtable -o $outdir/taxa_plots/ -L 2,3,4,5,6,7" >> $log
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

	mkdir $outdir/heatmaps

	make_otu_heatmap.py -i $table -o $outdir/heatmaps/otu_heatmap_unsorted.pdf --absolute_abundance

	for line in `cat $outdir/categories.tempfile`; do
	make_otu_heatmap.py -i $table -o $outdir/heatmaps/otu_heatmap_$line.pdf --absolute_abundance -c $line -m $mapfile
	done

	fi

## Distance boxplots for each category

	if [[ ! -d $outdir/bdiv ]]; then

	echo "
Make distance boxplots commands:" >> $log

	for line in `cat $outdir/categories.tempfile`; do

		for dm in $outdir/bdiv/*dm.txt; do
		dmbase=$( basename $dm _dm.txt )

		echo "	make_distance_boxplots.py -d $outdir/bdiv/$dmbase\_dm.txt -f $line -o $outdir/bdiv/$dmbase\_boxplots/ -m $mapfile -n 999" >> $log
		( make_distance_boxplots.py -d $outdir/bdiv/$dmbase\_dm.txt -f $line -o $outdir/bdiv/$dmbase\_boxplots/ -m $mapfile -n 999 ) &
		done

	done

	fi

## Group significance for each category

	if [[ ! -f $outdir/group_significance_* ]]; then
	echo "
Group significance commands:" >> $log
	fi
	for line in `cat $outdir/categories.tempfile`; do
	if [[ ! -f $outdir/group_significance_gtest_$line.txt ]]; then
	echo "	group_significance.py -i $table -m $mapfile -c $line -o $outdir/group_significance_gtest_$line.txt -s g_test" >> $log
	( group_significance.py -i $table -m $mapfile -c $line -o $outdir/group_significance_gtest_$line.txt -s g_test ) &
	fi
	done

## Make biplots

	if [[ ! -d $outdir/biplots ]]; then
	echo "
Make biplots commands:" >> $log

	mkdir $outdir/biplots
	for pc in $outdir/bdiv/*_pc.txt; do
	pcmethod=$( basename $pc _pc.txt )
	mkdir $outdir/biplots/$pcmethod

		for level in $outdir/taxa_plots/table_sorted_*.txt; do
		L=$( basename $level .txt )
		echo "	make_emperor.py -i $pc -m $mapfile -o $outdir/biplots/$pcmethod/$L -t $level" >> $log
		make_emperor.py -i $pc -m $mapfile -o $outdir/biplots/$pcmethod/$L -t $level
		done
	done

	fi

## Make html file

#	if [[ ! -f $outdir/index.html ]]; then

logfile=`basename $log`

echo "<html>
<head><title>QIIME results</title></head>
<body>
<a href=\"http://www.qiime.org\" target=\"_blank\"><img src=\"http://qiime.org/_static/wordpressheader.png\" alt=\"www.qiime.org\"\"/></a><p>
<h2> akutils core diversity workflow for normalized OTU tables </h2><p>
<a href=\"https://github.com/alk224/akutils\" target=\_blank\"><h3> https://github.com/alk224/akutils </h3></a><p>
<table border=1>
<tr colspan=2 align=center bgcolor=#e8e8e8><td colspan=2 align=center> Run summary data </td></tr>
<tr><td>Master run log</td><td> <a href=\" $logfile \" target=\"_blank\"> $logfile </a></td></tr>
<tr><td> BIOM table statistics </td><td> <a href=\"./biom_table_summary.txt\" target=\"_blank\"> biom_table_summary.txt </a></td></tr>" > $outdir/index.html

echo "
<tr colspan=2 align=center bgcolor=#e8e8e8><td colspan=2 align=center> Group significance results </td></tr>
<tr><td> Anosim results </td><td> <a href=\"anosim_results_collated.txt\" target=\"_blank\"> anosim_results_collated.txt </a></td></tr>
<tr><td> Permanova results </td><td> <a href=\"permanova_results_collated.txt\" target=\"_blank\"> permanova_results_collated.txt </a></td></tr>" >> $outdir/index.html

	for line in `cat $outdir/categories.tempfile`; do

echo "<tr><td> G-Test results - ${line} </td><td> <a href=\"group_significance_gtest_${line}.txt\" target=\"_blank\"> group_significance_gtest_${line}.txt </a></td></tr>" >> $outdir/index.html

	done

echo "
<tr colspan=2 align=center bgcolor=#e8e8e8><td colspan=2 align=center> Taxonomic summary results </td></tr>
<tr><td> Taxa summary bar plots </td><td> <a href=\"./taxa_plots/taxa_summary_plots/bar_charts.html\" target=\"_blank\"> bar_charts.html </a></td></tr>" >> $outdir/index.html

	for line in `cat $outdir/categories.tempfile`; do
echo "
<tr colspan=2 align=center bgcolor=#e8e8e8><td colspan=2 align=center> Taxonomic summary results (by $line) </td></tr>
<tr><td> Taxa summary bar plots </td><td> <a href=\"./taxa_plots_$line/taxa_summary_plots/bar_charts.html\" target=\"_blank\"> bar_charts.html </a></td></tr>
<tr><td> Taxa summary pie plots </td><td> <a href=\"./taxa_plots_$line/taxa_summary_plots/pie_charts.html\" target=\"_blank\"> pie_charts.html </a></td></tr>" >> $outdir/index.html
	done


echo "
<tr colspan=2 align=center bgcolor=#e8e8e8><td colspan=2 align=center> Alpha diversity results </td></tr>
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
<tr colspan=2 align=center bgcolor=#e8e8e8><td colspan=2 align=center> Beta diversity results </td></tr>" >> $outdir/index.html

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
<tr colspan=2 align=center bgcolor=#e8e8e8><td colspan=2 align=center> OTU heatmaps </td></tr>
<tr><td> OTU heatmap (unsorted) </td><td> <a href=\"heatmaps/otu_heatmap_unsorted.pdf\" target=\"_blank\"> otu_heatmap_unsorted.pdf </a></td></tr>" >> $outdir/index.html
	for line in `cat $outdir/categories.tempfile`; do
echo "<tr><td> OTU heatmap (${line}) </td><td> <a href=\"heatmaps/otu_heatmap_${line}.pdf\" target=\"_blank\"> heatmaps/otu_heatmap_${line}.pdf </a></td></tr>" >> $outdir/index.html
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


