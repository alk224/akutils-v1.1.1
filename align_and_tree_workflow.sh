#!/usr/bin/env bash
#
#  align_and_tree_workflow.sh - Align sequences, filter alignment, make phylogeny
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

## check whether user had supplied -h or --help. If yes display help 

	if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
	scriptdir="$( cd "$( dirname "$0" )" && pwd )"
	less $scriptdir/docs/otu_picking_workflow.help
		exit 0	
	fi

## If config supplied, run config utility instead

	if [[ "$1" == "config" ]]; then
		akutils_config_utility.sh
		exit 0
	fi

## If other than two arguments supplied, display usage 

	if [  "$#" -ne 2 ]; then 

	echo "
Usage:
align_and_tree_workflow.sh <target directory> <mode>

	Valid modes are 16S or other (cap sensitive).
	-- 16S will do PyNAST alignment using # threads in config file.
	-- other will do Mafft alignment and filter the top 10% entropic
	sites.
	-- Target directory must contain file(s) titled (*_rep_set.fna)
	-- If ALL (caps sensitive) is supplied for target directory,
	script will operate on all OTU subdirectories (*_otus_*).
	"
	exit 1
	fi

## Check that valid mode was entered

	if [[ $2 != other ]] && [[ $2 != 16S ]]; then
	echo "
Invalid mode entered (you entered $2).
Valid modes are 16S or other.

Usage:
align_and_tree_workflow.sh <target directory> <mode>

	Valid modes are 16S or other (cap sensitive).
	-- 16S will do PyNAST alignment using # threads in config file.
	-- other will do Mafft alignment and filter the top 10% entropic
	sites.
	-- Target directory must contain file(s) titled (*_rep_set.fna)
	-- If ALL (caps sensitive) is supplied for target directory,
	script will operate on all OTU subdirectories (*_otus_*).
	"
	exit 1
	fi

	mode=($2)

## Define working directory and log file
	workdir=$(pwd)
	date0=`date +%Y%m%d_%I%M%p`
	res1=$(date +%s.%N)

	log_count=`ls log_align_and_tree_workflow_* 2>/dev/null | wc -w`
	if [[ $log_count == 0 ]]; then
	log=($workdir/log_align_and_tree_workflow_$date0.txt)
	elif [[ $log_count == 1 ]]; then
	log=`ls log_align_and_tree_workflow_*`
	elif [[ $log_count -ge 2 ]]; then
	echo "
Surprised to find multiple log files for this workflow present in the
current directory.  There may be just one such file where you execute
this workflow.  Delete or move the ones you don't want appended and
rerun your command.  Exiting.
	"
	exit 1
	fi

## Check if ALL was supplied or if target directory is directory

if [[ $1 != "ALL" ]] && [[ ! -d $1 ]]; then
	echo "
Invalid target supplied (you entered $1).
Valid targets are any directory or \"ALL\"

Usage:
align_and_tree_workflow.sh <target directory> <mode>

	Valid modes are 16S or other (cap sensitive).
	-- 16S will do PyNAST alignment using # threads in config file.
	-- other will do Mafft alignment and filter the top 10% entropic
	sites.
	-- Target directory must contain file(s) titled (*_rep_set.fna)
	-- If ALL (caps sensitive) is supplied for target directory,
	script will operate on all OTU subdirectories (*_otus_*).
	"
	exit 1
fi

## Read in variables from config file

	local_config_count=`ls akutils*.config 2>/dev/null | wc -w`
	if [[ $local_config_count == "1" ]]; then

	config=`ls akutils*.config`

	echo "Using local akutils config file.
$config
	"
	echo "
Referencing local akutils config file.
$config
	" >> $log
	else
		global_config_count=(`ls $scriptdir/akutils_resources/akutils*.config 2>/dev/null | wc -w`)
		if [[ $global_config_count -ge 1 ]]; then

		config=`ls $scriptdir/akutils_resources/akutils*.config`

		echo "Using global akutils config file.
$config
		"
		echo "
Referencing global akutils config file.
$config
		" >> $log
		fi
	fi

