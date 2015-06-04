#!/usr/bin/env bash
#
#  akutils_dependency_check.sh - Test if your system will run akutils workflows
#
#  Version 0.1.0 (June 3, 2015)
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
	less $scriptdir/docs/akutils_dependency_check.help
	exit 0
	fi 

## Check whether user had supplied result. If yes display result 

	if [[ "$1" == "--result" ]]; then
	scriptdir="$( cd "$( dirname "$0" )" && pwd )"
	resultcount=`ls $scriptdir/akutils_resources/akutils.dependencies.result 2>/dev/null | wc -l`
		if [[ $resultcount == 0 ]]; then
		echo "
Dependency check has not been run previously.  Execute
akutils_dependency_check.sh to generate results.
		"
		elif [[ $resultcount == 1 ]]; then
		less $scriptdir/akutils_resources/akutils.dependencies.result
		fi
		exit 0
	fi 

## Find scripts location

scriptdir="$( cd "$( dirname "$0" )" && pwd )"

## Loop through full dependency list
echo "
Checking for required dependencies...
"
rm $scriptdir/akutils_resources/akutils.dependencies.result
for line in `cat $scriptdir/akutils_resources/akutils.dependencies.list | cut -f1`; do
#	scriptuse=`grep "$line" $scriptdir/akutils_resources/akutils.dependencies.list | cut -f2`
	titlecount=`echo $line | grep "#" | wc -l`
	if [[ $titlecount == 1 ]]; then
	echo "" >> $scriptdir/akutils_resources/akutils.dependencies.result
	grep "$line" $scriptdir/akutils_resources/akutils.dependencies.list >> $scriptdir/akutils_resources/akutils.dependencies.result
	elif [[ $titlecount == 0 ]]; then
	dependcount=`command -v $line 2>/dev/null | wc -w`
	if [[ $dependcount == 0 ]]; then
	echo "$line	FAIL" >> $scriptdir/akutils_resources/akutils.dependencies.result
	else
	if [[ $dependcount -ge 1 ]]; then
	echo "$line	pass" >> $scriptdir/akutils_resources/akutils.dependencies.result
	fi
	fi
	fi
done
echo "" >> $scriptdir/akutils_resources/akutils.dependencies.result
#sed -i "1i \t" $scriptdir/akutils_resources/akutils.dependencies.result

## Count results
	dependencycount=`grep -v "#" $scriptdir/akutils_resources/akutils.dependencies.list | sed '/^$/d' | wc -l`
	passcount=`grep "pass" $scriptdir/akutils_resources/akutils.dependencies.result | wc -l`
	failcount=`grep "FAIL" $scriptdir/akutils_resources/akutils.dependencies.result | wc -l`

if [[ $failcount == 0 ]]; then
	sed -i "1i No failures!  akutils workflows should run OK." $scriptdir/akutils_resources/akutils.dependencies.result
elif [[ $failcount -ge 1 ]]; then
	sed -i "1i Some dependencies are not in your path.  Correct failures and rerun\ndependency check." $scriptdir/akutils_resources/akutils.dependencies.result
fi

sed -i "1i Dependency check results for akutils:\n\nTested $dependencycount dependencies\nPassed: $passcount/$dependencycount\nFailed: $failcount/$dependencycount" $scriptdir/akutils_resources/akutils.dependencies.result



echo "Test complete.

For results, execute:
akutils_dependency_check.sh --result
"

exit 0

