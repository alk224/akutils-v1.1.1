#!/usr/bin/env bash
#
#  cdiv_graphs_and_stats_workflow.sh - Core diversity analysis through QIIME for OTU table analysis
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

	scriptdir="$( cd "$( dirname "$0" )" && pwd )"
	if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
	less $scriptdir/docs/cdiv_graphs_and_stats_workflow.help
		exit 0
	fi 

## Check whether user had supplied "rerun."  If yes, source command from log file to rerun workflow

	if [[ "$1" == "rerun" ]]; then
	## get command form log file and execute it as previously done
	echo "rerun not working yet. fix me!"
	## I think command first
	exit 0
	fi

## If less than five or more than 6 arguments supplied, display usage 

	if [[ "$#" -le 3 ]] || [[ "$#" -ge 6 ]]; then 
		echo "
Usage (order is important!!):
cdiv_graphs_and_stats_workflow.sh <input_table_prefix or input_table> <mapping_file> <comma_separated_categories> <processors_to_use> <tree_file>

	Input table for single table mode only
	Input table prefix for batch mode (execute within existing dir)
	Table prefix precedes \"_table_hdf5.biom\"

	<tree_file> is optional.  Analysis will be nonphylogenetic if no
	tree file is supplied.
		"
		exit 1
	fi

## Set date functions

	date0=`date +%Y%m%d_%I%M%p`
	date1=`date "+%a %b %d %I:%M %p %Z %Y"`

## Define log file or use existing

	logcount=`ls log_cdiv_graphs_and_stats* 2>/dev/null | wc -l`
	
	if [[ $logcount > 0 ]]; then
		log=`ls log_cdiv_graphs_and_stats_workflow*.txt | head -1`
		echo "
Core diversity workflow restarting."
		echo "$date1"
			echo "
Core diversity workflow restarting." >> $log
			date "+%a %b %d %I:%M %p %Z %Y" >> $log
	elif [[ $logcount == "0" ]]; then
		echo "
Core diversity workflow beginning."
		echo "$date1"
		log=log_cdiv_graphs_and_stats_workflow_$date0.txt
		echo "
Core diversity workflow beginning." > $log
		date "+%a %b %d %I:%M %p %Z %Y" >> $log
	fi

## Define variables

input=($1)
mapfile=($2)
cats=($3)
cores=($4)
threads=`expr $4 + 1`
tree=($5)

#set outname below to facilitate batch processing
#otuname=$(basename $intable .biom)

## Set output below to facilitate batch processing


	#might need to move this down to facilitate batch processing
	#I deleted this variable opting for auto determination of runmode
#if [[ $runmode == "TABLE" ]]; then
		#need to fix this string to auto determine depth
#depth=`grep -A 1 "Counts/sample detail" swarm_otus_d1/OTU_tables_uclust_tax/03_table_hdf5.summary | sed '/Counts/d' | cut -d" " -f3 | cut -d. -f1`

## Make output directory and get full working path

## Need to move this down to facilitate batch processing

#	if [[ ! -d $outdir ]]; then
#	mkdir -p $outdir
#	fi

## Set analysis mode (phylogenetic or nonphylogenetic)

	if [[ -z $tree ]]; then
	analysis=Nonphylogenetic
	metrics=bray_curtis,chord,hellinger,kulczynski
	else
	analysis=Phylogenetic
	metrics=bray_curtis,chord,hellinger,kulczynski,unweighted_unifrac,weighted_unifrac
	fi
	echo "Analysis: $analysis"
	echo "Analysis: $analysis" >> $log

## Set workflow mode (table or batch)

	if [[ -f $input ]]; then
	mode=table
	outdir0=`dirname $input`
	outdir=$dirname0/core_diversity
	echo "Mode: Table only
Input: $input"
	echo "Mode: Table only
Input: $input" >> $log
	else
	mode=batch
	execdir=`pwd`
	echo "Mode: Batch
Directory: $execdir"
	echo "Mode: Batch
