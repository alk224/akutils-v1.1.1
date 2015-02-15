#!/bin/bash
set -e

## check whether user had supplied -h or --help. If yes display help 

	if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
		echo "
		chained_workflow-openref.sh 

		This script takes an input directory and attempts to
		process contents through a qiime workflow.  The workflow
		references a config file.  You can reference a global
		config file (default), or a local one, if present in the
		directory this script is executed on, will be referenced
		instead.  Config files can be defined with the config
		utility by issuing:

		chained_workflow-openref.sh config
		
		Or by calling the config program directly:

		akutils_config_utility.sh

		Usage (order is important!!):
		chained_workflow-openref.sh <input folder> <mode>

		Example:
		chained_workflow-openref.sh ./ 16S

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
		4) Open reference OTU picking (UCLUST, set CPUs in config)
		5) Parallel Pynast alignment (16S only, CPUs in config)
		6) MAFFT alignment (other only)
		7) Parallel BLAST taxonomy assignment
		8) Make and summarize OTU table (no filtering at all)

		Config file:
		To get this script to work you need a valid config file.
		You can generate a config file and set up the necessary
		fields by running the egw config utility:

		chained_workflow-dev.sh config

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
		akutils_config_utility.sh
		exit 0
	fi

## If other than two arguments supplied, display usage 

	if [  "$#" -ne 2 ]; then 

		echo "
		Usage (order is important!!):
		chained_workflow-openref.sh <input folder> <mode>
		"
		exit 1
	fi

## Check that valid mode was entered

	if [[ $2 != other && $2 != 16S ]]; then
		echo "
		Invalid mode entered (you entered $2).
		Valid modes are 16S or other.

		Usage (order is important!!):
		chained_workflow-openref.sh <input folder> <mode>
		"
		exit 1
	fi

	mode=($2)

## Define working directory and log file
	workdir=$(pwd)
	outdir=($1)

## Check if output directory already exists

	if [[ -d $outdir ]]; then
		echo "
		Output directory already exists.
		$outdir

		Checking for prior workflow progress...
		"
		if [[ -e $outdir/chained_workflow-openref*.log ]]; then
		date0=`date +%Y%m%d_%I%M%p`
		log=($outdir/chained_workflow-openref_$date0.log)
		echo "		Chained workflow restarting in $mode mode"
		date1=`date "+%a %b %I:%M %p %Z %Y"`
		echo "		$date1"
		res1=$(date +%s.%N)
			echo "
Chained workflow restarting in $mode mode" > $log
			date "+%a %b %I:%M %p %Z %Y" >> $log
		fi
	fi

	if [[ ! -d $outdir ]]; then
		mkdir -p $outdir
	fi

	if [[ ! -e $outdir/chained_workflow-openref*.log ]]; then
		echo "		Beginning chained workflow script in $mode mode"
		date1=`date "+%a %b %I:%M %p %Z %Y"`
		echo "		$date1"
		date0=`date +%Y%m%d_%I%M%p`
		log=($outdir/chained_workflow-openref_$date0.log)
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
	prefix_len=(`grep "Prefix_length" $config | grep -v "#" | cut -f 2`)
	suffix_len=(`grep "Suffix_length" $config | grep -v "#" | cut -f 2`)
	maxaccepts=(`grep "Max_accepts" $config | grep -v "#" | cut -f 2`)
	maxrejects=(`grep "Max_rejects" $config | grep -v "#" | cut -f 2`)
	
## Check for split_libraries outputs and inputs

if [[ -f $outdir/split_libraries/seqs.fna ]]; then
	echo "		Split libraries output detected. 
		$outdir/split_libraries/seqs.fna
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

## chained OTU picking

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

otupickdir=openref_otus

if [[ ! -f $otupickdir/final_otu_map.txt ]]; then
res10=$(date +%s.%N)

