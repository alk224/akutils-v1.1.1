#!/usr/bin/env bash
#
#  align_and_tree_workflow.sh - Align sequences, filter alignment, make phylogeny
#
#  Version 1.0.0 (June 14, 2015)
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
	-- If ALL (caps sensitive) is supplied for target directory,
	script will operate on all OTU subdirectories (*_otus_*).
	"
	exit 1
	fi

## Check that valid mode was entered

	if [[ $2 != other && $2 != 16S ]]; then
	echo "
Invalid mode entered (you entered $2).
Valid modes are 16S, or other.

Usage:
align_and_tree_workflow.sh <target directory> <mode>

	Valid modes are 16S or other (cap sensitive).
	-- 16S will do PyNAST alignment using # threads in config file.
	-- other will do Mafft alignment and filter the top 10% entropic
	sites.
	-- If ALL (caps sensitive) is supplied for target directory,
	script will operate on all OTU subdirectories (*_otus_*).
	"
	exit 1
	fi

	mode=($2)

## Define working directory and log file
	workdir=$(pwd)
	date0=`date +%Y%m%d_%I%M%p`
	log=($workdir/log_align_and_tree_workflow_$date0.txt)
	res1=$(date +%s.%N)

## Check if ALL was supplied or if target directory is directory

if [[ $1 != "ALL" && ! -d $1 ]]; then
	echo "
Invalid target supplied (you entered $1).
Valid targets are any directory or \"ALL\"

Usage:
align_and_tree_workflow.sh <target directory> <mode>

	Valid modes are 16S or other (cap sensitive).
	-- 16S will do PyNAST alignment using # threads in config file.
	-- other will do Mafft alignment and filter the top 10% entropic
	sites.
	-- If ALL (caps sensitive) is supplied for target directory,
	script will operate on all OTU subdirectories (*_otus_*).
	"
	exit 1
fi

## Read in variables from config file

	local_config_count=(`ls $1/akutils*.config 2>/dev/null | wc -w`)
	if [[ $local_config_count -ge 1 ]]; then

	config=`ls $1/akutils*.config`

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

	template=(`grep "Alignment_template" $config | grep -v "#" | cut -f 2`)
	lanemask=(`grep "Alignment_lanemask" $config | grep -v "#" | cut -f 2`)
	threads=(`grep "Threads_align_seqs" $config | grep -v "#" | cut -f 2`)

## Workflow for single target directory

if [[ -d $1 ]]; then
	echo "
Beginning align and tree workflow on supplied directory in \"$mode\" mode.
($1)
	"




## Workflow for ALL otu picking subdirectories

elif [[ $1 == "ALL" ]]; then
	echo "
Beginning align and tree workflow on all subdirectories in \"$mode\" mode.
($1)
	"





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

