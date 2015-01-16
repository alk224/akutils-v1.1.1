#!/bin/bash
set -e

echo ""
echo "*********************************************************"
echo ""
echo "This script will process an input OTU table and mapping"
echo "file given some categories input and even sampling depth"
echo "and produce the core diversity product through QIIME as"
echo "well as producing those good old 2D plots that were"
echo "removed at QIIME 1.8.0, and anosim and permanova stats"
echo "for each of the input categories."
echo ""
echo "*********************************************************"
echo ""
echo "Enter your otu table:"
read -e otutable

echo ""
echo "Enter your sampling depth:"
read -e depth
echo ""

echo "Enter your mapping file:"
read -e mapfile

echo ""
echo "Enter your tree file:"
read -e treefile

echo "
Your mapping file contains the following categories:
"
grep "#" $mapfile | cut -f 2-100 | sed 's/\t/,/g'
echo "
Enter your categories as a comma-separated list:"
read -e cats

echo ""
echo "Enter your core diversity output folder - new subdirectory will be created:"
read -e outdir

echo ""
echo "Enter number of processors to use:"
read -e cores

echo "
Workflow will begin momentarily.  Please be patient...
"
sleep 2

#make parameters file
echo summarize_taxa:level     2,3,4,5,6,7 > phylogenetic_core_diversity_parameters.txt
echo summarize_taxa:absolute_abundance     True >> phylogenetic_core_diversity_parameters.txt
echo plot_taxa_summary:include_html_counts     True >> phylogenetic_core_diversity_parameters.txt
echo beta_diversity:metrics     abund_jaccard,binary_jaccard,bray_curtis,unweighted_unifrac,weighted_unifrac,binary_chord,chord,hellinger,kulczynski >> phylogenetic_core_diversity_parameters.txt

otuname=$(basename $otutable .biom)

#adjust python to not produce stupid warnings (commented out at the moment since it doesn't seem to work...)
#python -c "import matplotlib; matplotlib.rcParams['figure.max_open_warning'] = 0"

#core diversity processing plus stats loop and 2d plots
core_diversity_analyses.py -i $otutable -o $outdir/$otuname -e $depth -aO $cores -c $cats -p phylogenetic_core_diversity_parameters.txt -t $treefile -m $mapfile &

echo ""
echo "Core diversity command is running in the background on $cores cores."
echo "Processing $otuname.  Look in $outdir for results.
"
echo "Waiting on beta diversity to complete before computing stats and"
echo "other useful outputs while core_diversity_analyses.py completes."
echo ""
sleep 5

#make categories temp file
echo > $outdir/$otuname/categories.tempfile
IN=$cats

OIFS=$IFS
IFS=','
arr=$IN
for x in $arr
do
     echo $x >> $outdir/$otuname/categories.tempfile
done

IFS=$OIFS

echo ""
echo "Script is checking for completed beta diversity every 10 seconds..."

while [ ! -d $outdir/$otuname/arare_max$depth ]
do
     sleep 10
     echo "Still waiting on beta diversity completion..."
done
echo ""
echo "Beta diversity completed.  Producing anosim and permanova stats..."
echo ""


#anosim and permanova stats

echo > $outdir/$otuname/permanova_results_collated.txt
echo > $outdir/$otuname/anosim_results_collated.txt

for line in `cat $outdir/$otuname/categories.tempfile`
do
     for dm in $outdir/$otuname/bdiv_even$depth/*_dm.txt; do
     method=$(basename $dm .txt)
     compare_categories.py --method permanova -i $dm -m $mapfile -c $line -o $outdir/$otuname/permanova_temp/$line/$method/
     echo "Category: $line" >> $outdir/$otuname/permanova_results_collated.txt
     echo "Method: $method" >> $outdir/$otuname/permanova_results_collated.txt
     cat $outdir/$otuname/permanova_temp/$line/$method/permanova_results.txt >> $outdir/$otuname/permanova_results_collated.txt
     echo "" >> $outdir/$otuname/permanova_results_collated.txt


     compare_categories.py --method anosim -i $dm -m $mapfile -c $line -o $outdir/$otuname/anosim_temp/$line/$method/
     echo "Category: $line" >> $outdir/$otuname/anosim_results_collated.txt
     echo "Method: $method" >> $outdir/$otuname/anosim_results_collated.txt
     cat $outdir/$otuname/anosim_temp/$line/$method/anosim_results.txt >> $outdir/$otuname/anosim_results_collated.txt
     echo "" >> $outdir/$otuname/anosim_results_collated.txt

done
done
sleep 1

echo ""
echo "Stats completed.  Producing 2d plots..."
echo ""
echo "If (when) you recieve a matplotlib warning, it can be ignored."
echo "It can be silenced by changing the matplotlib configuration file."
echo "However, I have yet to do this successfully. If you succeed,
please email me your solution at alk224@nau.edu!!"
echo ""
sleep 3

for pc in $outdir/$otuname/bdiv_even$depth/*_pc.txt; do
sleep 1

     ( make_2d_plots.py -i $pc -m $mapfile -o $outdir/$otuname/2D_bdiv_plots ) &
done

echo ""
echo "2d plots completed.  Producing biplots as soon as taxa summaries are completed..."
echo ""

while [ ! -d $outdir/$otuname/taxa_plots_* ]
do
     sleep 2

done

echo "Producing biplots..."

mkdir $outdir/$otuname/Biplots
for pc in $outdir/$otuname/bdiv_even$depth/*_pc.txt; do
     pcmethod=$(basename $pc _pc.txt)
     mkdir $outdir/$otuname/Biplots/$pcmethod
     for level in $outdir/$otuname/taxa_plots/table_mc$depth\_sorted_*.txt; do
          L=$(basename $level .txt)
          make_emperor.py -i $pc -m $mapfile -o $outdir/$otuname/Biplots/$pcmethod/$L -t $level

done
done

echo ""
echo "Biplots completed.  Waiting for remaining core diversity workflow to complete."
echo ""


wait
echo ""
echo "Core diversity completed."
echo ""

#tidy things up
rm $outdir/$otuname/categories.tempfile
rm -r $outdir/$otuname/permanova_temp
rm -r $outdir/$otuname/anosim_temp










