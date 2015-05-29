#!/usr/bin/env bash
#
#  mapcats.sh - Read column headers from a QIIME-formatted mapping file
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

set -e

## Check whether user had supplied -h or --help. If yes display help 

	if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
		echo "
		This script reads a QIIME-formatted mapping file and returns
		the names of metadata categories.  This can be useful if
		preparing to run diversity analyses.

		Usage:
		mapcats.sh <mappingfile>
		
		"
		exit 0
	fi 

## If other than one argument supplied, display usage 

	if [  "$#" -ne 1 ] ;
	then 
		echo "
		Usage:
		mapcats.sh <mappingfile>

		"
		exit 1
	fi

## Read and display mapping categories

echo "
Mapping file: $1
Categories:" `grep "#" $1 | cut -f 2-100 | sed 's/\t/,/g'`
echo ""

exit 0
