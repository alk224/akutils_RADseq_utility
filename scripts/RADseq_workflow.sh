#!/usr/bin/env bash
#
#  Stacks workflow - process raw RADseq data all the way through Stacks pipline
#
#  Version 1.1.0 (June 16, 2015)
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
## Trap function on exit.
function finish {
if [[ -f $mapfile ]]; then
	rm $mapfile
fi
if [[ -f $stderr ]]; then
	rm $stderr
fi
}
trap finish EXIT

set -e
scriptdir="$( cd "$( dirname "$0" )" && pwd )"
configutilitypath=`command -v akutils_config_utility.sh`
akutilsdir="$( dirname $configutilitypath )"
randcode=`cat /dev/urandom |tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1` 2>/dev/null

## Check whether user had supplied -h or --help. If yes display help 
	if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
	less $scriptdir/docs/RADseq_workflow.help
	exit 0
	fi 

## If different than 5 or 6 arguments supplied, display usage 
	if [[  "$#" -le 4 ]] || [[  "$#" -ge 7 ]]; then 
		echo "
Usage (order is important):
RADseq_workflow.sh <databasename> <sample mapping file> <reference> <index_fastq> <read1_fastq> <read2_fastq>

	<databasename> should NOT include \"_radtags\" suffix

	<read2_fastq> is optional

	<reference> is absolute path to bowtie2-indexed reference or 
	specify \"denovo\" for denovo analysis

Mapping file must be in the following format:
Sample1	AAAATTTTCCCCGGGG
Sample2	ATATTATACGCGGCGC

Where sample names and index sequences are separated by a tab character.
		"
		exit 1
	fi

## Check for presence of adapters file in local directory
	adaptercount=`ls adapter* 2>/dev/null | wc -w`
	if [[ $adaptercount == "0" ]]; then
	echo "
No adapter file found in local directory.  Please copy a file containing
your adapter sequences to the local directory and try again.  The file
must contain reverse complements to the adapter sequences as they will
be read from the opposing strand.  Exiting.

Example file (fasta format):

>P1
CATAGCATCGCTTACTGGCTCTCCACATAGG
>P2
CTGACTTGGGTAATCGCAGTAGTGAGCGTTGAC
	"
	exit 1
	elif [[ $adaptercount -ge "2" ]]; then
	echo "
There are at least two files containing adapter sequences in your local
directory.  Remove or rename one of them and try again.  Exiting.
	"
	exit 1
	else
	adapters=`ls adapter*`
	fi

## Define inputs and working directory
	dbname=($1)
	dbunc=(${dbname}_uncorrected_radtags)
	dbcor=(${dbname}_corrected_radtags)
	metadatafile=($2)
	ref=($3)
	index=($4)
	read1=($5)
	read2=($6)
	issuedcommand="RADseq_workflow.sh $1 $2 $3 $4 $5 $6"

## Define sequencing mode based on number of supplied inputs
	if [[ "$#" == 5 ]]; then
	mode=(single)
	mode1=(SingleEnd)
	elif [[ "$#" == 6 ]]; then
	mode=(paired)
	mode1=(PairedEnd)
	fi

## Determine analysis mode based user input
	if [[  "$ref" == "denovo" ]]; then
	analysis=(denovo)
	else
	analysis=(reference)
	fi

## Define working directory and log file
	date0=`date +%Y%m%d_%I%M%p`
	date100=`date -R`
	workdir=$(pwd)
	outdir=($workdir/RADseq_workflow_${analysis})
	outdirunc=($outdir/uncorrected_output)
	outdircor=($outdir/corrected_output)
	if [[ -d $outdir ]]; then
	echo "
Output directory already exists.  Attempting to use previously generated
ouputs.
	"
	log=`ls $outdir/log_RADseq_workflow_* | head -1`
	echo "
********************************************************************************
********************************************************************************

RADseq_workflow.sh was rerun.
$date100

Command as issued:
	$issuedcommand

********************************************************************************
********************************************************************************
	" >> $log
	else
	mkdir -p $outdir
	log=($outdir/log_RADseq_workflow_${date0})
	touch $log
	echo "
********************************************************************************
********************************************************************************

RADseq_workflow.sh was run.
$date100

Command as issued:
	$issuedcommand

********************************************************************************
********************************************************************************
	" >> $log
	fi