## Import variables from config file and send useful feedback if there is a problem

	template=(`grep "Alignment_template" $config | grep -v "#" | cut -f 2`)
	lanemask=(`grep "Alignment_lanemask" $config | grep -v "#" | cut -f 2`)
	threads=(`grep "CPU_cores" $config | grep -v "#" | cut -f 2`)

	if [[ $mode == "16S" ]]; then
	if [[ $template == "undefined" ]] && [[ ! -z $template ]]; then
	echo "
Alignment template has not been defined.  Define it in your akutils
config file.  To update definitions, run:

akutils_config_utility.sh

If you just updated akutils be sure to select \"rebuild\" on your global
config file to update the available variables.  Exiting.
	"
	exit 1
	fi
	if [[ $lanemask == "undefined" ]] && [[ ! -z $lanemask ]]; then
	echo "
Alignment lanemask has not been defined.  Define it in your akutils
config file.  To update definitions, run:

akutils_config_utility.sh

If you just updated akutils be sure to select \"rebuild\" on your global
config file to update the available variables.  Exiting.
	"
	exit 1
	fi
	fi

	if [[ $threads == "undefined" ]] && [[ ! -z $threads ]]; then
	echo "
Threads to use during alignment has not been defined.  Define it in your
akutils config file.  To update definitions, run:

akutils_config_utility.sh

If you just updated akutils be sure to select \"rebuild\" on your global
config file to update the available variables.

Defaulting to 1 thread.
	"
	threads="1"
	fi

## Workflow for single target directory

if [[ -d $1 ]]; then
	echo "Beginning align and tree workflow on supplied directory in \"$mode\" mode.
Indir: $1"
	date "+%a %b %d %I:%M %p %Z %Y"
	echo ""
	echo "Beginning align and tree workflow on supplied directory in \"$mode\" mode.
Indir: $1" >> $log
	date "+%a %b %d %I:%M %p %Z %Y" >> $log
	echo "" >> $log

	## Check for rep_set file and assign variable if OK, exit if not.

	repset_count=`ls $1/*_rep_set.fna 2>/dev/null | wc -l`
	if [[ $repset_count -eq "0" ]]; then
	echo "No representative sequences file found.  Make sure there is a file
present in the target directory titled *_rep_set.fna where \"*\" is any
preceding character(s).  Exiting.
	"
	echo "No representative sequences file found.  Make sure there is a file
present in the target directory titled *_rep_set.fna where \"*\" is any
preceding character(s).  Exiting.
	" >> $log
	exit 1
	fi

	## For loop to process all rep sets in target directory

	for  repset_file in `ls $1/*_rep_set.fna 2>/dev/null`; do
	repset_base=`basename $repset_file .fna`
	seqcount0=`cat $repset_file | wc -l`
	seqcount=`expr $seqcount0 / 2`

	## 16S mode:
	if [[ $mode == "16S" ]]; then

	## Align sequences command and check that output is not an empty file
	res2=$(date +%s.%N)
	if [[ ! -f $1/pynast_alignment/${repset_base}_aligned.fasta ]]; then
	echo "Infile: $repset_file
Outdir: $1/pynast_alignment/
Aligning $seqcount sequences with PyNAST on $threads threads.
	"
	echo "Infile: $repset_file
Outdir: $1/pynast_alignment/
Aligning $seqcount sequences with PyNAST on $threads threads.

Align sequences command:
	parallel_align_seqs_pynast.py -i $repset_file -o $1/pynast_alignment -t $template -O $threads
" >> $log
	parallel_align_seqs_pynast.py -i $repset_file -o $1/pynast_alignment -t $template -O $threads
	else
	echo "Previous alignment output detected.
File: $1/pynast_alignment/${repset_base}_aligned.fasta
	"
	fi

	if [[ ! -s $1/pynast_alignment/${repset_base}_aligned.fasta ]]; then
	echo "No valid alignment produced.  Check your inputs and try again.  Exiting.
	"
	exit 1
	fi

