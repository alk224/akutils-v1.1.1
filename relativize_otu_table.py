#!/usr/bin/env python

## This script was concieved by Andrew Krohn
## Bo Stevens did most of the work because I still suck at python
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