## Read in variables from config file
	local_config_count=(`ls akutils*.config 2>/dev/null | wc -w`)
	if [[ $local_config_count -ge 1 ]]; then
	config=`ls akutils*.config`
	echo "Using local akutils config file.
$config
	"
	echo "
Referencing local akutils config file.
$config
	" >> $log
	else
		global_config_count=(`ls $akutilsdir/akutils_resources/akutils*.config 2>/dev/null | wc -w`)
		if [[ $global_config_count -ge 1 ]]; then
		config=`ls $akutilsdir/akutils_resources/akutils*.config`
		echo "Using global akutils config file.
$config
		"
		echo "
Referencing global akutils config file.
$config
		" >> $log
		fi
	fi

	cores=(`grep "CPU_cores" $config | grep -v "#" | cut -f 2`)
	threads=$(expr $cores + 1)
	qual=(`grep "Split_libraries_qvalue" $config | grep -v "#" | cut -f 2`)
	multx_errors=(`grep "Multx_errors" $config | grep -v "#" | cut -f 2`)
	slminpercent=(`grep "Split_libraries_minpercent" $config | grep -v "#" | cut -f 2`)

res0=$(date +%s.%N)
echo "RADseq workflow beginning.
Sequencing mode detected: $mode1
Analysis type: $analysis
CPU cores: $cores
"

## Parse metadata file contents
SampleIDcol=$(awk '{for(i=1; i<=NF; i++) {if($i == "SampleID") printf(i) } exit 0}' $metadatafile)
Indexcol=$(awk '{for(i=1; i<=NF; i++) {if($i == "IndexSequence") printf(i) } exit 0}' $metadatafile)
Repcol=$(awk '{for(i=1; i<=NF; i++) {if($i == "Rep") printf(i) } exit 0}' $metadatafile)
Popcol=$(awk '{for(i=1; i<=NF; i++) {if($i == "PopulationID") printf(i) } exit 0}' $metadatafile)

## Extract indexing data from metadata file
grep -v "#" $metadatafile | cut -f${SampleIDcol} > ${randcode}_sampleids.temp
grep -v "#" $metadatafile | cut -f${Indexcol} > ${randcode}_indexes.temp
paste ${randcode}_sampleids.temp ${randcode}_indexes.temp > ${randcode}_map.temp
wait
rm ${randcode}_sampleids.temp ${randcode}_indexes.temp 2>/dev/null || true

mapfile="${randcode}_map.temp"
	if [[ ! -f $mapfile ]]; then
		echo "Unexpected problem.  Demultiplexing map not generated.
Exiting.
		"
	exit 1
	fi

exit 0


## Demultiplex quality-filtered sequencing data with fastq-multx
if [[ -d $outdir/demultiplexed_data ]]; then
echo "Demultiplexing previously completed.  Skipping step.
$outdir/demultiplexed_data
"
else
echo "Demultiplexing raw data with fastq-multx.
"
echo "Demultiplexing raw data with fastq-multx.
" >> $log
res2=$(date +%s.%N)
mkdir -p $outdir/demultiplexed_data
echo "Demultiplexing command:" >> $log
	if [[ "$mode" == "single" ]]; then
	echo "fastq-multx -m $multx_errors -B $mapfile $index $read1 -o $outdir/demultiplexed_data/index.%.fq -o $outdir/demultiplexed_data/%.read.fq &> $outdir/demultiplexed_data/log_fastq-multx.txt
	" >> $log
	fastq-multx -m $multx_errors -B $mapfile $index $read1 -o $outdir/demultiplexed_data/index.%.fq -o $outdir/demultiplexed_data/%.read.fq &> $outdir/demultiplexed_data/log_fastq-multx.txt
	elif [[ "$mode" == "paired" ]]; then
	echo "fastq-multx -m $multx_errors -B $mapfile $index $read1 $read2 -o $outdir/demultiplexed_data/index.%.fq -o $outdir/demultiplexed_data/%.read1.fq -o $outdir/demultiplexed_data/%.read2.fq &> $outdir/demultiplexed_data/log_fastq-multx.txt
	" >> $log
	fastq-multx -m $multx_errors -B $mapfile $index $read1 $read2 -o $outdir/demultiplexed_data/index.%.fq -o $outdir/demultiplexed_data/%.read1.fq -o $outdir/demultiplexed_data/%.read2.fq &> $outdir/demultiplexed_data/log_fastq-multx.txt
	fi
rm $outdir/demultiplexed_data/index.*
rm $outdir/demultiplexed_data/unmatched*