Directory: $execdir" >> $log
	fi

	res0=$(date +%s.%N)

## Make categories temp file

	IN=$cats
	OIFS=$IFS
	IFS=','
	arr=$IN
	mkdir -p cdiv_temp
	tempdir=cdiv_temp
	echo > $tempdir/categories.tempfile
	for x in $arr; do
		echo $x >> $tempdir/categories.tempfile
	done
	IFS=$OIFS
	sed -i '/^\s*$/d' $tempdir/categories.tempfile

## If function to control mode and for loop for batch processing start here

	if [[ $mode == "table" ]]; then

	## Check for valid input (file has .biom extension)
	biombase=`basename "$1" | cut -d. -f1`
	outbase=`basename "$1" | cut -d. -f1 | cut -d"_" -f1-2`
	biomextension="${1##*.}"
	biomname="${1%.*}"
	biomdir=$(dirname $1)

	if [[ $biomextension != "biom" ]]; then
	echo "
	Input file is not a biom file.  Check your input and try again.
	Exiting.
	"
	exit 1
	else
	table=$1

	## Summarize input table(s) if necessary and extract rarefaction depth from shallowest sample
	if [[ ! -f $biomdir/$biombase.summary ]]; then
	biom-summarize_folder.sh $biomdir &>/dev/null
	fi
	depth=`grep -A 1 "Counts/sample detail" $biomdir/$biombase.summary | sed '/Counts/d' | cut -d" " -f3 | cut -d. -f1`

	## Check for normalized table
	normbase=`echo $biombase | sed 's/hdf5/CSS/'`
	normcount=`ls $biomdir/$normbase.biom 2>/dev/null | wc -l`
	if [[ $normcount == "0" ]]; then
	normtable="None supplied"
	else
	normtable="$biomdir/$normbase.biom"
	fi

	## Set output directory
	outdir=$biomdir/core_diversity/$outbase
	outdir1=$biomdir/core_diversity
	mkdir -p $outdir

	echo "Normalized table: $normtable
Output: $outdir
Rarefaction depth: $depth
	"
	echo "Normalized table: $normtable
Output: $outdir
Rarefaction depth: $depth
	" >> $log
	echo "Calling normalized_table_beta_diversity.sh function.
"
	echo "Calling normalized_table_beta_diversity.sh function.
Command:
bash $scriptdir/normalized_table_beta_diversity.sh <normalized_table> <output_dir> <mapping_file> <cores> <optional_tree>
bash $scriptdir/normalized_table_beta_diversity.sh $normtable $outdir $mapfile $cores $tree
" >> $log
	bash $scriptdir/normalized_table_beta_diversity.sh $normtable $outdir $mapfile $cores $tree

	echo "Calling nonnormalized_table_diversity_analyses.sh function.
"
	echo "Calling nonnormalized_table_diversity_analyses.sh function.
Command:
bash $scriptdir/nonnormalized_table_diversity_analyses.sh <OTU_table> <output_dir> <mapping_file> <cores> <rarefaction_depth> <optional_tree>
bash $scriptdir/nonnormalized_table_diversity_analyses.sh $table $outdir $mapfile $cores $depth $tree
" >> $log
	bash $scriptdir/nonnormalized_table_diversity_analyses.sh $table $outdir $mapfile $cats $cores $depth $tree
	fi

	elif [[ $mode == "batch" ]]; then
	ls | grep "_otus_" > $tempdir/otupickdirs.temp
	echo > $tempdir/batch_tablecount.temp
	for line in `cat $tempdir/otupickdirs.temp`; do
	for otutabledir in `ls $line 2>/dev/null | grep "OTU_tables"`; do
	eachtablecount=`ls $line/$otutabledir/${input}_table_hdf5.biom 2>/dev/null | wc -l`
	if [[ $eachtablecount == 1 ]]; then
	echo $eachtablecount >> $tempdir/batch_tablecount.temp
	fi
	done
	done
	sed -i '/^\s*$/d' $tempdir/batch_tablecount.temp
	alltablescount=`cat $tempdir/batch_tablecount.temp | wc -l`
	if [[ $alltablescount == 0 ]]; then
	echo "