numseqs1=`cat $presufdir/prefix_rep_set.fasta | wc -l`
numseqs2=(`expr $numseqs1 / 2`)

	if [[ $parameter_count == 1 ]]; then
	sim=`grep similarity $param_file | cut -d " " -f 2`
	maxaccepts=`grep max_accepts $param_file | cut -d " " -f 2`
	maxrejects=`grep max_rejects $param_file | cut -d " " -f 2`
	fi
	if [[ -z $sim ]]; then
	sim=0.97
	fi
	if [[ -z $maxaccepts ]]; then
	maxaccepts=20
	fi
	if [[ -z $maxrejects ]]; then
	maxrejects=500
	fi

	echo "		Picking OTUs against collapsed rep set.
		Input sequences: $numseqs2
		Method: Open reference (UCLUST)
		Similarity: $sim
		Max accepts: $maxaccepts
		Max rejects: $maxrejects
	"
	echo "Picking OTUs against collapsed rep set." >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "Input sequences: $numseqs2" >> $log
	echo "Method: Open reference (UCLUST)" >> $log
	echo "Similarity: $sim" >> $log
	echo "Max accepts: $maxaccepts" >> $log
	echo "Max rejects: $maxrejects" >> $log

	if [[ $parameter_count == 1 ]]; then
	echo "
	pick_open_reference_otus.py -i $presufdir/prefix_rep_set.fasta -o $otupickdir -p $param_file -aO $otupicking_threads -r $refs --prefilter_percent_id 0.0 --suppress_taxonomy_assignment --suppress_align_and_tree
	" >> $log
	`pick_open_reference_otus.py -i $presufdir/prefix_rep_set.fasta -o $otupickdir -p $param_file -aO $otupicking_threads -r $refs --prefilter_percent_id 0.0 --suppress_taxonomy_assignment --suppress_align_and_tree`
	else
	echo "
	pick_open_reference_otus.py -i $presufdir/prefix_rep_set.fasta -o $otupickdir -aO $otupicking_threads -r $refs --prefilter_percent_id 0.0 --suppress_taxonomy_assignment --suppress_align_and_tree
	" >> $log
	`pick_open_reference_otus.py -i $presufdir/prefix_rep_set.fasta -o $otupickdir -aO $otupicking_threads -r $refs --prefilter_percent_id 0.0 --suppress_taxonomy_assignment --suppress_align_and_tree`
	fi