res3=$(date +%s.%N)
dt=$(echo "$res3 - $res2" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

runtime=`printf "Demutliplexing runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`
echo "$runtime
" >> $log
fi

## Quality filter sequencing data with fastq-mcf
if [[ -d $outdir/quality_filtered_data ]]; then
echo "Quality filtering previously performed.  Skipping step.
$outdir/quality_filtered_data
"
else
seqlength=$((`sed '2q;d' $read1 | egrep "\w+" | wc -m`-1))
length=$(echo "$slminpercent*$seqlength" | bc | cut -d. -f1)
echo "Quality filtering raw data with fastq-mcf.
Read lengths detected: $seqlength
Minimum quality threshold: $qual
Minimum length to retain: $length
"
echo "Quality filtering raw data with fastq-mcf.
Read lengths detected: $seqlength
Minimum quality threshold: $qual
Minimum length to retain: $length
" >> $log
res2=$(date +%s.%N)
mkdir -p $outdir/quality_filtered_data
	if [[ "$mode" == "single" ]]; then
	for line in `cat $mapfile | cut -f1`; do
		while [ $( pgrep -P $$ |wc -w ) -ge ${threads} ]; do
		sleep 1
		done
		echo "	fastq-mcf -q $qual -l $length -L $length -k 0 -t 0.001 $adapters $outdir/demultiplexed_data/$line.read.fq -o $outdir/quality_filtered_data/$line.read.mcf.fq" >> $log
		( fastq-mcf -q $qual -l $length -L $length -k 0 -t 0.001 $adapters $outdir/demultiplexed_data/$line.read.fq -o $outdir/quality_filtered_data/$line.read.mcf.fq > $outdir/quality_filtered_data/log_${line}_fastq-mcf.txt 2>&1 || true ) &
	done
	fi
	if [[ "$mode" == "paired" ]]; then
	for line in `cat $mapfile | cut -f1`; do
		while [ $( pgrep -P $$ |wc -w ) -ge ${threads} ]; do
		sleep 1
		done
		echo "	fastq-mcf -q $qual -l $length -L $length -k 0 -t 0.001 $adapters $outdir/demultiplexed_data/$line.read1.fq $outdir/demultiplexed_data/$line.read2.fq -o $outdir/quality_filtered_data/$line.read1.mcf.fq -o $outdir/quality_filtered_data/$line.read2.mcf.fq" >> $log
		( fastq-mcf -q $qual -l $length -L $length -k 0 -t 0.001 $adapters $outdir/demultiplexed_data/$line.read1.fq $outdir/demultiplexed_data/$line.read2.fq -o $outdir/quality_filtered_data/$line.read1.mcf.fq -o $outdir/quality_filtered_data/$line.read2.mcf.fq > $outdir/quality_filtered_data/log_${line}_fastq-mcf.txt 2>&1 || true ) &
	done
	fi
wait

res3=$(date +%s.%N)
dt=$(echo "$res3 - $res2" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

runtime=`printf "Quality filtering runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`
echo "$runtime
" >> $log
fi

## Align each sample to reference (reference-based analysis only)
if [[ "$analysis" == "reference" ]]; then
if [[ -d $outdir/bowtie2_alignments ]]; then
echo "Alignments previously performed.  Skipping step.
$outdir/bowtie2_alignments
"
else
echo "Aligning quality-filtered data to reference sequence(s).
Supplied reference: $ref
"
echo "Aligning quality-filtered data to reference sequence(s).
Supplied reference: $ref
" >> $log
res2=$(date +%s.%N)
mkdir -p $outdir/bowtie2_alignments
	if [[ "$mode" == "single" ]]; then
	for line in `cat $mapfile | cut -f1`; do
		while [ $( pgrep -P $$ |wc -w ) -ge ${threads} ]; do
		sleep 1
		done
		echo "	bowtie2-align --local -x $ref -U $outdir/quality_filtered_data/${line}.read.fq -S $outdir/bowtie2_alignments/${line}.sam" >> $log
		( bowtie2-align --local -x $ref -U $outdir/quality_filtered_data/${line}.read.mcf.fq -S $outdir/bowtie2_alignments/${line}.sam > $outdir/bowtie2_alignments/log_${line}_bowtie2.txt 2>&1 || true ) &
	done
	fi
	if [[ "$mode" == "paired" ]]; then
	for line in `cat $mapfile | cut -f1`; do
		while [ $( pgrep -P $$ |wc -w ) -ge ${threads} ]; do
		sleep 1
		done
		echo "	bowtie2-align --local -x $ref -1 $outdir/quality_filtered_data/${line}.read1.fq -1 $outdir/quality_filtered_data/${line}.read2.fq -S $outdir/bowtie2_alignments/${line}.sam" >> $log
		( bowtie2-align --local -x $ref -1 $outdir/quality_filtered_data/${line}.read1.fq -1 $outdir/quality_filtered_data/${line}.read2.fq -S $outdir/bowtie2_alignments/${line}.sam > $outdir/bowtie2_alignments/log_${line}_bowtie2.txt 2>&1 || true ) &
	done
	fi
wait

res3=$(date +%s.%N)
dt=$(echo "$res3 - $res2" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

runtime=`printf "Reference alignment runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`
echo "$runtime
" >> $log
fi
fi

###################################
## START OF UNCORRECTED ANALYSIS ##
###################################
echo "Start of uncorrected analysis steps.
"
echo "Start of uncorrected analysis steps.
" >> $log

## Run pstacks for reference-aligned samples
if [[ "$analysis" == "reference" ]]; then
if [[ -d $outdirunc/pstacks_output ]]; then
echo "Pstacks output directory present.  Skipping step.
$outdirunc/pstacks_output
"
else
echo "Extracting stacks from sam files with pstacks.
"
echo "Extracting stacks from sam files with pstacks.
" >> $log
mkdir -p $outdirunc/pstacks_output
res2=$(date +%s.%N)
#i=1
	for line in `cat $mapfile | cut -f1`; do
	echo "  pstacks -t sam -f $outdir/bowtie2_alignments/${line}.aligned.sam -p $cores -o $outdirunc/pstacks_output -i $line" >> $log
	pstacks -t sam -f $outdir/bowtie2_alignments/${line}.sam -p $cores -o $outdirunc/pstacks_output -i $line &> $outdirunc/pstacks_output/log_${line}_pstacks.txt
	#let "i+=1"
	done

res3=$(date +%s.%N)
dt=$(echo "$res3 - $res2" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

runtime=`printf "Pstacks runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`
echo "$runtime
" >> $log
fi
fi

## Run ustacks for denovo samples
if [[ "$analysis" == "denovo" ]]; then
if [[ -d $outdirunc/ustacks_output ]]; then
echo "Ustacks output directory present.  Skipping step.
$outdirunc/ustacks_output
"
else
echo "Assembling loci denovo with ustacks.
"
echo "Assembling loci denovo with ustacks.
" >> $log
mkdir -p $outdirunc/ustacks_output
res2=$(date +%s.%N)
#i=1
	for line in `cat $mapfile | cut -f1`; do
	echo "  ustacks -t fastq -f $outdir/quality_filtered_data/${line}.read.mcf.fq -p $cores -o $outdirunc/ustacks_output -i $line -m 2 -M 4 -N 6 -r -d" >> $log
	ustacks -t fastq -f $outdir/quality_filtered_data/${line}.read.mcf.fq -p $cores -o $outdirunc/ustacks_output -i $line -m 2 -M 4 -N 6 -r -d &> $outdirunc/ustacks_output/log_${line}_ustacks.txt
	#let "i+=1"
	done

res3=$(date +%s.%N)
dt=$(echo "$res3 - $res2" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

runtime=`printf "Ustacks runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`
echo "$runtime
" >> $log
fi
fi

## Run cstacks to catalog loci across samples
if [[ -d $outdirunc/cstacks_output ]]; then
echo "Cstacks output directory present.  Skipping step.
$outdirunc/cstacks_output
"
else
echo "Cataloging loci with cstacks.
"
echo "Cataloging loci with cstacks.
" >> $log
res2=$(date +%s.%N)
	mcfcount=`ls $outdirunc/ustacks_output/*mcf* 2>/dev/null | wc -l`
	if [[ $mcfcount -ge 1 ]]; then
	cd $outdirunc/ustacks_output
	rename 's/read.mcf.//' *mcf*
	cd $workdir
	fi

mkdir -p $outdirunc/cstacks_output
	samp=""
	if [[ "$analysis" == "reference" ]]; then
	for line in `cat $mapfile | cut -f1`; do
	samp+="-s $outdirunc/pstacks_output/$line "
	done
	echo "	cstacks -g -p $cores -b 1 -n 1 $samp -o $outdirunc/cstacks_output &> $outdirunc/cstacks_output/log_cstacks.txt" >> $log
	cstacks -g -p $cores -b 1 -n 1 $samp -o $outdirunc/cstacks_output &> $outdirunc/cstacks_output/log_cstacks.txt
	fi
	if [[ "$analysis" == "denovo" ]]; then
	for line in `cat $mapfile | cut -f1`; do
	samp+="-s $outdirunc/ustacks_output/$line "
	done
	echo "	cstacks -p $cores -b 1 -n 4 -m $samp -o $outdirunc/cstacks_output &> $outdirunc/cstacks_output/log_cstacks.txt" >> $log
	cstacks -p $cores -b 1 -n 4 -m $samp -o $outdirunc/cstacks_output &> $outdirunc/cstacks_output/log_cstacks.txt
	fi

res3=$(date +%s.%N)
dt=$(echo "$res3 - $res2" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

runtime=`printf "Cstacks runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`
echo "$runtime
" >> $log
fi

## Search individual stacks against population catalog
## Need variables to manage batch IDs and catalog names
if [[ -d $outdirunc/sstacks_output ]]; then
echo "Sstacks output directory present.  Skipping step.
$outdirunc/sstacks_output
"
else
echo "Searching cataloged loci for each sample with sstacks.
"
echo "Searching cataloged loci for each sample with sstacks.
" >> $log
res2=$(date +%s.%N)
mkdir -p $outdirunc/sstacks_output
	for line in `cat $mapfile | cut -f1`; do
	if [[ "$analysis" == "reference" ]]; then
	echo "	sstacks -b 1 -c $outdirunc/cstacks_output/batch_1 -s $outdirunc/pstacks_output/$line -p $cores -o $outdirunc/sstacks_output &> $outdirunc/sstacks_output/log_${line}_sstacks.txt" >> $log
	sstacks -b 1 -c $outdirunc/cstacks_output/batch_1 -s $outdirunc/pstacks_output/$line -p $cores -o $outdirunc/sstacks_output &> $outdirunc/sstacks_output/log_${line}_sstacks.txt
	fi
	if [[ "$analysis" == "denovo" ]]; then
	echo "	sstacks -b 1 -c $outdirunc/cstacks_output/batch_1 -s $outdirunc/ustacks_output/$line -p $cores -o $outdirunc/sstacks_output &> $outdirunc/sstacks_output/log_${line}_sstacks.txt" >> $log
	sstacks -b 1 -c $outdirunc/cstacks_output/batch_1 -s $outdirunc/ustacks_output/$line -p $cores -o $outdirunc/sstacks_output &> $outdirunc/sstacks_output/log_${line}_sstacks.txt
	fi
	done

res3=$(date +%s.%N)
dt=$(echo "$res3 - $res2" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

runtime=`printf "Sstacks runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`
echo "$runtime
" >> $log
fi

## Copy all useful outputs to same directory for populations calculations
if [[ -d $outdirunc/stacks_all_output ]]; then
echo "Populations directory present.  Skipping step.
$outdirunc/stacks_all_output
"
else
mkdir -p $outdirunc/stacks_all_output
if [[ "$analysis" == "denovo" ]]; then
cp $outdirunc/ustacks_output/*.tsv $outdirunc/stacks_all_output 2>/dev/null || true
fi
if [[ "$analysis" == "reference" ]]; then
cp $outdirunc/pstacks_output/*.tsv $outdirunc/stacks_all_output 2>/dev/null || true
fi
cp $outdirunc/cstacks_output/*.tsv $outdirunc/stacks_all_output 2>/dev/null || true
cp $outdirunc/sstacks_output/*.tsv $outdirunc/stacks_all_output 2>/dev/null || true

## Run populations program to generate popgen stats plus various outputs
## Need to add a variable for the popmap file, and change path as appropriate
echo "Executing \"populations\" program to produce popgen stats and outputs.
"
echo "Executing \"populations\" program to produce popgen stats and outputs.
" >> $log
res2=$(date +%s.%N)
	echo "	populations -t $cores -b 1 -P $outdirunc/stacks_all_output -M popmap.txt -p 1 -f p_value -k -r 0.75 -s --structure --phylip --genepop --vcf --phase --fasta &> $outdirunc/stacks_all_output/log_populations.txt" >> $log
	populations -t $cores -b 1 -P $outdirunc/stacks_all_output -M popmap.txt -p 1 -f p_value -k -r 0.75 -s --structure --phylip --genepop --vcf --phase --fasta &> $outdirunc/stacks_all_output/log_populations.txt

res3=$(date +%s.%N)
dt=$(echo "$res3 - $res2" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

runtime=`printf "Populations runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`
echo "$runtime
" >> $log
fi

#################################
## START OF CORRECTED ANALYSIS ##
#################################
echo "Start of corrected analysis steps.
"
echo "Start of corrected analysis steps.
" >> $log

## Population-based corrections using rxstacks
if [[ -d $outdircor/rxstacks_output ]]; then
echo "Rxstacks output directory present.  Skipping step.
$outdircor/rxstacks_output
"
else
echo "Running rxstacks to correct SNP calls.
"
echo "Running rxstacks to correct SNP calls.
" >> $log
res2=$(date +%s.%N)
mkdir -p $outdircor/rxstacks_output
	echo "	rxstacks -b 1 -P $outdirunc/stacks_all_output -o $outdircor/rxstacks_output --conf_lim 0.25 --prune_haplo --model_type bounded --bound_high 0.1 --lnl_lim -8.0 --lnl_dist -t $cores --verbose &> $outdircor/rxstacks_output/log_rxstacks.txt" >> $log
	rxstacks -b 1 -P $outdirunc/stacks_all_output -o $outdircor/rxstacks_output --conf_lim 0.25 --prune_haplo --model_type bounded --bound_high 0.1 --lnl_lim -8.0 --lnl_dist -t $cores --verbose &> $outdircor/rxstacks_output/log_rxstacks.txt
res3=$(date +%s.%N)
dt=$(echo "$res3 - $res2" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

runtime=`printf "Rxstacks runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`
echo "$runtime
" >> $log
fi

## Rerun cstacks to rebuild catalog
if [[ -d $outdircor/cstacks_output ]]; then
echo "Corrected cstacks output directory present.  Skipping step.
$outdircor/cstacks_output
"
else
echo "Rebuilding catalog with cstacks.
"
echo "Rebuilding catalog with cstacks.
" >> $log
res2=$(date +%s.%N)
mkdir -p $outdircor/cstacks_output
	samp=""
	for line in `cat $mapfile | cut -f1`; do
	samp+="-s $outdircor/rxstacks_output/$line "
	done
	echo "	cstacks -b 1 -n 3 -p $cores -o $outdircor/cstacks_output $samp &> $outdircor/cstacks_output/log_cstacks.txt" >> $log
	cstacks -b 1 -n 3 -p $cores -o $outdircor/cstacks_output $samp &> $outdircor/cstacks_output/log_cstacks.txt

res3=$(date +%s.%N)
dt=$(echo "$res3 - $res2" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

runtime=`printf "Cstacks runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`
echo "$runtime
" >> $log
fi

## Rerun sstacks
if [[ -d $outdircor/sstacks_output ]]; then
echo "Corrected sstacks output directory present.  Skipping step.
$outdircor/sstacks_output
"
else
echo "Searching cataloged loci for each corrected sample with sstacks.
"
echo "Searching cataloged loci for each corrected sample with sstacks.
" >> $log
res2=$(date +%s.%N)
mkdir -p $outdircor/sstacks_output
	for line in `cat $mapfile | cut -f1`; do
	echo "	sstacks -b 1 -c $outdircor/cstacks_output/batch_1 -s $outdircor/rxstacks_output/$line -p $cores -o $outdircor/sstacks_output &> $outdircor/sstacks_output/log_${line}_sstacks.txt" >> $log
	sstacks -b 1 -c $outdircor/cstacks_output/batch_1 -s $outdircor/rxstacks_output/$line -p $cores -o $outdircor/sstacks_output &> $outdircor/sstacks_output/log_${line}_sstacks.txt
	done

res3=$(date +%s.%N)
dt=$(echo "$res3 - $res2" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

runtime=`printf "Sstacks runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`
echo "$runtime
" >> $log
fi

## Copy all useful outputs to same directory for populations calculations
if [[ -d $outdircor/stacks_all_output ]]; then
echo "Corrected populations output directory present.  Skipping step.
$outdircor/stacks_all_output
"
else
mkdir -p $outdircor/stacks_all_output
cp $outdircor/rxstacks_output/*.tsv $outdircor/stacks_all_output
cp $outdircor/cstacks_output/*.tsv $outdircor/stacks_all_output
cp $outdircor/sstacks_output/*.tsv $outdircor/stacks_all_output

## Rerun populations
echo "Executing \"populations\" program to produce popgen stats and outputs
for corrected data.
"
echo "Executing \"populations\" program to produce popgen stats and outputs
for corrected data.
" >> $log
res2=$(date +%s.%N)
	echo "	populations -t $cores -b 1 -P $outdircor/stacks_all_output -M popmap.txt -p 1 -f p_value -k -r 0.75 -s --structure --phylip --genepop --vcf --phase --fasta &> $outdircor/stacks_all_output/log_populations.txt" >> $log
	populations -t $cores -b 1 -P $outdircor/stacks_all_output -M popmap.txt -p 1 -f p_value -k -r 0.75 -s --structure --phylip --genepop --vcf --phase --fasta &> $outdircor/stacks_all_output/log_populations.txt

res3=$(date +%s.%N)
dt=$(echo "$res3 - $res2" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

runtime=`printf "Populations runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`
echo "$runtime
" >> $log
fi

###################################
## Add results to mysql database ##
###################################

#adjust dbname variables here
echo "Adding Stacks output to mysql database for viewing.  This takes a
while so be patient.
"
echo "adding Stacks output to mysql database.
" >> $log
	echo $dbunc > $outdirunc/.mysql_database
	echo $dbcor > $outdircor/.mysql_database

	# drop existing mysql databases in preparation for replacement
	mysql -e "DROP DATABASE $dbunc" 2>/dev/null || true
	mysql -e "DROP DATABASE $dbcor" 2>/dev/null || true

	# create new mysql databases
	echo "	mysql -e \"CREATE DATABASE $dbunc\"" >> $log
	mysql -e "CREATE DATABASE $dbunc"
	echo "	mysql -e \"CREATE DATABASE $dbcor\"" >> $log
	mysql -e "CREATE DATABASE $dbcor"
	echo "	mysql $dbunc < /usr/local/share/stacks/sql/stacks.sql" >> $log
	mysql $dbunc < /usr/local/share/stacks/sql/stacks.sql
	echo "	mysql $dbcor < /usr/local/share/stacks/sql/stacks.sql
	" >> $log
	mysql $dbcor < /usr/local/share/stacks/sql/stacks.sql
wait

res2=$(date +%s.%N)
echo "Loading and indexing uncorrected data.
"
echo "	load_radtags.pl -D $dbunc -b 1 -p $outdirunc/stacks_all_output -B -e \"$dbname uncorrected output\" -M popmap.txt -c" >> $log
load_radtags.pl -D $dbunc -b 1 -p $outdirunc/stacks_all_output -B -e "$dbname uncorrected output" -M popmap.txt -c &>/dev/null
echo "	index_radtags.pl -D $dbunc -c -t
" >> $log
index_radtags.pl -D $dbunc -c -t &>/dev/null

res3=$(date +%s.%N)
dt=$(echo "$res3 - $res2" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

runtime=`printf "Database load/index runtime (uncorrected data): %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`
echo "$runtime
" >> $log
echo "Uncorrected data is ready for viewing.
"
wait
res2=$(date +%s.%N)
echo "Loading and indexing corrected data.
"
echo "	load_radtags.pl -D $dbcor -b 1 -p $outdircor/stacks_all_output -B -e \"$dbname corrected output\" -M popmap.txt -c" >> $log
load_radtags.pl -D $dbcor -b 1 -p $outdircor/stacks_all_output -B -e "$dbname corrected output" -M popmap.txt -c &>/dev/null
echo "	index_radtags.pl -D $dbcor -c -t
" >> $log
index_radtags.pl -D $dbcor -c -t &>/dev/null

res3=$(date +%s.%N)
dt=$(echo "$res3 - $res2" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

runtime=`printf "Database load/index runtime (corrected data): %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`
echo "$runtime
" >> $log
echo "Corrected data is ready for viewing.
"
wait

## Final timing code and exit
res3=$(date +%s.%N)
dt=$(echo "$res3 - $res0" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)
runtime=`printf "Total RADseq workflow runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`
echo "$runtime
" >> $log
exit 0

#########################
## Spare code below here:
#########################

## Timing code
res2=$(date +%s.%N)
res3=$(date +%s.%N)
dt=$(echo "$res3 - $res2" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)
runtime=`printf "Function runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`
echo "$runtime
" >> $log


