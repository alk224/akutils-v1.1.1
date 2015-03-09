#!/bin/bash
set -e

## check whether user had supplied -h or --help. If yes display help 

	if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
		echo "
		chained_workflow-custom_openref.sh 

		This script takes an input directory and attempts to
		process contents through a qiime workflow.  The workflow
		references a config file.  You can reference a global
		config file (default), or a local one, if present in the
		directory this script is executed on, will be referenced
		instead.  Config files can be defined with the config
		utility by issuing:

		chained_workflow-custom_openref.sh config
		
		Or by calling the config program directly:

		akutils_config_utility.sh

		Usage (order is important!!):
		chained_workflow-custom_openref.sh <input folder> <mode>

		Example:
		chained_workflow-custom_openref.sh ./ 16S

		This example will attempt to process data residing in the
		current directory through a complete qiime workflow.  If
		certain conventions are met, the workflow will skip all
		steps that have already been processed.  It will try to
		guess why some step failed and give you feedback if/when
		it crashes.  Then when you restart it, it won't try to
		reprocess the steps that are already completed.

		Order of processing attempts:
		Checks for <input folder>/split_libraries/seqs.fna.  
		If present, moves forward to chimera filter or OTU
		picking.  If absent, checks for fastq files to process
		(as idx.fq and rd.fq).  Requires a mapping file be 
		present (map*).

		Workflow details:
		1) Split libraries (set -q in config)
		2) Chimera filtering with usearch61 (16S only)
		3) Prefix/suffix collapsing (set in config)
		4) Parallel BLAST OTU picking (reference-based, set CPUs in config)
		5) CD-hit OTU picking of failures from BLAST step (de novo, single core)
		6) Parallel BLAST taxonomy assignment
		7) Make raw OTU table
		8) Filter OTU table by observation at several depths (2, 5, 10, 20)
		9) Normalize filtered tables

		Why open-reference with BLAST/cdhit??
		Excellent question!!  I find myself constantly playing with
		the parameters of QIIME scripts in order to tease apart the
		subtle effects in the system I am working on for my dissertation.
		This system is FRUSTRATING to work in.  I wanted to use an open-
		reference approach, but QIIME only has the open-reference workflow
		for use with the QIIME UCLUST implementation.  I get consistently
		disappointing results whenever I use UCLUST, but consistently
		encouraging results if I do closed reference analysis with BLAST
		or de novo analysis with CD-hit.  So I thought, why not just
		write my own open-reference workflow with the assigners that
		generate good data for my system?  I tested this workflow on a
		16S mock community and got identical results as with the QIIME
		open-reference workflow, but I expect it will out-perform the
		QIIME workflow in terms of accuracy with an average environmental
		dataset, but I am also pretty certain it will be slower.

		Note: This workflow is intended to be performed on separate
		experiments ONLY!!  If you have multiple experiments on the same
		run that is fine, but break them up by the mapping file.  This
		is easy to do with tools from akutils.  If you first remove primer
		sequences (strip_primers.sh), then filter PhiX from your data
		(PhiX_filtering_workflow.sh) using a map file that only includes
		a single experiment, the output from the PhiX filtering step will
		only contain sequences that belong to that experiment.

		Config file:
		To get this script to work you need a valid config file.
		You can generate a config file and set up the necessary
		fields by running the egw config utility:

		chained_workflow-custom_openref.sh config

		Mapping file:
		Mapping files are formatted for QIIME.  Index sequences
		contained therein must be in the CORRECT orientation.

		Parameters file:

		*** Note: only similarity is referenced at the moment

		Parameters for the steps starting at OTU picking can be
		modified by placing a qiime-formatted parameters file in
		your working directory.  The parameters file must begin
		with \"parameters\".  More than one such file in your
		working directory will cause the workflow to exit.

		Example parameters file contents (parameters_fast.txt):
		pick_otus:similarity 0.97

		Requires the following dependencies to run all steps:
		1) QIIME 1.9.0 or later (qiime.org)
		2) akutils repo (https://github.com/alk224/akutils)
		
		Citations: 

		QIIME: 
		Caporaso, J., Kuczynski, J., & Stombaugh, J. (2010).
		QIIME allows analysis of high-throughput community
		sequencing data. Nature Methods, 7(5), 335–336.

		Open-reference OTU picking strategy:
		Navas-Molina, J.A., Peralta-Sanchez, J.M., Gonzalez, A.,
		 McMurdie, P.J., Vazquez-Baeza, Y., Xu, Z., Ursell, L.K., 
		Lauber, C., Zhou, H., Song, S.J., Huntley, J., Ackermann, 
		G.L., Berg-Lyons, D., Holmes, S., Caporaso, J.G., & Knight, 
		R. (2013). Advancing our understanding of the human 
		microbiome using QIIME. Methods in Enzymology, 531, 371-444.
		"
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
		chained_workflow-custom_openref.sh <input folder> <mode>
		"
		exit 1
	fi

## Check that valid mode was entered

	if [[ $2 != other && $2 != 16S ]]; then
		echo "
		Invalid mode entered (you entered $2).
		Valid modes are 16S or other.

		Usage (order is important!!):
		chained_workflow-custom_openref.sh <input folder> <mode>
		"
		exit 1
	fi

	mode=($2)

## Define working directory and log file
	workdir=$(pwd)
	outdir=($1)

## Check if output directory already exists and define log file

	if [[ -d $outdir ]]; then
		echo "
		Output directory already exists.
		$outdir

		Checking for prior workflow progress...
		"
	else
		mkdir -p $outdir
	fi

	logcount=`ls $outdir/log_custom_openref_workflow* | wc -l`

	if [[ $logcount > 0 ]]; then
		log=`ls $outdir/log_custom_openref*.txt | head -1`
		echo "		Chained workflow restarting in $mode mode"
		date1=`date "+%a %b %I:%M %p %Z %Y"`
		echo "		$date1"
		res1=$(date +%s.%N)
			echo "
Chained workflow restarting in $mode mode" >> $log
			date "+%a %b %I:%M %p %Z %Y" >> $log
	else
		echo "		Beginning chained workflow script in $mode mode"
		date1=`date "+%a %b %I:%M %p %Z %Y"`
		echo "		$date1"
		date0=`date +%Y%m%d_%I%M%p`
		log=($outdir/log_custom_openref_workflow_$date0.txt)
		echo "
Chained workflow beginning in $mode mode" > $log
		date "+%a %b %I:%M %p %Z %Y" >> $log
		res1=$(date +%s.%N)
		echo "
---
		" >> $log
	fi

## Check that no more than one parameter file is present

	parameter_count=(`ls $outdir/parameter* 2>/dev/null | wc -w`)

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
		$param_file
	"
	echo "Using custom parameters file.
$outdir/$param_file

Parameters file contents:" >> $log
	grep similarity $param_file >> $log

	elif [[ $parameter_count == 0 ]]; then
	echo "
		No parameters file found.  Running with default settings.
	"
	echo "No parameter file found.  Using default settings.
	" >> $log
	fi

## Check that no more than one mapping file is present

	map_count=(`ls $1/map* | wc -w`)

	if [[ $map_count -ge 2 || $map_count == 0 ]]; then

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


for line in `cat $scriptdir/akutils_resources/chained_workflow.dependencies.list`; do
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

	local_config_count=(`ls $1/akutils*.config 2>/dev/null | wc -w`)
	if [[ $local_config_count -ge 1 ]]; then

	config=`ls $1/akutils*.config`

	echo "		Using local akutils config file.
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

		echo "		Using global akutils config file.
		$config
		"
		echo "
Referencing global akutils config file.
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
	itsx_options=`grep "ITSx_options" $config | grep -v "#" | cut -f 2-`
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
	prefix_len=(`grep "Prefix_length" $config | grep -v "#" | cut -f 2`)
	suffix_len=(`grep "Suffix_length" $config | grep -v "#" | cut -f 2`)
#	otupicker=(`grep "OTU_picker" $config | grep -v "#" | cut -f 2`)
	
## Check for split_libraries outputs and inputs

if [[ -f $outdir/split_libraries/seqs.fna ]]; then
	echo "		Split libraries output detected. 
		$outdir/split_libraries/seqs.fna
		Skipping split_libraries_fastq.py step
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
	echo "		$barcodetype base indexes detected...
	"
	fi

	echo "Split libraries command:" >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "
	split_libraries_fastq.py -i rd.fq -b idx.fq -m $map -o $outdir/split_libraries -q $qual --barcode_type $barcodetype
	" >> $log
	res2=$(date +%s.%N)

	`split_libraries_fastq.py -i rd.fq -b idx.fq -m $map -o $outdir/split_libraries -q $qual --barcode_type $barcodetype`

res3=$(date +%s.%N)
dt=$(echo "$res3 - $res2" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

sl_runtime=`printf "Split libraries runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`
echo "$sl_runtime

" >> $log
	wait
fi

seqs=$outdir/split_libraries/seqs.fna
numseqs0=`cat $seqs | wc -l`
numseqs=$(($numseqs0/2))

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
		Subsearches: $chimera_threads
		Input sequences: $numseqs
"
	echo "
Chimera filtering commands:" >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "Method: usearch61
Reference: $chimera_refs
Subsearches: $chimera_threads

	identify_chimeric_seqs.py -m usearch61 -i $outdir/split_libraries/seqs.fna -r $chimera_refs -o $outdir/usearch61_chimera_checking

	filter_fasta.py -f $outdir/split_libraries/seqs.fna -o $outdir/split_libraries/seqs_chimera_filtered.fna -s $outdir/usearch61_chimera_checking/chimeras.txt -n
	" >> $log
res4=$(date +%s.%N)
	cd $outdir/split_libraries
	fasta-splitter.pl -n $chimera_threads seqs.fna
	cd ..
	mkdir -p $outdir/usearch61_chimera_checking
	echo ""	

	for seqpart in $outdir/split_libraries/seqs.part-* ; do

		seqpartbase=$( basename $seqpart .fna )
	`identify_chimeric_seqs.py -m usearch61 -i $seqpart -r $chimera_refs -o $outdir/usearch61_chimera_checking/$seqpartbase`
	echo "		Completed $seqpartbase"
	done	
	wait
	echo ""
	cat $outdir/usearch61_chimera_checking/seqs.part-*/chimeras.txt > $outdir/usearch61_chimera_checking/all_chimeras.txt
		chimeracount=`cat $outdir/usearch61_chimera_checking/all_chimeras.txt | wc -l`
		seqcount1=`cat $outdir/split_libraries/seqs.fna | wc -l`
		seqcount=`expr $seqcount1 / 2`
	echo "		Identified $chimeracount chimeric sequences from $seqcount
		total reads in your data."
	echo "		Identified $chimeracount chimeric sequences from $seqcount
		total reads in your data.
	" >> $log

	`filter_fasta.py -f $outdir/split_libraries/seqs.fna -o $outdir/split_libraries/seqs_chimera_filtered.fna -s $outdir/usearch61_chimera_checking/all_chimeras.txt -n`
	wait
	rm $outdir/split_libraries/seqs.part-*
seqs=$outdir/split_libraries/seqs_chimera_filtered.fna

res5=$(date +%s.%N)
dt=$(echo "$res5 - $res4" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

chim_runtime=`printf "Chimera filtering runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`	
echo "$chim_runtime

" >> $log

	echo ""
	else

	echo "		Chimera filtered sequences detected.
		$outdir/split_libraries/seqs_chimera_filtered.fna
		Skipping chimera checking step.
	"
seqs=$outdir/split_libraries/seqs_chimera_filtered.fna
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
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "
	adjust_seq_orientation.py -i $seqs -r -o $outdir/split_libraries/seqs_rc.fna
	" >> $log

	`adjust_seq_orientation.py -i $seqs -r -o $outdir/split_libraries/seqs_rc.fna`
	wait
	echo "		Demultiplexed sequences were reverse complemented.
	"
	seqs=$outdir/split_libraries/seqs_rc.fna
	fi
	else
	echo "		Sequences already in proper orientation.
	"
	fi

## chained OTU picking (prefix-suffix, parallel blast (ref), cdhit (de novo)

numseqs0=`cat $seqs | wc -l`
numseqs=(`expr $numseqs0 / 2`)

seqpath="${seqs%.*}"
seqname=`basename $seqpath`
presufdir=prefix$prefix_len\_suffix$suffix_len/

if [[ ! -f $presufdir/$seqname\_otus.txt ]]; then
res6=$(date +%s.%N)
	echo "		Collapsing sequences with prefix/suffix picker.
		Input sequences: $numseqs
		Prefix length: $prefix_len
		Suffix length: $suffix_len
	"
	echo "Collapsing $numseqs sequences with prefix/suffix picker." >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "Input sequences: $numseqs
Prefix length: $prefix_len
Suffix length: $suffix_len" >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "
	pick_otus.py -m prefix_suffix -p $prefix_len -u $suffix_len -i $seqs -o $presufdir	
	" >> $log
	`pick_otus.py -m prefix_suffix -p $prefix_len -u $suffix_len -i $seqs -o $presufdir`

res7=$(date +%s.%N)
dt=$(echo "$res7 - $res6" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

pref_runtime=`printf "Prefix/suffix collapse runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`	
echo "$pref_runtime

" >> $log
	
	else
	echo "		Prefix/suffix step previously completed.
	"
fi

if [[ ! -f $presufdir/prefix_rep_set.fasta ]]; then
res8=$(date +%s.%N)
	echo "		Picking rep set with prefix/suffix-collapsed OTU map.
	"
	echo "Picking rep set with prefix/suffix-collapsed OTU map:" >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "
	pick_rep_set.py -i $presufdir/$seqname\_otus.txt -f $seqs -o $presufdir/prefix_rep_set.fasta
	" >> $log
	`pick_rep_set.py -i $presufdir/$seqname\_otus.txt -f $seqs -o $presufdir/prefix_rep_set.fasta`

res9=$(date +%s.%N)
dt=$(echo "$res9 - $res8" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

repset_runtime=`printf "Pick rep set runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`	
echo "$repset_runtime

" >> $log

	else
	echo "		Prefix/suffix rep set already present.
	"
fi

if [[ ! -f $presufdir/prefix_rep_set_ITSx_filtered.fasta ]]; then
res81=$(date +%s.%N)
numpreseqs0=`cat $presufdir/prefix_rep_set.fasta | wc -l`
numpreseqs=(`expr $numpreseqs0 / 2`)
	
	echo "		Filtering collapsed sequence set with ITSx on $itsx_threads cores.
		Input sequences: $numpreseqs
	"
	echo "Filtering collapsed sequence set with ITSx on $itsx_threads cores:" >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "
	ITSx_parallel.sh $presufdir/prefix_rep_set.fasta $itsx_threads $itsx_options
	" >> $log
	`ITSx_parallel.sh $presufdir/prefix_rep_set.fasta $itsx_threads $itsx_options >>$presufdir/ITSx_stdout.txt 2>&1`

res91=$(date +%s.%N)
dt=$(echo "$res91 - $res81" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

itsx_runtime=`printf "Parallel ITSx runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`	
echo "$itsx_runtime

" >> $log

	else
	echo "		ITSx-filtered rep set already present.
	"
fi

otupickdir=$outdir/custom-openref_otus

if [[ ! -f $otupickdir/blast_step1_reference/prefix_rep_set_ITSx_filtered_otus.txt ]] || [[ ! -f $otupickdir/blast_step1_reference/step1_rep_set.fasta ]]; then
res10=$(date +%s.%N)

numseqs1=`cat $presufdir/prefix_rep_set_ITSx_filtered.fasta | wc -l`
numseqs2=(`expr $numseqs1 / 2`)

	if [[ -d $otupickdir/blast_step1_reference ]]; then 
	rm -r $otupickdir/blast_step1_reference/*
	fi
	if [[ -d $otupickdir/cdhit_step2_denovo ]]; then
	rm -r $otupickdir/cdhit_step2_denovo
	fi

	echo "		Picking OTUs against collapsed rep set.
		Input sequences: $numseqs2
		Method: BLAST (step 1, reference-based OTU picking)"
	echo "Picking OTUs against collapsed rep set." >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "Input sequences: $numseqs2" >> $log
	echo "Method: BLAST (step 1, reference-based OTU picking)" >> $log

	if [[ $parameter_count == 1 ]]; then
	sim=`grep "similarity" $param_file | cut -d " " -f 2`
	echo "Similarity: $sim" >> $log
	echo "		Similarity: $sim
	"
	echo "
	parallel_pick_otus_blast.py -i $presufdir/prefix_rep_set_ITSx_filtered.fasta -o $otupickdir/blast_step1_reference -s $sim -O $otupicking_threads -r $refs
	" >> $log
	`parallel_pick_otus_blast.py -i $presufdir/prefix_rep_set_ITSx_filtered.fasta -o $otupickdir/blast_step1_reference -s $sim -O $otupicking_threads -r $refs`
	else
	echo "Similarity: 0.97" >> $log
	echo "		Similarity: 0.97
	"
	echo "
	parallel_pick_otus_blast.py -i $presufdir/prefix_rep_set_ITSx_filtered.fasta -o $otupickdir/blast_step1_reference -O $otupicking_threads -r $refs -s 0.97
	" >> $log
	`parallel_pick_otus_blast.py -i $presufdir/prefix_rep_set_ITSx_filtered.fasta -o $otupickdir/blast_step1_reference -O $otupicking_threads -r $refs -s 0.97`
	fi

	## Merge OTU maps and pick rep set for reference-based successes

	`merge_otu_maps.py -i $presufdir/$seqname\_otus.txt,$otupickdir/blast_step1_reference/prefix_rep_set_ITSx_filtered_otus.txt -o $otupickdir/blast_step1_reference/merged_step1_otus.txt`

	`pick_rep_set.py -i $otupickdir/blast_step1_reference/merged_step1_otus.txt -f $seqs -o $otupickdir/blast_step1_reference/step1_rep_set.fasta`

	## Make failures file for clustering against de novo

	cat $otupickdir/blast_step1_reference/prefix_rep_set_ITSx_filtered_otus.txt | cut -f 2- > $otupickdir/blast_step1_reference/prefix_rep_set_otuids_all.txt
	paste -sd ' ' - < $otupickdir/blast_step1_reference/prefix_rep_set_otuids_all.txt > $otupickdir/blast_step1_reference/prefix_rep_set_otuids_1row.txt
	tr -s "[:space:]" "\n" <$otupickdir/blast_step1_reference/prefix_rep_set_otuids_1row.txt | sed "/^$/d" > $otupickdir/blast_step1_reference/prefix_rep_set_otuids.txt
	rm $otupickdir/blast_step1_reference/prefix_rep_set_otuids_1row.txt
	rm $otupickdir/blast_step1_reference/prefix_rep_set_otuids_all.txt
	filter_fasta.py -f $presufdir/prefix_rep_set_ITSx_filtered.fasta -o $otupickdir/blast_step1_reference/step1_failures.fasta -s $otupickdir/blast_step1_reference/prefix_rep_set_otuids.txt -n
	rm $otupickdir/blast_step1_reference/prefix_rep_set_otuids.txt
	
	## Count successes and failures from step 1 for reporting purposes

	successlines=`cat $otupickdir/blast_step1_reference/step1_rep_set.fasta | wc -l`
	successseqs=$(($successlines/2))
	failurelines=`cat $otupickdir/blast_step1_reference/step1_failures.fasta | wc -l`
	failureseqs=$(($failurelines/2))

	echo "		$successseqs OTUs picked against reference collection.
		$failureseqs OTUs passed to de novo step.
	"

res11=$(date +%s.%N)
dt=$(echo "$res11 - $res10" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

otu_runtime=`printf "BLAST OTU picking runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`

echo "$otu_runtime

	" >> $log

	else
	echo "		BLAST reference-based OTU picking already completed (step 1 OTUs).
	"
fi

if [[ ! -f $otupickdir/cdhit_step2_denovo/step1_failures_otus.txt ]] || [[ ! -f $otupickdir/cdhit_step2_denovo/step2_rep_set.fasta ]]; then
res12=$(date +%s.%N)

	failurelines=`cat $otupickdir/blast_step1_reference/step1_failures.fasta | wc -l`
	failureseqs=$(($failurelines/2))

	echo "		Picking OTUs against step 1 failures.
		Input sequences: $failureseqs
		Method: CDHIT (step 2, de novo OTU picking)
	"
	echo "Picking OTUs against step 1 failures." >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "Input sequences: $failureseqs" >> $log
	echo "Method: CDHIT (step 2, de novo OTU picking)" >> $log

	`pick_otus.py -i $otupickdir/blast_step1_reference/step1_failures.fasta -o $otupickdir/cdhit_step2_denovo -m cdhit -M 8000`

	sed -i "s/^/cdhit.denovo.otu./" $otupickdir/cdhit_step2_denovo/step1_failures_otus.txt

	`merge_otu_maps.py -i $presufdir/$seqname\_otus.txt,$otupickdir/cdhit_step2_denovo/step1_failures_otus.txt -o $otupickdir/cdhit_step2_denovo/merged_step2_otus.txt`

	`pick_rep_set.py -i $otupickdir/cdhit_step2_denovo/merged_step2_otus.txt -f $seqs -o $otupickdir/cdhit_step2_denovo/step2_rep_set.fasta`

	denovolines=`cat $otupickdir/cdhit_step2_denovo/step2_rep_set.fasta | wc -l`
	denovoseqs=$(($denovolines/2))
	echo "		$denovoseqs additional OTUs clustered de novo.
	"

res13=$(date +%s.%N)
dt=$(echo "$res13 - $res12" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

denovo_runtime=`printf "CDHIT OTU picking runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`

echo "$denovo_runtime

	" >> $log

	else
	echo "		CDHIT de novo OTU picking already completed (step 2 OTUs).
	"
fi

if [[ ! -f $otupickdir/final_otu_map.txt ]]; then

	cat $otupickdir/blast_step1_reference/merged_step1_otus.txt $otupickdir/cdhit_step2_denovo/merged_step2_otus.txt > $otupickdir/final_otu_map.txt

fi

if [[ ! -f $otupickdir/final_rep_set.fasta ]]; then

	cat $otupickdir/blast_step1_reference/step1_rep_set.fasta $otupickdir/cdhit_step2_denovo/step2_rep_set.fasta > $otupickdir/final_rep_set.fasta
 
fi

## Assign taxonomy (BLAST)

taxdir=$outdir/$otupickdir/blast_taxonomy_assignment

	if [[ ! -f $taxdir/final_rep_set_tax_assignments.txt ]]; then
res24=$(date +%s.%N)
	echo "		Assigning taxonomy.
		Method: BLAST on $taxassignment_threads cores.
	"
	echo "Assigning taxonomy (BLAST):" >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "
	parallel_assign_taxonomy_blast.py -i $outdir/$otupickdir/final_rep_set.fasta -o $taxdir -r $refs -t $tax -O $taxassignment_threads
	" >> $log
	`parallel_assign_taxonomy_blast.py -i $outdir/$otupickdir/final_rep_set.fasta -o $taxdir -r $refs -t $tax -O $taxassignment_threads`
	wait

res25=$(date +%s.%N)
dt=$(echo "$res25 - $res24" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

tax_runtime=`printf "Tax assignment runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`	
echo "$tax_runtime

	" >> $log


	else
	echo "		Taxonomy assignments detected.
		$taxdir/merged_rep_set_tax_assignments.txt
		Skipping taxonomy assignment step.
	"
	fi

## Make raw otu table

	if [[ ! -f $outdir/$otupickdir/raw_otu_table.biom ]]; then
	
	echo "		Making raw OTU table.
	"
	echo "Making raw OTU table:" >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "
	make_otu_table.py -i $outdir/$otupickdir/final_otu_map.txt -t $taxdir/final_rep_set_tax_assignments.txt -o $outdir/$otupickdir/raw_otu_table.biom
	" >> $log
	`make_otu_table.py -i $outdir/$otupickdir/final_otu_map.txt -t $taxdir/final_rep_set_tax_assignments.txt -o $outdir/$otupickdir/raw_otu_table.biom`

	else
	echo "		Raw OTU table detected.
		$outdir/$otupickdir/raw_otu_table.biom
	"
	fi

## Filter low count samples

	if [[ ! -f $outdir/$otupickdir/min100_table ]]; then

	echo "		Filtering low count (<100) samples from
		raw OTU table.
	"
	`filter_samples_from_otu_table.py -i $outdir/$otupickdir/raw_otu_table.biom -o $outdir/$otupickdir/min100_table.biom -n 100`

	fi

## Filter by observation at different depths (2, 5, 10, 20)

	echo "		Filtering OTUs at various depths by observation (2, 5, 10, 20)
	"

	rm -f $outdir/$otupickdir/n2_table*
	rm -f $outdir/$otupickdir/n5_table*
	rm -f $outdir/$otupickdir/n10_table*
	rm -f $outdir/$otupickdir/n20_table*

	echo "2
5
10
20" > $outdir/$otupickdir/depths.temp

	for line in `cat $outdir/$otupickdir/depths.temp`; do
	
	filter_observations_by_sample.py -i $outdir/$otupickdir/min100_table.biom -o $outdir/$otupickdir/n$line\_table0.biom -n $line
	filter_otus_from_otu_table.py -i $outdir/$otupickdir/n$line\_table0.biom -o $outdir/$otupickdir/n$line\_table.biom -n $line -s 2
	biom convert -i $outdir/$otupickdir/n$line\_table.biom -o $outdir/$otupickdir/n$line\_table_hdf5.biom --table-type="OTU table" --to-hdf5
	normalize_table.py -i $outdir/$otupickdir/n$line\_table_hdf5.biom -o $outdir/$otupickdir/n$line\_table_CSS.biom -a CSS >/dev/null 2>&1 || true
	rm $outdir/$otupickdir/n$line\_table0.biom
	rm $outdir/$otupickdir/n$line\_table.biom

	done
	rm $outdir/$otupickdir/depths.temp


## Summarize raw otu tables and log final sequence count

	biom-summarize_folder.sh $outdir/$otupickdir >/dev/null
	written_seqs=`grep "Total count:" custom-openref_otus/raw_otu_table.summary | cut -d" " -f3`
	input_seqs=`grep "Total number seqs written" split_libraries/split_library_log.txt | cut -f2`

	echo "		$written_seqs out of $input_seqs input sequences written.
	"

## Print OTU table summary header to screen and log file

	echo "		Unfiltered OTU table summary header:
	"
	head -14 $outdir/$otupickdir/raw_otu_table.summary | sed 's/^/\t/'

	echo "Unfiltered OTU table summary header:
	" >> $log
	head -14 $outdir/$otupickdir/raw_otu_table.summary | sed 's/^/\t/' >> $log

## remove jobs directory

	if [[ -d $outdir/jobs ]]; then
	rm -r $outdir/jobs
	fi

res26=$(date +%s.%N)
dt=$(echo "$res26 - $res1" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

runtime=`printf "Total runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`

echo "		Workflow steps completed.

		$runtime
"
echo "---

All workflow steps completed.  Hooray!" >> $log
date "+%a %b %I:%M %p %Z %Y" >> $log
echo "
$runtime 
" >> $log

