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
Usage (order is important!!):
chained_workflow-swarm.sh <input folder> <mode>
	"
	exit 1
	fi

## Check that valid mode was entered

	if [[ $2 != other && $2 != 16S && $2 != ITS ]]; then
	echo "
Invalid mode entered (you entered $2).
Valid modes are 16S, ITS, or other.

Usage (order is important!!):
chained_workflow-swarm.sh <input folder> <mode>
	"
	exit 1
	fi

	mode=($2)

## Define working directory and log file
	workdir=$(pwd)
	cd $1
	outdir=$(pwd)
	cd $workdir