No OTU tables found matching the supplied prefix.  To perform batch
processing, execute cdiv_graphs_and_stats_workflow.sh from the same
directory you processed the rest of your data.  If you want to target
the tables matching \"03_table_hdf5.biom\" and the associated normalized
table, you would enter \"03\" as the prefix.

You supplied: $input

Exiting.
	"
	else
	echo "Processing core diversity analyses for $alltablescount OTU tables.
	"

	# Build list of tables to process
	echo > $tempdir/batch_tablelist.temp
	for line in `cat $tempdir/otupickdirs.temp`; do
	for otutabledir in `ls $line 2>/dev/null | grep "OTU_tables"`; do
	if [[ -f $line/$otutabledir/${input}_table_hdf5.biom ]]; then
	echo $line/$otutabledir/${input}_table_hdf5.biom >> $tempdir/batch_tablelist.temp
	fi
	done
	done

	# Process tables loop
	for table in `cat $tempdir/batch_tablelist.temp`; do
	## Check for valid input (file has .biom extension)
	biombase=`basename "$table" | cut -d. -f1`
	outbase=`basename "$table" | cut -d. -f1 | cut -d"_" -f1-2`
	biomextension="${table##*.}"
	biomname="${table%.*}"
	biomdir=$(dirname $table)
	## Summarize input table(s) if necessary and extract rarefaction depth from shallowest sample
	if [[ ! -f $biomdir/$biombase.summary ]]; then
	biom-summarize_folder.sh $biomdir &>/dev/null
	fi
	depth=`grep -A 1 "Counts/sample detail" $biomdir/$biombase.summary | sed '/Counts/d' | cut -d" " -f3 | cut -d. -f1`

	## Check for normalized table
	normbase=`echo $biombase | sed 's/hdf5/CSS/'`
	normcount=`ls $biomdir/$normbase.biom 2>/dev/null | wc -l`
	if [[ $normcount == "0" ]]; then
	normtable="None supplied"
	else
	normtable="$biomdir/$normbase.biom"
	fi

	## Set output directory
	outdir=$biomdir/core_diversity/$outbase
	outdir1=$biomdir/core_diversity
	mkdir -p $outdir

	echo "Input table: $table
Normalized table: $normtable
Output: $outdir
Rarefaction depth: $depth
	"
	echo "Input table: $table
Normalized table: $normtable
Output: $outdir
Rarefaction depth: $depth
	" >> $log
	echo "Calling normalized_table_beta_diversity.sh function.
"
	echo "Calling normalized_table_beta_diversity.sh function.
Command:
bash $scriptdir/normalized_table_beta_diversity.sh <normalized_table> <output_dir> <mapping_file> <cores> <optional_tree>
bash $scriptdir/normalized_table_beta_diversity.sh $normtable $outdir $mapfile $cores $tree
" >> $log
	bash $scriptdir/normalized_table_beta_diversity.sh $normtable $outdir $mapfile $cores $tree

	echo "Calling nonnormalized_table_diversity_analyses.sh function.
"
	echo "Calling nonnormalized_table_diversity_analyses.sh function.
Command:
bash $scriptdir/nonnormalized_table_diversity_analyses.sh <OTU_table> <output_dir> <mapping_file> <cores> <rarefaction_depth> <optional_tree>
bash $scriptdir/nonnormalized_table_diversity_analyses.sh $table $outdir $mapfile $cores $depth $tree
" >> $log
	bash $scriptdir/nonnormalized_table_diversity_analyses.sh $table $outdir $mapfile $cats $cores $depth $tree
	done
	fi
	fi

## Tidy up
#	if [[ -d cdiv_temp ]]; then
#	rm -r cdiv_temp
#	fi

exit 0

