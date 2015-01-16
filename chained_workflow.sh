#!/bin/bash
set -e

## check whether user had supplied -h or --help. If yes display help 

	if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
		echo "
		eqw.sh (EnGGen QIIME workflow)

		This script takes an input directory and attempts to
		process contents through a qiime workflow.  The workflow
		references a config file.  You can reference a global
		config file (default), or a local one, if present in the
		directory this script is executed on, will be referenced
		instead.  Config files can be defined with the config
		utility by issuing:

		eqw.sh config

		Usage (order is important!!):
		eqw.sh <input folder> <mode>

		Example:
		eqw.sh ./ 16S

		This example will attempt to process data residing in the
		current directory through a complete qiime workflow.  If
		certain conventions are met, the workflow will skip all
		steps that have already been processed.  It will try to
		guess why some step failed and give you feedback if/when
		it crashes.  Then when you restart it, it won't try to
		reprocess the steps that are already completed.

		Order of processing attempts:
		1) Checks for <input folder>/split_libraries/seqs.fna.  
		If present, moves forward to chimera filter or OTU
		picking.  If absent, checks for fastq files to process
		(as idx.fq and rd.fq).  Requires a mapping file be 
		present (map*).

		Config file:
		To get this script to work you need a valid config file.
		You can generate a config file and set up the necessary
		fields by running the egw config utility:

		eqw.sh config

		Mapping file:
		Mapping files are formatted for QIIME.  Index sequences
		contained therein must be in the CORRECT orientation.

		Parameters file:
		Parameters for the steps starting at OTU picking can be
		modified by placing a qiime-formatted parameters file in
		your working directory.  The parameters file must begin
		with \"parameters\".  More than one such file in your
		working directory will cause the workflow to exit.

		Example parameters file contents (parameters_fast.txt):
		pick_otus:max_accepts	1
		pick_otus:max_rejects	8

		Requires the following dependencies to run all steps:
		1) QIIME 1.8.0 or later (qiime.org)
		
		Citations: 

		QIIME: 
		Caporaso, J., Kuczynski, J., & Stombaugh, J. (2010).
		QIIME allows analysis of high-throughput community
		sequencing data. Nature Methods, 7(5), 335–336.
		"
		exit 0	
	fi

## If config supplied, run config utility instead

	if [[ "$1" == "config" ]]; then
		eqw_config_utility.sh
		exit 0
	fi

## If other than two arguments supplied, display usage 

	if [  "$#" -ne 2 ]; then 

		echo "
		Usage (order is important!!):
		Qiime_workflow.sh <input folder> <mode>
		"
		exit 1
	fi

## Check that valid mode was entered

	if [[ $2 != other && $2 != 16S ]]; then
		echo "
		Invalid mode entered (you entered $2).
		Valid modes are 16S or other.

		Usage (order is important!!):
		eqw.sh <input folder> <mode>
		"
		exit 1
	fi

	mode=($2)

## Define working directory and log file
	workdir=$(pwd)
	outdir=($1)

## Check if output directory already exists

	if [[ -d $outdir ]]; then
		echo "		Output directory already exists ($outdir).

		Checking for prior workflow progress...
		"
		if [[ -e $outdir/eqw_workflow.log ]]; then
		log=($outdir/eqw_workflow.log)
			echo "
Workflow restarting in $mode mode" >> $log
			date >> $log
		fi
	fi

	if [[ ! -d $outdir ]]; then
		mkdir -p $outdir
	fi

	if [[ ! -e $outdir/eqw_workflow.log ]]; then
		echo "		Beginning qiime_workflow_script in $mode mode
		"
		touch $outdir/eqw_workflow.log
		log=($outdir/eqw_workflow.log)
		echo "Workflow beginning in $mode mode" >> $log
		date >> $log
		echo "
---
		" >> $log

	fi
		log=($outdir/eqw_workflow.log)

