#!/usr/bin/env python
#
#  relativize_otu_table.py - Convert an OTU table from total counts to relative abundances
#
#  Version 0.1.0 (May 29, 2015)
#
#  Copyright (c) 2015 Bo Stevens
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

## This script was concieved by Andrew Krohn
## Bo Stevens did most of the work
## Thanks, Bo!


from biom.parse import load_table
from biom.util import biom_open
import sys
import argparse
import os.path

parser = argparse.ArgumentParser(description='This is a python script to relativize biom tables')

def file_choices(choices, fname):
	ext = os.path.splitext(fname)[1][1:]
	if ext not in choices:
		parser.error('file must be biom format')
	return fname

parser.add_argument('-i', type=lambda s:file_choices(('biom','tab'),s), help='Input biom file', action='store', required = True)

if len(sys.argv)<=1:
	parser.print_help()
	sys.exit(1)

results = parser.parse_args()

print '\nInput file:', results.i
out = results.i[:-5] + '_relativized.biom'
	
t = load_table(results.i)
normed = t.norm(axis='sample', inplace=False)


with biom_open(out, 'w') as f:
	normed.to_hdf5(f, 'example')

print '\n\tSuccess!\n\tOutput file: ' + out + '\n'