res11=$(date +%s.%N)
dt=$(echo "$res11 - $res10" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

otu_runtime=`printf "Open reference OTU picking runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`	
echo "$otu_runtime

	" >> $log

	else
	echo "		Open reference OTU picking already completed.
	"
fi

if [[ ! -f $otupickdir/merged_otu_map.txt ]]; then
res12=$(date +%s.%N)
	echo "		Merging OTU maps.
	"
	echo "Merging OTU maps:" >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "
	merge_otu_maps.py -i $presufdir/$seqname@_otus.txt,$otupickdir/final_otu_map.txt -o $otupickdir/merged_otu_map.txt
	" >> $log
	`merge_otu_maps.py -i $presufdir/$seqname\_otus.txt,$otupickdir/final_otu_map.txt -o $otupickdir/merged_otu_map.txt`

res13=$(date +%s.%N)
dt=$(echo "$res13 - $res12" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

merge_runtime=`printf "Merge OTU maps runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`	
echo "$merge_runtime

	" >> $log

	else
	echo "		OTU maps already merged.
	"
fi

if [[ ! -f $otupickdir/merged_rep_set.fna ]]; then
res14=$(date +%s.%N)
	echo "		Picking rep set against merged OTU map.
	"
	echo "Picking rep set against merged OTU map:" >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "	
	pick_rep_set.py -i $otupickdir/merged_otu_map.txt -f $seqs -o $otupickdir/merged_rep_set.fna
	" >> $log
	`pick_rep_set.py -i $otupickdir/merged_otu_map.txt -f $seqs -o $otupickdir/merged_rep_set.fna`
	
res15=$(date +%s.%N)
dt=$(echo "$res15 - $res14" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

mergerep_runtime=`printf "Pick rep set runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`	
echo "$mergerep_runtime

	" >> $log


	else
	echo "		Merged rep set already completed.
	"
fi

### Align sequences (16S mode)
#
#	if [[ $mode == "16S" ]]; then
#
#	if [[ ! -f $outdir/$otupickdir/pynast_aligned_seqs/merged_rep_set_aligned.fasta ]]; then
#res16=$(date +%s.%N)
#	echo "		Aligning sequences.
#		Method: Pynast on $alignseqs_threads cores
#		Template: $alignment_template
#	"
#	echo "Aligning sequences:" >> $log
#	date "+%a %b %I:%M %p %Z %Y" >> $log
#	echo "
#	parallel_align_seqs_pynast.py -i $outdir/$otupickdir/merged_rep_set.fna -o $outdir/$otupickdir/pynast_aligned_seqs -t $alignment_template -O $alignseqs_threads
#	" >> $log
#	`parallel_align_seqs_pynast.py -i $outdir/$otupickdir/merged_rep_set.fna -o $outdir/$otupickdir/pynast_aligned_seqs -t $alignment_template -O $alignseqs_threads`
#	wait
#
#res17=$(date +%s.%N)
#dt=$(echo "$res17 - $res16" | bc)
#dd=$(echo "$dt/86400" | bc)
#dt2=$(echo "$dt-86400*$dd" | bc)
#dh=$(echo "$dt2/3600" | bc)
#dt3=$(echo "$dt2-3600*$dh" | bc)
#dm=$(echo "$dt3/60" | bc)
#ds=$(echo "$dt3-60*$dm" | bc)
#
#align_runtime=`printf "Pynast alignment runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`	
#echo "$align_runtime
#
#	" >> $log
#
#	else	
#	echo "		Alignment file detected.
#		$outdir/$otupickdir/pynast_aligned_seqs/merged_rep_set_aligned.fasta
#		Skipping sequence alignment step.
#	"
#	fi
#	fi
#
### Align sequences (other mode)
#
#	if [[ $mode == "other" ]]; then
#
#	if [[ ! -f $outdir/$otupickdir/mafft_aligned_seqs/merged_rep_set_aligned.fasta ]]; then
#res18=$(date +%s.%N)
#	echo "		Aligning sequences.
#		Method: Mafft on a single core.
#		Template: none.
#	"
#	echo "Aligning sequences:" >> $log
#	date "+%a %b %I:%M %p %Z %Y" >> $log
#	echo "
#	align_seqs.py -i $outdir/$otupickdir/merged_rep_set.fna -o $outdir/$otupickdir/mafft_aligned_seqs -m mafft
#	" >> $log
#	`align_seqs.py -i $outdir/$otupickdir/merged_rep_set.fna -o $outdir/$otupickdir/mafft_aligned_seqs -m mafft`
#	wait
#
#res19=$(date +%s.%N)
#dt=$(echo "$res19 - $res18" | bc)
#dd=$(echo "$dt/86400" | bc)
#dt2=$(echo "$dt-86400*$dd" | bc)
#dh=$(echo "$dt2/3600" | bc)
#dt3=$(echo "$dt2-3600*$dh" | bc)
#dm=$(echo "$dt3/60" | bc)
#ds=$(echo "$dt3-60*$dm" | bc)
#
#align_runtime=`printf "Mafft alignment runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`	
#echo "$align_runtime
#
#	" >> $log
#
#	else	
#	echo "		Alignment file detected.
#		$outdir/$otupickdir/mafft_aligned_seqs/merged_rep_set_aligned.fasta
#		Skipping sequence alignment step.
#	"
#	fi
#	fi
#
### Filtering alignment (16S mode)
#
#	if [[ $mode == "16S" ]]; then
#
#	if [[  ! -f $outdir/$otupickdir/pynast_aligned_seqs/merged_rep_set_aligned_pfiltered.fasta ]]; then
#res20=$(date +%s.%N)
#	echo "		Filtering sequence alignment.
#		Lanemask file: $alignment_lanemask.
#	"
#	echo "Filtering alignment:" >> $log
#	date "+%a %b %I:%M %p %Z %Y" >> $log
#	echo "
#	filter_alignment.py -i $outdir/$otupickdir/pynast_aligned_seqs/merged_rep_set_aligned.fasta -o $outdir/$otupickdir/pynast_aligned_seqs/ -m $alignment_lanemask
#	" >> $log
#	`filter_alignment.py -i $outdir/$otupickdir/pynast_aligned_seqs/merged_rep_set_aligned.fasta -o $outdir/$otupickdir/pynast_aligned_seqs/ -m $alignment_lanemask`
#	wait
#
#res21=$(date +%s.%N)
#dt=$(echo "$res21 - $res20" | bc)
#dd=$(echo "$dt/86400" | bc)
#dt2=$(echo "$dt-86400*$dd" | bc)
#dh=$(echo "$dt2/3600" | bc)
#dt3=$(echo "$dt2-3600*$dh" | bc)
#dm=$(echo "$dt3/60" | bc)
#ds=$(echo "$dt3-60*$dm" | bc)
#
#filt_runtime=`printf "Alignment filtering runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`	
#echo "$filt_runtime
#
#	" >> $log
#
#	else
#	echo "		Filtered alignment detected.
#		$outdir/$otupickdir/pynast_aligned_seqs/merged_rep_set_aligned_pfiltered.fasta
#		Skipping alignment filtering step.
#	"
#	fi
#	fi
#
### Filtering alignment (other mode)
#
#	if [[ $mode == "other" ]]; then
#
#	if [[  ! -f $outdir/$otupickdir/mafft_aligned_seqs/merged_rep_set_aligned_pfiltered.fasta ]]; then
#res22=$(date +%s.%N)
#	echo "		Filtering sequence alignment.
#		Entropy threshold: 0.1
#	"
#	echo "Filtering alignment:" >> $log
#	date "+%a %b %I:%M %p %Z %Y" >> $log
#	echo "
#	filter_alignment.py -i $outdir/$otupickdir/mafft_aligned_seqs/merged_rep_set_aligned.fasta -o $outdir/$otupickdir/mafft_aligned_seqs/ -e 0.1
#	" >> $log
#	`filter_alignment.py -i $outdir/$otupickdir/mafft_aligned_seqs/merged_rep_set_aligned.fasta -o $outdir/$otupickdir/mafft_aligned_seqs/ -e 0.1`
#	wait
#
#res23=$(date +%s.%N)
#dt=$(echo "$res23 - $res22" | bc)
#dd=$(echo "$dt/86400" | bc)
#dt2=$(echo "$dt-86400*$dd" | bc)
#dh=$(echo "$dt2/3600" | bc)
#dt3=$(echo "$dt2-3600*$dh" | bc)
#dm=$(echo "$dt3/60" | bc)
#ds=$(echo "$dt3-60*$dm" | bc)
#
#filt_runtime=`printf "Alignment filtering runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`	
#echo "$filt_runtime
#
#	" >> $log
#
#	else
#	echo "		Filtered alignment detected.
#		$outdir/$otupickdir/mafft_aligned_seqs/merged_rep_set_aligned_pfiltered.fasta
#		Skipping alignment filtering step.
#	"
#	fi
#	fi
#
### Make phylogeny in background (16S mode)
#
#	if [[ $mode == "16S" ]]; then
#
#	if [[ ! -f $outdir/$otupickdir/pynast_aligned_seqs/fasttree_phylogeny.tre ]]; then
#
#	echo "		Constructing phylogeny based on sample sequences.
#		Method: Fasttree
#	"
#	echo "Making phylogeny:" >> $log
#	date "+%a %b %I:%M %p %Z %Y" >> $log
#	echo "
#	make_phylogeny.py -i $outdir/$otupickdir/pynast_aligned_seqs/merged_rep_set_aligned_pfiltered.fasta -o $outdir/$otupickdir/pynast_aligned_seqs/fasttree_phylogeny.tre
#	" >> $log
#	( `make_phylogeny.py -i $outdir/$otupickdir/pynast_aligned_seqs/merged_rep_set_aligned_pfiltered.fasta -o $outdir/$otupickdir/pynast_aligned_seqs/fasttree_phylogeny.tre` ) &
#
#	else
#	echo "		Phylogenetic tree detected.
#		$outdir/$otupickdir/pynast_aligned_seqs/fasttree_phylogeny.tre
#		Skipping make phylogeny step.
#	"
#	fi
#	fi
#
### Make phylogeny in background (other mode)
#
#	if [[ $mode == "other" ]]; then
#
#	if [[ ! -f $outdir/$otupickdir/mafft_aligned_seqs/fasttree_phylogeny.tre ]]; then
#
#	echo "		Constructing phylogeny based on sample sequences.
#		Method: Fasttree
#	"
#	echo "Making phylogeny:" >> $log
#	date "+%a %b %I:%M %p %Z %Y" >> $log
#	echo "
#	make_phylogeny.py -i $outdir/$otupickdir/mafft_aligned_seqs/merged_rep_set_aligned_pfiltered.fasta -o $outdir/$otupickdir/mafft_aligned_seqs/fasttree_phylogeny.tre
#	" >> $log
#	( `make_phylogeny.py -i $outdir/$otupickdir/mafft_aligned_seqs/merged_rep_set_aligned_pfiltered.fasta -o $outdir/$otupickdir/mafft_aligned_seqs/fasttree_phylogeny.tre` ) &
#
#	else
#	echo "		Phylogenetic tree detected.
#		$outdir/$otupickdir/mafft_aligned_seqs/fasttree_phylogeny.tre
#		Skipping make phylogeny step.
#	"
#	fi
#	fi
#
## Assign taxonomy (BLAST)

taxdir=$outdir/$otupickdir/blast_taxonomy_assignment

	if [[ ! -f $taxdir/merged_rep_set_tax_assignments.txt ]]; then
res24=$(date +%s.%N)
	echo "		Assigning taxonomy.
		Method: BLAST on $taxassignment_threads cores.
	"
	echo "Assigning taxonomy (BLAST):" >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "
	parallel_assign_taxonomy_blast.py -i $outdir/$otupickdir/merged_rep_set.fna -o $taxdir -r $refs -t $tax -O $taxassignment_threads
	" >> $log
	`parallel_assign_taxonomy_blast.py -i $outdir/$otupickdir/merged_rep_set.fna -o $taxdir -r $refs -t $tax -O $taxassignment_threads`
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

## Make initial otu table (needs hdf5 conversion)

	if [[ ! -f $outdir/$otupickdir/initial_otu_table.biom ]]; then
	
	echo "		Making initial OTU table.
	"
	echo "Making initial OTU table:" >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "
	make_otu_table.py -i $outdir/$otupickdir/merged_otu_map.txt -t $taxdir/merged_rep_set_tax_assignments.txt -o $outdir/$otupickdir/initial_otu_table.biom
	" >> $log
	`make_otu_table.py -i $outdir/$otupickdir/merged_otu_map.txt -t $taxdir/merged_rep_set_tax_assignments.txt -o $outdir/$otupickdir/initial_otu_table.biom`

	else
	echo "		Initial OTU table detected.
		$outdir/$otupickdir/initial_otu_table.biom
	"
	fi

## Convert initial table to raw table (hdf5)

	if [[ ! -f $outdir/$otupickdir/raw_otu_table.biom ]]; then
	
	echo "		Making raw hdf5 OTU table.
	"
	echo "Making raw hdf5 OTU table:" >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "
	biom convert -i $outdir/$otupickdir/initial_otu_table.biom -o $outdir/$otupickdir/raw_otu_table.biom --table-type=\"OTU table\" --to-hdf5
	" >> $log
	`biom convert -i $outdir/$otupickdir/initial_otu_table.biom -o $outdir/$otupickdir/raw_otu_table.biom --table-type="OTU table" --to-hdf5`
	wait
	rm $outdir/$otupickdir/initial_otu_table.biom
	else
	echo "		Raw OTU table detected.
		$outdir/$otupickdir/raw_otu_table.biom
		Moving to final filtering steps.
	"
	fi

## Summarize raw otu table in background

	if [[ ! -f $outdir/$otupickdir/raw_otu_table.summary ]]; then
	( `biom summarize-table -i $outdir/$otupickdir/raw_otu_table.biom -o $outdir/$otupickdir/raw_otu_table.summary` ) &
	fi
wait

## Print OTU table summary header to screen and log file

	echo "		Unfiltered OTU table summary header:
	"
	head -14 $outdir/$otupickdir/raw_otu_table.summary

	echo "Unfiltered OTU table summary header:
	" >> $log
	head -14 $outdir/$otupickdir/raw_otu_table.summary >> $log

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