## Check that no more than one parameter file is present

	parameter_count=(`ls $outdir/parameter* | wc -w`)

	if [[ $parameter_count -ge 2 ]]; then

		echo "
		No more than one parameter file can reside in your working
		directory.  Presently, there are $parameter_count such files.  
		Move or rename all but one of these files and restart the
		workflow.  A parameter file is any file in your working
		directory that starts with \"parameter\".  See --help for
		more details.
		
		Exiting...
		"
		exit 1

	elif [[ $parameter_count == 1 ]]; then
		param_file=(`ls $outdir/parameter*`)
	echo "
		Found parameters file.
		($param_file)
	"
	echo "Using custom parameters file ($outdir/$param_file)
	Parameters file contents:
	" >> $log
		cat $param_file >> $log

	elif [[ $parameter_count == 0 ]]; then
	echo "
		No parameters file found.  Running with default settings.
	"
	echo "No parameter file found.  Using default settings.
	" >> $log
	fi

## Check that no more than one mapping file is present

	map_count=(`ls $1/map* | wc -w`)

	if [[ $map_count -ge 2 && $map_count == 0 ]]; then

		echo "
		This workflow requires a mapping file.  No more than one 
		mapping file can reside in your working directory.  Presently,
		there are $map_count such files.  Move or rename all but one 
		of these files and restart the workflow.  A mapping file is 
		any file in your working directory that starts with \"map\".
		It should be properly formatted for QIIME processing.
		
		Exiting...
		"
		
		exit 1
	else
		map=(`ls $1/map*`)	
	fi

## Check for required dependencies:

	scriptdir="$( cd "$( dirname "$0" )" && pwd )"

echo "
		Checking for required dependencies...
"

scriptdir="$( cd "$( dirname "$0" )" && pwd )"


for line in `cat $scriptdir/eqw_resources/eqw.dependencies.list`; do
	dependcount=`command -v $line 2>/dev/null | wc -w`
	if [[ $dependcount == 0 ]]; then
	echo "
		$line is not in your path.  Dependencies not satisfied.
		Exiting.
	"
	exit 1
	else
	if [[ $dependcount -ge 1 ]]; then
	echo "		$line is in your path..."
	fi
	fi
done
echo "
		All dependencies satisfied.  Proceeding...
"

##Read in variables from config file

	local_config_count=(`ls $1/eqw*.config 2>/dev/null | wc -w`)
	if [[ $local_config_count -ge 1 ]]; then

	config=`ls $1/eqw*.config`

	echo "		Using local eqw config file.
		$config
	"
	echo "Referencing local eqw config file.
$config
	" >> $log
	else
		global_config_count=(`ls $scriptdir/eqw_resources/eqw*.config 2>/dev/null | wc -w`)
		if [[ $global_config_count -ge 1 ]]; then

		config=`ls $scriptdir/eqw_resources/eqw*.config`

		echo "		Using global eqw config file.
		$config
		"
		echo "Referencing global eqw config file.
