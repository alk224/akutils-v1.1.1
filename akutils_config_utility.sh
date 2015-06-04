#!/usr/bin/env bash
#
#  akutils_config_utility.sh - Utility to configure akutils parameters
#
#  Version 1.0 (June 5, 2015)
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

## Needs help info and usage still...
## This whole script could use some major revision, but it does work for now.

# check whether user had supplied -h or --help. If yes display help 

	if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
	scriptdir="$( cd "$( dirname "$0" )" && pwd )"
	less $scriptdir/docs/akutils_config_utility.help
	exit 0
	fi 

## Set working directory
	workdir=(`pwd`)

## Check for config file (in subdirectory called "akutils_resources stored in directory where script is located )

scriptdir="$( cd "$( dirname "$0" )" && pwd )"
globalconfigsearch=(`ls $scriptdir/akutils_resources/akutils*.config 2>/dev/null`)
localconfigsearch=(`ls akutils*.config 2>/dev/null`)
DATE=`date +%Y%m%d-%I%M%p`

## If user passes read, then display the configured settings

if [[ $1 == "read" ]]; then

	# determine if reading local or global config
	if [[ -f $localconfigsearch ]]; then
	readfile=$localconfigsearch
	echo "
Reading akutils configurable fields from local config file.
$readfile
	"
	else
	readfile=$scriptdir/akutils_resources/akutils.global.config
	echo "
Reading akutils configurable fields from global config file.
$readfile
	"
	fi

	echo ""
	grep -v "#" $readfile | sed '/^$/d'
	echo ""
	exit 0
	
fi

## Start config process

echo "
This will help you configure your akutils config file for running akutils
workflows.

First, would you like to configure your global settings or make
a local config file to override your global settings?  A local
config file will reside within your current directory.

Or else, you can choose rebuild if you want to generate a fresh
global config file.  This is useful if you just updated akutils
and you desire new configuration options to be available.

Enter \"global,\" \"local,\" or \"rebuild.\"
"

## Determine input
read globallocal

if [[ ! $globallocal == "global" && ! $globallocal == "local" && ! $globallocal == "rebuild" ]]; then
		echo "Invalid entry.  global, local, or rebuild only."
		read yesno
	if [[ ! $globallocal == "global" && ! $globallocal == "local" && ! $globallocal == "rebuild" ]]; then
		echo "Invalid entry.  Exiting.
		"
		exit 1
	fi
fi

if [[ $globallocal == rebuild ]]; then
	echo "
OK.  Building new global config file in akutils resources directory.
($scriptdir/akutils_resources/)
	"
	sleep 1
	
	rm $scriptdir/akutils_resources/akutils.global.config 2>/dev/null
	cat $scriptdir/akutils_resources/blank_config.config > $scriptdir/akutils_resources/akutils.global.config
	configfile=($scriptdir/akutils_resources/akutils.global.config)

fi

if [[ $globallocal == global ]]; then
	echo "
OK.  Checking for existing global config file in akutils resources
directory.
($scriptdir/akutils_resources/)
	"
	sleep 1


if [[ ! -f $globalconfigsearch ]]; then
	echo "
No config file detected in akutils resources directory.
($scriptdir/akutils_resources/)

Shall I create a new one for you (yes or no)?"

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
		echo "		OK.  Creating global akutils config file.
		($scriptdir/akutils_resources/akutils.global.config)
		"
		cat $scriptdir/akutils_resources/blank_config.config > $scriptdir/akutils_resources/akutils.global.config
		configfile=($scriptdir/akutils_resources/akutils.global.config)
		fi

		if [[ $yesno == "no" ]]; then
		echo "
OK.  Please enter the path of the config file you want to update.
		"
		read -e configfile
		fi

	else
	echo "Found config file."
	echo "$globalconfigsearch
	"
	sleep 1
	configfile=($globalconfigsearch)
fi
fi

if [[ $globallocal == local ]]; then
	echo "
OK.  Checking for existing config file in current directory.
($workdir/)
	"
	sleep 1

if [[ ! -f $localconfigsearch ]]; then
	echo "
No config file detected in local directory.  Shall I create one for
you (yes or no)?"
		read yesno
	
		if [[ ! $yesno == "yes" && ! $yesno == "no" ]]; then
			echo "Invalid entry.  Yes or no only."
			read yesno
			if [[ ! $yesno == "yes" && ! $yesno == "no" ]]; then
				echo "Invalid entry.  Exiting.
				"
				exit 1
			fi
		fi

		if [[ $yesno == "yes" ]]; then

			if [[ -e $scriptdir/akutils_resources/akutils.global.config ]]; then
			echo "		
Found global config file.
($scriptdir/akutils_resources/akutils.global.config)

Do you want to generate a whole new config file or make a copy of the
existing global file and modify that (new or copy)?"
			read newcopy

				if [[ ! $newcopy == "new" && ! $newcopy == "copy" ]]; then
					echo "Invalid entry.  new or copy only."
					read yesno
					if [[ ! $newcopy == "new" && ! $newcopy == "copy" ]]; then
						echo "Invalid entry.  Exiting.
						"
						exit 1
					fi
				fi
			fi

		if [[ $newcopy == "new" ]]; then
			echo "
OK.  Creating new config file in your current directory.
($workdir/akutils.$DATE.config)
		"
			cat $scriptdir/akutils_resources/blank_config.config > $workdir/akutils.$DATE.config
			configfile=($workdir/akutils.$DATE.config)
		fi

		if [[ $newcopy == "copy" ]]; then
			echo "
OK.  Copying global config file for local use in your current
directory.
($workdir/akutils.$DATE.config)
		"
			cat $scriptdir/akutils_resources/akutils.global.config > $workdir/akutils.$DATE.config
			configfile=($workdir/akutils.$DATE.config)
		fi


		if [[ $yesno == "no" ]]; then
			echo "
OK.  Please enter the path of the config file you want to update.
		"
			read -e configfile
		fi
	fi
	else
	echo "Found config file."
	echo "$localconfigsearch
	"
	sleep 1
	configfile=($localconfigsearch)
	fi

fi


	echo "
File selected is:
$configfile
Reading configurable fields...
	"
	sleep 1
	cat $configfile | grep -v "#" | grep -E -v '^$'

	echo "
I will now go through each configurable field and require your input.
Press enter to retain the current value or enter a new value.  When
entering paths (say, to greengenes database) use absolute path and
remember to use tab-autocomplete to avoid errors.
	"



for field in `grep -v "#" $configfile | cut -f 1`; do
	fielddesc=`grep $field $configfile | grep "#" | cut -f 2-3`

	echo "Field: $fielddesc"
	setting=`grep $field $configfile | grep -v "#" | cut -f 2`
	echo "
Current setting is: $setting

Enter new value (or press enter to keep current setting):

	"
	read -e newsetting
	if [[ ! -z "$newsetting" ]]; then
	sed -i -e "s@^$field\t$setting@$field\t$newsetting@" $configfile
	echo "Setting changed.
	"
	else
	echo "Setting unchanged.
	"
	fi
done

echo "$configfile updated.
"
exit 0
