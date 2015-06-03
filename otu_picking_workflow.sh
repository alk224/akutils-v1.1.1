#!/bin/bash
set -e

## check whether user had supplied -h or --help. If yes display help 

	if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
	scriptdir="$( cd "$( dirname "$0" )" && pwd )"
	less $scriptdir/docs/otu_picking_workflow.help
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
	chained_workflow-swarm.sh <input folder> <mode>
	"
	exit 1
	fi

## Check that valid mode was entered

	if [[ $2 != other && $2 != 16S && $2 != ITS ]]; then
	echo "
	Invalid mode entered (you entered $2).
	Valid modes are 16S, ITS, or other.

	Usage (order is important!!):
	chained_workflow-swarm.sh <input folder> <mode>
	"
	exit 1
	fi

	mode=($2)

## Define working directory and log file
	workdir=$(pwd)
	cd $1
	outdir=$(pwd)
	cd $workdir

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

	logcount=`ls $outdir/log_otu_picking_workflow* 2>/dev/null | wc -l`

	if [[ $logcount > 0 ]]; then
		log=`ls $outdir/log_otu_picking_workflow*.txt | head -1`
		echo "	Chained workflow restarting in $mode mode"
		date1=`date "+%a %b %I:%M %p %Z %Y"`
		echo "	$date1"
		res1=$(date +%s.%N)
			echo "
Chained workflow restarting in $mode mode" >> $log
			date "+%a %b %I:%M %p %Z %Y" >> $log
	else
		echo "	Beginning chained workflow script in $mode mode"
		date1=`date "+%a %b %I:%M %p %Z %Y"`
		echo "	$date1"
		date0=`date +%Y%m%d_%I%M%p`
		log=($outdir/log_otu_picking_workflow_$date0.txt)
		echo "
Chained workflow beginning in $mode mode" > $log
		date "+%a %b %I:%M %p %Z %Y" >> $log
		res1=$(date +%s.%N)
		echo "
---
		" >> $log
	fi

## Establish temp directory

	if [[ ! -d $outdir/workflow_temp ]]; then
	mkdir -p $outdir/workflow_temp
	fi

	tempdir=$outdir/workflow_temp

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
	echo "	$line is in your path..."
	fi
	fi
done
echo "
	All dependencies satisfied.  Proceeding...
"

## Read in variables from config file

	local_config_count=(`ls $1/akutils*.config 2>/dev/null | wc -w`)
	if [[ $local_config_count -ge 1 ]]; then

	config=`ls $1/akutils*.config`

	echo "	Using local akutils config file.
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

		echo "	Using global akutils config file.
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
	chimera_threads=(`grep "Chimera_filter_subsearches" $config | grep -v "#" | cut -f 2`)
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
	otupicker=(`grep "OTU_picker" $config | grep -v "#" | cut -f 2`)
	taxassigner=(`grep "Tax_assigner" $config | grep -v "#" | cut -f 2`)

## Check for valid OTU picking and tax assignment modes

if [[ "$otupicker" != "blast" && "$otupicker" != "cdhit" && "$otupicker" != "swarm" && "$otupicker" != "openref" && "$otupicker" != "custom_openref" && "$otupicker" != "ALL" ]]; then
	echo "	Invalid OTU picking method chosen.
	Your current setting: $otupicker

	Valid choices are blast, cdhit, swarm, openref, custom_openref, or ALL.
	Rerun akutils_config_utility and change the current OTU picker setting.
	Exiting.
	"
	exit 1
	else echo "	OTU picking method(s): $otupicker
	"
fi

if [[ "$taxassigner" != "blast" && "$taxassigner" != "rdp" && "$taxassigner" != "uclust" && "$taxassigner" != "ALL" ]]; then
	echo "	Invalid taxonomy assignment method chosen.
	Your current setting: $taxassigner

	Valid choices are blast, rdp, uclust ALL. Rerun akutils_config_utility
	and change the current taxonomy assigner setting.
	Exiting.
	"
	exit 1
	else echo "	Taxonomy assignment method(s): $taxassigner
	"
fi
	
## Check for split_libraries outputs and inputs

if [[ -f $outdir/split_libraries/seqs.fna ]]; then
	echo "	Split libraries output detected.
	"
	else
	echo "	Split libraries needs to be completed.
	Checking for fastq files.
	"

		if [[ ! -f idx.fq ]]; then
		echo "	Index file not present (./idx.fq).
	Correct this error by renaming your index file as idx.fq
	and ensuring it resides within this directory
		"
		exit 1
		fi

		if [[ ! -f rd.fq ]]; then
		echo "	Sequence read file not present (./rd.fq).
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
	echo "	Performing split_libraries.py command (q$qvalue)"
	if [[ $barcodetype == "golay_12" ]]; then
	echo " 		12 base Golay index codes detected...
	"
	else
	echo "	$barcodetype base indexes detected...
	"
	fi

	echo "Split libraries command:" >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "
	split_libraries_fastq.py -i rd.fq -b idx.fq -m $map -o $outdir/split_libraries -q $qual --barcode_type $barcodetype -p 0.95 -r 0
	" >> $log
	res2=$(date +%s.%N)

	`split_libraries_fastq.py -i rd.fq -b idx.fq -m $map -o $outdir/split_libraries -q $qual --barcode_type $barcodetype -p 0.95 -r 0`

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

## Chimera filtering step

	if [[ $chimera_refs != "undefined" ]]; then
	if [[ ! -f $outdir/split_libraries/seqs_chimera_filtered.fna ]]; then

	echo "	Filtering chimeras.
	Method: vsearch (uchime_ref)
	Reference: $chimera_refs
	Threads: $chimera_threads
	Input sequences: $numseqs
"
	echo "
Chimera filtering commands:" >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "Method: vsearch (uchime_ref)
Reference: $chimera_refs
	" >> $log
res4=$(date +%s.%N)

	echo "	vsearch --uchime_ref $outdir/split_libraries/seqs.fna --db $chimera_refs --threads $chimera_threads --nonchimeras $outdir/split_libraries/vsearch_nonchimeras.fna" >> $log

	`vsearch --uchime_ref $outdir/split_libraries/seqs.fna --db $chimera_refs --threads $chimera_threads --nonchimeras $outdir/split_libraries/vsearch_nonchimeras.fna &>>$log`
	wait

	#unwrap output
	unwrap_fasta.sh $outdir/split_libraries/vsearch_nonchimeras.fna $outdir/split_libraries/seqs_chimera_filtered.fna

		chimeracount1=`cat $outdir/split_libraries/seqs_chimera_filtered.fna | wc -l`
		chimeracount2=`expr $chimeracount1 / 2`
		seqcount1=`cat $outdir/split_libraries/seqs.fna | wc -l`
		seqcount=`expr $seqcount1 / 2`
		chimeracount=`expr $seqcount \- $chimeracount2`

	echo "	Identified $chimeracount chimeric sequences from $seqcount
	total reads in your data."
	echo "	Identified $chimeracount chimeric sequences from $seqcount
		total reads in your data.
	" >> $log

#	`filter_fasta.py -f $outdir/split_libraries/seqs.fna -o $outdir/split_libraries/seqs_chimera_filtered.fna -s $outdir/usearch61_chimera_checking/all_chimeras.txt -n`
	wait
	rm $outdir/split_libraries/vsearch_nonchimeras.fna
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

	echo "	Chimera filtered sequences detected.
	"
seqs=$outdir/split_libraries/seqs_chimera_filtered.fna
	fi
	else echo "	No chimera reference collection supplied.
	Skipping chimera checking step.
	"
	fi

## ITSx filtering (mode ITS only)

	if [[ $mode == "ITS" ]]; then

## Set seqs variable in case prior steps are skipped.  Prefer chimera filtered results.

	if [[ -f $outdir/split_libraries/seqs_chimera_filtered.fna ]]; then
	seqs=$outdir/split_libraries/seqs_chimera_filtered.fna
	else
	seqs=$outdir/split_libraries/seqs.fna
	fi

	seqbase1=`basename $seqs .fna`

	if [[ ! -f $outdir/split_libraries/$seqbase1\_ITSx_filtered.fna ]]; then

	slcount0=`cat $seqs | wc -l`
	slcount=`expr $slcount0 / 2`
	echo "	Screening sequences for ITS HMMer profiles
	with ITSx on $itsx_threads cores.
	Input sequences: $slcount
	"

	echo "
ITSx command:" >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "
	ITSx_parallel.sh $seqs $itsx_threads $itsx_options
	" >> $log

res45=$(date +%s.%N)
	ITSx_parallel.sh $seqs $itsx_threads $itsx_options 2>/dev/null 1>/dev/null
	wait