$config
		" >> $log
		fi
	fi

	refs=(`grep "Reference" $config | grep -v "#" | cut -f 2`)
	tax=(`grep "Taxonomy" $config | grep -v "#" | cut -f 2`)
	tree=(`grep "Tree" $config | grep -v "#" | cut -f 2`)
	chimera_refs=(`grep "Chimeras" $config | grep -v "#" | cut -f 2`)
	seqs=($outdir/split_libraries/seqs_chimera_filtered.fna)
	alignment_template=(`grep "Alignment_template" $config | grep -v "#" | cut -f 2`)
	alignment_lanemask=(`grep "Alignment_lanemask" $config | grep -v "#" | cut -f 2`)
	revcomp=(`grep "RC_seqs" $config | grep -v "#" | cut -f 2`)
	seqs=($outdir/split_libraries/seqs.fna)
	itsx_threads=(`grep "Threads_ITSx" $config | grep -v "#" | cut -f 2`)
	itsx_options=(`grep "ITSx_options" $config | grep -v "#" | cut -f 2`)
	slqual=(`grep "Split_libraries_qvalue" $config | grep -v "#" | cut -f 2`)
	chimera_threads=(`grep "Threads_chimera_filter" $config | grep -v "#" | cut -f 2`)
	otupicking_threads=(`grep "Threads_pick_otus" $config | grep -v "#" | cut -f 2`)
	taxassignment_threads=(`grep "Threads_assign_taxonomy" $config | grep -v "#" | cut -f 2`)
	alignseqs_threads=(`grep "Threads_align_seqs" $config | grep -v "#" | cut -f 2`)
	min_overlap=(`grep "Min_overlap" $config | grep -v "#" | cut -f 2`)
	max_mismatch=(`grep "Max_mismatch" $config | grep -v "#" | cut -f 2`)
	mcf_threads=(`grep "Threads_mcf" $config | grep -v "#" | cut -f 2`)
	phix_index=(`grep "PhiX_index" $config | grep -v "#" | cut -f 2`)
	smalt_threads=(`grep "Threads_smalt" $config | grep -v "#" | cut -f 2`)
	multx_errors=(`grep "Multx_errors" $config | grep -v "#" | cut -f 2`)
	rdp_confidence=(`grep "RDP_confidence" $config | grep -v "#" | cut -f 2`)
	rdp_max_memory=(`grep "RDP_max_memory" $config | grep -v "#" | cut -f 2`)
	
## Check for split_libraries outputs and inputs

if [[ -f $outdir/split_libraries/seqs.fna ]]; then
	echo "		Split libraries output detected. 
		($outdir/split_libraries/seqs.fna)
		Skipping split_libraries_fastq.py step,
	"
	else

	echo "		Split libraries needs to be completed.
		Checking for fastq files.
	"



		if [[ ! -f idx.fq ]]; then
		echo "		Index file not present (./idx.fq).
		Correct this error by renaming your index file as idx.fq
		and ensuring it resides within this directory
		"
		exit 1
		fi

		if [[ ! -f rd.fq ]]; then
		echo "		Sequence read file not present (./rd.fq).
		Correct this error by renaming your read file as rd.fq
		and ensuring it resides within this directory
		"
		exit 1
		fi

	fi

## split_libraries_fastq.py command

	log=($outdir/eqw_workflow.log)

if [[ ! -f $outdir/split_libraries/seqs.fna ]]; then
	
	if [[ $slqual == "" ]]; then 
	qual=(19)
	else
	qual=($slqual)
	fi

	## detect barcode lengths
	if [[ `sed '2q;d' idx.fq | egrep "\w+" | wc -m` == 13  ]]; then
	barcodetype=(golay_12)
	else
	barcodetype=$((`sed '2q;d' idx.fq | egrep "\w+" | wc -m`-1))
	fi
	qvalue=$((qual+1))
	echo "		Performing split_libraries.py command (q$qvalue)"
	if [[ $barcodetype == "golay_12" ]]; then
	echo " 		12 base Golay index codes detected...
	"
	else
	echo "$barcodetype base indexes detected...
	"
	fi

	echo "Split libraries command:" >> $log
	date >> $log
	echo "
	split_libraries_fastq.py -i rd.fq -b idx.fq -m $map -o $outdir/split_libraries -q $qual --barcode_type $barcodetype
	" >> $log

	`split_libraries_fastq.py -i rd.fq -b idx.fq -m $map -o $outdir/split_libraries -q $qual --barcode_type $barcodetype`
	wait
fi

seqs=$outdir/split_libraries/seqs.fna

