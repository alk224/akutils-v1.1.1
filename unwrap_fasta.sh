#!/usr/bin/env bash

## Quick script to remove text wrapping from fasta file

## Check whether user had supplied -h or --help. If yes display help 

	if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
		echo "
		This script will take a fasta file as input and remove
		any text wrapping as can occur with some software.

		Usage (order is important!!):
		unwrap_fasta.sh <input_fasta> <output_fasta>
		
		Example:
		unwrap_fasta.sh sequences.fasta sequences_unwrapped.fasta
		"
		exit 0
	fi 

# if more or less than one arguments supplied, display usage 

	if [  "$#" -ne 2 ] ;
	then 
		echo "
		Usage (order is important!!):
		unwrap_fasta.sh sequences.fasta sequences_unwrapped.fasta
		"
		exit 1
	fi 

## Define variables

inseqs=$1
outseqs=$2

## Awk script

	awk '!/^>/ { printf "%s", $0; n = "\n" } 
	/^>/ { print n $0; n = "" }
	END { printf "%s", n }
	' $inseqs > $outseqs
	wait