res3=$(date +%s.%N)
dt=$(echo "$res3 - $res2" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

runtime=`printf "Alignment runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`
echo "$runtime
" >> $log

	## Filter alignment command
	res2=$(date +%s.%N)
	if [[ ! -f $1/pynast_alignment/${repset_base}_aligned_pfiltered.fasta ]]; then
	echo "Filtering alignment against supplied lanemask file.
	"
	echo "Filter alignment command:
	filter_alignment.py -i $1/pynast_alignment/${repset_base}_aligned.fasta -m $lanemask -o $1/pynast_alignment/
" >> $log
	filter_alignment.py -i $1/pynast_alignment/${repset_base}_aligned.fasta -m $lanemask -o $1/pynast_alignment/
	else
	echo "Alignment previously filtered.
	"
	fi

res3=$(date +%s.%N)
dt=$(echo "$res3 - $res2" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

runtime=`printf "Filter alignment runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`
echo "$runtime
" >> $log

	## Make phylogeny command
	res2=$(date +%s.%N)
	if [[ ! -f $1/pynast_alignment/fasttree_phylogeny.tre ]]; then
	echo "Building phylogenetic tree with fasttree.
	"
	echo "Make phylogeny command:
	make_phylogeny.py -i $1/pynast_alignment/${repset_base}_aligned_pfiltered.fasta -t fasttree -o $1/pynast_alignment/fasttree_phylogeny.tre
" >> $log
	make_phylogeny.py -i $1/pynast_alignment/${repset_base}_aligned_pfiltered.fasta -t fasttree -o $1/pynast_alignment/fasttree_phylogeny.tre
	else
	echo "Phylogeny previously completed.
file: $1/pynast_alignment/fasttree_phylogeny.tre
	"
	fi

res3=$(date +%s.%N)
dt=$(echo "$res3 - $res2" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

runtime=`printf "Make phylogeny runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`
echo "$runtime
" >> $log

	## "other" mode:
	elif [[ $mode == "other" ]]; then

	## Align sequences command and check that output is not an empty file
	res2=$(date +%s.%N)
	if [[ ! -f $1/mafft_alignment/${repset_base}_aligned.fasta ]]; then
	echo "Infile: $repset_file
Outdir: $1/mafft_alignment/
Aligning $seqcount sequences with MAFFT on $threads threads.
	"
	echo "Infile: $repset_file
Outdir: $1/mafft_alignment/
Aligning $seqcount sequences with MAFFT on $threads threads.

Align sequences command (MAFFT command):
	mafft --thread $threads --parttree --retree 2 --partsize 1000 --alga $repset_file > $1/mafft_alignment/${repset_base}_aligned.fasta 2>$1/mafft_alignment/alignment_log_${repset_base}.txt
" >> $log
	mkdir -p $1/mafft_alignment
	mafft --thread $threads --parttree --retree 2 --partsize 1000 --alga $repset_file > $1/mafft_alignment/${repset_base}_aligned.fasta 2>$1/mafft_alignment/alignment_log_${repset_base}.txt
	else
	echo "Previous alignment output detected.
File: $1/mafft_alignment/${repset_base}_aligned.fasta
	"
	fi

	if [[ ! -s $1/mafft_alignment/${repset_base}_aligned.fasta ]]; then
	echo "No valid alignment produced.  Check your inputs and try again.  Exiting.
	"
	exit 1
	fi

res3=$(date +%s.%N)
dt=$(echo "$res3 - $res2" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

runtime=`printf "Alignment runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`
echo "$runtime
" >> $log

	## Filter alignment command
	res2=$(date +%s.%N)
	if [[ ! -f $1/mafft_alignment/${repset_base}_aligned_pfiltered.fasta ]]; then
	echo "Filtering top 10% entropic sites from alignment.
	"
	echo "Filter alignment command:
	filter_alignment.py -i $1/mafft_alignment/${repset_base}_aligned.fasta -e 0.1 -o $1/mafft_alignment/
" >> $log
	filter_alignment.py -i $1/mafft_alignment/${repset_base}_aligned.fasta -e 0.1 -o $1/mafft_alignment/
	else
	echo "Alignment previously filtered.
	"
	fi

res3=$(date +%s.%N)
dt=$(echo "$res3 - $res2" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

runtime=`printf "Filter alignment runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`
echo "$runtime
" >> $log

	## Make phylogeny command
	res2=$(date +%s.%N)
	if [[ ! -f $1/mafft_alignment/fasttree_phylogeny.tre ]]; then
	echo "Building phylogenetic tree with fasttree.
	"
	echo "Make phylogeny command:
	make_phylogeny.py -i $1/mafft_alignment/${repset_base}_aligned_pfiltered.fasta -t fasttree -o $1/mafft_alignment/fasttree_phylogeny.tre
" >> $log
	make_phylogeny.py -i $1/mafft_alignment/${repset_base}_aligned_pfiltered.fasta -t fasttree -o $1/mafft_alignment/fasttree_phylogeny.tre
	else
	echo "Phylogeny previously completed.
file: $1/mafft_alignment/fasttree_phylogeny.tre
	"
	fi

res3=$(date +%s.%N)
dt=$(echo "$res3 - $res2" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

runtime=`printf "Make phylogeny runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`
echo "$runtime
" >> $log
	fi

	## End of for loop for target directory
	done

## Workflow for ALL otu picking subdirectories

elif [[ $1 == "ALL" ]]; then
	echo "Beginning align and tree workflow on all subdirectories in \"$mode\" mode.
Indir: ALL subdirectories containing \"*_otus_*\""
	date "+%a %b %d %I:%M %p %Z %Y"
	echo ""
	echo "Beginning align and tree workflow on all subdirectories in \"$mode\" mode.
Indir: ALL subdirectories containing \"*_otus_*\"" >> $log
	date "+%a %b %d %I:%M %p %Z %Y" >> $log
	echo "" >> $log

for otudir in `ls | grep "_otus_"`; do

	if [[ -d $otudir ]]; then
	for  repset_file in `ls $otudir/*_rep_set.fna 2>/dev/null`; do
	repset_base=`basename $repset_file .fna`
	seqcount0=`cat $repset_file | wc -l`
	seqcount=`expr $seqcount0 / 2`

	## 16S mode:
	if [[ $mode == "16S" ]]; then

	## Align sequences command and check that output is not an empty file
	res2=$(date +%s.%N)
	if [[ ! -f $otudir/pynast_alignment/${repset_base}_aligned.fasta ]]; then
	echo "Infile: $repset_file
Outdir: $otudir/pynast_alignment/
Aligning $seqcount sequences with PyNAST on $threads threads.
	"
	echo "Infile: $repset_file
Outdir: $otudir/pynast_alignment/
Aligning $seqcount sequences with PyNAST on $threads threads.

Align sequences command:
	parallel_align_seqs_pynast.py -i $repset_file -o $otudir/pynast_alignment -t $template -O $threads
" >> $log
	parallel_align_seqs_pynast.py -i $repset_file -o $otudir/pynast_alignment -t $template -O $threads
	else
	echo "Previous alignment output detected.
File: $otudir/pynast_alignment/${repset_base}_aligned.fasta
	"
	fi

	if [[ ! -s $otudir/pynast_alignment/${repset_base}_aligned.fasta ]]; then
	echo "No valid alignment produced.  Check your inputs and try again.  Exiting.
	"
	exit 1
	fi

res3=$(date +%s.%N)
dt=$(echo "$res3 - $res2" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

runtime=`printf "Alignment runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`
echo "$runtime
" >> $log

	## Filter alignment command
	res2=$(date +%s.%N)
	if [[ ! -f $otudir/pynast_alignment/${repset_base}_aligned_pfiltered.fasta ]]; then
	echo "Filtering alignment against supplied lanemask file.
	"
	echo "Filter alignment command:
	filter_alignment.py -i $otudir/pynast_alignment/${repset_base}_aligned.fasta -m $lanemask -o $otudir/pynast_alignment/
" >> $log
	filter_alignment.py -i $otudir/pynast_alignment/${repset_base}_aligned.fasta -m $lanemask -o $otudir/pynast_alignment/
	else
	echo "Alignment previously filtered.
	"
	fi

res3=$(date +%s.%N)
dt=$(echo "$res3 - $res2" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

runtime=`printf "Filter alignment runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`
echo "$runtime
" >> $log

	## Make phylogeny command
	res2=$(date +%s.%N)
	if [[ ! -f $otudir/pynast_alignment/fasttree_phylogeny.tre ]]; then
	echo "Building phylogenetic tree with fasttree.
	"
	echo "Make phylogeny command:
	make_phylogeny.py -i $otudir/pynast_alignment/${repset_base}_aligned_pfiltered.fasta -t fasttree -o $otudir/pynast_alignment/fasttree_phylogeny.tre
" >> $log
	make_phylogeny.py -i $otudir/pynast_alignment/${repset_base}_aligned_pfiltered.fasta -t fasttree -o $otudir/pynast_alignment/fasttree_phylogeny.tre
	else
	echo "Phylogeny previously completed.
file: $otudir/pynast_alignment/fasttree_phylogeny.tre
	"
	fi

res3=$(date +%s.%N)
dt=$(echo "$res3 - $res2" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

runtime=`printf "Make phylogeny runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`
echo "$runtime
" >> $log

	## "other" mode:
	elif [[ $mode == "other" ]]; then

	## Align sequences command and check that output is not an empty file
	res2=$(date +%s.%N)
	if [[ ! -f $otudir/mafft_alignment/${repset_base}_aligned.fasta ]]; then
	echo "Infile: $repset_file
Outdir: $otudir/mafft_alignment/
Aligning $seqcount sequences with MAFFT on $threads threads.
	"
	echo "Infile: $repset_file
Outdir: $otudir/mafft_alignment/
Aligning $seqcount sequences with MAFFT on $threads threads.

Align sequences command (MAFFT command):
	mafft --thread $threads --parttree --retree 2 --partsize 1000 --alga $repset_file > $otudir/mafft_alignment/${repset_base}_aligned.fasta
" >> $log
	mkdir -p $otudir/mafft_alignment
	mafft --thread $threads --parttree --retree 2 --partsize 1000 --alga $repset_file > $otudir/mafft_alignment/${repset_base}_aligned.fasta 2>$otudir/mafft_alignment/alignment_log_${repset_base}.txt
	else
	echo "Previous alignment output detected.
File: $otudir/mafft_alignment/${repset_base}_aligned.fasta
	"
	fi

	if [[ ! -s $otudir/mafft_alignment/${repset_base}_aligned.fasta ]]; then
	echo "No valid alignment produced.  Check your inputs and try again.  Exiting.
	"
	exit 1
	fi

res3=$(date +%s.%N)
dt=$(echo "$res3 - $res2" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

runtime=`printf "Alignment runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`
echo "$runtime
" >> $log

	## Filter alignment command
	res2=$(date +%s.%N)
	if [[ ! -f $otudir/mafft_alignment/${repset_base}_aligned_pfiltered.fasta ]]; then
	echo "Filtering top 10% entropic sites from alignment.
	"
	echo "Filter alignment command:
	filter_alignment.py -i $otudir/mafft_alignment/${repset_base}_aligned.fasta -e 0.1 -o $otudir/mafft_alignment/
" >> $log
	filter_alignment.py -i $otudir/mafft_alignment/${repset_base}_aligned.fasta -e 0.1 -o $otudir/mafft_alignment/
	else
	echo "Alignment previously filtered.
	"
	fi

res3=$(date +%s.%N)
dt=$(echo "$res3 - $res2" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

runtime=`printf "Filter alignment runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`
echo "$runtime
" >> $log

	## Make phylogeny command
	res2=$(date +%s.%N)
	if [[ ! -f $otudir/mafft_alignment/fasttree_phylogeny.tre ]]; then
	echo "Building phylogenetic tree with fasttree.
	"
	echo "Make phylogeny command:
	make_phylogeny.py -i $otudir/mafft_alignment/${repset_base}_aligned_pfiltered.fasta -t fasttree -o $otudir/mafft_alignment/fasttree_phylogeny.tre
" >> $log
	make_phylogeny.py -i $otudir/mafft_alignment/${repset_base}_aligned_pfiltered.fasta -t fasttree -o $otudir/mafft_alignment/fasttree_phylogeny.tre
	else
	echo "Phylogeny previously completed.
file: $otudir/mafft_alignment/fasttree_phylogeny.tre
	"
	fi

res3=$(date +%s.%N)
dt=$(echo "$res3 - $res2" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

runtime=`printf "Make phylogeny runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`
echo "$runtime
" >> $log
	fi

	## End of for loop for target directory
	done
fi
done
fi

## Log end of workflow and print time

res25=$(date +%s.%N)
dt=$(echo "$res25 - $res1" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

runtime=`printf "Total runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`

echo "All workflow steps completed.  Hooray!

$runtime
"
echo "---

All workflow steps completed.  Hooray!" >> $log
date "+%a %b %d %I:%M %p %Z %Y" >> $log
echo "
$runtime 
" >> $log