## Check for split libraries success

	if [[ ! -s $outdir/split_libraries/seqs.fna ]]; then
		echo "
		Split libraries step seems to not have identified any samples
		based on the indexing data you supplied.  You should check
		your list of indexes and try again (do they need to be reverse-
		complemented?
		"
		exit 1
	fi

## Chimera filtering step (for 16S mode only)

	if [[ $mode == "16S" ]]; then

	if [[ ! -f $outdir/split_libraries/seqs_chimera_filtered.fna ]]; then

	echo "		Filtering chimeras.
		Method: usearch61
		Reference: $chimera_refs
"
	echo "
Chimera filtering commands:" >> $log
	date >> $log
	echo "Method: usearch61
Reference: $chimera_refs

	identify_chimeric_seqs.py -m usearch61 -i $outdir/split_libraries/seqs.fna -r $chimera_refs -o $outdir/usearch61_chimera_checking

	filter_fasta.py -f $outdir/split_libraries/seqs.fna -o $outdir/split_libraries/seqs_chimera_filtered.fna -s $outdir/usearch61_chimera_checking/chimeras.txt -n
	" >> $log

	`identify_chimeric_seqs.py -m usearch61 -i $outdir/split_libraries/seqs.fna -r $chimera_refs -o $outdir/usearch61_chimera_checking`
	wait
	`filter_fasta.py -f $outdir/split_libraries/seqs.fna -o $outdir/split_libraries/seqs_chimera_filtered.fna -s $outdir/usearch61_chimera_checking/chimeras.txt -n`
	wait
	echo ""
	else

	echo "		Chimera filtered sequences detected.
		($seqs)
		Skipping chimera checking step.
	"

	fi
	fi

## Reverse complement demultiplexed sequences if necessary

	if [[ $revcomp == "True" ]]; then

	if [[ ! -f $outdir/split_libraries/seqs_rc.fna ]]; then

	echo "		Reverse complementing split libraries output according
		to config file setting.
	"
	echo "
Reverse complement command:"
	date >> $log
	echo "
	adjust_seq_orientation.py -i $seqs -r -o $outdir/split_libraries/seqs_rc.fna
	" >> $log

	`adjust_seq_orientation.py -i $seqs -r -o $outdir/split_libraries/seqs_rc.fna`
	wait
	echo "		Demultiplexed sequences were reverse complemented.
	"
	seqs=$outdir/split_libraries/seqs_rc.fna
	else
	echo "		Sequences already in proper orientation.
	"
	fi
	fi

## chained OTU picking

seqpath="${seqs%.*}"
seqname=`basename $seqpath`


if [[ ! -f prefix50_suffix0/$seqname\_otus.txt ]]; then

	echo "		Collapsing sequences with prefix/suffix picker.
	"
	echo "Collapsing sequences with prefix/suffix picker:" >> $log
	date >> $log
	echo "
	pick_otus.py -m prefix_suffix -p 50 -u 0 -i $seqs -o prefix50_suffix0	
	" >> $log
	`pick_otus.py -m prefix_suffix -p 50 -u 0 -i $seqs -o prefix50_suffix0`
	
	else
	echo "		Prefix/suffix step previously completed.
	"
fi

if [[ ! -f prefix50_suffix0/prefix_rep_set.fasta ]]; then

	echo "		Picking rep set with prefix/suffix-collapsed OTU map.
	"
	echo "Picking rep set with prefix/suffix-collapsed OTU map:" >> $log
	date >> $log
	echo "
	pick_rep_set.py -i prefix50_suffix0/$seqname\_otus.txt -f $seqs -o prefix50_suffix0/prefix_rep_set.fasta
	" >> $log
	`pick_rep_set.py -i prefix50_suffix0/$seqname\_otus.txt -f $seqs -o prefix50_suffix0/prefix_rep_set.fasta`

	else
	echo "		Prefix/suffix rep set already present.
	"
fi

if [[ ! -f cdhit_otus/prefix_rep_set_otus.txt ]]; then

	echo "		Picking OTUs against collapsed rep set.
	"
	echo "Picking OTUs against collapsed rep set:" >> $log
	date >> $log
	echo "
	pick_otus.py -m cdhit -M 2000 -i prefix50_suffix0/prefix_rep_set.fasta -o cdhit_otus
	" >> $log
	`pick_otus.py -m cdhit -M 2000 -i prefix50_suffix0/prefix_rep_set.fasta -o cdhit_otus`

	else
	echo "		Main OTU picking already completed.
	"
fi

if [[ ! -f cdhit_otus/merged_otu_map.txt ]]; then

	echo "		Merging OTU maps.
	"
	echo "Merging OTU maps:" >> $log
	date >> $log
	echo "
	merge_otu_maps.py -i prefix50_suffix0/$seqname\_otus.txt,cdhit_otus/prefix_rep_set_otus.txt -o cdhit_otus/merged_otu_map.txt
	" >> $log
	`merge_otu_maps.py -i prefix50_suffix0/$seqname\_otus.txt,cdhit_otus/prefix_rep_set_otus.txt -o cdhit_otus/merged_otu_map.txt`

	else
	echo "		OTU maps already merged.
	"
fi

if [[ ! -f cdhit_otus/merged_rep_set.fna ]]; then

	echo "		Picking rep set against merged OTU map.
	"
	echo "Picking rep set against merged OTU map:" >> $log
	date >> $log
	echo "	
	pick_rep_set.py -i cdhit_otus/merged_otu_map.txt -f $seqs -o cdhit_otus/merged_rep_set.fna
	" >> $log
	`pick_rep_set.py -i cdhit_otus/merged_otu_map.txt -f $seqs -o cdhit_otus/merged_rep_set.fna`
	
	else
	echo "		Merged rep set already completed.
	"
fi

## Align sequences (16S mode)

	if [[ $mode == "16S" ]]; then

	if [[ ! -f $outdir/cdhit_otus/pynast_aligned_seqs/merged_rep_set_aligned.fasta ]]; then

	echo "		Aligning sequences.
		Method: Pynast on $alignseqs_threads cores
		Template: $alignment_template
	"
	echo "Aligning sequences:" >> $log
	date >> $log
	echo "
	parallel_align_seqs_pynast.py -i $outdir/cdhit_otus/merged_rep_set.fna -o $outdir/cdhit_otus/pynast_aligned_seqs -t $alignment_template -O $alignseqs_threads
	" >> $log
	`parallel_align_seqs_pynast.py -i $outdir/cdhit_otus/merged_rep_set.fna -o $outdir/cdhit_otus/pynast_aligned_seqs -t $alignment_template -O $alignseqs_threads`
	wait

	else	
	echo "		Alignment file detected.
		($outdir/cdhit_otus/pynast_aligned_seqs/merged_rep_set_aligned.fasta)
		Skipping sequence alignment step.
	"
	fi
	fi

## Align sequences (other mode)

	if [[ $mode == "other" ]]; then

	if [[ ! -f $outdir/cdhit_otus/mafft_aligned_seqs/merged_rep_set_aligned.fasta ]]; then

	echo "		Aligning sequences.
		Method: Mafft on $alignseqs_threads cores
		Template: none
	"
	echo "Aligning sequences:" >> $log
	date >> $log
	echo "
	align_seqs.py -i $outdir/cdhit_otus/merged_rep_set.fna -o $outdir/cdhit_otus/mafft_aligned_seqs -m mafft
	" >> $log
	`align_seqs.py -i $outdir/cdhit_otus/merged_rep_set.fna -o $outdir/cdhit_otus/mafft_aligned_seqs -m mafft`
	wait

	else	
	echo "		Alignment file detected.
		($outdir/cdhit_otus/mafft_aligned_seqs/merged_rep_set_aligned.fasta)
		Skipping sequence alignment step.
	"
	fi
	fi

## Filtering alignment (16S mode)

	if [[ $mode == "16S" ]]; then

	if [[  ! -f $outdir/cdhit_otus/pynast_aligned_seqs/merged_rep_set_aligned_pfiltered.fasta ]]; then
	
	echo "		Filtering sequence alignment.
		Lanemask file: $alignment_lanemask.
	"
	echo "Filtering alignment:" >> $log
	date >> $log
	echo "
	filter_alignment.py -i $outdir/cdhit_otus/pynast_aligned_seqs/merged_rep_set_aligned.fasta -o $outdir/cdhit_otus/pynast_aligned_seqs/ -m $alignment_lanemask
	" >> $log
	`filter_alignment.py -i $outdir/cdhit_otus/pynast_aligned_seqs/merged_rep_set_aligned.fasta -o $outdir/cdhit_otus/pynast_aligned_seqs/ -m $alignment_lanemask`
	wait

	else
	echo "		Filtered alignment detected.
		($outdir/cdhit_otus/pynast_aligned_seqs/merged_rep_set_aligned_pfiltered.fasta)
		Skipping alignment filtering step.
	"
	fi
	fi

## Filtering alignment (other mode)

	if [[ $mode == "other" ]]; then

	if [[  ! -f $outdir/cdhit_otus/mafft_aligned_seqs/merged_rep_set_aligned_pfiltered.fasta ]]; then
	
	echo "		Filtering sequence alignment.
		Entropy threshold: 0.1
	"
	echo "Filtering alignment:" >> $log
	date >> $log
	echo "
	filter_alignment.py -i $outdir/cdhit_otus/mafft_aligned_seqs/merged_rep_set_aligned.fasta -o $outdir/cdhit_otus/mafft_aligned_seqs/ -e 0.1
	" >> $log
	`filter_alignment.py -i $outdir/cdhit_otus/mafft_aligned_seqs/merged_rep_set_aligned.fasta -o $outdir/cdhit_otus/mafft_aligned_seqs/ -e 0.1`
	wait

	else
	echo "		Filtered alignment detected.
		($outdir/cdhit_otus/mafft_aligned_seqs/merged_rep_set_aligned_pfiltered.fasta)
		Skipping alignment filtering step.
	"
	fi
	fi

## Make phylogeny in background (16S mode)

	if [[ $mode == "16S" ]]; then

	if [[ ! -f $outdir/cdhit_otus/pynast_aligned_seqs/fasttree_phylogeny.tre ]]; then

	echo "		Constructing phylogeny based on sample sequences.
		Method: Fasttree
	"
	echo "Making phylogeny:" >> $log
	date >> $log
	echo "
	make_phylogeny.py -i $outdir/cdhit_otus/pynast_aligned_seqs/merged_rep_set_aligned_pfiltered.fasta -o $outdir/cdhit_otus/pynast_aligned_seqs/fasttree_phylogeny.tre
	" >> $log
	( `make_phylogeny.py -i $outdir/cdhit_otus/pynast_aligned_seqs/merged_rep_set_aligned_pfiltered.fasta -o $outdir/cdhit_otus/pynast_aligned_seqs/fasttree_phylogeny.tre` ) &

	else
	echo "		Phylogenetic tree detected.
		($outdir/cdhit_otus/pynast_aligned_seqs/fasttree_phylogeny.tre)
		Skipping make phylogeny step.
	"
	fi
	fi

## Make phylogeny in background (other mode)

	if [[ $mode == "other" ]]; then

	if [[ ! -f $outdir/cdhit_otus/mafft_aligned_seqs/fasttree_phylogeny.tre ]]; then

	echo "		Constructing phylogeny based on sample sequences.
		Method: Fasttree
	"
	echo "Making phylogeny:" >> $log
	date >> $log
	echo "
	make_phylogeny.py -i $outdir/cdhit_otus/mafft_aligned_seqs/merged_rep_set_aligned_pfiltered.fasta -o $outdir/cdhit_otus/mafft_aligned_seqs/fasttree_phylogeny.tre
	" >> $log
	( `make_phylogeny.py -i $outdir/cdhit_otus/mafft_aligned_seqs/merged_rep_set_aligned_pfiltered.fasta -o $outdir/cdhit_otus/mafft_aligned_seqs/fasttree_phylogeny.tre` ) &

	else
	echo "		Phylogenetic tree detected.
		($outdir/cdhit_otus/mafft_aligned_seqs/fasttree_phylogeny.tre)
		Skipping make phylogeny step.
	"
	fi
	fi


## Assign taxonomy (RDP)

	if [[ ! -f $outdir/cdhit_otus/rdp_taxonomy_assignment/merged_rep_set_tax_assignments.txt ]]; then

	echo "		Assigning taxonomy.
		Method: RDP Classifier on $taxassignment_threads cores.
	"
	echo "Assigning taxonomy (RDP):" >> $log
	date >> $log
	echo "
	parallel_assign_taxonomy_rdp.py -i $outdir/cdhit_otus/merged_rep_set.fna -o $outdir/cdhit_otus/rdp_taxonomy_assignment -c $rdp_confidence -r $refs -t $tax --rdp_max_memory $rdp_max_memory -O $taxassignment_threads
	" >> $log
	`parallel_assign_taxonomy_rdp.py -i $outdir/cdhit_otus/merged_rep_set.fna -o $outdir/cdhit_otus/rdp_taxonomy_assignment -c $rdp_confidence -r $refs -t $tax --rdp_max_memory $rdp_max_memory -O $taxassignment_threads`
	wait

	else
	echo "		Taxonomy assignments detected.
		($outdir/cdhit_otus/rdp_taxonomy_assignment/merged_rep_set_tax_assignments.txt)
		Skipping taxonomy assignment step.
	"
	fi


## Make raw otu table

	if [[ ! -f $outdir/cdhit_otus/raw_otu_table.biom ]]; then
	
	echo "		Making raw OTU table.
	"
	echo "Making OTU table:" >> $log
	date >> $log
	echo "
	make_otu_table.py -i $outdir/cdhit_otus/merged_otu_map.txt -t $outdir/cdhit_otus/rdp_taxonomy_assignment/merged_rep_set_tax_assignments.txt -o $outdir/cdhit_otus/raw_otu_table.biom
	" >> $log
	`make_otu_table.py -i $outdir/cdhit_otus/merged_otu_map.txt -t $outdir/cdhit_otus/rdp_taxonomy_assignment/merged_rep_set_tax_assignments.txt -o $outdir/cdhit_otus/raw_otu_table.biom`

	else
	echo "		Raw OTU table detected.
		($outdir/cdhit_otus/raw_otu_table.biom)
		Moving to final filtering steps.
	"
	fi

## Summarize raw otu table in background

	if [[ ! -f $outdir/cdhit_otus/raw_otu_table.summary ]]; then
	( `biom summarize-table -i $outdir/cdhit_otus/raw_otu_table.biom -o $outdir/cdhit_otus/raw_otu_table.summary` ) &
	fi

## Final filtering steps for OTU tables
## Remove singletons and doubletons

	if [[ ! -f $outdir/cdhit_otus/raw_otu_table_no_singletons_no_doubletons.biom ]]; then
	
	echo "Filtering singletons/doubletons from OTU table:" >> $log
	date >> $log
	echo "
	filter_otus_from_otu_table.py -i $outdir/cdhit_otus/raw_otu_table.biom -o $outdir/cdhit_otus/raw_otu_table_no_singletons_no_doubletons.biom -n 3
	" >> $log
	`filter_otus_from_otu_table.py -i $outdir/cdhit_otus/raw_otu_table.biom -o $outdir/cdhit_otus/raw_otu_table_no_singletons_no_doubletons.biom -n 3`
	fi

	if [[ ! -f $outdir/cdhit_otus/raw_otu_table_no_singletons_no_doubletons.summary ]]; then
	( `biom summarize-table -i $outdir/cdhit_otus/raw_otu_table_no_singletons_no_doubletons.biom -o $outdir/cdhit_otus/raw_otu_table_no_singletons_no_doubletons.summary` ) &
	fi
wait

## remove jobs directory

	if [[ -d $outdir/jobs ]]; then
	rm -r $outdir/jobs
	fi

echo "		Workflow steps completed.
"
echo "---

All workflow steps completed." >> $log
date >> $log