res55=$(date +%s.%N)
dt=$(echo "$res55 - $res45" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

itsx_runtime=`printf "ITSx runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`	
echo "$itsx_runtime

" >> $log

	ITSx_check=`grep "No ITS profiles matched in full sequences.  No detections attempted for ITS1 and ITS2." $outdir/split_libraries/seqs_ITSx_output/log_* 2>/dev/null | wc -l`

	if [[ $ITSx_check == 1 ]]; then
	echo "	ITSx step failed to identify any ITS profiles.
	Check your data and try again.  Exiting.
	"
	exit 1

	fi
	else

	echo "	ITSx filtered sequences detected.
	"

	fi
	if [[ -f $outdir/split_libraries/seqs_chimera_filtered_ITSx_filtered.fna ]]; then
	seqs=$outdir/split_libraries/seqs_chimera_filtered_ITSx_filtered.fna
	elif [[ -f $outdir/split_libraries/seqs_ITSx_filtered.fna ]]; then
	seqs=$outdir/split_libraries/seqs_ITSx_filtered.fna
	fi
	fi

## Reverse complement demultiplexed sequences if necessary
#
#	if [[ $revcomp == "True" ]]; then
#
#	if [[ ! -f $outdir/split_libraries/seqs_rc.fna ]]; then
#
#	echo "		Reverse complementing split libraries output according
#		to config file setting.
#	"
#	echo "
#Reverse complement command:"
#	date "+%a %b %I:%M %p %Z %Y" >> $log
#	echo "
#	adjust_seq_orientation.py -i $seqs -r -o $outdir/split_libraries/seqs_rc.fna
#	" >> $log
#
#	`adjust_seq_orientation.py -i $seqs -r -o $outdir/split_libraries/seqs_rc.fna`
#	wait
#	echo "		Demultiplexed sequences were reverse complemented.
#	"
#	seqs=$outdir/split_libraries/seqs_rc.fna
#	fi
#	else
#	echo "		Sequences already in proper orientation.
#	"
#	fi

## chained OTU picking

numseqs0=`cat $seqs | wc -l`
numseqs=(`expr $numseqs0 / 2`)

seqpath="${seqs%.*}"
seqname=`basename $seqpath`
presufdir=prefix$prefix_len\_suffix$suffix_len/

if [[ ! -f $presufdir/$seqname\_otus.txt ]]; then
res6=$(date +%s.%N)
	echo "	Collapsing sequences with prefix/suffix picker.
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
	echo "	Prefix/suffix step previously completed.
	"
fi

if [[ ! -f $presufdir/prefix_rep_set.fasta ]]; then
res8=$(date +%s.%N)
	echo "	Picking rep set with prefix/suffix-collapsed OTU map.
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
	echo "	Prefix/suffix rep set already present.
	"
fi

################################
## SWARM OTU Steps BEGIN HERE ##
################################

## Define otu picking parameters ahead of outdir naming

if [[ $otupicker == "swarm" || $otupicker == "ALL" ]]; then
otumethod=Swarm

if [[ $parameter_count == 1 ]]; then
	grep "swarm_resolution" $param_file | cut -d " " -f2 | sed '/^$/d' > $tempdir/swarm_resolutions.temp
	else
	echo 1 > $tempdir/swarm_resolutions.temp
fi
	resolutioncount=`cat $tempdir/swarm_resolutions.temp | wc -l`

	if [[ $resolutioncount == 0 ]]; then
	echo 1 > $tempdir/swarm_resolutions.temp
	fi

	resolutioncount=`cat $tempdir/swarm_resolutions.temp | wc -l`

	echo "	Beginning sequential OTU picking (Swarm) at $resolutioncount resolution values.
	"
	echo "Beginning sequential OTU picking (Swarm) at $resolutioncount resolution values." >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	res9a=$(date +%s.%N)

## Start sequential OTU picking (swarm)

for resolution in `cat $tempdir/swarm_resolutions.temp`; do

otupickdir=swarm_otus_d$resolution

if [[ ! -f $otupickdir/prefix_rep_set_otus.txt ]]; then
res10=$(date +%s.%N)

numseqs1=`cat $presufdir/prefix_rep_set.fasta | wc -l`
numseqs2=(`expr $numseqs1 / 2`)

	echo "	Picking OTUs against collapsed rep set.
	Input sequences: $numseqs2
	Method: SWARM (de novo)"
	echo "Picking OTUs against collapsed rep set." >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "Input sequences: $numseqs2" >> $log
	echo "Method: SWARM (de novo)" >> $log
	echo "Swarm resolution: $resolution" >> $log
	echo "	Swarm resolution: $resolution
	"
	echo "
	pick_otus.py -m swarm -i $presufdir/prefix_rep_set.fasta -o $otupickdir --threads $otupicking_threads --swarm_resolution $resolution
	" >> $log
	`pick_otus.py -m swarm -i $presufdir/prefix_rep_set.fasta -o $otupickdir --threads $otupicking_threads --swarm_resolution $resolution`

res11=$(date +%s.%N)
dt=$(echo "$res11 - $res10" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

otu_runtime=`printf "SWARM OTU picking runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`	
echo "$otu_runtime

	" >> $log

	else
	echo "	SWARM OTU picking already completed (d$resolution).
	"
fi

if [[ ! -f $otupickdir/merged_otu_map.txt ]]; then
res12=$(date +%s.%N)
	echo "	Merging OTU maps.
	"
	echo "Merging OTU maps:" >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "
	merge_otu_maps.py -i $presufdir/$seqname@_otus.txt,$otupickdir/prefix_rep_set_otus.txt -o $otupickdir/merged_otu_map.txt
	" >> $log
	merge_otu_maps.py -i $presufdir/$seqname\_otus.txt,$otupickdir/prefix_rep_set_otus.txt -o $otupickdir/merged_otu_map.txt

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
	echo "	OTU maps already merged.
	"
fi

if [[ ! -f $otupickdir/merged_rep_set.fna ]]; then
res14=$(date +%s.%N)
	echo "	Picking rep set against merged OTU map.
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
	echo "	Merged rep set already completed.
	"
fi

## Assign taxonomy (one or all tax assigners)

## BLAST

if [[ $taxassigner == "blast" || $taxassigner == "ALL" ]]; then
taxmethod=BLAST
taxdir=$outdir/$otupickdir/blast_taxonomy_assignment

	if [[ ! -f $taxdir/merged_rep_set_tax_assignments.txt ]]; then
res24=$(date +%s.%N)
	echo "	Assigning taxonomy.
	Method: $taxmethod on $taxassignment_threads cores.
	"
	echo "Assigning taxonomy ($taxmethod):" >> $log
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

tax_runtime=`printf "$taxmethod taxonomy assignment runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`	
echo "$tax_runtime

	" >> $log
	else
	echo "	$taxmethod taxonomy assignments detected.
	"
	fi

## Build OTU tables

	if [[ ! -d $otupickdir/OTU_tables_blast_tax ]]; then
		mkdir -p $otupickdir/OTU_tables_blast_tax
	fi
	otutable_dir=$otupickdir/OTU_tables_blast_tax

## Make initial otu table (needs hdf5 conversion)

	if [[ ! -f $otutable_dir/raw_otu_table.biom ]]; then	
	echo "	Building OTU tables with $taxmethod assignments.
	"
	echo "Making initial OTU table:" >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "
	make_otu_table.py -i $outdir/$otupickdir/merged_otu_map.txt -t $taxdir/merged_rep_set_tax_assignments.txt -o $otutable_dir/initial_otu_table.biom
	" >> $log
	`make_otu_table.py -i $outdir/$otupickdir/merged_otu_map.txt -t $taxdir/merged_rep_set_tax_assignments.txt -o $otutable_dir/initial_otu_table.biom`

	fi

## Convert initial table to raw table (hdf5)

	if [[ ! -f $otutable_dir/raw_otu_table.biom ]]; then
	echo "	Making raw hdf5 OTU table.
	"
	echo "Making raw hdf5 OTU table:" >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "
	biom convert -i $otutable_dir/initial_otu_table.biom -o $otutable_dir/raw_otu_table.biom --table-type=\"OTU table\" --to-hdf5
	" >> $log
	`biom convert -i $otutable_dir/initial_otu_table.biom -o $otutable_dir/raw_otu_table.biom --table-type="OTU table" --to-hdf5`
	wait
	rm $otutable_dir/initial_otu_table.biom
	else
	echo "	Raw OTU table detected.
	"
	raw_or_taxfiltered_table=$otutable_dir/raw_otu_table.biom
	fi

## Filter non-target taxa (ITS and 16S mode only)

	if [[ $mode == "16S" ]]; then
		if [[ ! -f $otutable_dir/raw_otu_table_bacteria_only.biom ]]; then
		echo "	Filtering away non-prokaryotic sequences.
		"
		`filter_taxa_from_otu_table.py -i $otutable_dir/raw_otu_table.biom -o $otutable_dir/raw_otu_table_bacteria_only.biom -p k__Bacteria,k__Archaea` >/dev/null 2>&1 || true
		fi
		if [[ -f $otutable_dir/raw_otu_table_bacteria_only.biom ]]; then
		raw_or_taxfiltered_table=$otutable_dir/raw_otu_table_bacteria_only.biom
		fi
	fi

	if [[ $mode == "ITS" ]]; then
		if [[ ! -f $otutable_dir/raw_otu_table_fungi_only.biom ]]; then
		echo "	Filtering away non-fungal sequences.
		"
		`filter_taxa_from_otu_table.py -i $otutable_dir/raw_otu_table.biom -o $otutable_dir/raw_otu_table_fungi_only.biom -p k__Fungi` >/dev/null 2>&1 || true
		fi
		if [[ -f $otutable_dir/raw_otu_table_fungi_only.biom ]]; then
		raw_or_taxfiltered_table=$otutable_dir/raw_otu_table_fungi_only.biom
		fi
	fi

## Filter low count samples

	if [[ ! -f $otutable_dir/min100_table.biom ]]; then
	echo "	Filtering away low count samples (<100 reads).
	"
	`filter_samples_from_otu_table.py -i $raw_or_taxfiltered_table -o $otutable_dir/min100_table.biom -n 100`
	fi

## Filter singletons and unshared OTUs from each sample

if [[ ! -f $otutable_dir/n2_table_hdf5.biom ]] && [[ ! -f $otutable_dir/n2_table_CSS.biom ]] && [[ ! -f $otutable_dir/mc2_table_hdf5.biom ]] && [[ ! -f $otutable_dir/mc2_table_CSS.biom ]] && [[ ! -f $otutable_dir/005_table_hdf5.biom ]] && [[ ! -f $otutable_dir/005_table_CSS.biom ]] && [[ ! -f $otutable_dir/03_table_hdf5.biom ]] && [[ ! -f $otutable_dir/03_table_CSS.biom ]]; then

	if [[ ! -f $otutable_dir/n2_table_hdf5.biom ]]; then
	## filter singletons by sample and normalize
	filter_observations_by_sample.py -i $otutable_dir/min100_table.biom -o $otutable_dir/n2_table0.biom -n 1
	filter_otus_from_otu_table.py -i $otutable_dir/n2_table0.biom -o $otutable_dir/n2_table.biom -n 1 -s 2
	biom convert -i $otutable_dir/n2_table.biom -o $otutable_dir/n2_table_hdf5.biom --table-type="OTU table" --to-hdf5
	fi

	if [[ ! -f $otutable_dir/n2_table_CSS.biom ]]; then
	normalize_table.py -i $otutable_dir/n2_table_hdf5.biom -o $otutable_dir/n2_table_CSS.biom -a CSS >/dev/null 2>&1 || true
	fi

	## filter singletons by table and normalize
	if [[ ! -f $otutable_dir/mc2_table_hdf5.biom ]]; then
	filter_otus_from_otu_table.py -i $otutable_dir/min100_table.biom -o $otutable_dir/mc2_table_hdf5.biom -n 2 -s 2
	fi

	if [[ ! -f $otutable_dir/mc2_table_CSS.biom ]]; then
	normalize_table.py -i $otutable_dir/mc2_table_hdf5.biom -o $otutable_dir/mc2_table_CSS.biom -a CSS >/dev/null 2>&1 || true
	fi

	## filter table by 0.005 percent and normalize
	if [[ ! -f $otutable_dir/005_table_hdf5.biom ]]; then
	filter_otus_from_otu_table.py -i $otutable_dir/min100_table.biom -o $otutable_dir/005_table_hdf5.biom --min_count_fraction 0.00005 -s 2
	fi

	if [[ ! -f $otutable_dir/005_table_CSS.biom ]]; then
	normalize_table.py -i $otutable_dir/005_table_hdf5.biom -o $otutable_dir/005_table_CSS.biom -a CSS >/dev/null 2>&1 || true
	fi

	## filter at 0.3% by sample and normalize
	if [[ ! -f $otutable_dir/03_table_hdf5.biom ]]; then
	filter_observations_by_sample.py -i $otutable_dir/min100_table.biom -o $otutable_dir/03_table0.biom -f -n 0.003
	filter_otus_from_otu_table.py -i $otutable_dir/03_table0.biom -o $otutable_dir/03_table.biom -n 1 -s 2
	biom convert -i $otutable_dir/03_table.biom -o $otutable_dir/03_table_hdf5.biom --table-type="OTU table" --to-hdf5
	fi

	if [[ ! -f $otutable_dir/03_table_CSS.biom ]]; then
	normalize_table.py -i $otutable_dir/03_table_hdf5.biom -o $otutable_dir/03_table_CSS.biom -a CSS >/dev/null 2>&1 || true
	fi

	rm $otutable_dir/03_table0.biom >/dev/null 2>&1 || true
	rm $otutable_dir/03_table.biom >/dev/null 2>&1 || true
	rm $otutable_dir/n2_table0.biom >/dev/null 2>&1 || true
	rm $otutable_dir/n2_table.biom >/dev/null 2>&1 || true

## Summarize raw otu tables

	biom-summarize_folder.sh $otutable_dir >/dev/null
	written_seqs=`grep "Total count:" $otutable_dir/n2_table_hdf5.summary | cut -d" " -f3`
	input_seqs=`grep "Total number seqs written" split_libraries/split_library_log.txt | cut -f2`
	echo "	$written_seqs out of $input_seqs input sequences written.
	"

## Print filtered OTU table summary header to screen and log file

	echo "	OTU picking method: $otumethod (d$resolution)
	Tax assignment method: $taxmethod
	Singleton-filtered OTU table summary header:
	"
	head -14 $otutable_dir/n2_table_hdf5.summary | sed 's/^/\t\t/'
	echo "OTU picking method:
Tax assignment method: $taxmethod
Singleton-filtered OTU table summary header:
	" >> $log
	head -14 $otutable_dir/n2_table_hdf5.summary | sed 's/^/\t\t/' >> $log

	else
	echo "	Filtered tables detected.
	"
fi
fi

#####

## RDP

if [[ $taxassigner == "rdp" || $taxassigner == "ALL" ]]; then
taxmethod=RDP
taxdir=$outdir/$otupickdir/rdp_taxonomy_assignment

	## Adjust threads since RDP seems to choke with too many threads (> 12)
	if [[ $taxassignment_threads -gt 12 ]]; then
		rdptaxassignment_threads=12
	else
		rdptaxassignment_threads=$taxassignment_threads
	fi

	if [[ ! -f $taxdir/merged_rep_set_tax_assignments.txt ]]; then
res24=$(date +%s.%N)
	echo "	Assigning taxonomy.
	Method: $taxmethod on $rdptaxassignment_threads cores.
	"
	echo "Assigning taxonomy ($taxmethod):" >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "
	parallel_assign_taxonomy_rdp.py -i $outdir/$otupickdir/merged_rep_set.fna -o $taxdir -r $refs -t $tax -O $rdptaxassignment_threads -c 0.5 --rdp_max_memory 6000
	" >> $log
	`parallel_assign_taxonomy_rdp.py -i $outdir/$otupickdir/merged_rep_set.fna -o $taxdir -r $refs -t $tax -O $rdptaxassignment_threads -c 0.5 --rdp_max_memory 6000`
	wait

res25=$(date +%s.%N)
dt=$(echo "$res25 - $res24" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

tax_runtime=`printf "$taxmethod taxonomy assignment runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`	
echo "$tax_runtime

	" >> $log


	else
	echo "	$taxmethod taxonomy assignments detected.
	"
	fi

## Build OTU tables

	if [[ ! -d $otupickdir/OTU_tables_rdp_tax ]]; then
		mkdir -p $otupickdir/OTU_tables_rdp_tax
	fi
	otutable_dir=$otupickdir/OTU_tables_rdp_tax

## Make initial otu table (needs hdf5 conversion)

	if [[ ! -f $otutable_dir/raw_otu_table.biom ]]; then	
	echo "	Building OTU tables with $taxmethod assignments.
	"
	echo "Making initial OTU table:" >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "
	make_otu_table.py -i $outdir/$otupickdir/merged_otu_map.txt -t $taxdir/merged_rep_set_tax_assignments.txt -o $otutable_dir/initial_otu_table.biom
	" >> $log
	`make_otu_table.py -i $outdir/$otupickdir/merged_otu_map.txt -t $taxdir/merged_rep_set_tax_assignments.txt -o $otutable_dir/initial_otu_table.biom`

	fi

## Convert initial table to raw table (hdf5)

	if [[ ! -f $otutable_dir/raw_otu_table.biom ]]; then
	echo "	Making raw hdf5 OTU table.
	"
	echo "Making raw hdf5 OTU table:" >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "
	biom convert -i $otutable_dir/initial_otu_table.biom -o $otutable_dir/raw_otu_table.biom --table-type=\"OTU table\" --to-hdf5
	" >> $log
	`biom convert -i $otutable_dir/initial_otu_table.biom -o $otutable_dir/raw_otu_table.biom --table-type="OTU table" --to-hdf5`
	wait
	rm $otutable_dir/initial_otu_table.biom
	else
	echo "	Raw OTU table detected.
	"
	raw_or_taxfiltered_table=$otutable_dir/raw_otu_table.biom
	fi

## Filter non-target taxa (ITS and 16S mode only)

	if [[ $mode == "16S" ]]; then
		if [[ ! -f $otutable_dir/raw_otu_table_bacteria_only.biom ]]; then
		echo "	Filtering away non-prokaryotic sequences.
		"
		`filter_taxa_from_otu_table.py -i $otutable_dir/raw_otu_table.biom -o $otutable_dir/raw_otu_table_bacteria_only.biom -p k__Bacteria,k__Archaea` >/dev/null 2>&1 || true
		fi
		if [[ -f $otutable_dir/raw_otu_table_bacteria_only.biom ]]; then
		raw_or_taxfiltered_table=$otutable_dir/raw_otu_table_bacteria_only.biom
		fi
	fi

	if [[ $mode == "ITS" ]]; then
		if [[ ! -f $otutable_dir/raw_otu_table_fungi_only.biom ]]; then
		echo "	Filtering away non-fungal sequences.
		"
		`filter_taxa_from_otu_table.py -i $otutable_dir/raw_otu_table.biom -o $otutable_dir/raw_otu_table_fungi_only.biom -p k__Fungi` >/dev/null 2>&1 || true
		fi
		if [[ -f $otutable_dir/raw_otu_table_fungi_only.biom ]]; then
		raw_or_taxfiltered_table=$otutable_dir/raw_otu_table_fungi_only.biom
		fi
	fi

## Filter low count samples

	if [[ ! -f $otutable_dir/min100_table.biom ]]; then
	echo "	Filtering away low count samples (<100 reads).
	"
	`filter_samples_from_otu_table.py -i $raw_or_taxfiltered_table -o $otutable_dir/min100_table.biom -n 100`
	fi

## Filter singletons and unshared OTUs from each sample

if [[ ! -f $otutable_dir/n2_table_hdf5.biom ]] && [[ ! -f $otutable_dir/n2_table_CSS.biom ]] && [[ ! -f $otutable_dir/mc2_table_hdf5.biom ]] && [[ ! -f $otutable_dir/mc2_table_CSS.biom ]] && [[ ! -f $otutable_dir/005_table_hdf5.biom ]] && [[ ! -f $otutable_dir/005_table_CSS.biom ]] && [[ ! -f $otutable_dir/03_table_hdf5.biom ]] && [[ ! -f $otutable_dir/03_table_CSS.biom ]]; then

	if [[ ! -f $otutable_dir/n2_table_hdf5.biom ]]; then
	## filter singletons by sample and normalize
	filter_observations_by_sample.py -i $otutable_dir/min100_table.biom -o $otutable_dir/n2_table0.biom -n 1
	filter_otus_from_otu_table.py -i $otutable_dir/n2_table0.biom -o $otutable_dir/n2_table.biom -n 1 -s 2
	biom convert -i $otutable_dir/n2_table.biom -o $otutable_dir/n2_table_hdf5.biom --table-type="OTU table" --to-hdf5
	fi

	if [[ ! -f $otutable_dir/n2_table_CSS.biom ]]; then
	normalize_table.py -i $otutable_dir/n2_table_hdf5.biom -o $otutable_dir/n2_table_CSS.biom -a CSS >/dev/null 2>&1 || true
	fi

	## filter singletons by table and normalize
	if [[ ! -f $otutable_dir/mc2_table_hdf5.biom ]]; then
	filter_otus_from_otu_table.py -i $otutable_dir/min100_table.biom -o $otutable_dir/mc2_table_hdf5.biom -n 2 -s 2
	fi

	if [[ ! -f $otutable_dir/mc2_table_CSS.biom ]]; then
	normalize_table.py -i $otutable_dir/mc2_table_hdf5.biom -o $otutable_dir/mc2_table_CSS.biom -a CSS >/dev/null 2>&1 || true
	fi

	## filter table by 0.005 percent and normalize
	if [[ ! -f $otutable_dir/005_table_hdf5.biom ]]; then
	filter_otus_from_otu_table.py -i $otutable_dir/min100_table.biom -o $otutable_dir/005_table_hdf5.biom --min_count_fraction 0.00005 -s 2
	fi

	if [[ ! -f $otutable_dir/005_table_CSS.biom ]]; then
	normalize_table.py -i $otutable_dir/005_table_hdf5.biom -o $otutable_dir/005_table_CSS.biom -a CSS >/dev/null 2>&1 || true
	fi

	## filter at 0.3% by sample and normalize
	if [[ ! -f $otutable_dir/03_table_hdf5.biom ]]; then
	filter_observations_by_sample.py -i $otutable_dir/min100_table.biom -o $otutable_dir/03_table0.biom -f -n 0.003
	filter_otus_from_otu_table.py -i $otutable_dir/03_table0.biom -o $otutable_dir/03_table.biom -n 1 -s 2
	biom convert -i $otutable_dir/03_table.biom -o $otutable_dir/03_table_hdf5.biom --table-type="OTU table" --to-hdf5
	fi

	if [[ ! -f $otutable_dir/03_table_CSS.biom ]]; then
	normalize_table.py -i $otutable_dir/03_table_hdf5.biom -o $otutable_dir/03_table_CSS.biom -a CSS >/dev/null 2>&1 || true
	fi

	rm $otutable_dir/03_table0.biom >/dev/null 2>&1 || true
	rm $otutable_dir/03_table.biom >/dev/null 2>&1 || true
	rm $otutable_dir/n2_table0.biom >/dev/null 2>&1 || true
	rm $otutable_dir/n2_table.biom >/dev/null 2>&1 || true

## Summarize raw otu tables

	biom-summarize_folder.sh $otutable_dir >/dev/null
	written_seqs=`grep "Total count:" $otutable_dir/n2_table_hdf5.summary | cut -d" " -f3`
	input_seqs=`grep "Total number seqs written" split_libraries/split_library_log.txt | cut -f2`
	echo "	$written_seqs out of $input_seqs input sequences written.
	"

## Print filtered OTU table summary header to screen and log file

	echo "	OTU picking method: $otumethod (d$resolution)
	Tax assignment method: $taxmethod
	Singleton-filtered OTU table summary header:
	"
	head -14 $otutable_dir/n2_table_hdf5.summary | sed 's/^/\t\t/'
	echo "OTU picking method:
Tax assignment method: $taxmethod
Singleton-filtered OTU table summary header:
	" >> $log
	head -14 $otutable_dir/n2_table_hdf5.summary | sed 's/^/\t\t/' >> $log

	else
	echo "	Filtered tables detected.
	"
fi
fi

#####

## UCLUST

if [[ $taxassigner == "uclust" || $taxassigner == "ALL" ]]; then
taxmethod=UCLUST
taxdir=$outdir/$otupickdir/uclust_taxonomy_assignment

	if [[ ! -f $taxdir/merged_rep_set_tax_assignments.txt ]]; then
res24=$(date +%s.%N)
	echo "	Assigning taxonomy.
	Method: $taxmethod on $taxassignment_threads cores.
	"
	echo "Assigning taxonomy ($taxmethod):" >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "
	parallel_assign_taxonomy_uclust.py -i $outdir/$otupickdir/merged_rep_set.fna -o $taxdir -r $refs -t $tax -O $taxassignment_threads
	" >> $log
	`parallel_assign_taxonomy_uclust.py -i $outdir/$otupickdir/merged_rep_set.fna -o $taxdir -r $refs -t $tax -O $taxassignment_threads`
	wait

res25=$(date +%s.%N)
dt=$(echo "$res25 - $res24" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

tax_runtime=`printf "$taxmethod taxonomy assignment runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`	
echo "$tax_runtime

	" >> $log


	else
	echo "	$taxmethod taxonomy assignments detected.
	"
	fi

## Build OTU tables

	if [[ ! -d $otupickdir/OTU_tables_uclust_tax ]]; then
		mkdir -p $otupickdir/OTU_tables_uclust_tax
	fi
	otutable_dir=$otupickdir/OTU_tables_uclust_tax

## Make initial otu table (needs hdf5 conversion)

	if [[ ! -f $otutable_dir/raw_otu_table.biom ]]; then	
	echo "	Building OTU tables with $taxmethod assignments.
	"
	echo "Making initial OTU table:" >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "
	make_otu_table.py -i $outdir/$otupickdir/merged_otu_map.txt -t $taxdir/merged_rep_set_tax_assignments.txt -o $otutable_dir/initial_otu_table.biom
	" >> $log
	`make_otu_table.py -i $outdir/$otupickdir/merged_otu_map.txt -t $taxdir/merged_rep_set_tax_assignments.txt -o $otutable_dir/initial_otu_table.biom`

	fi

## Convert initial table to raw table (hdf5)

	if [[ ! -f $otutable_dir/raw_otu_table.biom ]]; then
	echo "	Making raw hdf5 OTU table.
	"
	echo "Making raw hdf5 OTU table:" >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "
	biom convert -i $otutable_dir/initial_otu_table.biom -o $otutable_dir/raw_otu_table.biom --table-type=\"OTU table\" --to-hdf5
	" >> $log
	`biom convert -i $otutable_dir/initial_otu_table.biom -o $otutable_dir/raw_otu_table.biom --table-type="OTU table" --to-hdf5`
	wait
	rm $otutable_dir/initial_otu_table.biom
	else
	echo "	Raw OTU table detected.
	"
	raw_or_taxfiltered_table=$otutable_dir/raw_otu_table.biom
	fi

## Filter non-target taxa (ITS and 16S mode only)

	if [[ $mode == "16S" ]]; then
		if [[ ! -f $otutable_dir/raw_otu_table_bacteria_only.biom ]]; then
		echo "	Filtering away non-prokaryotic sequences.
		"
		`filter_taxa_from_otu_table.py -i $otutable_dir/raw_otu_table.biom -o $otutable_dir/raw_otu_table_bacteria_only.biom -p k__Bacteria,k__Archaea` >/dev/null 2>&1 || true
		fi
		if [[ -f $otutable_dir/raw_otu_table_bacteria_only.biom ]]; then
		raw_or_taxfiltered_table=$otutable_dir/raw_otu_table_bacteria_only.biom
		fi
	fi

	if [[ $mode == "ITS" ]]; then
		if [[ ! -f $otutable_dir/raw_otu_table_fungi_only.biom ]]; then
		echo "	Filtering away non-fungal sequences.
		"
		`filter_taxa_from_otu_table.py -i $otutable_dir/raw_otu_table.biom -o $otutable_dir/raw_otu_table_fungi_only.biom -p k__Fungi` >/dev/null 2>&1 || true
		fi
		if [[ -f $otutable_dir/raw_otu_table_fungi_only.biom ]]; then
		raw_or_taxfiltered_table=$otutable_dir/raw_otu_table_fungi_only.biom
		fi
	fi

## Filter low count samples

	if [[ ! -f $otutable_dir/min100_table.biom ]]; then
	echo "	Filtering away low count samples (<100 reads).
	"
	`filter_samples_from_otu_table.py -i $raw_or_taxfiltered_table -o $otutable_dir/min100_table.biom -n 100`
	fi

## Filter singletons and unshared OTUs from each sample

if [[ ! -f $otutable_dir/n2_table_hdf5.biom ]] && [[ ! -f $otutable_dir/n2_table_CSS.biom ]] && [[ ! -f $otutable_dir/mc2_table_hdf5.biom ]] && [[ ! -f $otutable_dir/mc2_table_CSS.biom ]] && [[ ! -f $otutable_dir/005_table_hdf5.biom ]] && [[ ! -f $otutable_dir/005_table_CSS.biom ]] && [[ ! -f $otutable_dir/03_table_hdf5.biom ]] && [[ ! -f $otutable_dir/03_table_CSS.biom ]]; then

	if [[ ! -f $otutable_dir/n2_table_hdf5.biom ]]; then
	## filter singletons by sample and normalize
	filter_observations_by_sample.py -i $otutable_dir/min100_table.biom -o $otutable_dir/n2_table0.biom -n 1
	filter_otus_from_otu_table.py -i $otutable_dir/n2_table0.biom -o $otutable_dir/n2_table.biom -n 1 -s 2
	biom convert -i $otutable_dir/n2_table.biom -o $otutable_dir/n2_table_hdf5.biom --table-type="OTU table" --to-hdf5
	fi

	if [[ ! -f $otutable_dir/n2_table_CSS.biom ]]; then
	normalize_table.py -i $otutable_dir/n2_table_hdf5.biom -o $otutable_dir/n2_table_CSS.biom -a CSS >/dev/null 2>&1 || true
	fi

	## filter singletons by table and normalize
	if [[ ! -f $otutable_dir/mc2_table_hdf5.biom ]]; then
	filter_otus_from_otu_table.py -i $otutable_dir/min100_table.biom -o $otutable_dir/mc2_table_hdf5.biom -n 2 -s 2
	fi

	if [[ ! -f $otutable_dir/mc2_table_CSS.biom ]]; then
	normalize_table.py -i $otutable_dir/mc2_table_hdf5.biom -o $otutable_dir/mc2_table_CSS.biom -a CSS >/dev/null 2>&1 || true
	fi

	## filter table by 0.005 percent and normalize
	if [[ ! -f $otutable_dir/005_table_hdf5.biom ]]; then
	filter_otus_from_otu_table.py -i $otutable_dir/min100_table.biom -o $otutable_dir/005_table_hdf5.biom --min_count_fraction 0.00005 -s 2
	fi

	if [[ ! -f $otutable_dir/005_table_CSS.biom ]]; then
	normalize_table.py -i $otutable_dir/005_table_hdf5.biom -o $otutable_dir/005_table_CSS.biom -a CSS >/dev/null 2>&1 || true
	fi

	## filter at 0.3% by sample and normalize
	if [[ ! -f $otutable_dir/03_table_hdf5.biom ]]; then
	filter_observations_by_sample.py -i $otutable_dir/min100_table.biom -o $otutable_dir/03_table0.biom -f -n 0.003
	filter_otus_from_otu_table.py -i $otutable_dir/03_table0.biom -o $otutable_dir/03_table.biom -n 1 -s 2
	biom convert -i $otutable_dir/03_table.biom -o $otutable_dir/03_table_hdf5.biom --table-type="OTU table" --to-hdf5
	fi

	if [[ ! -f $otutable_dir/03_table_CSS.biom ]]; then
	normalize_table.py -i $otutable_dir/03_table_hdf5.biom -o $otutable_dir/03_table_CSS.biom -a CSS >/dev/null 2>&1 || true
	fi

	rm $otutable_dir/03_table0.biom >/dev/null 2>&1 || true
	rm $otutable_dir/03_table.biom >/dev/null 2>&1 || true
	rm $otutable_dir/n2_table0.biom >/dev/null 2>&1 || true
	rm $otutable_dir/n2_table.biom >/dev/null 2>&1 || true

## Summarize raw otu tables

	biom-summarize_folder.sh $otutable_dir >/dev/null
	written_seqs=`grep "Total count:" $otutable_dir/n2_table_hdf5.summary | cut -d" " -f3`
	input_seqs=`grep "Total number seqs written" split_libraries/split_library_log.txt | cut -f2`
	echo "	$written_seqs out of $input_seqs input sequences written.
	"

## Print filtered OTU table summary header to screen and log file

	echo "	OTU picking method: $otumethod (d$resolution)
	Tax assignment method: $taxmethod
	Singleton-filtered OTU table summary header:
	"
	head -14 $otutable_dir/n2_table_hdf5.summary | sed 's/^/\t\t/'
	echo "OTU picking method:
Tax assignment method: $taxmethod
Singleton-filtered OTU table summary header:
	" >> $log
	head -14 $otutable_dir/n2_table_hdf5.summary | sed 's/^/\t\t/' >> $log

	else
	echo "	Filtered tables detected.
	"
fi
fi

#####

done

res26a=$(date +%s.%N)
dt=$(echo "$res26a - $res9a" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

runtime=`printf "Total runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`

echo "	Sequential OTU picking steps completed (Swarm).

	$runtime
"
echo "---

Sequential OTU picking completed (Swarm)." >> $log
date "+%a %b %I:%M %p %Z %Y" >> $log
echo "
$runtime 
" >> $log
fi

##############################
## SWARM OTU Steps END HERE ##
##############################

#####

################################
## BLAST OTU Steps BEGIN HERE ##
################################

## Define otu picking parameters ahead of outdir naming

if [[ $otupicker == "blast" || $otupicker == "ALL" ]]; then
otumethod=BLAST

if [[ $parameter_count == 1 ]]; then
	grep "similarity" $param_file | cut -d " " -f2 > $tempdir/percent_similarities.temp
	else
	echo "0.97" > $tempdir/percent_similarities.temp
fi
	similaritycount=`cat $tempdir/percent_similarities.temp | wc -l`

	echo "	Beginning sequential OTU picking (BLAST) at $similaritycount similarity thresholds.
	"
	echo "Beginning sequential OTU picking (BLAST) at $similaritycount similarity thresholds." >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	res9a=$(date +%s.%N)

## Start sequential OTU picking

for similarity in `cat $tempdir/percent_similarities.temp`; do

otupickdir=blast_otus_$similarity

if [[ ! -f $otupickdir/prefix_rep_set_otus.txt ]]; then
res10=$(date +%s.%N)

numseqs1=`cat $presufdir/prefix_rep_set.fasta | wc -l`
numseqs2=(`expr $numseqs1 / 2`)

	echo "	Picking OTUs against collapsed rep set.
	Input sequences: $numseqs2
	Method: BLAST (closed reference)"
	echo "Picking OTUs against collapsed rep set." >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "Input sequences: $numseqs2" >> $log
	echo "Method: BLAST (closed reference)" >> $log
	echo "Percent similarity: $similarity" >> $log
	echo "	Percent similarity: $similarity
	"
	echo "
	parallel_pick_otus_blast.py -i $presufdir/prefix_rep_set.fasta -o $otupickdir -s $similarity -O $otupicking_threads -r $refs
	" >> $log
	`parallel_pick_otus_blast.py -i $presufdir/prefix_rep_set.fasta -o $otupickdir -s $similarity -O $otupicking_threads -r $refs -e 0.001`

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
	echo "	BLAST OTU picking already completed ($similarity).
	"
fi

if [[ ! -f $otupickdir/merged_otu_map.txt ]]; then
res12=$(date +%s.%N)
	echo "	Merging OTU maps.
	"
	echo "Merging OTU maps:" >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "
	merge_otu_maps.py -i $presufdir/$seqname@_otus.txt,$otupickdir/prefix_rep_set_otus.txt -o $otupickdir/merged_otu_map.txt
	" >> $log
	`merge_otu_maps.py -i $presufdir/$seqname\_otus.txt,$otupickdir/prefix_rep_set_otus.txt -o $otupickdir/merged_otu_map.txt`

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
	echo "	OTU maps already merged.
	"
fi

if [[ ! -f $otupickdir/merged_rep_set.fna ]]; then
res14=$(date +%s.%N)
	echo "	Picking rep set against merged OTU map.
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
	echo "	Merged rep set already completed.
	"
fi

## Assign taxonomy (one or all tax assigners)

## BLAST

if [[ $taxassigner == "blast" || $taxassigner == "ALL" ]]; then
taxmethod=BLAST
taxdir=$outdir/$otupickdir/blast_taxonomy_assignment

	if [[ ! -f $taxdir/merged_rep_set_tax_assignments.txt ]]; then
res24=$(date +%s.%N)
	echo "	Assigning taxonomy.
	Method: $taxmethod on $taxassignment_threads cores.
	"
	echo "Assigning taxonomy ($taxmethod):" >> $log
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

tax_runtime=`printf "$taxmethod taxonomy assignment runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`	
echo "$tax_runtime

	" >> $log
	else
	echo "	$taxmethod taxonomy assignments detected.
	"
	fi

## Build OTU tables

	if [[ ! -d $otupickdir/OTU_tables_blast_tax ]]; then
		mkdir -p $otupickdir/OTU_tables_blast_tax
	fi
	otutable_dir=$otupickdir/OTU_tables_blast_tax

## Make initial otu table (needs hdf5 conversion)

	if [[ ! -f $otutable_dir/raw_otu_table.biom ]]; then	
	echo "	Building OTU tables with $taxmethod assignments.
	"
	echo "Making initial OTU table:" >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "
	make_otu_table.py -i $outdir/$otupickdir/merged_otu_map.txt -t $taxdir/merged_rep_set_tax_assignments.txt -o $otutable_dir/initial_otu_table.biom
	" >> $log
	`make_otu_table.py -i $outdir/$otupickdir/merged_otu_map.txt -t $taxdir/merged_rep_set_tax_assignments.txt -o $otutable_dir/initial_otu_table.biom`

	fi

## Convert initial table to raw table (hdf5)

	if [[ ! -f $otutable_dir/raw_otu_table.biom ]]; then
	echo "	Making raw hdf5 OTU table.
	"
	echo "Making raw hdf5 OTU table:" >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "
	biom convert -i $otutable_dir/initial_otu_table.biom -o $otutable_dir/raw_otu_table.biom --table-type=\"OTU table\" --to-hdf5
	" >> $log
	`biom convert -i $otutable_dir/initial_otu_table.biom -o $otutable_dir/raw_otu_table.biom --table-type="OTU table" --to-hdf5`
	wait
	rm $otutable_dir/initial_otu_table.biom
	else
	echo "	Raw OTU table detected.
	"
	raw_or_taxfiltered_table=$otutable_dir/raw_otu_table.biom
	fi

## Filter non-target taxa (ITS and 16S mode only)

	if [[ $mode == "16S" ]]; then
		if [[ ! -f $otutable_dir/raw_otu_table_bacteria_only.biom ]]; then
		echo "	Filtering away non-prokaryotic sequences.
		"
		`filter_taxa_from_otu_table.py -i $otutable_dir/raw_otu_table.biom -o $otutable_dir/raw_otu_table_bacteria_only.biom -p k__Bacteria,k__Archaea` >/dev/null 2>&1 || true
		fi
		if [[ -f $otutable_dir/raw_otu_table_bacteria_only.biom ]]; then
		raw_or_taxfiltered_table=$otutable_dir/raw_otu_table_bacteria_only.biom
		fi
	fi

	if [[ $mode == "ITS" ]]; then
		if [[ ! -f $otutable_dir/raw_otu_table_fungi_only.biom ]]; then
		echo "	Filtering away non-fungal sequences.
		"
		`filter_taxa_from_otu_table.py -i $otutable_dir/raw_otu_table.biom -o $otutable_dir/raw_otu_table_fungi_only.biom -p k__Fungi` >/dev/null 2>&1 || true
		fi
		if [[ -f $otutable_dir/raw_otu_table_fungi_only.biom ]]; then
		raw_or_taxfiltered_table=$otutable_dir/raw_otu_table_fungi_only.biom
		fi
	fi

## Filter low count samples

	if [[ ! -f $otutable_dir/min100_table.biom ]]; then
	echo "	Filtering away low count samples (<100 reads).
	"
	`filter_samples_from_otu_table.py -i $raw_or_taxfiltered_table -o $otutable_dir/min100_table.biom -n 100`
	fi

## Filter singletons and unshared OTUs from each sample

if [[ ! -f $otutable_dir/n2_table_hdf5.biom ]] && [[ ! -f $otutable_dir/n2_table_CSS.biom ]] && [[ ! -f $otutable_dir/mc2_table_hdf5.biom ]] && [[ ! -f $otutable_dir/mc2_table_CSS.biom ]] && [[ ! -f $otutable_dir/005_table_hdf5.biom ]] && [[ ! -f $otutable_dir/005_table_CSS.biom ]] && [[ ! -f $otutable_dir/03_table_hdf5.biom ]] && [[ ! -f $otutable_dir/03_table_CSS.biom ]]; then

	if [[ ! -f $otutable_dir/n2_table_hdf5.biom ]]; then
	## filter singletons by sample and normalize
	filter_observations_by_sample.py -i $otutable_dir/min100_table.biom -o $otutable_dir/n2_table0.biom -n 1
	filter_otus_from_otu_table.py -i $otutable_dir/n2_table0.biom -o $otutable_dir/n2_table.biom -n 1 -s 2
	biom convert -i $otutable_dir/n2_table.biom -o $otutable_dir/n2_table_hdf5.biom --table-type="OTU table" --to-hdf5
	fi

	if [[ ! -f $otutable_dir/n2_table_CSS.biom ]]; then
	normalize_table.py -i $otutable_dir/n2_table_hdf5.biom -o $otutable_dir/n2_table_CSS.biom -a CSS >/dev/null 2>&1 || true
	fi

	## filter singletons by table and normalize
	if [[ ! -f $otutable_dir/mc2_table_hdf5.biom ]]; then
	filter_otus_from_otu_table.py -i $otutable_dir/min100_table.biom -o $otutable_dir/mc2_table_hdf5.biom -n 2 -s 2
	fi

	if [[ ! -f $otutable_dir/mc2_table_CSS.biom ]]; then
	normalize_table.py -i $otutable_dir/mc2_table_hdf5.biom -o $otutable_dir/mc2_table_CSS.biom -a CSS >/dev/null 2>&1 || true
	fi

	## filter table by 0.005 percent and normalize
	if [[ ! -f $otutable_dir/005_table_hdf5.biom ]]; then
	filter_otus_from_otu_table.py -i $otutable_dir/min100_table.biom -o $otutable_dir/005_table_hdf5.biom --min_count_fraction 0.00005 -s 2
	fi

	if [[ ! -f $otutable_dir/005_table_CSS.biom ]]; then
	normalize_table.py -i $otutable_dir/005_table_hdf5.biom -o $otutable_dir/005_table_CSS.biom -a CSS >/dev/null 2>&1 || true
	fi

	## filter at 0.3% by sample and normalize
	if [[ ! -f $otutable_dir/03_table_hdf5.biom ]]; then
	filter_observations_by_sample.py -i $otutable_dir/min100_table.biom -o $otutable_dir/03_table0.biom -f -n 0.003
	filter_otus_from_otu_table.py -i $otutable_dir/03_table0.biom -o $otutable_dir/03_table.biom -n 1 -s 2
	biom convert -i $otutable_dir/03_table.biom -o $otutable_dir/03_table_hdf5.biom --table-type="OTU table" --to-hdf5
	fi

	if [[ ! -f $otutable_dir/03_table_CSS.biom ]]; then
	normalize_table.py -i $otutable_dir/03_table_hdf5.biom -o $otutable_dir/03_table_CSS.biom -a CSS >/dev/null 2>&1 || true
	fi

	rm $otutable_dir/03_table0.biom >/dev/null 2>&1 || true
	rm $otutable_dir/03_table.biom >/dev/null 2>&1 || true
	rm $otutable_dir/n2_table0.biom >/dev/null 2>&1 || true
	rm $otutable_dir/n2_table.biom >/dev/null 2>&1 || true

## Summarize raw otu tables

	biom-summarize_folder.sh $otutable_dir >/dev/null
	written_seqs=`grep "Total count:" $otutable_dir/n2_table_hdf5.summary | cut -d" " -f3`
	input_seqs=`grep "Total number seqs written" split_libraries/split_library_log.txt | cut -f2`
	echo "	$written_seqs out of $input_seqs input sequences written.
	"

## Print filtered OTU table summary header to screen and log file

	echo "	OTU picking method: $otumethod ($similarity)
	Tax assignment method: $taxmethod
	Singleton-filtered OTU table summary header:
	"
	head -14 $otutable_dir/n2_table_hdf5.summary | sed 's/^/\t\t/'
	echo "OTU picking method:
Tax assignment method: $taxmethod
Singleton-filtered OTU table summary header:
	" >> $log
	head -14 $otutable_dir/n2_table_hdf5.summary | sed 's/^/\t\t/' >> $log

	else
	echo "	Filtered tables detected.
	"
fi
fi

#####

## RDP

if [[ $taxassigner == "rdp" || $taxassigner == "ALL" ]]; then
taxmethod=RDP
taxdir=$outdir/$otupickdir/rdp_taxonomy_assignment

	## Adjust threads since RDP seems to choke with too many threads (> 12)
	if [[ $taxassignment_threads -gt 12 ]]; then
		rdptaxassignment_threads=12
	else
		rdptaxassignment_threads=$taxassignment_threads
	fi

	if [[ ! -f $taxdir/merged_rep_set_tax_assignments.txt ]]; then
res24=$(date +%s.%N)
	echo "	Assigning taxonomy.
	Method: $taxmethod on $rdptaxassignment_threads cores.
	"
	echo "Assigning taxonomy ($taxmethod):" >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "
	parallel_assign_taxonomy_rdp.py -i $outdir/$otupickdir/merged_rep_set.fna -o $taxdir -r $refs -t $tax -O $rdptaxassignment_threads -c 0.5 --rdp_max_memory 6000
	" >> $log
	`parallel_assign_taxonomy_rdp.py -i $outdir/$otupickdir/merged_rep_set.fna -o $taxdir -r $refs -t $tax -O $rdptaxassignment_threads -c 0.5 --rdp_max_memory 6000`
	wait

res25=$(date +%s.%N)
dt=$(echo "$res25 - $res24" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

tax_runtime=`printf "$taxmethod taxonomy assignment runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`	
echo "$tax_runtime

	" >> $log


	else
	echo "	$taxmethod taxonomy assignments detected.
	"
	fi

## Build OTU tables

	if [[ ! -d $otupickdir/OTU_tables_rdp_tax ]]; then
		mkdir -p $otupickdir/OTU_tables_rdp_tax
	fi
	otutable_dir=$otupickdir/OTU_tables_rdp_tax

## Make initial otu table (needs hdf5 conversion)

	if [[ ! -f $otutable_dir/raw_otu_table.biom ]]; then	
	echo "	Building OTU tables with $taxmethod assignments.
	"
	echo "Making initial OTU table:" >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "
	make_otu_table.py -i $outdir/$otupickdir/merged_otu_map.txt -t $taxdir/merged_rep_set_tax_assignments.txt -o $otutable_dir/initial_otu_table.biom
	" >> $log
	`make_otu_table.py -i $outdir/$otupickdir/merged_otu_map.txt -t $taxdir/merged_rep_set_tax_assignments.txt -o $otutable_dir/initial_otu_table.biom`

	fi

## Convert initial table to raw table (hdf5)

	if [[ ! -f $otutable_dir/raw_otu_table.biom ]]; then
	echo "	Making raw hdf5 OTU table.
	"
	echo "Making raw hdf5 OTU table:" >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "
	biom convert -i $otutable_dir/initial_otu_table.biom -o $otutable_dir/raw_otu_table.biom --table-type=\"OTU table\" --to-hdf5
	" >> $log
	`biom convert -i $otutable_dir/initial_otu_table.biom -o $otutable_dir/raw_otu_table.biom --table-type="OTU table" --to-hdf5`
	wait
	rm $otutable_dir/initial_otu_table.biom
	else
	echo "	Raw OTU table detected.
	"
	raw_or_taxfiltered_table=$otutable_dir/raw_otu_table.biom
	fi

## Filter non-target taxa (ITS and 16S mode only)

	if [[ $mode == "16S" ]]; then
		if [[ ! -f $otutable_dir/raw_otu_table_bacteria_only.biom ]]; then
		echo "	Filtering away non-prokaryotic sequences.
		"
		`filter_taxa_from_otu_table.py -i $otutable_dir/raw_otu_table.biom -o $otutable_dir/raw_otu_table_bacteria_only.biom -p k__Bacteria,k__Archaea` >/dev/null 2>&1 || true
		fi
		if [[ -f $otutable_dir/raw_otu_table_bacteria_only.biom ]]; then
		raw_or_taxfiltered_table=$otutable_dir/raw_otu_table_bacteria_only.biom
		fi
	fi

	if [[ $mode == "ITS" ]]; then
		if [[ ! -f $otutable_dir/raw_otu_table_fungi_only.biom ]]; then
		echo "	Filtering away non-fungal sequences.
		"
		`filter_taxa_from_otu_table.py -i $otutable_dir/raw_otu_table.biom -o $otutable_dir/raw_otu_table_fungi_only.biom -p k__Fungi` >/dev/null 2>&1 || true
		fi
		if [[ -f $otutable_dir/raw_otu_table_fungi_only.biom ]]; then
		raw_or_taxfiltered_table=$otutable_dir/raw_otu_table_fungi_only.biom
		fi
	fi

## Filter low count samples

	if [[ ! -f $otutable_dir/min100_table.biom ]]; then
	echo "	Filtering away low count samples (<100 reads).
	"
	`filter_samples_from_otu_table.py -i $raw_or_taxfiltered_table -o $otutable_dir/min100_table.biom -n 100`
	fi

## Filter singletons and unshared OTUs from each sample

if [[ ! -f $otutable_dir/n2_table_hdf5.biom ]] && [[ ! -f $otutable_dir/n2_table_CSS.biom ]] && [[ ! -f $otutable_dir/mc2_table_hdf5.biom ]] && [[ ! -f $otutable_dir/mc2_table_CSS.biom ]] && [[ ! -f $otutable_dir/005_table_hdf5.biom ]] && [[ ! -f $otutable_dir/005_table_CSS.biom ]] && [[ ! -f $otutable_dir/03_table_hdf5.biom ]] && [[ ! -f $otutable_dir/03_table_CSS.biom ]]; then

	if [[ ! -f $otutable_dir/n2_table_hdf5.biom ]]; then
	## filter singletons by sample and normalize
	filter_observations_by_sample.py -i $otutable_dir/min100_table.biom -o $otutable_dir/n2_table0.biom -n 1
	filter_otus_from_otu_table.py -i $otutable_dir/n2_table0.biom -o $otutable_dir/n2_table.biom -n 1 -s 2
	biom convert -i $otutable_dir/n2_table.biom -o $otutable_dir/n2_table_hdf5.biom --table-type="OTU table" --to-hdf5
	fi

	if [[ ! -f $otutable_dir/n2_table_CSS.biom ]]; then
	normalize_table.py -i $otutable_dir/n2_table_hdf5.biom -o $otutable_dir/n2_table_CSS.biom -a CSS >/dev/null 2>&1 || true
	fi

	## filter singletons by table and normalize
	if [[ ! -f $otutable_dir/mc2_table_hdf5.biom ]]; then
	filter_otus_from_otu_table.py -i $otutable_dir/min100_table.biom -o $otutable_dir/mc2_table_hdf5.biom -n 2 -s 2
	fi

	if [[ ! -f $otutable_dir/mc2_table_CSS.biom ]]; then
	normalize_table.py -i $otutable_dir/mc2_table_hdf5.biom -o $otutable_dir/mc2_table_CSS.biom -a CSS >/dev/null 2>&1 || true
	fi

	## filter table by 0.005 percent and normalize
	if [[ ! -f $otutable_dir/005_table_hdf5.biom ]]; then
	filter_otus_from_otu_table.py -i $otutable_dir/min100_table.biom -o $otutable_dir/005_table_hdf5.biom --min_count_fraction 0.00005 -s 2
	fi

	if [[ ! -f $otutable_dir/005_table_CSS.biom ]]; then
	normalize_table.py -i $otutable_dir/005_table_hdf5.biom -o $otutable_dir/005_table_CSS.biom -a CSS >/dev/null 2>&1 || true
	fi

	## filter at 0.3% by sample and normalize
	if [[ ! -f $otutable_dir/03_table_hdf5.biom ]]; then
	filter_observations_by_sample.py -i $otutable_dir/min100_table.biom -o $otutable_dir/03_table0.biom -f -n 0.003
	filter_otus_from_otu_table.py -i $otutable_dir/03_table0.biom -o $otutable_dir/03_table.biom -n 1 -s 2
	biom convert -i $otutable_dir/03_table.biom -o $otutable_dir/03_table_hdf5.biom --table-type="OTU table" --to-hdf5
	fi

	if [[ ! -f $otutable_dir/03_table_CSS.biom ]]; then
	normalize_table.py -i $otutable_dir/03_table_hdf5.biom -o $otutable_dir/03_table_CSS.biom -a CSS >/dev/null 2>&1 || true
	fi

	rm $otutable_dir/03_table0.biom >/dev/null 2>&1 || true
	rm $otutable_dir/03_table.biom >/dev/null 2>&1 || true
	rm $otutable_dir/n2_table0.biom >/dev/null 2>&1 || true
	rm $otutable_dir/n2_table.biom >/dev/null 2>&1 || true

## Summarize raw otu tables

	biom-summarize_folder.sh $otutable_dir >/dev/null
	written_seqs=`grep "Total count:" $otutable_dir/n2_table_hdf5.summary | cut -d" " -f3`
	input_seqs=`grep "Total number seqs written" split_libraries/split_library_log.txt | cut -f2`
	echo "	$written_seqs out of $input_seqs input sequences written.
	"

## Print filtered OTU table summary header to screen and log file

	echo "	OTU picking method: $otumethod ($similarity)
	Tax assignment method: $taxmethod
	Singleton-filtered OTU table summary header:
	"
	head -14 $otutable_dir/n2_table_hdf5.summary | sed 's/^/\t\t/'
	echo "OTU picking method:
Tax assignment method: $taxmethod
Singleton-filtered OTU table summary header:
	" >> $log
	head -14 $otutable_dir/n2_table_hdf5.summary | sed 's/^/\t\t/' >> $log

	else
	echo "	Filtered tables detected.
	"
fi
fi

#####

## UCLUST

if [[ $taxassigner == "uclust" || $taxassigner == "ALL" ]]; then
taxmethod=UCLUST
taxdir=$outdir/$otupickdir/uclust_taxonomy_assignment

	if [[ ! -f $taxdir/merged_rep_set_tax_assignments.txt ]]; then
res24=$(date +%s.%N)
	echo "	Assigning taxonomy.
	Method: $taxmethod on $taxassignment_threads cores.
	"
	echo "Assigning taxonomy ($taxmethod):" >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "
	parallel_assign_taxonomy_uclust.py -i $outdir/$otupickdir/merged_rep_set.fna -o $taxdir -r $refs -t $tax -O $taxassignment_threads
	" >> $log
	`parallel_assign_taxonomy_uclust.py -i $outdir/$otupickdir/merged_rep_set.fna -o $taxdir -r $refs -t $tax -O $taxassignment_threads`
	wait

res25=$(date +%s.%N)
dt=$(echo "$res25 - $res24" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

tax_runtime=`printf "$taxmethod taxonomy assignment runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`	
echo "$tax_runtime

	" >> $log


	else
	echo "	$taxmethod taxonomy assignments detected.
	"
	fi

## Build OTU tables

	if [[ ! -d $otupickdir/OTU_tables_uclust_tax ]]; then
		mkdir -p $otupickdir/OTU_tables_uclust_tax
	fi
	otutable_dir=$otupickdir/OTU_tables_uclust_tax

## Make initial otu table (needs hdf5 conversion)

	if [[ ! -f $otutable_dir/raw_otu_table.biom ]]; then	
	echo "	Building OTU tables with $taxmethod assignments.
	"
	echo "Making initial OTU table:" >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "
	make_otu_table.py -i $outdir/$otupickdir/merged_otu_map.txt -t $taxdir/merged_rep_set_tax_assignments.txt -o $otutable_dir/initial_otu_table.biom
	" >> $log
	`make_otu_table.py -i $outdir/$otupickdir/merged_otu_map.txt -t $taxdir/merged_rep_set_tax_assignments.txt -o $otutable_dir/initial_otu_table.biom`

	fi

## Convert initial table to raw table (hdf5)

	if [[ ! -f $otutable_dir/raw_otu_table.biom ]]; then
	echo "	Making raw hdf5 OTU table.
	"
	echo "Making raw hdf5 OTU table:" >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "
	biom convert -i $otutable_dir/initial_otu_table.biom -o $otutable_dir/raw_otu_table.biom --table-type=\"OTU table\" --to-hdf5
	" >> $log
	`biom convert -i $otutable_dir/initial_otu_table.biom -o $otutable_dir/raw_otu_table.biom --table-type="OTU table" --to-hdf5`
	wait
	rm $otutable_dir/initial_otu_table.biom
	else
	echo "	Raw OTU table detected.
	"
	raw_or_taxfiltered_table=$otutable_dir/raw_otu_table.biom
	fi

## Filter non-target taxa (ITS and 16S mode only)

	if [[ $mode == "16S" ]]; then
		if [[ ! -f $otutable_dir/raw_otu_table_bacteria_only.biom ]]; then
		echo "	Filtering away non-prokaryotic sequences.
		"
		`filter_taxa_from_otu_table.py -i $otutable_dir/raw_otu_table.biom -o $otutable_dir/raw_otu_table_bacteria_only.biom -p k__Bacteria,k__Archaea` >/dev/null 2>&1 || true
		fi
		if [[ -f $otutable_dir/raw_otu_table_bacteria_only.biom ]]; then
		raw_or_taxfiltered_table=$otutable_dir/raw_otu_table_bacteria_only.biom
		fi
	fi

	if [[ $mode == "ITS" ]]; then
		if [[ ! -f $otutable_dir/raw_otu_table_fungi_only.biom ]]; then
		echo "	Filtering away non-fungal sequences.
		"
		`filter_taxa_from_otu_table.py -i $otutable_dir/raw_otu_table.biom -o $otutable_dir/raw_otu_table_fungi_only.biom -p k__Fungi` >/dev/null 2>&1 || true
		fi
		if [[ -f $otutable_dir/raw_otu_table_fungi_only.biom ]]; then
		raw_or_taxfiltered_table=$otutable_dir/raw_otu_table_fungi_only.biom
		fi
	fi

## Filter low count samples

	if [[ ! -f $otutable_dir/min100_table.biom ]]; then
	echo "	Filtering away low count samples (<100 reads).
	"
	`filter_samples_from_otu_table.py -i $raw_or_taxfiltered_table -o $otutable_dir/min100_table.biom -n 100`
	fi

## Filter singletons and unshared OTUs from each sample

if [[ ! -f $otutable_dir/n2_table_hdf5.biom ]] && [[ ! -f $otutable_dir/n2_table_CSS.biom ]] && [[ ! -f $otutable_dir/mc2_table_hdf5.biom ]] && [[ ! -f $otutable_dir/mc2_table_CSS.biom ]] && [[ ! -f $otutable_dir/005_table_hdf5.biom ]] && [[ ! -f $otutable_dir/005_table_CSS.biom ]] && [[ ! -f $otutable_dir/03_table_hdf5.biom ]] && [[ ! -f $otutable_dir/03_table_CSS.biom ]]; then

	if [[ ! -f $otutable_dir/n2_table_hdf5.biom ]]; then
	## filter singletons by sample and normalize
	filter_observations_by_sample.py -i $otutable_dir/min100_table.biom -o $otutable_dir/n2_table0.biom -n 1
	filter_otus_from_otu_table.py -i $otutable_dir/n2_table0.biom -o $otutable_dir/n2_table.biom -n 1 -s 2
	biom convert -i $otutable_dir/n2_table.biom -o $otutable_dir/n2_table_hdf5.biom --table-type="OTU table" --to-hdf5
	fi

	if [[ ! -f $otutable_dir/n2_table_CSS.biom ]]; then
	normalize_table.py -i $otutable_dir/n2_table_hdf5.biom -o $otutable_dir/n2_table_CSS.biom -a CSS >/dev/null 2>&1 || true
	fi

	## filter singletons by table and normalize
	if [[ ! -f $otutable_dir/mc2_table_hdf5.biom ]]; then
	filter_otus_from_otu_table.py -i $otutable_dir/min100_table.biom -o $otutable_dir/mc2_table_hdf5.biom -n 2 -s 2
	fi

	if [[ ! -f $otutable_dir/mc2_table_CSS.biom ]]; then
	normalize_table.py -i $otutable_dir/mc2_table_hdf5.biom -o $otutable_dir/mc2_table_CSS.biom -a CSS >/dev/null 2>&1 || true
	fi

	## filter table by 0.005 percent and normalize
	if [[ ! -f $otutable_dir/005_table_hdf5.biom ]]; then
	filter_otus_from_otu_table.py -i $otutable_dir/min100_table.biom -o $otutable_dir/005_table_hdf5.biom --min_count_fraction 0.00005 -s 2
	fi

	if [[ ! -f $otutable_dir/005_table_CSS.biom ]]; then
	normalize_table.py -i $otutable_dir/005_table_hdf5.biom -o $otutable_dir/005_table_CSS.biom -a CSS >/dev/null 2>&1 || true
	fi

	## filter at 0.3% by sample and normalize
	if [[ ! -f $otutable_dir/03_table_hdf5.biom ]]; then
	filter_observations_by_sample.py -i $otutable_dir/min100_table.biom -o $otutable_dir/03_table0.biom -f -n 0.003
	filter_otus_from_otu_table.py -i $otutable_dir/03_table0.biom -o $otutable_dir/03_table.biom -n 1 -s 2
	biom convert -i $otutable_dir/03_table.biom -o $otutable_dir/03_table_hdf5.biom --table-type="OTU table" --to-hdf5
	fi

	if [[ ! -f $otutable_dir/03_table_CSS.biom ]]; then
	normalize_table.py -i $otutable_dir/03_table_hdf5.biom -o $otutable_dir/03_table_CSS.biom -a CSS >/dev/null 2>&1 || true
	fi

	rm $otutable_dir/03_table0.biom >/dev/null 2>&1 || true
	rm $otutable_dir/03_table.biom >/dev/null 2>&1 || true
	rm $otutable_dir/n2_table0.biom >/dev/null 2>&1 || true
	rm $otutable_dir/n2_table.biom >/dev/null 2>&1 || true

## Summarize raw otu tables

	biom-summarize_folder.sh $otutable_dir >/dev/null
	written_seqs=`grep "Total count:" $otutable_dir/n2_table_hdf5.summary | cut -d" " -f3`
	input_seqs=`grep "Total number seqs written" split_libraries/split_library_log.txt | cut -f2`
	echo "	$written_seqs out of $input_seqs input sequences written.
	"

## Print filtered OTU table summary header to screen and log file

	echo "	OTU picking method: $otumethod ($similarity)
	Tax assignment method: $taxmethod
	Singleton-filtered OTU table summary header:
	"
	head -14 $otutable_dir/n2_table_hdf5.summary | sed 's/^/\t\t/'
	echo "OTU picking method:
Tax assignment method: $taxmethod
Singleton-filtered OTU table summary header:
	" >> $log
	head -14 $otutable_dir/n2_table_hdf5.summary | sed 's/^/\t\t/' >> $log

	else
	echo "	Filtered tables detected.
	"
fi
fi

#####

done


res26a=$(date +%s.%N)
dt=$(echo "$res26a - $res9a" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

runtime=`printf "Total runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`

echo "	Sequential OTU picking steps completed (BLAST).

	$runtime
"
echo "---

Sequential OTU picking completed (BLAST)." >> $log
date "+%a %b %I:%M %p %Z %Y" >> $log
echo "
$runtime 
" >> $log
fi


##############################
## BLAST OTU Steps END HERE ##
##############################

#####

################################
## CDHIT OTU Steps BEGIN HERE ##
################################

## Define otu picking parameters ahead of outdir naming

if [[ $otupicker == "cdhit" || $otupicker == "ALL" ]]; then
otumethod=CDHIT

if [[ $parameter_count == 1 ]]; then
	grep "similarity" $param_file | cut -d " " -f2 > $tempdir/percent_similarities.temp
	else
	echo "0.97" > $tempdir/percent_similarities.temp
fi
	similaritycount=`cat $tempdir/percent_similarities.temp | wc -l`

	echo "	Beginning sequential OTU picking (CDHIT) at $similaritycount similarity thresholds.
	"
	echo "Beginning sequential OTU picking (CDHIT) at $similaritycount similarity thresholds." >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	res9a=$(date +%s.%N)

## Start sequential OTU picking

for similarity in `cat $tempdir/percent_similarities.temp`; do

otupickdir=cdhit_otus_$similarity

if [[ ! -f $otupickdir/prefix_rep_set_otus.txt ]]; then
res10=$(date +%s.%N)

numseqs1=`cat $presufdir/prefix_rep_set.fasta | wc -l`
numseqs2=(`expr $numseqs1 / 2`)

	echo "	Picking OTUs against collapsed rep set.
	Input sequences: $numseqs2
	Method: CD-HIT (de novo)"
	echo "Picking OTUs against collapsed rep set." >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "Input sequences: $numseqs2" >> $log
	echo "Method: CD-HIT (de novo)" >> $log
	echo "Percent similarity: $similarity" >> $log
	echo "	Percent similarity: $similarity
	"
	echo "
	pick_otus.py -m cdhit -M 6000 -i $presufdir/prefix_rep_set.fasta -o $otupickdir -s $similarity -r $refs
	" >> $log
	`pick_otus.py -m cdhit -M 6000 -i $presufdir/prefix_rep_set.fasta -o $otupickdir -s $similarity -r $refs`

res11=$(date +%s.%N)
dt=$(echo "$res11 - $res10" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

otu_runtime=`printf "CD-HIT OTU picking runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`	
echo "$otu_runtime

	" >> $log

	else
	echo "	CD-HIT OTU picking already completed ($similarity).
	"
fi

if [[ ! -f $otupickdir/merged_otu_map.txt ]]; then
res12=$(date +%s.%N)
	echo "	Merging OTU maps.
	"
	echo "Merging OTU maps:" >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "
	merge_otu_maps.py -i $presufdir/$seqname@_otus.txt,$otupickdir/prefix_rep_set_otus.txt -o $otupickdir/merged_otu_map.txt
	" >> $log
	`merge_otu_maps.py -i $presufdir/$seqname\_otus.txt,$otupickdir/prefix_rep_set_otus.txt -o $otupickdir/merged_otu_map.txt`

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
	echo "	OTU maps already merged.
	"
fi

if [[ ! -f $otupickdir/merged_rep_set.fna ]]; then
res14=$(date +%s.%N)
	echo "	Picking rep set against merged OTU map.
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
	echo "	Merged rep set already completed.
	"
fi

## Assign taxonomy (one or all tax assigners)

## BLAST

if [[ $taxassigner == "blast" || $taxassigner == "ALL" ]]; then
taxmethod=BLAST
taxdir=$outdir/$otupickdir/blast_taxonomy_assignment

	if [[ ! -f $taxdir/merged_rep_set_tax_assignments.txt ]]; then
res24=$(date +%s.%N)
	echo "	Assigning taxonomy.
	Method: $taxmethod on $taxassignment_threads cores.
	"
	echo "Assigning taxonomy ($taxmethod):" >> $log
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

tax_runtime=`printf "$taxmethod taxonomy assignment runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`	
echo "$tax_runtime

	" >> $log
	else
	echo "	$taxmethod taxonomy assignments detected.
	"
	fi

## Build OTU tables

	if [[ ! -d $otupickdir/OTU_tables_blast_tax ]]; then
		mkdir -p $otupickdir/OTU_tables_blast_tax
	fi
	otutable_dir=$otupickdir/OTU_tables_blast_tax

## Make initial otu table (needs hdf5 conversion)

	if [[ ! -f $otutable_dir/raw_otu_table.biom ]]; then	
	echo "	Building OTU tables with $taxmethod assignments.
	"
	echo "Making initial OTU table:" >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "
	make_otu_table.py -i $outdir/$otupickdir/merged_otu_map.txt -t $taxdir/merged_rep_set_tax_assignments.txt -o $otutable_dir/initial_otu_table.biom
	" >> $log
	`make_otu_table.py -i $outdir/$otupickdir/merged_otu_map.txt -t $taxdir/merged_rep_set_tax_assignments.txt -o $otutable_dir/initial_otu_table.biom`

	fi

## Convert initial table to raw table (hdf5)

	if [[ ! -f $otutable_dir/raw_otu_table.biom ]]; then
	echo "	Making raw hdf5 OTU table.
	"
	echo "Making raw hdf5 OTU table:" >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "
	biom convert -i $otutable_dir/initial_otu_table.biom -o $otutable_dir/raw_otu_table.biom --table-type=\"OTU table\" --to-hdf5
	" >> $log
	`biom convert -i $otutable_dir/initial_otu_table.biom -o $otutable_dir/raw_otu_table.biom --table-type="OTU table" --to-hdf5`
	wait
	rm $otutable_dir/initial_otu_table.biom
	else
	echo "	Raw OTU table detected.
	"
	raw_or_taxfiltered_table=$otutable_dir/raw_otu_table.biom
	fi

## Filter non-target taxa (ITS and 16S mode only)

	if [[ $mode == "16S" ]]; then
		if [[ ! -f $otutable_dir/raw_otu_table_bacteria_only.biom ]]; then
		echo "	Filtering away non-prokaryotic sequences.
		"
		`filter_taxa_from_otu_table.py -i $otutable_dir/raw_otu_table.biom -o $otutable_dir/raw_otu_table_bacteria_only.biom -p k__Bacteria,k__Archaea` >/dev/null 2>&1 || true
		fi
		if [[ -f $otutable_dir/raw_otu_table_bacteria_only.biom ]]; then
		raw_or_taxfiltered_table=$otutable_dir/raw_otu_table_bacteria_only.biom
		fi
	fi

	if [[ $mode == "ITS" ]]; then
		if [[ ! -f $otutable_dir/raw_otu_table_fungi_only.biom ]]; then
		echo "	Filtering away non-fungal sequences.
		"
		`filter_taxa_from_otu_table.py -i $otutable_dir/raw_otu_table.biom -o $otutable_dir/raw_otu_table_fungi_only.biom -p k__Fungi` >/dev/null 2>&1 || true
		fi
		if [[ -f $otutable_dir/raw_otu_table_fungi_only.biom ]]; then
		raw_or_taxfiltered_table=$otutable_dir/raw_otu_table_fungi_only.biom
		fi
	fi

## Filter low count samples

	if [[ ! -f $otutable_dir/min100_table.biom ]]; then
	echo "	Filtering away low count samples (<100 reads).
	"
	`filter_samples_from_otu_table.py -i $raw_or_taxfiltered_table -o $otutable_dir/min100_table.biom -n 100`
	fi

## Filter singletons and unshared OTUs from each sample

if [[ ! -f $otutable_dir/n2_table_hdf5.biom ]] && [[ ! -f $otutable_dir/n2_table_CSS.biom ]] && [[ ! -f $otutable_dir/mc2_table_hdf5.biom ]] && [[ ! -f $otutable_dir/mc2_table_CSS.biom ]] && [[ ! -f $otutable_dir/005_table_hdf5.biom ]] && [[ ! -f $otutable_dir/005_table_CSS.biom ]] && [[ ! -f $otutable_dir/03_table_hdf5.biom ]] && [[ ! -f $otutable_dir/03_table_CSS.biom ]]; then

	if [[ ! -f $otutable_dir/n2_table_hdf5.biom ]]; then
	## filter singletons by sample and normalize
	filter_observations_by_sample.py -i $otutable_dir/min100_table.biom -o $otutable_dir/n2_table0.biom -n 1
	filter_otus_from_otu_table.py -i $otutable_dir/n2_table0.biom -o $otutable_dir/n2_table.biom -n 1 -s 2
	biom convert -i $otutable_dir/n2_table.biom -o $otutable_dir/n2_table_hdf5.biom --table-type="OTU table" --to-hdf5
	fi

	if [[ ! -f $otutable_dir/n2_table_CSS.biom ]]; then
	normalize_table.py -i $otutable_dir/n2_table_hdf5.biom -o $otutable_dir/n2_table_CSS.biom -a CSS >/dev/null 2>&1 || true
	fi

	## filter singletons by table and normalize
	if [[ ! -f $otutable_dir/mc2_table_hdf5.biom ]]; then
	filter_otus_from_otu_table.py -i $otutable_dir/min100_table.biom -o $otutable_dir/mc2_table_hdf5.biom -n 2 -s 2
	fi

	if [[ ! -f $otutable_dir/mc2_table_CSS.biom ]]; then
	normalize_table.py -i $otutable_dir/mc2_table_hdf5.biom -o $otutable_dir/mc2_table_CSS.biom -a CSS >/dev/null 2>&1 || true
	fi

	## filter table by 0.005 percent and normalize
	if [[ ! -f $otutable_dir/005_table_hdf5.biom ]]; then
	filter_otus_from_otu_table.py -i $otutable_dir/min100_table.biom -o $otutable_dir/005_table_hdf5.biom --min_count_fraction 0.00005 -s 2
	fi

	if [[ ! -f $otutable_dir/005_table_CSS.biom ]]; then
	normalize_table.py -i $otutable_dir/005_table_hdf5.biom -o $otutable_dir/005_table_CSS.biom -a CSS >/dev/null 2>&1 || true
	fi

	## filter at 0.3% by sample and normalize
	if [[ ! -f $otutable_dir/03_table_hdf5.biom ]]; then
	filter_observations_by_sample.py -i $otutable_dir/min100_table.biom -o $otutable_dir/03_table0.biom -f -n 0.003
	filter_otus_from_otu_table.py -i $otutable_dir/03_table0.biom -o $otutable_dir/03_table.biom -n 1 -s 2
	biom convert -i $otutable_dir/03_table.biom -o $otutable_dir/03_table_hdf5.biom --table-type="OTU table" --to-hdf5
	fi

	if [[ ! -f $otutable_dir/03_table_CSS.biom ]]; then
	normalize_table.py -i $otutable_dir/03_table_hdf5.biom -o $otutable_dir/03_table_CSS.biom -a CSS >/dev/null 2>&1 || true
	fi

	rm $otutable_dir/03_table0.biom >/dev/null 2>&1 || true
	rm $otutable_dir/03_table.biom >/dev/null 2>&1 || true
	rm $otutable_dir/n2_table0.biom >/dev/null 2>&1 || true
	rm $otutable_dir/n2_table.biom >/dev/null 2>&1 || true

## Summarize raw otu tables

	biom-summarize_folder.sh $otutable_dir >/dev/null
	written_seqs=`grep "Total count:" $otutable_dir/n2_table_hdf5.summary | cut -d" " -f3`
	input_seqs=`grep "Total number seqs written" split_libraries/split_library_log.txt | cut -f2`
	echo "	$written_seqs out of $input_seqs input sequences written.
	"

## Print filtered OTU table summary header to screen and log file

	echo "	OTU picking method: $otumethod ($similarity)
	Tax assignment method: $taxmethod
	Singleton-filtered OTU table summary header:
	"
	head -14 $otutable_dir/n2_table_hdf5.summary | sed 's/^/\t\t/'
	echo "OTU picking method:
Tax assignment method: $taxmethod
Singleton-filtered OTU table summary header:
	" >> $log
	head -14 $otutable_dir/n2_table_hdf5.summary | sed 's/^/\t\t/' >> $log

	else
	echo "	Filtered tables detected.
	"
fi
fi

#####

## RDP

if [[ $taxassigner == "rdp" || $taxassigner == "ALL" ]]; then
taxmethod=RDP
taxdir=$outdir/$otupickdir/rdp_taxonomy_assignment

	## Adjust threads since RDP seems to choke with too many threads (> 12)
	if [[ $taxassignment_threads -gt 12 ]]; then
		rdptaxassignment_threads=12
	else
		rdptaxassignment_threads=$taxassignment_threads
	fi

	if [[ ! -f $taxdir/merged_rep_set_tax_assignments.txt ]]; then
res24=$(date +%s.%N)
	echo "	Assigning taxonomy.
	Method: $taxmethod on $rdptaxassignment_threads cores.
	"
	echo "Assigning taxonomy ($taxmethod):" >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "
	parallel_assign_taxonomy_rdp.py -i $outdir/$otupickdir/merged_rep_set.fna -o $taxdir -r $refs -t $tax -O $rdptaxassignment_threads -c 0.5 --rdp_max_memory 6000
	" >> $log
	`parallel_assign_taxonomy_rdp.py -i $outdir/$otupickdir/merged_rep_set.fna -o $taxdir -r $refs -t $tax -O $rdptaxassignment_threads -c 0.5 --rdp_max_memory 6000`
	wait

res25=$(date +%s.%N)
dt=$(echo "$res25 - $res24" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

tax_runtime=`printf "$taxmethod taxonomy assignment runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`	
echo "$tax_runtime

	" >> $log


	else
	echo "	$taxmethod taxonomy assignments detected.
	"
	fi

## Build OTU tables

	if [[ ! -d $otupickdir/OTU_tables_rdp_tax ]]; then
		mkdir -p $otupickdir/OTU_tables_rdp_tax
	fi
	otutable_dir=$otupickdir/OTU_tables_rdp_tax

## Make initial otu table (needs hdf5 conversion)

	if [[ ! -f $otutable_dir/raw_otu_table.biom ]]; then	
	echo "	Building OTU tables with $taxmethod assignments.
	"
	echo "Making initial OTU table:" >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "
	make_otu_table.py -i $outdir/$otupickdir/merged_otu_map.txt -t $taxdir/merged_rep_set_tax_assignments.txt -o $otutable_dir/initial_otu_table.biom
	" >> $log
	`make_otu_table.py -i $outdir/$otupickdir/merged_otu_map.txt -t $taxdir/merged_rep_set_tax_assignments.txt -o $otutable_dir/initial_otu_table.biom`

	fi

## Convert initial table to raw table (hdf5)

	if [[ ! -f $otutable_dir/raw_otu_table.biom ]]; then
	echo "	Making raw hdf5 OTU table.
	"
	echo "Making raw hdf5 OTU table:" >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "
	biom convert -i $otutable_dir/initial_otu_table.biom -o $otutable_dir/raw_otu_table.biom --table-type=\"OTU table\" --to-hdf5
	" >> $log
	`biom convert -i $otutable_dir/initial_otu_table.biom -o $otutable_dir/raw_otu_table.biom --table-type="OTU table" --to-hdf5`
	wait
	rm $otutable_dir/initial_otu_table.biom
	else
	echo "	Raw OTU table detected.
	"
	raw_or_taxfiltered_table=$otutable_dir/raw_otu_table.biom
	fi

## Filter non-target taxa (ITS and 16S mode only)

	if [[ $mode == "16S" ]]; then
		if [[ ! -f $otutable_dir/raw_otu_table_bacteria_only.biom ]]; then
		echo "	Filtering away non-prokaryotic sequences.
		"
		`filter_taxa_from_otu_table.py -i $otutable_dir/raw_otu_table.biom -o $otutable_dir/raw_otu_table_bacteria_only.biom -p k__Bacteria,k__Archaea` >/dev/null 2>&1 || true
		fi
		if [[ -f $otutable_dir/raw_otu_table_bacteria_only.biom ]]; then
		raw_or_taxfiltered_table=$otutable_dir/raw_otu_table_bacteria_only.biom
		fi
	fi

	if [[ $mode == "ITS" ]]; then
		if [[ ! -f $otutable_dir/raw_otu_table_fungi_only.biom ]]; then
		echo "	Filtering away non-fungal sequences.
		"
		`filter_taxa_from_otu_table.py -i $otutable_dir/raw_otu_table.biom -o $otutable_dir/raw_otu_table_fungi_only.biom -p k__Fungi` >/dev/null 2>&1 || true
		fi
		if [[ -f $otutable_dir/raw_otu_table_fungi_only.biom ]]; then
		raw_or_taxfiltered_table=$otutable_dir/raw_otu_table_fungi_only.biom
		fi
	fi

## Filter low count samples

	if [[ ! -f $otutable_dir/min100_table.biom ]]; then
	echo "	Filtering away low count samples (<100 reads).
	"
	`filter_samples_from_otu_table.py -i $raw_or_taxfiltered_table -o $otutable_dir/min100_table.biom -n 100`
	fi

## Filter singletons and unshared OTUs from each sample

if [[ ! -f $otutable_dir/n2_table_hdf5.biom ]] && [[ ! -f $otutable_dir/n2_table_CSS.biom ]] && [[ ! -f $otutable_dir/mc2_table_hdf5.biom ]] && [[ ! -f $otutable_dir/mc2_table_CSS.biom ]] && [[ ! -f $otutable_dir/005_table_hdf5.biom ]] && [[ ! -f $otutable_dir/005_table_CSS.biom ]] && [[ ! -f $otutable_dir/03_table_hdf5.biom ]] && [[ ! -f $otutable_dir/03_table_CSS.biom ]]; then

	if [[ ! -f $otutable_dir/n2_table_hdf5.biom ]]; then
	## filter singletons by sample and normalize
	filter_observations_by_sample.py -i $otutable_dir/min100_table.biom -o $otutable_dir/n2_table0.biom -n 1
	filter_otus_from_otu_table.py -i $otutable_dir/n2_table0.biom -o $otutable_dir/n2_table.biom -n 1 -s 2
	biom convert -i $otutable_dir/n2_table.biom -o $otutable_dir/n2_table_hdf5.biom --table-type="OTU table" --to-hdf5
	fi

	if [[ ! -f $otutable_dir/n2_table_CSS.biom ]]; then
	normalize_table.py -i $otutable_dir/n2_table_hdf5.biom -o $otutable_dir/n2_table_CSS.biom -a CSS >/dev/null 2>&1 || true
	fi

	## filter singletons by table and normalize
	if [[ ! -f $otutable_dir/mc2_table_hdf5.biom ]]; then
	filter_otus_from_otu_table.py -i $otutable_dir/min100_table.biom -o $otutable_dir/mc2_table_hdf5.biom -n 2 -s 2
	fi

	if [[ ! -f $otutable_dir/mc2_table_CSS.biom ]]; then
	normalize_table.py -i $otutable_dir/mc2_table_hdf5.biom -o $otutable_dir/mc2_table_CSS.biom -a CSS >/dev/null 2>&1 || true
	fi

	## filter table by 0.005 percent and normalize
	if [[ ! -f $otutable_dir/005_table_hdf5.biom ]]; then
	filter_otus_from_otu_table.py -i $otutable_dir/min100_table.biom -o $otutable_dir/005_table_hdf5.biom --min_count_fraction 0.00005 -s 2
	fi

	if [[ ! -f $otutable_dir/005_table_CSS.biom ]]; then
	normalize_table.py -i $otutable_dir/005_table_hdf5.biom -o $otutable_dir/005_table_CSS.biom -a CSS >/dev/null 2>&1 || true
	fi

	## filter at 0.3% by sample and normalize
	if [[ ! -f $otutable_dir/03_table_hdf5.biom ]]; then
	filter_observations_by_sample.py -i $otutable_dir/min100_table.biom -o $otutable_dir/03_table0.biom -f -n 0.003
	filter_otus_from_otu_table.py -i $otutable_dir/03_table0.biom -o $otutable_dir/03_table.biom -n 1 -s 2
	biom convert -i $otutable_dir/03_table.biom -o $otutable_dir/03_table_hdf5.biom --table-type="OTU table" --to-hdf5
	fi

	if [[ ! -f $otutable_dir/03_table_CSS.biom ]]; then
	normalize_table.py -i $otutable_dir/03_table_hdf5.biom -o $otutable_dir/03_table_CSS.biom -a CSS >/dev/null 2>&1 || true
	fi

	rm $otutable_dir/03_table0.biom >/dev/null 2>&1 || true
	rm $otutable_dir/03_table.biom >/dev/null 2>&1 || true
	rm $otutable_dir/n2_table0.biom >/dev/null 2>&1 || true
	rm $otutable_dir/n2_table.biom >/dev/null 2>&1 || true

## Summarize raw otu tables

	biom-summarize_folder.sh $otutable_dir >/dev/null
	written_seqs=`grep "Total count:" $otutable_dir/n2_table_hdf5.summary | cut -d" " -f3`
	input_seqs=`grep "Total number seqs written" split_libraries/split_library_log.txt | cut -f2`
	echo "	$written_seqs out of $input_seqs input sequences written.
	"

## Print filtered OTU table summary header to screen and log file

	echo "	OTU picking method: $otumethod ($similarity)
	Tax assignment method: $taxmethod
	Singleton-filtered OTU table summary header:
	"
	head -14 $otutable_dir/n2_table_hdf5.summary | sed 's/^/\t\t/'
	echo "OTU picking method:
Tax assignment method: $taxmethod
Singleton-filtered OTU table summary header:
	" >> $log
	head -14 $otutable_dir/n2_table_hdf5.summary | sed 's/^/\t\t/' >> $log

	else
	echo "	Filtered tables detected.
	"
fi
fi

#####

## UCLUST

if [[ $taxassigner == "uclust" || $taxassigner == "ALL" ]]; then
taxmethod=UCLUST
taxdir=$outdir/$otupickdir/uclust_taxonomy_assignment

	if [[ ! -f $taxdir/merged_rep_set_tax_assignments.txt ]]; then
res24=$(date +%s.%N)
	echo "	Assigning taxonomy.
	Method: $taxmethod on $taxassignment_threads cores.
	"
	echo "Assigning taxonomy ($taxmethod):" >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "
	parallel_assign_taxonomy_uclust.py -i $outdir/$otupickdir/merged_rep_set.fna -o $taxdir -r $refs -t $tax -O $taxassignment_threads
	" >> $log
	`parallel_assign_taxonomy_uclust.py -i $outdir/$otupickdir/merged_rep_set.fna -o $taxdir -r $refs -t $tax -O $taxassignment_threads`
	wait

res25=$(date +%s.%N)
dt=$(echo "$res25 - $res24" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

tax_runtime=`printf "$taxmethod taxonomy assignment runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`	
echo "$tax_runtime

	" >> $log


	else
	echo "	$taxmethod taxonomy assignments detected.
	"
	fi

## Build OTU tables

	if [[ ! -d $otupickdir/OTU_tables_uclust_tax ]]; then
		mkdir -p $otupickdir/OTU_tables_uclust_tax
	fi
	otutable_dir=$otupickdir/OTU_tables_uclust_tax

## Make initial otu table (needs hdf5 conversion)

	if [[ ! -f $otutable_dir/raw_otu_table.biom ]]; then	
	echo "	Building OTU tables with $taxmethod assignments.
	"
	echo "Making initial OTU table:" >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "
	make_otu_table.py -i $outdir/$otupickdir/merged_otu_map.txt -t $taxdir/merged_rep_set_tax_assignments.txt -o $otutable_dir/initial_otu_table.biom
	" >> $log
	`make_otu_table.py -i $outdir/$otupickdir/merged_otu_map.txt -t $taxdir/merged_rep_set_tax_assignments.txt -o $otutable_dir/initial_otu_table.biom`

	fi

## Convert initial table to raw table (hdf5)

	if [[ ! -f $otutable_dir/raw_otu_table.biom ]]; then
	echo "	Making raw hdf5 OTU table.
	"
	echo "Making raw hdf5 OTU table:" >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "
	biom convert -i $otutable_dir/initial_otu_table.biom -o $otutable_dir/raw_otu_table.biom --table-type=\"OTU table\" --to-hdf5
	" >> $log
	`biom convert -i $otutable_dir/initial_otu_table.biom -o $otutable_dir/raw_otu_table.biom --table-type="OTU table" --to-hdf5`
	wait
	rm $otutable_dir/initial_otu_table.biom
	else
	echo "	Raw OTU table detected.
	"
	raw_or_taxfiltered_table=$otutable_dir/raw_otu_table.biom
	fi

## Filter non-target taxa (ITS and 16S mode only)

	if [[ $mode == "16S" ]]; then
		if [[ ! -f $otutable_dir/raw_otu_table_bacteria_only.biom ]]; then
		echo "	Filtering away non-prokaryotic sequences.
		"
		`filter_taxa_from_otu_table.py -i $otutable_dir/raw_otu_table.biom -o $otutable_dir/raw_otu_table_bacteria_only.biom -p k__Bacteria,k__Archaea` >/dev/null 2>&1 || true
		fi
		if [[ -f $otutable_dir/raw_otu_table_bacteria_only.biom ]]; then
		raw_or_taxfiltered_table=$otutable_dir/raw_otu_table_bacteria_only.biom
		fi
	fi

	if [[ $mode == "ITS" ]]; then
		if [[ ! -f $otutable_dir/raw_otu_table_fungi_only.biom ]]; then
		echo "	Filtering away non-fungal sequences.
		"
		`filter_taxa_from_otu_table.py -i $otutable_dir/raw_otu_table.biom -o $otutable_dir/raw_otu_table_fungi_only.biom -p k__Fungi` >/dev/null 2>&1 || true
		fi
		if [[ -f $otutable_dir/raw_otu_table_fungi_only.biom ]]; then
		raw_or_taxfiltered_table=$otutable_dir/raw_otu_table_fungi_only.biom
		fi
	fi

## Filter low count samples

	if [[ ! -f $otutable_dir/min100_table.biom ]]; then
	echo "	Filtering away low count samples (<100 reads).
	"
	`filter_samples_from_otu_table.py -i $raw_or_taxfiltered_table -o $otutable_dir/min100_table.biom -n 100`
	fi

## Filter singletons and unshared OTUs from each sample

if [[ ! -f $otutable_dir/n2_table_hdf5.biom ]] && [[ ! -f $otutable_dir/n2_table_CSS.biom ]] && [[ ! -f $otutable_dir/mc2_table_hdf5.biom ]] && [[ ! -f $otutable_dir/mc2_table_CSS.biom ]] && [[ ! -f $otutable_dir/005_table_hdf5.biom ]] && [[ ! -f $otutable_dir/005_table_CSS.biom ]] && [[ ! -f $otutable_dir/03_table_hdf5.biom ]] && [[ ! -f $otutable_dir/03_table_CSS.biom ]]; then

	if [[ ! -f $otutable_dir/n2_table_hdf5.biom ]]; then
	## filter singletons by sample and normalize
	filter_observations_by_sample.py -i $otutable_dir/min100_table.biom -o $otutable_dir/n2_table0.biom -n 1
	filter_otus_from_otu_table.py -i $otutable_dir/n2_table0.biom -o $otutable_dir/n2_table.biom -n 1 -s 2
	biom convert -i $otutable_dir/n2_table.biom -o $otutable_dir/n2_table_hdf5.biom --table-type="OTU table" --to-hdf5
	fi

	if [[ ! -f $otutable_dir/n2_table_CSS.biom ]]; then
	normalize_table.py -i $otutable_dir/n2_table_hdf5.biom -o $otutable_dir/n2_table_CSS.biom -a CSS >/dev/null 2>&1 || true
	fi

	## filter singletons by table and normalize
	if [[ ! -f $otutable_dir/mc2_table_hdf5.biom ]]; then
	filter_otus_from_otu_table.py -i $otutable_dir/min100_table.biom -o $otutable_dir/mc2_table_hdf5.biom -n 2 -s 2
	fi

	if [[ ! -f $otutable_dir/mc2_table_CSS.biom ]]; then
	normalize_table.py -i $otutable_dir/mc2_table_hdf5.biom -o $otutable_dir/mc2_table_CSS.biom -a CSS >/dev/null 2>&1 || true
	fi

	## filter table by 0.005 percent and normalize
	if [[ ! -f $otutable_dir/005_table_hdf5.biom ]]; then
	filter_otus_from_otu_table.py -i $otutable_dir/min100_table.biom -o $otutable_dir/005_table_hdf5.biom --min_count_fraction 0.00005 -s 2
	fi

	if [[ ! -f $otutable_dir/005_table_CSS.biom ]]; then
	normalize_table.py -i $otutable_dir/005_table_hdf5.biom -o $otutable_dir/005_table_CSS.biom -a CSS >/dev/null 2>&1 || true
	fi

	## filter at 0.3% by sample and normalize
	if [[ ! -f $otutable_dir/03_table_hdf5.biom ]]; then
	filter_observations_by_sample.py -i $otutable_dir/min100_table.biom -o $otutable_dir/03_table0.biom -f -n 0.003
	filter_otus_from_otu_table.py -i $otutable_dir/03_table0.biom -o $otutable_dir/03_table.biom -n 1 -s 2
	biom convert -i $otutable_dir/03_table.biom -o $otutable_dir/03_table_hdf5.biom --table-type="OTU table" --to-hdf5
	fi

	if [[ ! -f $otutable_dir/03_table_CSS.biom ]]; then
	normalize_table.py -i $otutable_dir/03_table_hdf5.biom -o $otutable_dir/03_table_CSS.biom -a CSS >/dev/null 2>&1 || true
	fi

	rm $otutable_dir/03_table0.biom >/dev/null 2>&1 || true
	rm $otutable_dir/03_table.biom >/dev/null 2>&1 || true
	rm $otutable_dir/n2_table0.biom >/dev/null 2>&1 || true
	rm $otutable_dir/n2_table.biom >/dev/null 2>&1 || true

## Summarize raw otu tables

	biom-summarize_folder.sh $otutable_dir >/dev/null
	written_seqs=`grep "Total count:" $otutable_dir/n2_table_hdf5.summary | cut -d" " -f3`
	input_seqs=`grep "Total number seqs written" split_libraries/split_library_log.txt | cut -f2`
	echo "	$written_seqs out of $input_seqs input sequences written.
	"

## Print filtered OTU table summary header to screen and log file

	echo "	OTU picking method: $otumethod ($similarity)
	Tax assignment method: $taxmethod
	Singleton-filtered OTU table summary header:
	"
	head -14 $otutable_dir/n2_table_hdf5.summary | sed 's/^/\t\t/'
	echo "OTU picking method:
Tax assignment method: $taxmethod
Singleton-filtered OTU table summary header:
	" >> $log
	head -14 $otutable_dir/n2_table_hdf5.summary | sed 's/^/\t\t/' >> $log

	else
	echo "	Filtered tables detected.
	"
fi
fi

#####

done


res26a=$(date +%s.%N)
dt=$(echo "$res26a - $res9a" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

runtime=`printf "Total runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`

echo "	Sequential OTU picking steps completed (CDHIT).

	$runtime
"
echo "---

Sequential OTU picking completed (CDHIT)." >> $log
date "+%a %b %I:%M %p %Z %Y" >> $log
echo "
$runtime 
" >> $log
fi

##############################
## CDHIT OTU Steps END HERE ##
##############################

#####

##################################
## Openref OTU Steps BEGIN HERE ##
##################################

## Define otu picking parameters ahead of outdir naming

if [[ $otupicker == "openref" || $otupicker == "ALL" ]]; then
otumethod=OpenRef

if [[ $parameter_count == 1 ]]; then
	grep "similarity" $param_file | cut -d " " -f 2 > $tempdir/percent_similarities.temp
	else
	echo "0.97" > $tempdir/percent_similarities.temp
fi
	similaritycount=`cat $tempdir/percent_similarities.temp | wc -l`

	echo "	Beginning sequential OTU picking (Open Reference UCLUST) at $similaritycount similarity thresholds.
	"
	echo "Beginning sequential OTU picking (Open Reference UCLUST) at $similaritycount similarity thresholds." >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	res9a=$(date +%s.%N)

## Start sequential OTU picking

for similarity in `cat $tempdir/percent_similarities.temp`; do

## Open reference workflow command

otupickdir=openref_otus_$similarity

if [[ ! -f $otupickdir/final_otu_map.txt ]]; then
res10=$(date +%s.%N)

numseqs1=`cat $presufdir/prefix_rep_set.fasta | wc -l`
numseqs2=(`expr $numseqs1 / 2`)

	if [[ $parameter_count == 1 ]]; then
	maxaccepts=`grep max_accepts $param_file | cut -d " " -f 2`
	maxrejects=`grep max_rejects $param_file | cut -d " " -f 2`
	fi
	if [[ -z $maxaccepts ]]; then
	maxaccepts=20
	fi
	if [[ -z $maxrejects ]]; then
	maxrejects=500
	fi

	## build temporary parameter file
	echo "pick_otus:similarity $similarity" > $tempdir/openref_params.temp
	echo "pick_otus:max_accepts $maxaccepts" >> $tempdir/openref_params.temp
	echo "pick_otus:max_rejects $maxrejects" >> $tempdir/openref_params.temp
	or_params=$tempdir/openref_params.temp

	echo "	Picking OTUs against collapsed rep set.
	Input sequences: $numseqs2
	Method: Open reference (UCLUST)
	Similarity: $similarity
	Max accepts: $maxaccepts
	Max rejects: $maxrejects
	"
	echo "Picking OTUs against collapsed rep set." >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "Input sequences: $numseqs2" >> $log
	echo "Method: Open reference (UCLUST)" >> $log
	echo "Similarity: $similarity" >> $log
	echo "Max accepts: $maxaccepts" >> $log
	echo "Max rejects: $maxrejects" >> $log

	echo "
	pick_open_reference_otus.py -i $presufdir/prefix_rep_set.fasta -o $otupickdir -p $or_params -aO $otupicking_threads -r $refs --prefilter_percent_id 0.0 --suppress_taxonomy_assignment --suppress_align_and_tree
	" >> $log
	`pick_open_reference_otus.py -i $presufdir/prefix_rep_set.fasta -o $otupickdir -p $or_params -aO $otupicking_threads -r $refs --prefilter_percent_id 0.0 --suppress_taxonomy_assignment --suppress_align_and_tree`

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
	echo "	Open reference OTU picking already completed ($similarity).
	"
fi

if [[ ! -f $otupickdir/merged_otu_map.txt ]]; then
res12=$(date +%s.%N)
	echo "	Merging OTU maps.
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
	echo "	OTU maps already merged.
	"
fi

if [[ ! -f $otupickdir/merged_rep_set.fna ]]; then
res14=$(date +%s.%N)
	echo "	Picking rep set against merged OTU map.
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
	echo "	Merged rep set already completed.
	"
fi

## Assign taxonomy (one or all tax assigners)

## BLAST

if [[ $taxassigner == "blast" || $taxassigner == "ALL" ]]; then
taxmethod=BLAST
taxdir=$outdir/$otupickdir/blast_taxonomy_assignment

	if [[ ! -f $taxdir/merged_rep_set_tax_assignments.txt ]]; then
res24=$(date +%s.%N)
	echo "	Assigning taxonomy.
	Method: $taxmethod on $taxassignment_threads cores.
	"
	echo "Assigning taxonomy ($taxmethod):" >> $log
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

tax_runtime=`printf "$taxmethod taxonomy assignment runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`	
echo "$tax_runtime

	" >> $log
	else
	echo "	$taxmethod taxonomy assignments detected.
	"
	fi

## Build OTU tables

	if [[ ! -d $otupickdir/OTU_tables_blast_tax ]]; then
		mkdir -p $otupickdir/OTU_tables_blast_tax
	fi
	otutable_dir=$otupickdir/OTU_tables_blast_tax

## Make initial otu table (needs hdf5 conversion)

	if [[ ! -f $otutable_dir/raw_otu_table.biom ]]; then	
	echo "	Building OTU tables with $taxmethod assignments.
	"
	echo "Making initial OTU table:" >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "
	make_otu_table.py -i $outdir/$otupickdir/merged_otu_map.txt -t $taxdir/merged_rep_set_tax_assignments.txt -o $otutable_dir/initial_otu_table.biom
	" >> $log
	`make_otu_table.py -i $outdir/$otupickdir/merged_otu_map.txt -t $taxdir/merged_rep_set_tax_assignments.txt -o $otutable_dir/initial_otu_table.biom`

	fi

## Convert initial table to raw table (hdf5)

	if [[ ! -f $otutable_dir/raw_otu_table.biom ]]; then
	echo "	Making raw hdf5 OTU table.
	"
	echo "Making raw hdf5 OTU table:" >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "
	biom convert -i $otutable_dir/initial_otu_table.biom -o $otutable_dir/raw_otu_table.biom --table-type=\"OTU table\" --to-hdf5
	" >> $log
	`biom convert -i $otutable_dir/initial_otu_table.biom -o $otutable_dir/raw_otu_table.biom --table-type="OTU table" --to-hdf5`
	wait
	rm $otutable_dir/initial_otu_table.biom
	else
	echo "	Raw OTU table detected.
	"
	raw_or_taxfiltered_table=$otutable_dir/raw_otu_table.biom
	fi

## Filter non-target taxa (ITS and 16S mode only)

	if [[ $mode == "16S" ]]; then
		if [[ ! -f $otutable_dir/raw_otu_table_bacteria_only.biom ]]; then
		echo "	Filtering away non-prokaryotic sequences.
		"
		`filter_taxa_from_otu_table.py -i $otutable_dir/raw_otu_table.biom -o $otutable_dir/raw_otu_table_bacteria_only.biom -p k__Bacteria,k__Archaea` >/dev/null 2>&1 || true
		fi
		if [[ -f $otutable_dir/raw_otu_table_bacteria_only.biom ]]; then
		raw_or_taxfiltered_table=$otutable_dir/raw_otu_table_bacteria_only.biom
		fi
	fi

	if [[ $mode == "ITS" ]]; then
		if [[ ! -f $otutable_dir/raw_otu_table_fungi_only.biom ]]; then
		echo "	Filtering away non-fungal sequences.
		"
		`filter_taxa_from_otu_table.py -i $otutable_dir/raw_otu_table.biom -o $otutable_dir/raw_otu_table_fungi_only.biom -p k__Fungi` >/dev/null 2>&1 || true
		fi
		if [[ -f $otutable_dir/raw_otu_table_fungi_only.biom ]]; then
		raw_or_taxfiltered_table=$otutable_dir/raw_otu_table_fungi_only.biom
		fi
	fi

## Filter low count samples

	if [[ ! -f $otutable_dir/min100_table.biom ]]; then
	echo "	Filtering away low count samples (<100 reads).
	"
	`filter_samples_from_otu_table.py -i $raw_or_taxfiltered_table -o $otutable_dir/min100_table.biom -n 100`
	fi

## Filter singletons and unshared OTUs from each sample

if [[ ! -f $otutable_dir/n2_table_hdf5.biom ]] && [[ ! -f $otutable_dir/n2_table_CSS.biom ]] && [[ ! -f $otutable_dir/mc2_table_hdf5.biom ]] && [[ ! -f $otutable_dir/mc2_table_CSS.biom ]] && [[ ! -f $otutable_dir/005_table_hdf5.biom ]] && [[ ! -f $otutable_dir/005_table_CSS.biom ]] && [[ ! -f $otutable_dir/03_table_hdf5.biom ]] && [[ ! -f $otutable_dir/03_table_CSS.biom ]]; then

	if [[ ! -f $otutable_dir/n2_table_hdf5.biom ]]; then
	## filter singletons by sample and normalize
	filter_observations_by_sample.py -i $otutable_dir/min100_table.biom -o $otutable_dir/n2_table0.biom -n 1
	filter_otus_from_otu_table.py -i $otutable_dir/n2_table0.biom -o $otutable_dir/n2_table.biom -n 1 -s 2
	biom convert -i $otutable_dir/n2_table.biom -o $otutable_dir/n2_table_hdf5.biom --table-type="OTU table" --to-hdf5
	fi

	if [[ ! -f $otutable_dir/n2_table_CSS.biom ]]; then
	normalize_table.py -i $otutable_dir/n2_table_hdf5.biom -o $otutable_dir/n2_table_CSS.biom -a CSS >/dev/null 2>&1 || true
	fi

	## filter singletons by table and normalize
	if [[ ! -f $otutable_dir/mc2_table_hdf5.biom ]]; then
	filter_otus_from_otu_table.py -i $otutable_dir/min100_table.biom -o $otutable_dir/mc2_table_hdf5.biom -n 2 -s 2
	fi

	if [[ ! -f $otutable_dir/mc2_table_CSS.biom ]]; then
	normalize_table.py -i $otutable_dir/mc2_table_hdf5.biom -o $otutable_dir/mc2_table_CSS.biom -a CSS >/dev/null 2>&1 || true
	fi

	## filter table by 0.005 percent and normalize
	if [[ ! -f $otutable_dir/005_table_hdf5.biom ]]; then
	filter_otus_from_otu_table.py -i $otutable_dir/min100_table.biom -o $otutable_dir/005_table_hdf5.biom --min_count_fraction 0.00005 -s 2
	fi

	if [[ ! -f $otutable_dir/005_table_CSS.biom ]]; then
	normalize_table.py -i $otutable_dir/005_table_hdf5.biom -o $otutable_dir/005_table_CSS.biom -a CSS >/dev/null 2>&1 || true
	fi

	## filter at 0.3% by sample and normalize
	if [[ ! -f $otutable_dir/03_table_hdf5.biom ]]; then
	filter_observations_by_sample.py -i $otutable_dir/min100_table.biom -o $otutable_dir/03_table0.biom -f -n 0.003
	filter_otus_from_otu_table.py -i $otutable_dir/03_table0.biom -o $otutable_dir/03_table.biom -n 1 -s 2
	biom convert -i $otutable_dir/03_table.biom -o $otutable_dir/03_table_hdf5.biom --table-type="OTU table" --to-hdf5
	fi

	if [[ ! -f $otutable_dir/03_table_CSS.biom ]]; then
	normalize_table.py -i $otutable_dir/03_table_hdf5.biom -o $otutable_dir/03_table_CSS.biom -a CSS >/dev/null 2>&1 || true
	fi

	rm $otutable_dir/03_table0.biom >/dev/null 2>&1 || true
	rm $otutable_dir/03_table.biom >/dev/null 2>&1 || true
	rm $otutable_dir/n2_table0.biom >/dev/null 2>&1 || true
	rm $otutable_dir/n2_table.biom >/dev/null 2>&1 || true

## Summarize raw otu tables

	biom-summarize_folder.sh $otutable_dir >/dev/null
	written_seqs=`grep "Total count:" $otutable_dir/n2_table_hdf5.summary | cut -d" " -f3`
	input_seqs=`grep "Total number seqs written" split_libraries/split_library_log.txt | cut -f2`
	echo "	$written_seqs out of $input_seqs input sequences written.
	"

## Print filtered OTU table summary header to screen and log file

	echo "	OTU picking method: $otumethod ($similarity)
	Tax assignment method: $taxmethod
	Singleton-filtered OTU table summary header:
	"
	head -14 $otutable_dir/n2_table_hdf5.summary | sed 's/^/\t\t/'
	echo "OTU picking method:
Tax assignment method: $taxmethod
Singleton-filtered OTU table summary header:
	" >> $log
	head -14 $otutable_dir/n2_table_hdf5.summary | sed 's/^/\t\t/' >> $log

	else
	echo "	Filtered tables detected.
	"
fi
fi

#####

## RDP

if [[ $taxassigner == "rdp" || $taxassigner == "ALL" ]]; then
taxmethod=RDP
taxdir=$outdir/$otupickdir/rdp_taxonomy_assignment

	## Adjust threads since RDP seems to choke with too many threads (> 12)
	if [[ $taxassignment_threads -gt 12 ]]; then
		rdptaxassignment_threads=12
	else
		rdptaxassignment_threads=$taxassignment_threads
	fi

	if [[ ! -f $taxdir/merged_rep_set_tax_assignments.txt ]]; then
res24=$(date +%s.%N)
	echo "	Assigning taxonomy.
	Method: $taxmethod on $rdptaxassignment_threads cores.
	"
	echo "Assigning taxonomy ($taxmethod):" >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "
	parallel_assign_taxonomy_rdp.py -i $outdir/$otupickdir/merged_rep_set.fna -o $taxdir -r $refs -t $tax -O $rdptaxassignment_threads -c 0.5 --rdp_max_memory 6000
	" >> $log
	`parallel_assign_taxonomy_rdp.py -i $outdir/$otupickdir/merged_rep_set.fna -o $taxdir -r $refs -t $tax -O $rdptaxassignment_threads -c 0.5 --rdp_max_memory 6000`
	wait

res25=$(date +%s.%N)
dt=$(echo "$res25 - $res24" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

tax_runtime=`printf "$taxmethod taxonomy assignment runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`	
echo "$tax_runtime

	" >> $log


	else
	echo "	$taxmethod taxonomy assignments detected.
	"
	fi

## Build OTU tables

	if [[ ! -d $otupickdir/OTU_tables_rdp_tax ]]; then
		mkdir -p $otupickdir/OTU_tables_rdp_tax
	fi
	otutable_dir=$otupickdir/OTU_tables_rdp_tax

## Make initial otu table (needs hdf5 conversion)

	if [[ ! -f $otutable_dir/raw_otu_table.biom ]]; then	
	echo "	Building OTU tables with $taxmethod assignments.
	"
	echo "Making initial OTU table:" >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "
	make_otu_table.py -i $outdir/$otupickdir/merged_otu_map.txt -t $taxdir/merged_rep_set_tax_assignments.txt -o $otutable_dir/initial_otu_table.biom
	" >> $log
	`make_otu_table.py -i $outdir/$otupickdir/merged_otu_map.txt -t $taxdir/merged_rep_set_tax_assignments.txt -o $otutable_dir/initial_otu_table.biom`

	fi

## Convert initial table to raw table (hdf5)

	if [[ ! -f $otutable_dir/raw_otu_table.biom ]]; then
	echo "	Making raw hdf5 OTU table.
	"
	echo "Making raw hdf5 OTU table:" >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "
	biom convert -i $otutable_dir/initial_otu_table.biom -o $otutable_dir/raw_otu_table.biom --table-type=\"OTU table\" --to-hdf5
	" >> $log
	`biom convert -i $otutable_dir/initial_otu_table.biom -o $otutable_dir/raw_otu_table.biom --table-type="OTU table" --to-hdf5`
	wait
	rm $otutable_dir/initial_otu_table.biom
	else
	echo "	Raw OTU table detected.
	"
	raw_or_taxfiltered_table=$otutable_dir/raw_otu_table.biom
	fi

## Filter non-target taxa (ITS and 16S mode only)

	if [[ $mode == "16S" ]]; then
		if [[ ! -f $otutable_dir/raw_otu_table_bacteria_only.biom ]]; then
		echo "	Filtering away non-prokaryotic sequences.
		"
		`filter_taxa_from_otu_table.py -i $otutable_dir/raw_otu_table.biom -o $otutable_dir/raw_otu_table_bacteria_only.biom -p k__Bacteria,k__Archaea` >/dev/null 2>&1 || true
		fi
		if [[ -f $otutable_dir/raw_otu_table_bacteria_only.biom ]]; then
		raw_or_taxfiltered_table=$otutable_dir/raw_otu_table_bacteria_only.biom
		fi
	fi

	if [[ $mode == "ITS" ]]; then
		if [[ ! -f $otutable_dir/raw_otu_table_fungi_only.biom ]]; then
		echo "	Filtering away non-fungal sequences.
		"
		`filter_taxa_from_otu_table.py -i $otutable_dir/raw_otu_table.biom -o $otutable_dir/raw_otu_table_fungi_only.biom -p k__Fungi` >/dev/null 2>&1 || true
		fi
		if [[ -f $otutable_dir/raw_otu_table_fungi_only.biom ]]; then
		raw_or_taxfiltered_table=$otutable_dir/raw_otu_table_fungi_only.biom
		fi
	fi

## Filter low count samples

	if [[ ! -f $otutable_dir/min100_table.biom ]]; then
	echo "	Filtering away low count samples (<100 reads).
	"
	`filter_samples_from_otu_table.py -i $raw_or_taxfiltered_table -o $otutable_dir/min100_table.biom -n 100`
	fi

## Filter singletons and unshared OTUs from each sample

if [[ ! -f $otutable_dir/n2_table_hdf5.biom ]] && [[ ! -f $otutable_dir/n2_table_CSS.biom ]] && [[ ! -f $otutable_dir/mc2_table_hdf5.biom ]] && [[ ! -f $otutable_dir/mc2_table_CSS.biom ]] && [[ ! -f $otutable_dir/005_table_hdf5.biom ]] && [[ ! -f $otutable_dir/005_table_CSS.biom ]] && [[ ! -f $otutable_dir/03_table_hdf5.biom ]] && [[ ! -f $otutable_dir/03_table_CSS.biom ]]; then

	if [[ ! -f $otutable_dir/n2_table_hdf5.biom ]]; then
	## filter singletons by sample and normalize
	filter_observations_by_sample.py -i $otutable_dir/min100_table.biom -o $otutable_dir/n2_table0.biom -n 1
	filter_otus_from_otu_table.py -i $otutable_dir/n2_table0.biom -o $otutable_dir/n2_table.biom -n 1 -s 2
	biom convert -i $otutable_dir/n2_table.biom -o $otutable_dir/n2_table_hdf5.biom --table-type="OTU table" --to-hdf5
	fi

	if [[ ! -f $otutable_dir/n2_table_CSS.biom ]]; then
	normalize_table.py -i $otutable_dir/n2_table_hdf5.biom -o $otutable_dir/n2_table_CSS.biom -a CSS >/dev/null 2>&1 || true
	fi

	## filter singletons by table and normalize
	if [[ ! -f $otutable_dir/mc2_table_hdf5.biom ]]; then
	filter_otus_from_otu_table.py -i $otutable_dir/min100_table.biom -o $otutable_dir/mc2_table_hdf5.biom -n 2 -s 2
	fi

	if [[ ! -f $otutable_dir/mc2_table_CSS.biom ]]; then
	normalize_table.py -i $otutable_dir/mc2_table_hdf5.biom -o $otutable_dir/mc2_table_CSS.biom -a CSS >/dev/null 2>&1 || true
	fi

	## filter table by 0.005 percent and normalize
	if [[ ! -f $otutable_dir/005_table_hdf5.biom ]]; then
	filter_otus_from_otu_table.py -i $otutable_dir/min100_table.biom -o $otutable_dir/005_table_hdf5.biom --min_count_fraction 0.00005 -s 2
	fi

	if [[ ! -f $otutable_dir/005_table_CSS.biom ]]; then
	normalize_table.py -i $otutable_dir/005_table_hdf5.biom -o $otutable_dir/005_table_CSS.biom -a CSS >/dev/null 2>&1 || true
	fi

	## filter at 0.3% by sample and normalize
	if [[ ! -f $otutable_dir/03_table_hdf5.biom ]]; then
	filter_observations_by_sample.py -i $otutable_dir/min100_table.biom -o $otutable_dir/03_table0.biom -f -n 0.003
	filter_otus_from_otu_table.py -i $otutable_dir/03_table0.biom -o $otutable_dir/03_table.biom -n 1 -s 2
	biom convert -i $otutable_dir/03_table.biom -o $otutable_dir/03_table_hdf5.biom --table-type="OTU table" --to-hdf5
	fi

	if [[ ! -f $otutable_dir/03_table_CSS.biom ]]; then
	normalize_table.py -i $otutable_dir/03_table_hdf5.biom -o $otutable_dir/03_table_CSS.biom -a CSS >/dev/null 2>&1 || true
	fi

	rm $otutable_dir/03_table0.biom >/dev/null 2>&1 || true
	rm $otutable_dir/03_table.biom >/dev/null 2>&1 || true
	rm $otutable_dir/n2_table0.biom >/dev/null 2>&1 || true
	rm $otutable_dir/n2_table.biom >/dev/null 2>&1 || true

## Summarize raw otu tables

	biom-summarize_folder.sh $otutable_dir >/dev/null
	written_seqs=`grep "Total count:" $otutable_dir/n2_table_hdf5.summary | cut -d" " -f3`
	input_seqs=`grep "Total number seqs written" split_libraries/split_library_log.txt | cut -f2`
	echo "	$written_seqs out of $input_seqs input sequences written.
	"

## Print filtered OTU table summary header to screen and log file

	echo "	OTU picking method: $otumethod ($similarity)
	Tax assignment method: $taxmethod
	Singleton-filtered OTU table summary header:
	"
	head -14 $otutable_dir/n2_table_hdf5.summary | sed 's/^/\t\t/'
	echo "OTU picking method:
Tax assignment method: $taxmethod
Singleton-filtered OTU table summary header:
	" >> $log
	head -14 $otutable_dir/n2_table_hdf5.summary | sed 's/^/\t\t/' >> $log

	else
	echo "	Filtered tables detected.
	"
fi
fi

#####

## UCLUST

if [[ $taxassigner == "uclust" || $taxassigner == "ALL" ]]; then
taxmethod=UCLUST
taxdir=$outdir/$otupickdir/uclust_taxonomy_assignment

	if [[ ! -f $taxdir/merged_rep_set_tax_assignments.txt ]]; then
res24=$(date +%s.%N)
	echo "	Assigning taxonomy.
	Method: $taxmethod on $taxassignment_threads cores.
	"
	echo "Assigning taxonomy ($taxmethod):" >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "
	parallel_assign_taxonomy_uclust.py -i $outdir/$otupickdir/merged_rep_set.fna -o $taxdir -r $refs -t $tax -O $taxassignment_threads
	" >> $log
	`parallel_assign_taxonomy_uclust.py -i $outdir/$otupickdir/merged_rep_set.fna -o $taxdir -r $refs -t $tax -O $taxassignment_threads`
	wait

res25=$(date +%s.%N)
dt=$(echo "$res25 - $res24" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

tax_runtime=`printf "$taxmethod taxonomy assignment runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`	
echo "$tax_runtime

	" >> $log


	else
	echo "	$taxmethod taxonomy assignments detected.
	"
	fi

## Build OTU tables

	if [[ ! -d $otupickdir/OTU_tables_uclust_tax ]]; then
		mkdir -p $otupickdir/OTU_tables_uclust_tax
	fi
	otutable_dir=$otupickdir/OTU_tables_uclust_tax

## Make initial otu table (needs hdf5 conversion)

	if [[ ! -f $otutable_dir/raw_otu_table.biom ]]; then	
	echo "	Building OTU tables with $taxmethod assignments.
	"
	echo "Making initial OTU table:" >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "
	make_otu_table.py -i $outdir/$otupickdir/merged_otu_map.txt -t $taxdir/merged_rep_set_tax_assignments.txt -o $otutable_dir/initial_otu_table.biom
	" >> $log
	`make_otu_table.py -i $outdir/$otupickdir/merged_otu_map.txt -t $taxdir/merged_rep_set_tax_assignments.txt -o $otutable_dir/initial_otu_table.biom`

	fi

## Convert initial table to raw table (hdf5)

	if [[ ! -f $otutable_dir/raw_otu_table.biom ]]; then
	echo "	Making raw hdf5 OTU table.
	"
	echo "Making raw hdf5 OTU table:" >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "
	biom convert -i $otutable_dir/initial_otu_table.biom -o $otutable_dir/raw_otu_table.biom --table-type=\"OTU table\" --to-hdf5
	" >> $log
	`biom convert -i $otutable_dir/initial_otu_table.biom -o $otutable_dir/raw_otu_table.biom --table-type="OTU table" --to-hdf5`
	wait
	rm $otutable_dir/initial_otu_table.biom
	else
	echo "	Raw OTU table detected.
	"
	raw_or_taxfiltered_table=$otutable_dir/raw_otu_table.biom
	fi

## Filter non-target taxa (ITS and 16S mode only)

	if [[ $mode == "16S" ]]; then
		if [[ ! -f $otutable_dir/raw_otu_table_bacteria_only.biom ]]; then
		echo "	Filtering away non-prokaryotic sequences.
		"
		`filter_taxa_from_otu_table.py -i $otutable_dir/raw_otu_table.biom -o $otutable_dir/raw_otu_table_bacteria_only.biom -p k__Bacteria,k__Archaea` >/dev/null 2>&1 || true
		fi
		if [[ -f $otutable_dir/raw_otu_table_bacteria_only.biom ]]; then
		raw_or_taxfiltered_table=$otutable_dir/raw_otu_table_bacteria_only.biom
		fi
	fi

	if [[ $mode == "ITS" ]]; then
		if [[ ! -f $otutable_dir/raw_otu_table_fungi_only.biom ]]; then
		echo "	Filtering away non-fungal sequences.
		"
		`filter_taxa_from_otu_table.py -i $otutable_dir/raw_otu_table.biom -o $otutable_dir/raw_otu_table_fungi_only.biom -p k__Fungi` >/dev/null 2>&1 || true
		fi
		if [[ -f $otutable_dir/raw_otu_table_fungi_only.biom ]]; then
		raw_or_taxfiltered_table=$otutable_dir/raw_otu_table_fungi_only.biom
		fi
	fi

## Filter low count samples

	if [[ ! -f $otutable_dir/min100_table.biom ]]; then
	echo "	Filtering away low count samples (<100 reads).
	"
	`filter_samples_from_otu_table.py -i $raw_or_taxfiltered_table -o $otutable_dir/min100_table.biom -n 100`
	fi

## Filter singletons and unshared OTUs from each sample

if [[ ! -f $otutable_dir/n2_table_hdf5.biom ]] && [[ ! -f $otutable_dir/n2_table_CSS.biom ]] && [[ ! -f $otutable_dir/mc2_table_hdf5.biom ]] && [[ ! -f $otutable_dir/mc2_table_CSS.biom ]] && [[ ! -f $otutable_dir/005_table_hdf5.biom ]] && [[ ! -f $otutable_dir/005_table_CSS.biom ]] && [[ ! -f $otutable_dir/03_table_hdf5.biom ]] && [[ ! -f $otutable_dir/03_table_CSS.biom ]]; then

	if [[ ! -f $otutable_dir/n2_table_hdf5.biom ]]; then
	## filter singletons by sample and normalize
	filter_observations_by_sample.py -i $otutable_dir/min100_table.biom -o $otutable_dir/n2_table0.biom -n 1
	filter_otus_from_otu_table.py -i $otutable_dir/n2_table0.biom -o $otutable_dir/n2_table.biom -n 1 -s 2
	biom convert -i $otutable_dir/n2_table.biom -o $otutable_dir/n2_table_hdf5.biom --table-type="OTU table" --to-hdf5
	fi

	if [[ ! -f $otutable_dir/n2_table_CSS.biom ]]; then
	normalize_table.py -i $otutable_dir/n2_table_hdf5.biom -o $otutable_dir/n2_table_CSS.biom -a CSS >/dev/null 2>&1 || true
	fi

	## filter singletons by table and normalize
	if [[ ! -f $otutable_dir/mc2_table_hdf5.biom ]]; then
	filter_otus_from_otu_table.py -i $otutable_dir/min100_table.biom -o $otutable_dir/mc2_table_hdf5.biom -n 2 -s 2
	fi

	if [[ ! -f $otutable_dir/mc2_table_CSS.biom ]]; then
	normalize_table.py -i $otutable_dir/mc2_table_hdf5.biom -o $otutable_dir/mc2_table_CSS.biom -a CSS >/dev/null 2>&1 || true
	fi

	## filter table by 0.005 percent and normalize
	if [[ ! -f $otutable_dir/005_table_hdf5.biom ]]; then
	filter_otus_from_otu_table.py -i $otutable_dir/min100_table.biom -o $otutable_dir/005_table_hdf5.biom --min_count_fraction 0.00005 -s 2
	fi

	if [[ ! -f $otutable_dir/005_table_CSS.biom ]]; then
	normalize_table.py -i $otutable_dir/005_table_hdf5.biom -o $otutable_dir/005_table_CSS.biom -a CSS >/dev/null 2>&1 || true
	fi

	## filter at 0.3% by sample and normalize
	if [[ ! -f $otutable_dir/03_table_hdf5.biom ]]; then
	filter_observations_by_sample.py -i $otutable_dir/min100_table.biom -o $otutable_dir/03_table0.biom -f -n 0.003
	filter_otus_from_otu_table.py -i $otutable_dir/03_table0.biom -o $otutable_dir/03_table.biom -n 1 -s 2
	biom convert -i $otutable_dir/03_table.biom -o $otutable_dir/03_table_hdf5.biom --table-type="OTU table" --to-hdf5
	fi

	if [[ ! -f $otutable_dir/03_table_CSS.biom ]]; then
	normalize_table.py -i $otutable_dir/03_table_hdf5.biom -o $otutable_dir/03_table_CSS.biom -a CSS >/dev/null 2>&1 || true
	fi

	rm $otutable_dir/03_table0.biom >/dev/null 2>&1 || true
	rm $otutable_dir/03_table.biom >/dev/null 2>&1 || true
	rm $otutable_dir/n2_table0.biom >/dev/null 2>&1 || true
	rm $otutable_dir/n2_table.biom >/dev/null 2>&1 || true

## Summarize raw otu tables

	biom-summarize_folder.sh $otutable_dir >/dev/null
	written_seqs=`grep "Total count:" $otutable_dir/n2_table_hdf5.summary | cut -d" " -f3`
	input_seqs=`grep "Total number seqs written" split_libraries/split_library_log.txt | cut -f2`
	echo "	$written_seqs out of $input_seqs input sequences written.
	"

## Print filtered OTU table summary header to screen and log file

	echo "	OTU picking method: $otumethod ($similarity)
	Tax assignment method: $taxmethod
	Singleton-filtered OTU table summary header:
	"
	head -14 $otutable_dir/n2_table_hdf5.summary | sed 's/^/\t\t/'
	echo "OTU picking method:
Tax assignment method: $taxmethod
Singleton-filtered OTU table summary header:
	" >> $log
	head -14 $otutable_dir/n2_table_hdf5.summary | sed 's/^/\t\t/' >> $log

	else
	echo "	Filtered tables detected.
	"
fi
fi

#####

done


res26a=$(date +%s.%N)
dt=$(echo "$res26a - $res9a" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

runtime=`printf "Total runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`

echo "	Sequential OTU picking steps completed (UCLUST openref).

	$runtime
"
echo "---

Sequential OTU picking completed (UCLUST openref)." >> $log
date "+%a %b %I:%M %p %Z %Y" >> $log
echo "
$runtime 
" >> $log
fi


################################
## Openref OTU Steps END HERE ##
################################

#####

#########################################
## Custom openref OTU Steps BEGIN HERE ##
#########################################

## Define otu picking parameters ahead of outdir naming

if [[ $otupicker == "custom_openref" || $otupicker == "ALL" ]]; then
otumethod=CustomOpenRef

if [[ $parameter_count == 1 ]]; then
	grep "similarity" $param_file | cut -d " " -f 2 > $tempdir/percent_similarities.temp
	else
	echo "0.97" > $tempdir/percent_similarities.temp
fi
	similaritycount=`cat $tempdir/percent_similarities.temp | wc -l`

	echo "	Beginning sequential OTU picking (Custom openref) at $similaritycount similarity thresholds.
	"
	echo "Beginning sequential OTU picking (Custom openref) at $similaritycount similarity thresholds." >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	res9a=$(date +%s.%N)

## Start sequential OTU picking

for similarity in `cat $tempdir/percent_similarities.temp`; do

otupickdir=custom-openref_otus_$similarity

## Custom openref if 1 - all steps
if [[ ! -f $otupickdir/final_rep_set.fna ]]; then
res10=$(date +%s.%N)

## Custom openref if 1a - blast step
	if [[ ! -f $otupickdir/blast_step1_reference/step1_rep_set.fasta ]]; then
numseqs1=`cat $presufdir/prefix_rep_set.fasta | wc -l`
numseqs2=(`expr $numseqs1 / 2`)

	if [[ -d $otupickdir/blast_step1_reference ]]; then 
	rm -r $otupickdir/blast_step1_reference/*
	fi
	if [[ -d $otupickdir/cdhit_step2_denovo ]]; then
	rm -r $otupickdir/cdhit_step2_denovo
	fi

	echo "	Picking OTUs against collapsed rep set.
	Input sequences: $numseqs2
	Method: BLAST (step 1, reference-based OTU picking)"
	echo "Picking OTUs against collapsed rep set." >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "Input sequences: $numseqs2" >> $log
	echo "Method: BLAST (step 1, reference-based OTU picking)" >> $log
	echo "Percent similarity: $similarity" >> $log
	echo "	Percent similarity: $similarity
	"
	echo "
	parallel_pick_otus_blast.py -i $presufdir/prefix_rep_set.fasta -o $otupickdir/blast_step1_reference -s $similarity -O $otupicking_threads -r $refs
	" >> $log
	`parallel_pick_otus_blast.py -i $presufdir/prefix_rep_set.fasta -o $otupickdir/blast_step1_reference -s $similarity -O $otupicking_threads -r $refs`

	## Merge OTU maps and pick rep set for reference-based successes

	`merge_otu_maps.py -i $presufdir/$seqname\_otus.txt,$otupickdir/blast_step1_reference/prefix_rep_set_otus.txt -o $otupickdir/blast_step1_reference/merged_step1_otus.txt`

	`pick_rep_set.py -i $otupickdir/blast_step1_reference/merged_step1_otus.txt -f $seqs -o $otupickdir/blast_step1_reference/step1_rep_set.fasta`

	## Make failures file for clustering against de novo

	cat $otupickdir/blast_step1_reference/prefix_rep_set_otus.txt | cut -f 2- > $otupickdir/blast_step1_reference/prefix_rep_set_otuids_all.txt
	paste -sd ' ' - < $otupickdir/blast_step1_reference/prefix_rep_set_otuids_all.txt > $otupickdir/blast_step1_reference/prefix_rep_set_otuids_1row.txt
	tr -s "[:space:]" "\n" <$otupickdir/blast_step1_reference/prefix_rep_set_otuids_1row.txt | sed "/^$/d" > $otupickdir/blast_step1_reference/prefix_rep_set_otuids.txt
	rm $otupickdir/blast_step1_reference/prefix_rep_set_otuids_1row.txt
	rm $otupickdir/blast_step1_reference/prefix_rep_set_otuids_all.txt
	filter_fasta.py -f $presufdir/prefix_rep_set.fasta -o $otupickdir/blast_step1_reference/step1_failures.fasta -s $otupickdir/blast_step1_reference/prefix_rep_set_otuids.txt -n
	rm $otupickdir/blast_step1_reference/prefix_rep_set_otuids.txt
	
	## Count successes and failures from step 1 for reporting purposes

	successlines=`cat $otupickdir/blast_step1_reference/step1_rep_set.fasta | wc -l`
	successseqs=$(($successlines/2))
	failurelines=`cat $otupickdir/blast_step1_reference/step1_failures.fasta | wc -l`
	failureseqs=$(($failurelines/2))

	echo "	$successseqs OTUs picked against reference collection.
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
echo "	$otu_runtime
"
echo "$otu_runtime

	" >> $log

	else
	echo "	BLAST OTU picking already completed (step 1 OTUs, $similarity).
	"

## Custom openref fi 1a - blast step
	fi

	## Start step 2 (de novo) OTU picking with CDHIT, skip if no failures

## Custom openref if 2 - run denovo if any failures were produced
if [[ -s $otupickdir/blast_step1_reference/step1_failures.fasta ]]; then

## Custom openref if 3 - denovo step
	if [[ ! -f $otupickdir/cdhit_step2_denovo/step1_failures_otus.txt ]] || [[ ! -f $otupickdir/cdhit_step2_denovo/step2_rep_set.fasta ]]; then
res12=$(date +%s.%N)

	failurelines=`cat $otupickdir/blast_step1_reference/step1_failures.fasta | wc -l`
	failureseqs=$(($failurelines/2))

	echo "	Picking OTUs against step 1 failures.
	Input sequences: $failureseqs
	Method: CDHIT (step 2, de novo OTU picking)"
	echo "Picking OTUs against step 1 failures." >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "Input sequences: $failureseqs" >> $log
	echo "Method: CDHIT (step 2, de novo OTU picking)" >> $log
	echo "Percent similarity: $similarity" >> $log
	echo "	Percent similarity: $similarity
	"

	`pick_otus.py -i $otupickdir/blast_step1_reference/step1_failures.fasta -o $otupickdir/cdhit_step2_denovo -m cdhit -M 8000 -s $similarity`

	sed -i "s/^/cdhit.denovo.otu./" $otupickdir/cdhit_step2_denovo/step1_failures_otus.txt

	`merge_otu_maps.py -i $presufdir/$seqname\_otus.txt,$otupickdir/cdhit_step2_denovo/step1_failures_otus.txt -o $otupickdir/cdhit_step2_denovo/merged_step2_otus.txt`

	`pick_rep_set.py -i $otupickdir/cdhit_step2_denovo/merged_step2_otus.txt -f $seqs -o $otupickdir/cdhit_step2_denovo/step2_rep_set.fasta`

	denovolines=`cat $otupickdir/cdhit_step2_denovo/step2_rep_set.fasta | wc -l`
	denovoseqs=$(($denovolines/2))
	echo "	$denovoseqs additional OTUs clustered de novo.
	"

	if [[ ! -f $otupickdir/final_otu_map.txt ]]; then

	cat $otupickdir/blast_step1_reference/merged_step1_otus.txt $otupickdir/cdhit_step2_denovo/merged_step2_otus.txt > $otupickdir/final_otu_map.txt

	fi

	if [[ ! -f $otupickdir/final_rep_set.fna ]]; then

	cat $otupickdir/blast_step1_reference/step1_rep_set.fasta $otupickdir/cdhit_step2_denovo/step2_rep_set.fasta > $otupickdir/final_rep_set.fna
 
	fi

res13=$(date +%s.%N)
dt=$(echo "$res13 - $res12" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

denovo_runtime=`printf "CDHIT OTU picking runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`
echo "	$denovo_runtime
"
echo "$denovo_runtime

	" >> $log

	else
	echo "	CDHIT OTU picking already completed (step 2 OTUs, $similarity).
	"

## Custom openref fi 3 - denovo
	fi

	else
	echo "	No sequences to pass to de novo step.
	"
	if [[ ! -f $otupickdir/final_otu_map.txt ]]; then

	cat $otupickdir/blast_step1_reference/merged_step1_otus.txt > $otupickdir/final_otu_map.txt

	fi

	if [[ ! -f $otupickdir/final_rep_set.fna ]]; then

	cat $otupickdir/blast_step1_reference/step1_rep_set.fasta > $otupickdir/final_rep_set.fna
 
	fi

## Custom openref fi 2 - if denovo ran or not
	fi

## Custom openref fi 1 - all steps
fi

## Assign taxonomy (one or all tax assigners)

## BLAST

if [[ $taxassigner == "blast" || $taxassigner == "ALL" ]]; then
taxmethod=BLAST
taxdir=$outdir/$otupickdir/blast_taxonomy_assignment

	if [[ ! -f $taxdir/final_rep_set_tax_assignments.txt ]]; then
res24=$(date +%s.%N)
	echo "	Assigning taxonomy.
	Method: $taxmethod on $taxassignment_threads cores.
	"
	echo "Assigning taxonomy ($taxmethod):" >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "
	parallel_assign_taxonomy_blast.py -i $outdir/$otupickdir/final_rep_set.fna -o $taxdir -r $refs -t $tax -O $taxassignment_threads
	" >> $log
	`parallel_assign_taxonomy_blast.py -i $outdir/$otupickdir/final_rep_set.fna -o $taxdir -r $refs -t $tax -O $taxassignment_threads`
	wait

res25=$(date +%s.%N)
dt=$(echo "$res25 - $res24" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

tax_runtime=`printf "$taxmethod taxonomy assignment runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`	
echo "$tax_runtime

	" >> $log
	else
	echo "	$taxmethod taxonomy assignments detected.
	"
	fi

## Build OTU tables

	if [[ ! -d $otupickdir/OTU_tables_blast_tax ]]; then
		mkdir -p $otupickdir/OTU_tables_blast_tax
	fi
	otutable_dir=$otupickdir/OTU_tables_blast_tax

## Make initial otu table (needs hdf5 conversion)

	if [[ ! -f $otutable_dir/raw_otu_table.biom ]]; then	
	echo "	Building OTU tables with $taxmethod assignments.
	"
	echo "Making initial OTU table:" >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "
	make_otu_table.py -i $outdir/$otupickdir/final_otu_map.txt -t $taxdir/final_rep_set_tax_assignments.txt -o $otutable_dir/initial_otu_table.biom
	" >> $log
	`make_otu_table.py -i $outdir/$otupickdir/final_otu_map.txt -t $taxdir/final_rep_set_tax_assignments.txt -o $otutable_dir/initial_otu_table.biom`

	fi

## Convert initial table to raw table (hdf5)

	if [[ ! -f $otutable_dir/raw_otu_table.biom ]]; then
	echo "	Making raw hdf5 OTU table.
	"
	echo "Making raw hdf5 OTU table:" >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "
	biom convert -i $otutable_dir/initial_otu_table.biom -o $otutable_dir/raw_otu_table.biom --table-type=\"OTU table\" --to-hdf5
	" >> $log
	`biom convert -i $otutable_dir/initial_otu_table.biom -o $otutable_dir/raw_otu_table.biom --table-type="OTU table" --to-hdf5`
	wait
	rm $otutable_dir/initial_otu_table.biom
	else
	echo "	Raw OTU table detected.
	"
	raw_or_taxfiltered_table=$otutable_dir/raw_otu_table.biom
	fi

## Filter non-target taxa (ITS and 16S mode only)

	if [[ $mode == "16S" ]]; then
		if [[ ! -f $otutable_dir/raw_otu_table_bacteria_only.biom ]]; then
		echo "	Filtering away non-prokaryotic sequences.
		"
		`filter_taxa_from_otu_table.py -i $otutable_dir/raw_otu_table.biom -o $otutable_dir/raw_otu_table_bacteria_only.biom -p k__Bacteria,k__Archaea` >/dev/null 2>&1 || true
		fi
		if [[ -f $otutable_dir/raw_otu_table_bacteria_only.biom ]]; then
		raw_or_taxfiltered_table=$otutable_dir/raw_otu_table_bacteria_only.biom
		fi
	fi

	if [[ $mode == "ITS" ]]; then
		if [[ ! -f $otutable_dir/raw_otu_table_fungi_only.biom ]]; then
		echo "	Filtering away non-fungal sequences.
		"
		`filter_taxa_from_otu_table.py -i $otutable_dir/raw_otu_table.biom -o $otutable_dir/raw_otu_table_fungi_only.biom -p k__Fungi` >/dev/null 2>&1 || true
		fi
		if [[ -f $otutable_dir/raw_otu_table_fungi_only.biom ]]; then
		raw_or_taxfiltered_table=$otutable_dir/raw_otu_table_fungi_only.biom
		fi
	fi

## Filter low count samples

	if [[ ! -f $otutable_dir/min100_table.biom ]]; then
	echo "	Filtering away low count samples (<100 reads).
	"
	`filter_samples_from_otu_table.py -i $raw_or_taxfiltered_table -o $otutable_dir/min100_table.biom -n 100`
	fi

## Filter singletons and unshared OTUs from each sample

if [[ ! -f $otutable_dir/n2_table_hdf5.biom ]] && [[ ! -f $otutable_dir/n2_table_CSS.biom ]] && [[ ! -f $otutable_dir/mc2_table_hdf5.biom ]] && [[ ! -f $otutable_dir/mc2_table_CSS.biom ]] && [[ ! -f $otutable_dir/005_table_hdf5.biom ]] && [[ ! -f $otutable_dir/005_table_CSS.biom ]] && [[ ! -f $otutable_dir/03_table_hdf5.biom ]] && [[ ! -f $otutable_dir/03_table_CSS.biom ]]; then

	if [[ ! -f $otutable_dir/n2_table_hdf5.biom ]]; then
	## filter singletons by sample and normalize
	filter_observations_by_sample.py -i $otutable_dir/min100_table.biom -o $otutable_dir/n2_table0.biom -n 1
	filter_otus_from_otu_table.py -i $otutable_dir/n2_table0.biom -o $otutable_dir/n2_table.biom -n 1 -s 2
	biom convert -i $otutable_dir/n2_table.biom -o $otutable_dir/n2_table_hdf5.biom --table-type="OTU table" --to-hdf5
	fi

	if [[ ! -f $otutable_dir/n2_table_CSS.biom ]]; then
	normalize_table.py -i $otutable_dir/n2_table_hdf5.biom -o $otutable_dir/n2_table_CSS.biom -a CSS >/dev/null 2>&1 || true
	fi

	## filter singletons by table and normalize
	if [[ ! -f $otutable_dir/mc2_table_hdf5.biom ]]; then
	filter_otus_from_otu_table.py -i $otutable_dir/min100_table.biom -o $otutable_dir/mc2_table_hdf5.biom -n 2 -s 2
	fi

	if [[ ! -f $otutable_dir/mc2_table_CSS.biom ]]; then
	normalize_table.py -i $otutable_dir/mc2_table_hdf5.biom -o $otutable_dir/mc2_table_CSS.biom -a CSS >/dev/null 2>&1 || true
	fi

	## filter table by 0.005 percent and normalize
	if [[ ! -f $otutable_dir/005_table_hdf5.biom ]]; then
	filter_otus_from_otu_table.py -i $otutable_dir/min100_table.biom -o $otutable_dir/005_table_hdf5.biom --min_count_fraction 0.00005 -s 2
	fi

	if [[ ! -f $otutable_dir/005_table_CSS.biom ]]; then
	normalize_table.py -i $otutable_dir/005_table_hdf5.biom -o $otutable_dir/005_table_CSS.biom -a CSS >/dev/null 2>&1 || true
	fi

	## filter at 0.3% by sample and normalize
	if [[ ! -f $otutable_dir/03_table_hdf5.biom ]]; then
	filter_observations_by_sample.py -i $otutable_dir/min100_table.biom -o $otutable_dir/03_table0.biom -f -n 0.003
	filter_otus_from_otu_table.py -i $otutable_dir/03_table0.biom -o $otutable_dir/03_table.biom -n 1 -s 2
	biom convert -i $otutable_dir/03_table.biom -o $otutable_dir/03_table_hdf5.biom --table-type="OTU table" --to-hdf5
	fi

	if [[ ! -f $otutable_dir/03_table_CSS.biom ]]; then
	normalize_table.py -i $otutable_dir/03_table_hdf5.biom -o $otutable_dir/03_table_CSS.biom -a CSS >/dev/null 2>&1 || true
	fi

	rm $otutable_dir/03_table0.biom >/dev/null 2>&1 || true
	rm $otutable_dir/03_table.biom >/dev/null 2>&1 || true
	rm $otutable_dir/n2_table0.biom >/dev/null 2>&1 || true
	rm $otutable_dir/n2_table.biom >/dev/null 2>&1 || true

## Summarize raw otu tables

	biom-summarize_folder.sh $otutable_dir >/dev/null
	written_seqs=`grep "Total count:" $otutable_dir/n2_table_hdf5.summary | cut -d" " -f3`
	input_seqs=`grep "Total number seqs written" split_libraries/split_library_log.txt | cut -f2`
	echo "	$written_seqs out of $input_seqs input sequences written.
	"

## Print filtered OTU table summary header to screen and log file

	echo "	OTU picking method: $otumethod ($similarity)
	Tax assignment method: $taxmethod
	Singleton-filtered OTU table summary header:
	"
	head -14 $otutable_dir/n2_table_hdf5.summary | sed 's/^/\t\t/'
	echo "OTU picking method:
Tax assignment method: $taxmethod
Singleton-filtered OTU table summary header:
	" >> $log
	head -14 $otutable_dir/n2_table_hdf5.summary | sed 's/^/\t\t/' >> $log

	else
	echo "	Filtered tables detected.
	"
fi
fi

#####

## RDP

if [[ $taxassigner == "rdp" || $taxassigner == "ALL" ]]; then
taxmethod=RDP
taxdir=$outdir/$otupickdir/rdp_taxonomy_assignment

	## Adjust threads since RDP seems to choke with too many threads (> 12)
	if [[ $taxassignment_threads -gt 12 ]]; then
		rdptaxassignment_threads=12
	else
		rdptaxassignment_threads=$taxassignment_threads
	fi

	if [[ ! -f $taxdir/final_rep_set_tax_assignments.txt ]]; then
res24=$(date +%s.%N)
	echo "	Assigning taxonomy.
	Method: $taxmethod on $rdptaxassignment_threads cores.
	"
	echo "Assigning taxonomy ($taxmethod):" >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "
	parallel_assign_taxonomy_rdp.py -i $outdir/$otupickdir/final_rep_set.fna -o $taxdir -r $refs -t $tax -O $rdptaxassignment_threads -c 0.5 --rdp_max_memory 6000
	" >> $log
	`parallel_assign_taxonomy_rdp.py -i $outdir/$otupickdir/final_rep_set.fna -o $taxdir -r $refs -t $tax -O $rdptaxassignment_threads -c 0.5 --rdp_max_memory 6000`
	wait

res25=$(date +%s.%N)
dt=$(echo "$res25 - $res24" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

tax_runtime=`printf "$taxmethod taxonomy assignment runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`	
echo "$tax_runtime

	" >> $log


	else
	echo "	$taxmethod taxonomy assignments detected.
	"
	fi

## Build OTU tables

	if [[ ! -d $otupickdir/OTU_tables_rdp_tax ]]; then
		mkdir -p $otupickdir/OTU_tables_rdp_tax
	fi
	otutable_dir=$otupickdir/OTU_tables_rdp_tax

## Make initial otu table (needs hdf5 conversion)

	if [[ ! -f $otutable_dir/raw_otu_table.biom ]]; then	
	echo "	Building OTU tables with $taxmethod assignments.
	"
	echo "Making initial OTU table:" >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "
	make_otu_table.py -i $outdir/$otupickdir/final_otu_map.txt -t $taxdir/final_rep_set_tax_assignments.txt -o $otutable_dir/initial_otu_table.biom
	" >> $log
	`make_otu_table.py -i $outdir/$otupickdir/final_otu_map.txt -t $taxdir/final_rep_set_tax_assignments.txt -o $otutable_dir/initial_otu_table.biom`

	fi

## Convert initial table to raw table (hdf5)

	if [[ ! -f $otutable_dir/raw_otu_table.biom ]]; then
	echo "	Making raw hdf5 OTU table.
	"
	echo "Making raw hdf5 OTU table:" >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "
	biom convert -i $otutable_dir/initial_otu_table.biom -o $otutable_dir/raw_otu_table.biom --table-type=\"OTU table\" --to-hdf5
	" >> $log
	`biom convert -i $otutable_dir/initial_otu_table.biom -o $otutable_dir/raw_otu_table.biom --table-type="OTU table" --to-hdf5`
	wait
	rm $otutable_dir/initial_otu_table.biom
	else
	echo "	Raw OTU table detected.
	"
	raw_or_taxfiltered_table=$otutable_dir/raw_otu_table.biom
	fi

## Filter non-target taxa (ITS and 16S mode only)

	if [[ $mode == "16S" ]]; then
		if [[ ! -f $otutable_dir/raw_otu_table_bacteria_only.biom ]]; then
		echo "	Filtering away non-prokaryotic sequences.
		"
		`filter_taxa_from_otu_table.py -i $otutable_dir/raw_otu_table.biom -o $otutable_dir/raw_otu_table_bacteria_only.biom -p k__Bacteria,k__Archaea` >/dev/null 2>&1 || true
		fi
		if [[ -f $otutable_dir/raw_otu_table_bacteria_only.biom ]]; then
		raw_or_taxfiltered_table=$otutable_dir/raw_otu_table_bacteria_only.biom
		fi
	fi

	if [[ $mode == "ITS" ]]; then
		if [[ ! -f $otutable_dir/raw_otu_table_fungi_only.biom ]]; then
		echo "	Filtering away non-fungal sequences.
		"
		`filter_taxa_from_otu_table.py -i $otutable_dir/raw_otu_table.biom -o $otutable_dir/raw_otu_table_fungi_only.biom -p k__Fungi` >/dev/null 2>&1 || true
		fi
		if [[ -f $otutable_dir/raw_otu_table_fungi_only.biom ]]; then
		raw_or_taxfiltered_table=$otutable_dir/raw_otu_table_fungi_only.biom
		fi
	fi

## Filter low count samples

	if [[ ! -f $otutable_dir/min100_table.biom ]]; then
	echo "	Filtering away low count samples (<100 reads).
	"
	`filter_samples_from_otu_table.py -i $raw_or_taxfiltered_table -o $otutable_dir/min100_table.biom -n 100`
	fi

## Filter singletons and unshared OTUs from each sample

if [[ ! -f $otutable_dir/n2_table_hdf5.biom ]] && [[ ! -f $otutable_dir/n2_table_CSS.biom ]] && [[ ! -f $otutable_dir/mc2_table_hdf5.biom ]] && [[ ! -f $otutable_dir/mc2_table_CSS.biom ]] && [[ ! -f $otutable_dir/005_table_hdf5.biom ]] && [[ ! -f $otutable_dir/005_table_CSS.biom ]] && [[ ! -f $otutable_dir/03_table_hdf5.biom ]] && [[ ! -f $otutable_dir/03_table_CSS.biom ]]; then

	if [[ ! -f $otutable_dir/n2_table_hdf5.biom ]]; then
	## filter singletons by sample and normalize
	filter_observations_by_sample.py -i $otutable_dir/min100_table.biom -o $otutable_dir/n2_table0.biom -n 1
	filter_otus_from_otu_table.py -i $otutable_dir/n2_table0.biom -o $otutable_dir/n2_table.biom -n 1 -s 2
	biom convert -i $otutable_dir/n2_table.biom -o $otutable_dir/n2_table_hdf5.biom --table-type="OTU table" --to-hdf5
	fi

	if [[ ! -f $otutable_dir/n2_table_CSS.biom ]]; then
	normalize_table.py -i $otutable_dir/n2_table_hdf5.biom -o $otutable_dir/n2_table_CSS.biom -a CSS >/dev/null 2>&1 || true
	fi

	## filter singletons by table and normalize
	if [[ ! -f $otutable_dir/mc2_table_hdf5.biom ]]; then
	filter_otus_from_otu_table.py -i $otutable_dir/min100_table.biom -o $otutable_dir/mc2_table_hdf5.biom -n 2 -s 2
	fi

	if [[ ! -f $otutable_dir/mc2_table_CSS.biom ]]; then
	normalize_table.py -i $otutable_dir/mc2_table_hdf5.biom -o $otutable_dir/mc2_table_CSS.biom -a CSS >/dev/null 2>&1 || true
	fi

	## filter table by 0.005 percent and normalize
	if [[ ! -f $otutable_dir/005_table_hdf5.biom ]]; then
	filter_otus_from_otu_table.py -i $otutable_dir/min100_table.biom -o $otutable_dir/005_table_hdf5.biom --min_count_fraction 0.00005 -s 2
	fi

	if [[ ! -f $otutable_dir/005_table_CSS.biom ]]; then
	normalize_table.py -i $otutable_dir/005_table_hdf5.biom -o $otutable_dir/005_table_CSS.biom -a CSS >/dev/null 2>&1 || true
	fi

	## filter at 0.3% by sample and normalize
	if [[ ! -f $otutable_dir/03_table_hdf5.biom ]]; then
	filter_observations_by_sample.py -i $otutable_dir/min100_table.biom -o $otutable_dir/03_table0.biom -f -n 0.003
	filter_otus_from_otu_table.py -i $otutable_dir/03_table0.biom -o $otutable_dir/03_table.biom -n 1 -s 2
	biom convert -i $otutable_dir/03_table.biom -o $otutable_dir/03_table_hdf5.biom --table-type="OTU table" --to-hdf5
	fi

	if [[ ! -f $otutable_dir/03_table_CSS.biom ]]; then
	normalize_table.py -i $otutable_dir/03_table_hdf5.biom -o $otutable_dir/03_table_CSS.biom -a CSS >/dev/null 2>&1 || true
	fi

	rm $otutable_dir/03_table0.biom >/dev/null 2>&1 || true
	rm $otutable_dir/03_table.biom >/dev/null 2>&1 || true
	rm $otutable_dir/n2_table0.biom >/dev/null 2>&1 || true
	rm $otutable_dir/n2_table.biom >/dev/null 2>&1 || true

## Summarize raw otu tables

	biom-summarize_folder.sh $otutable_dir >/dev/null
	written_seqs=`grep "Total count:" $otutable_dir/n2_table_hdf5.summary | cut -d" " -f3`
	input_seqs=`grep "Total number seqs written" split_libraries/split_library_log.txt | cut -f2`
	echo "	$written_seqs out of $input_seqs input sequences written.
	"

## Print filtered OTU table summary header to screen and log file

	echo "	OTU picking method: $otumethod ($similarity)
	Tax assignment method: $taxmethod
	Singleton-filtered OTU table summary header:
	"
	head -14 $otutable_dir/n2_table_hdf5.summary | sed 's/^/\t\t/'
	echo "OTU picking method:
Tax assignment method: $taxmethod
Singleton-filtered OTU table summary header:
	" >> $log
	head -14 $otutable_dir/n2_table_hdf5.summary | sed 's/^/\t\t/' >> $log

	else
	echo "	Filtered tables detected.
	"
fi
fi

#####

## UCLUST

if [[ $taxassigner == "uclust" || $taxassigner == "ALL" ]]; then
taxmethod=UCLUST
taxdir=$outdir/$otupickdir/uclust_taxonomy_assignment

	if [[ ! -f $taxdir/final_rep_set_tax_assignments.txt ]]; then
res24=$(date +%s.%N)
	echo "	Assigning taxonomy.
	Method: $taxmethod on $taxassignment_threads cores.
	"
	echo "Assigning taxonomy ($taxmethod):" >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "
	parallel_assign_taxonomy_uclust.py -i $outdir/$otupickdir/final_rep_set.fna -o $taxdir -r $refs -t $tax -O $taxassignment_threads
	" >> $log
	`parallel_assign_taxonomy_uclust.py -i $outdir/$otupickdir/final_rep_set.fna -o $taxdir -r $refs -t $tax -O $taxassignment_threads`
	wait

res25=$(date +%s.%N)
dt=$(echo "$res25 - $res24" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

tax_runtime=`printf "$taxmethod taxonomy assignment runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`	
echo "$tax_runtime

	" >> $log


	else
	echo "	$taxmethod taxonomy assignments detected.
	"
	fi

## Build OTU tables

	if [[ ! -d $otupickdir/OTU_tables_uclust_tax ]]; then
		mkdir -p $otupickdir/OTU_tables_uclust_tax
	fi
	otutable_dir=$otupickdir/OTU_tables_uclust_tax

## Make initial otu table (needs hdf5 conversion)

	if [[ ! -f $otutable_dir/raw_otu_table.biom ]]; then	
	echo "	Building OTU tables with $taxmethod assignments.
	"
	echo "Making initial OTU table:" >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "
	make_otu_table.py -i $outdir/$otupickdir/final_otu_map.txt -t $taxdir/final_rep_set_tax_assignments.txt -o $otutable_dir/initial_otu_table.biom
	" >> $log
	`make_otu_table.py -i $outdir/$otupickdir/final_otu_map.txt -t $taxdir/final_rep_set_tax_assignments.txt -o $otutable_dir/initial_otu_table.biom`

	fi

## Convert initial table to raw table (hdf5)

	if [[ ! -f $otutable_dir/raw_otu_table.biom ]]; then
	echo "	Making raw hdf5 OTU table.
	"
	echo "Making raw hdf5 OTU table:" >> $log
	date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "
	biom convert -i $otutable_dir/initial_otu_table.biom -o $otutable_dir/raw_otu_table.biom --table-type=\"OTU table\" --to-hdf5
	" >> $log
	`biom convert -i $otutable_dir/initial_otu_table.biom -o $otutable_dir/raw_otu_table.biom --table-type="OTU table" --to-hdf5`
	wait
	rm $otutable_dir/initial_otu_table.biom
	else
	echo "	Raw OTU table detected.
	"
	raw_or_taxfiltered_table=$otutable_dir/raw_otu_table.biom
	fi

## Filter non-target taxa (ITS and 16S mode only)

	if [[ $mode == "16S" ]]; then
		if [[ ! -f $otutable_dir/raw_otu_table_bacteria_only.biom ]]; then
		echo "	Filtering away non-prokaryotic sequences.
		"
		`filter_taxa_from_otu_table.py -i $otutable_dir/raw_otu_table.biom -o $otutable_dir/raw_otu_table_bacteria_only.biom -p k__Bacteria,k__Archaea` >/dev/null 2>&1 || true
		fi
		if [[ -f $otutable_dir/raw_otu_table_bacteria_only.biom ]]; then
		raw_or_taxfiltered_table=$otutable_dir/raw_otu_table_bacteria_only.biom
		fi
	fi

	if [[ $mode == "ITS" ]]; then
		if [[ ! -f $otutable_dir/raw_otu_table_fungi_only.biom ]]; then
		echo "	Filtering away non-fungal sequences.
		"
		`filter_taxa_from_otu_table.py -i $otutable_dir/raw_otu_table.biom -o $otutable_dir/raw_otu_table_fungi_only.biom -p k__Fungi` >/dev/null 2>&1 || true
		fi
		if [[ -f $otutable_dir/raw_otu_table_fungi_only.biom ]]; then
		raw_or_taxfiltered_table=$otutable_dir/raw_otu_table_fungi_only.biom
		fi
	fi

## Filter low count samples

	if [[ ! -f $otutable_dir/min100_table.biom ]]; then
	echo "	Filtering away low count samples (<100 reads).
	"
	`filter_samples_from_otu_table.py -i $raw_or_taxfiltered_table -o $otutable_dir/min100_table.biom -n 100`
	fi

## Filter singletons and unshared OTUs from each sample

if [[ ! -f $otutable_dir/n2_table_hdf5.biom ]] && [[ ! -f $otutable_dir/n2_table_CSS.biom ]] && [[ ! -f $otutable_dir/mc2_table_hdf5.biom ]] && [[ ! -f $otutable_dir/mc2_table_CSS.biom ]] && [[ ! -f $otutable_dir/005_table_hdf5.biom ]] && [[ ! -f $otutable_dir/005_table_CSS.biom ]] && [[ ! -f $otutable_dir/03_table_hdf5.biom ]] && [[ ! -f $otutable_dir/03_table_CSS.biom ]]; then

	if [[ ! -f $otutable_dir/n2_table_hdf5.biom ]]; then
	## filter singletons by sample and normalize
	filter_observations_by_sample.py -i $otutable_dir/min100_table.biom -o $otutable_dir/n2_table0.biom -n 1
	filter_otus_from_otu_table.py -i $otutable_dir/n2_table0.biom -o $otutable_dir/n2_table.biom -n 1 -s 2
	biom convert -i $otutable_dir/n2_table.biom -o $otutable_dir/n2_table_hdf5.biom --table-type="OTU table" --to-hdf5
	fi

	if [[ ! -f $otutable_dir/n2_table_CSS.biom ]]; then
	normalize_table.py -i $otutable_dir/n2_table_hdf5.biom -o $otutable_dir/n2_table_CSS.biom -a CSS >/dev/null 2>&1 || true
	fi

	## filter singletons by table and normalize
	if [[ ! -f $otutable_dir/mc2_table_hdf5.biom ]]; then
	filter_otus_from_otu_table.py -i $otutable_dir/min100_table.biom -o $otutable_dir/mc2_table_hdf5.biom -n 2 -s 2
	fi

	if [[ ! -f $otutable_dir/mc2_table_CSS.biom ]]; then
	normalize_table.py -i $otutable_dir/mc2_table_hdf5.biom -o $otutable_dir/mc2_table_CSS.biom -a CSS >/dev/null 2>&1 || true
	fi

	## filter table by 0.005 percent and normalize
	if [[ ! -f $otutable_dir/005_table_hdf5.biom ]]; then
	filter_otus_from_otu_table.py -i $otutable_dir/min100_table.biom -o $otutable_dir/005_table_hdf5.biom --min_count_fraction 0.00005 -s 2
	fi

	if [[ ! -f $otutable_dir/005_table_CSS.biom ]]; then
	normalize_table.py -i $otutable_dir/005_table_hdf5.biom -o $otutable_dir/005_table_CSS.biom -a CSS >/dev/null 2>&1 || true
	fi

	## filter at 0.3% by sample and normalize
	if [[ ! -f $otutable_dir/03_table_hdf5.biom ]]; then
	filter_observations_by_sample.py -i $otutable_dir/min100_table.biom -o $otutable_dir/03_table0.biom -f -n 0.003
	filter_otus_from_otu_table.py -i $otutable_dir/03_table0.biom -o $otutable_dir/03_table.biom -n 1 -s 2
	biom convert -i $otutable_dir/03_table.biom -o $otutable_dir/03_table_hdf5.biom --table-type="OTU table" --to-hdf5
	fi

	if [[ ! -f $otutable_dir/03_table_CSS.biom ]]; then
	normalize_table.py -i $otutable_dir/03_table_hdf5.biom -o $otutable_dir/03_table_CSS.biom -a CSS >/dev/null 2>&1 || true
	fi

	rm $otutable_dir/03_table0.biom >/dev/null 2>&1 || true
	rm $otutable_dir/03_table.biom >/dev/null 2>&1 || true
	rm $otutable_dir/n2_table0.biom >/dev/null 2>&1 || true
	rm $otutable_dir/n2_table.biom >/dev/null 2>&1 || true

## Summarize raw otu tables

	biom-summarize_folder.sh $otutable_dir >/dev/null
	written_seqs=`grep "Total count:" $otutable_dir/n2_table_hdf5.summary | cut -d" " -f3`
	input_seqs=`grep "Total number seqs written" split_libraries/split_library_log.txt | cut -f2`
	echo "	$written_seqs out of $input_seqs input sequences written.
	"

## Print filtered OTU table summary header to screen and log file

	echo "	OTU picking method: $otumethod ($similarity)
	Tax assignment method: $taxmethod
	Singleton-filtered OTU table summary header:
	"
	head -14 $otutable_dir/n2_table_hdf5.summary | sed 's/^/\t\t/'
	echo "OTU picking method:
Tax assignment method: $taxmethod
Singleton-filtered OTU table summary header:
	" >> $log
	head -14 $otutable_dir/n2_table_hdf5.summary | sed 's/^/\t\t/' >> $log

	else
	echo "	Filtered tables detected.
	"
fi
fi

#####

done


res26a=$(date +%s.%N)
dt=$(echo "$res26a - $res9a" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

runtime=`printf "Total runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`

echo "	Sequential OTU picking steps completed (Custom openref).

	$runtime
"
echo "---

Sequential OTU picking completed (Custom openref)." >> $log
date "+%a %b %I:%M %p %Z %Y" >> $log
echo "
$runtime 
" >> $log
fi


#######################################
## Custom openref OTU Steps END HERE ##
#######################################

## clean up

	if [[ -d $outdir/jobs ]]; then
	rm -r $outdir/jobs
	fi
	if [[ -d $tempdir ]]; then
	rm -r $tempdir
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

echo "	All workflow steps completed.  Hooray!

	$runtime
"
echo "---

All workflow steps completed.  Hooray!" >> $log
date "+%a %b %I:%M %p %Z %Y" >> $log
echo "
$runtime 
" >> $log

