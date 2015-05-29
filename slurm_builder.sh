#!/usr/bin/env bash
#
#  slurm_builder.sh - Utility to generate an sbatch file for use on systems that use SLURM for job queuing
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

## Interactive tool to generate a slurm file for use on monsoon

set -e

## check whether user had supplied -h or --help. If yes display help 

	if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
		echo "
		slurm_builder.sh

		This script helps a user to build a slurm file appropriate
		for their job.  It will be appropriate for use on the
		monsoon cluster at NAU.  It can generate a new slurm
		script for you or modify an existing one.  In order to be
		modified by this script, your existing slurm script must be
		called slurm_script*.sh (where * is any character).

		Usage:
		slurm_builder.sh
		"
		exit 0	
	fi

## If other than two arguments supplied, display usage 

	if [  "$#" -ne 0 ]; then 

		echo "
		Usage:
		slurm_builder.sh
		"
		exit 1
	fi

## Set working directory
	workdir=(`pwd`)

## Check for local slurm file and template file

scriptdir="$( cd "$( dirname "$0" )" && pwd )"
slurmtemplate=(`ls $scriptdir/akutils_resources/slurm_template.txt 2>/dev/null`)
localslurmcount=(`ls slurm_script*.sh 2>/dev/null | wc -l`)
DATE=`date +%Y%m%d-%I%M%p`

## Check for existing slurm script

if [[ $localslurmcount == 0 ]]; then
	echo "
		No slurm script detected in local directory.
		Shall I create one for you (yes or no)?"
		read yesno
	
		if [[ ! $yesno == "yes" && ! $yesno == "no" ]]; then
			echo "		Invalid entry.  Yes or no only."
			read yesno
			if [[ ! $yesno == "yes" && ! $yesno == "no" ]]; then
				echo "		Invalid entry.  Exiting.
				"
				exit 1
			fi
		fi

		if [[ $yesno == "yes" ]]; then
			echo "		Creating new slurm script.
		$workdir/slurm_script_$DATE.sh
		"
		touch $workdir/slurm_script_$DATE.sh
		slurm=($workdir/slurm_script_$DATE.sh)
		cat $slurmtemplate > $slurm

		fi

		if [[ $yesno == "no" ]]; then
			echo "		OK.  Make it yourself then!
		Exiting.
		"
			exit 0
		fi
	else
		if [[ $localslurmcount -ge 2 ]]; then
		echo "
		Found multiple slurm script files.  Delete the one(s)
		you don't want/need and start over.
		"
		exit 1
		fi
	localslurmsearch=(`ls slurm_script*.sh 2>/dev/null`)
	slurm=($localslurmsearch)
	echo "
		Found local slurm script file."
	echo "		$slurm
	"
	sleep 1

fi

## Interactive data entry

	echo "		I will ask you several questions.  Enter a response
		to change the applicable field, or press <enter>
		to leave that field unchanged.
	"
	sleep 1

## job name
	currentjob=(`grep -e "--job-name" $slurm | cut -d "=" -f 2`)
	echo "
		Enter a name for this job (8 letters or less is best).
		Current value is $currentjob:
	"
	read newjob
	if [[ ! -z "$newjob" ]]; then
	sed -i -e "s/job-name=$currentjob/job-name=$newjob/g" $slurm
	echo "		Setting changed.
	"
	else
	echo "		Setting unchanged.
	"
	fi

## job time
	currenttime=(`grep -e "--time" $slurm | cut -d "=" -f 2`)
	echo "
		Enter how long you think this job might need in minutes
		(1440 = 1 day, 7200 = 5 days).
		Current value is $currenttime:
	"
	read newtime
	if [[ ! -z "$newtime" ]]; then
	sed -i -e "s/--time=$currenttime/--time=$newtime/g" $slurm
	echo "		Setting changed.
	"
	else
	echo "		Setting unchanged.
	"
	fi

## job RAM
	currentram=(`grep -e "--mem-per-cpu" $slurm | cut -d "=" -f 2`)
	echo "
		Enter the amount of RAM per CPU you need in MB
		(12000 is default).
		Current value is $currentram:
	"
	read newram
	if [[ ! -z "$newram" ]]; then
	sed -i -e "s/--mem-per-cpu=$currentram/--mem-per-cpu=$newram/g" $slurm
	echo "		Setting changed.
	"
	else
	echo "		Setting unchanged.
	"
	fi

## job CPUs
	currentcpu=(`grep -e "--cpus-per-task" $slurm | cut -d "=" -f 2`)
	echo "
		Enter the number of CPUs your job requires
		(32 available per node).
		Current value is $currentcpu:
	"
	read newcpu
	if [[ ! -z "$newcpu" ]]; then
	sed -i -e "s/--cpus-per-task=$currentcpu/--cpus-per-task=$newcpu/g" $slurm
	echo "		Setting changed.
	"
	else
	echo "		Setting unchanged.
	"
	fi


## job partition
	currentpartition=(`grep -e "--partition" $slurm | cut -d "=" -f 2`)
	echo "
		Enter the partition your job should run on
		(valid choices are debug, express, long, all, or himem).
		Current value is $currentpartition:
	"
	read newpartition
	if [[ ! -z "$newpartition" ]]; then
	sed -i -e "s/--partition=$currentpartition/--partition=$newpartition/g" $slurm
	echo "		Setting changed.
	"
	else
	echo "		Setting unchanged.
	"
	fi

## command
#	currentcommand=(`grep -e "srun" $slurm`) # | cut -d " " -f 2-100`)
#	echo "
#		Enter the command youyou wish to run (without srun)		
#		Current command is:
#		$currentcommand
#	"
#	read -e newcommand
#	if [[ ! -z "$newcommand" ]]; then
#	sed -i -e "s/srun $currentcommand/srun $newcommand/g" $slurm
#	echo "		Setting changed.
#	"
#	else
#	echo "		Setting unchanged.
#	"
#	fi

	sed -i "s@--output=.*@--output=$workdir/std_err.txt@g" $slurm
	sed -i "s@--workdir=.*@--workdir=$workdir/@g" $slurm


## set executable
chmod a+x $slurm

echo "
		$slurm options updated.
		Working directory is defined as
		$workdir.

		Still need to update your srun command.

		Change this in a text editor so that your command appears:
		srun <yourcommand> <commandoptions>

"

exit 0
