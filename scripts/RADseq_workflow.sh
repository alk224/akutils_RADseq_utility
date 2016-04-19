#!/usr/bin/env bash
#
#  Stacks workflow - process raw RADseq data all the way through Stacks pipline
#
#  Version 1.2.0 (April 19, 2016)
#
#  Copyright (c) 2014-2016 Andrew Krohn
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
if [[ -f $stdout ]]; then
	rm -r $stdout
fi
if [[ -f $stderr ]]; then
	rm -r $stderr
fi
if [[ -f $filetesttemp ]]; then
	rm -r $filetesttemp
fi
}
trap finish EXIT

## Define inputs and working directory
	scriptdir="$(cd "$(dirname "$0")" && pwd)"
	repodir=`dirname $scriptdir`
	tempdir="$repodir/temp/"
	workdir=$(pwd)

	stdout=($1)
	stderr=($2)
	randcode=($3)
	config=($4)
	globallocal=($5)
	dbname=($6)
	ref=($7)
	date0=`date +%Y%m%d_%I%M%p`
	date100=`date -R`

## If demult-derep output not present, run first
	if [[ ! -d "demult-derep_output" ]]; then

	# Define map and read files
	map=$(ls map* 2>/dev/null | head -1)
	index=$(ls index.fastq 2>/dev/null)
	read1=$(ls read1.fastq 2>/dev/null)
	read2=$(ls read2.fastq 2>/dev/null)

	# Test for valid file definitions, exit if necessary
	filetesttemp="$tempdir/${randcode}_filetest.temp"
	if [[ ! -z "$map" ]]; then
		echo "Valid mapfile: $map" > $filetesttemp
	else
		echo "No valid mapfile found. (map*)" > $filetesttemp
	fi
	if [[ ! -z "$index" ]]; then
		echo "Valid index: $index" >> $filetesttemp
	else
		echo "No valid index file found. (index.fastq)" >> $filetesttemp
	fi
	if [[ ! -z "$read1" ]]; then
		echo "Valid read 1: $read1" >> $filetesttemp
	else
		echo "No valid read 1 file found. (read1.fastq)" >> $filetesttemp
	fi
	if [[ ! -z "$read2" ]]; then
		echo "Valid read 2: $read2" >> $filetesttemp
	else
		echo "No valid read 2 file found. (read2.fastq)" >> $filetesttemp
	fi
		echo "
Testing for required input files:"
		cat $filetesttemp
	if [[ -z "$map" ]] || [[ -z "$index" ]] || [[ -z "$read1" ]]; then
		echo "
Missing required input files. Exiting.
	"
		exit 1
	fi
		echo ""
		bash $scriptdir/RADseq_demult-derep.sh $stdout $stderr $randcode $config $globallocal $map $index $read1 $read2
		wait
	fi

## Define file variables from demult-derep output
	mapfile="$workdir/demult-derep_output/metadata_file.txt"
	popmap="$workdir/demult-derep_output/populations_file.txt"
	repfile="$workdir/demult-derep_output/repfile.txt"

## Determine analysis mode based user input
	if [[  "$ref" == "denovo" ]]; then
	analysis="denovo"
	analysis1="De novo"
	else
	analysis="reference"
	analysis1="Reference-based"
	fi

## Read sequencing mode from demult-derep output
	mode1=$(cat demult-derep_output/.sequencing_mode)

## Define output directory, log file, and database name
	outdir="$workdir/RADseq_workflow_${analysis}"
	outdirunc=($outdir/uncorrected_output)
	outdircor=($outdir/corrected_output)
	if [[ -d "$outdir" ]]; then
	echo "
Output directory already exists.  Attempting to use previously generated
ouputs.
	"
	log=`ls $outdir/log_RADseq_workflow_* | head -1`
		if [[ -f "$outdir/.dbname" ]]; then
		db=$(cat $outdir/.dbname)
		else
			if [[  "$ref" == "denovo" ]]; then
				db=(${dbname}_DENOVO_radtags)
				echo "$db" > $outdir/.dbname
			else
				db=(${dbname}_REFERENCE_radtags)
				echo "$db" > $outdir/.dbname
			fi
		fi
	else
	mkdir -p $outdir
	log=($outdir/log_RADseq_workflow_${date0})
	touch $log
		if [[  "$ref" == "denovo" ]]; then
			db=(${dbname}_DENOVO_radtags)
			echo "$db" > $outdir/.dbname
		else
			db=(${dbname}_REFERENCE_radtags)
			echo "$db" > $outdir/.dbname
		fi
	fi

## Read in variables from config file
	if [[ "$globallocal" == "local" ]]; then
	echo "Using local akutils RADseq utility config file.
$config
	"
	echo "
Referencing local akutils RADseq utility config file.
$config
	" >> $log
	else
		if [[ "$globallocal" == "global" ]]; then
		echo "Using global akutils RADseq utility config file.
$config
		"
		echo "
Referencing global akutils RADseq utility config file.
$config
		" >> $log
		fi
	fi

	cores=(`grep "CPU_cores" $config | grep -v "#" | cut -f 2`)
	threads=$(expr $cores + 1)
	qual=(`grep "Qual_score" $config | grep -v "#" | cut -f 2`)
	multx_errors=(`grep "Multx_errors" $config | grep -v "#" | cut -f 2`)
	slminpercent="0.95"
	batch=(`grep "Batch_ID" $config | grep -v "#" | cut -f 2`)
	Min_depth=(`grep "Min_depth" $config | grep -v "#" | cut -f 2`)
	Max_stacks_dist=(`grep "Max_stacks_dist" $config | grep -v "#" | cut -f 2`)
	Max_dist_align=(`grep "Max_dist_align" $config | grep -v "#" | cut -f 2`)
	Removal_alg=(`grep "Removal_alg" $config | grep -v "#" | cut -f 2`)
		if [[ "$Removal_alg" == "YES" ]]; then
			remov="-r"
		fi
	Deleverage_alg=(`grep "Deleverage_alg" $config | grep -v "#" | cut -f 2`)
		if [[ "$Deleverage_alg" == "YES" ]]; then
			delev="-d"
		fi
	Duplicate_match=(`grep "Duplicate_match" $config | grep -v "#" | cut -f 2`)
	Tag_mismatches=(`grep "Tag_mismatches" $config | grep -v "#" | cut -f 2`)
		if [[ "$Tag_mismatches" == "YES" ]]; then
			mismat="-m"
		fi
	Catalog_match=(`grep "Catalog_match" $config | grep -v "#" | cut -f 2`)
		if [[ "$Catalog_match" == "GENOMIC" ]]; then
			catmat="-g"
		fi

res0=$(date +%s.%N)
echo "RADseq workflow beginning.
Sequencing mode detected: $mode1
Analysis type: $analysis1
CPU cores: $cores
"

###################################################################
## ANALYSIS STEPS BEGIN HERE
###################################################################

## Align each sample to reference (reference-based analysis only)
	res2=$(date +%s.%N)
	if [[ "$analysis" == "reference" ]]; then
	if [[ -d $outdir/bowtie2_alignments ]]; then
echo "Alignments previously performed.  Skipping step.
$outdir/bowtie2_alignments
"
echo "Alignments previously performed.  Skipping step.
$outdir/bowtie2_alignments
" >> $log
	else
echo "Aligning sequence data to supplied reference sequence.
$ref
"
echo "Aligning sequence data to supplied reference sequence.
$ref
" >> $log
		bash $scriptdir/bowtie2_slave.sh $stdout $stderr $randcode $configfile $ref $outdir $mode $mapfile $threads
	fi
	fi

###################################
## START OF UNCORRECTED ANALYSIS ##
###################################
echo "Start of uncorrected analysis steps.
"
echo "Start of uncorrected analysis steps.
" >> $log

## Run pstacks for reference-based analysis
	res2=$(date +%s.%N)
	if [[ "$analysis" == "reference" ]]; then
	if [[ -d $outdirunc/dereplicated_pstacks_output ]]; then
	echo "Pstacks output directory present. Skipping step.
$outdirunc/dereplicated_pstacks_output"
	echo "Pstacks output directory present. Skipping step.
$outdirunc/dereplicated_pstacks_output" >> $log
	else
	echo "Extracting stacks from sam files with pstacks.
	"
	echo "Extracting stacks from sam files with pstacks.
	" >> $log
		bash $scriptdir/pstacks_slave.sh $stdout $stderr $randcode $configfile $outdir $outdirunc $repfile
	fi
	fi

## Run ustacks for denovo samples
	res2=$(date +%s.%N)
	if [[ "$analysis" == "denovo" ]]; then
	if [[ -d $outdirunc/dereplicated_ustacks_output ]]; then
	echo "Ustacks output directory present. Skipping step.
$outdirunc/dereplicated_ustacks_output"
	echo "Ustacks output directory present. Skipping step.
$outdirunc/dereplicated_ustacks_output" >> $log
	else
	echo "Assembling loci denovo with ustacks.
	"
	echo "Assembling loci denovo with ustacks.
	" >> $log
		bash $scriptdir/ustacks_slave.sh $stdout $stderr $randcode $configfile $outdir $outdirunc $repfile
	fi
	fi

## Run cstacks to catalog loci across samples
	res2=$(date +%s.%N)
	if [[ -d $outdirunc/dereplicated_cstacks_output ]]; then
	echo "Cstacks output directory present.  Skipping step.
$outdirunc/dereplicated_cstacks_output
"
	echo "Cstacks output directory present.  Skipping step.
$outdirunc/dereplicated_cstacks_output
" >> $log
	else
	echo "Cataloging loci with cstacks.
"
	echo "Cataloging loci with cstacks.
" >> $log
		bash $scriptdir/cstacks_slave.sh $stdout $stderr $randcode $configfile $outdir $outdirunc $repfile $analysis
	fi

## Search individual stacks against population catalog (sstacks)
	res2=$(date +%s.%N)
	if [[ -d $outdirunc/dereplicated_sstacks_output ]]; then
	echo "Sstacks output directory present. Skipping step.
$outdirunc/dereplicated_sstacks_output"
	echo "Sstacks output directory present. Skipping step.
$outdirunc/dereplicated_sstacks_output" >> $log
	else
	echo "Searching cataloged loci for each sample with sstacks.
"
	echo "Searching cataloged loci for each sample with sstacks.
" >> $log
		bash $scriptdir/sstacks_slave.sh $stdout $stderr $randcode $configfile $outdir $outdirunc $repfile $analysis
	fi

## Copy all useful outputs to same directory for populations calculations
	res2=$(date +%s.%N)
	if [[ -d $outdirunc/dereplicated_stacks_all_output ]]; then
	echo "Populations output directory present. Skipping step.
$outdirunc/dereplicated_stacks_all_output"
	echo "Populations output directory present. Skipping step.
$outdirunc/dereplicated_stacks_all_output" >> $log
	else
	echo "Copying all output to new directory for populations calculations.
$outdirunc/dereplicated_stacks_all_output
"
	echo "Copying all output to new directory for populations calculations.
$outdirunc/dereplicated_stacks_all_output
" >> $log
	mkdir -p $outdirunc/dereplicated_stacks_all_output
		if [[ "$analysis" == "denovo" ]]; then
		cp $outdirunc/dereplicated_ustacks_output/*.tsv $outdirunc/dereplicated_stacks_all_output 2>/dev/null || true
		fi
		if [[ "$analysis" == "reference" ]]; then
		cp $outdirunc/dereplicated_pstacks_output/*.tsv $outdirunc/dereplicated_stacks_all_output 2>/dev/null || true
		fi
		cp $outdirunc/dereplicated_cstacks_output/*.tsv $outdirunc/dereplicated_stacks_all_output 2>/dev/null || true
		cp $outdirunc/dereplicated_sstacks_output/*.tsv $outdirunc/dereplicated_stacks_all_output 2>/dev/null || true

## Run populations program to generate popgen stats plus various outputs
	echo "Executing \"populations\" program to produce popgen stats and outputs.
"
	echo "Executing \"populations\" program to produce popgen stats and outputs.
" >> $log
		bash $scriptdir/populations_slave.sh $stdout $stderr $randcode $configfile $outdir $outdirunc $popmap1 $analysis
	fi



















exit 0
## Align each sample to reference (reference-based analysis only)
res2=$(date +%s.%N)
if [[ "$analysis" == "reference" ]]; then
if [[ ! -d $outdir/bowtie2_alignments || ! -d $outdir/dereplicated_bowtie2_alignments ]]; then
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
mkdir -p $outdir/bowtie2_alignments
	if [[ "$mode" == "single" ]]; then
	for line in `cat $mapfile | cut -f1`; do
		while [ $( pgrep -P $$ |wc -w ) -ge ${threads} ]; do
		sleep 1
		done
		echo "	bowtie2-align --local -x $ref -U $outdir/quality_filtered_data/${line}.read.mcf.fq -S $outdir/bowtie2_alignments/${line}.sam > $outdir/bowtie2_alignments/log_${line}_bowtie2.txt" >> $log
		( bowtie2-align --local -x $ref -U $outdir/quality_filtered_data/${line}.read.mcf.fq -S $outdir/bowtie2_alignments/${line}.sam > $outdir/bowtie2_alignments/log_${line}_bowtie2.txt 2>&1 || true ) &
	done
	fi
	if [[ "$mode" == "paired" ]]; then
	for line in `cat $mapfile | cut -f1`; do
		while [ $( pgrep -P $$ |wc -w ) -ge ${threads} ]; do
		sleep 1
		done
		echo "	bowtie2-align --local -x $ref -1 $outdir/quality_filtered_data/${line}.read1.mcf.fq -2 $outdir/quality_filtered_data/${line}.read2.mcf.fq -S $outdir/bowtie2_alignments/${line}.sam > $outdir/bowtie2_alignments/log_${line}_bowtie2.txt" >> $log
		( bowtie2-align --local -x $ref -1 $outdir/quality_filtered_data/${line}.read1.mcf.fq -2 $outdir/quality_filtered_data/${line}.read2.mcf.fq -S $outdir/bowtie2_alignments/${line}.sam > $outdir/bowtie2_alignments/log_${line}_bowtie2.txt 2>&1 || true ) &
	done
	fi
wait
fi

if [[ -d $outdir/dereplicated_bowtie2_alignments ]]; then
echo "Alignments previously performed (dereplicated data).  Skipping step.
$outdir/dereplicated_bowtie2_alignments
"
else
echo "Aligning dereplicated quality-filtered data to reference sequence(s).
Supplied reference: $ref
"
echo "Aligning dereplicated quality-filtered data to reference sequence(s).
Supplied reference: $ref
" >> $log
mkdir -p $outdir/dereplicated_bowtie2_alignments
	if [[ "$mode" == "single" ]]; then
	for line in `cat $repfile`; do
		while [ $( pgrep -P $$ |wc -w ) -ge ${threads} ]; do
		sleep 1
		done
		echo "	bowtie2-align --local -x $ref -U $outdir/dereplicated_quality_filtered_data/${line}.read.mcf.fq -S $outdir/dereplicated_bowtie2_alignments/${line}.sam > $outdir/dereplicated_bowtie2_alignments/log_${line}_bowtie2.txt" >> $log
		( bowtie2-align --local -x $ref -U $outdir/dereplicated_quality_filtered_data/${line}.read.mcf.fq -S $outdir/dereplicated_bowtie2_alignments/${line}.sam > $outdir/dereplicated_bowtie2_alignments/log_${line}_bowtie2.txt 2>&1 || true ) &
	done
	fi
	if [[ "$mode" == "paired" ]]; then
	for line in `cat $repfile`; do
		while [ $( pgrep -P $$ |wc -w ) -ge ${threads} ]; do
		sleep 1
		done
		echo "	bowtie2-align --local -x $ref -1 $outdir/dereplicated_quality_filtered_data/${line}.read1.mcf.fq -2 $outdir/dereplicated_quality_filtered_data/${line}.read2.mcf.fq -S $outdir/dereplicated_bowtie2_alignments/${line}.sam > $outdir/dereplicated_bowtie2_alignments/log_${line}_bowtie2.txt" >> $log
		( bowtie2-align --local -x $ref -1 $outdir/dereplicated_quality_filtered_data/${line}.read1.mcf.fq -2 $outdir/dereplicated_quality_filtered_data/${line}.read2.mcf.fq -S $outdir/dereplicated_bowtie2_alignments/${line}.sam > $outdir/dereplicated_bowtie2_alignments/log_${line}_bowtie2.txt 2>&1 || true ) &
	done
	fi
wait
fi

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
res2=$(date +%s.%N)
if [[ "$analysis" == "reference" ]]; then
	if [[ ! -d $outdirunc/dereplicated_pstacks_output ]]; then
	echo "Extracting stacks from sam files with pstacks (dereplicated data).
	"
	echo "Extracting stacks from sam files with pstacks (dereplicated data).
	" >> $log
	mkdir -p $outdirunc/dereplicated_pstacks_output
		for line in `cat $repfile | cut -f1`; do
		sqlid=$(cat /dev/urandom |tr -dc '0-9' | fold -w 8 | head -n 1)
		echo "  pstacks -t sam -f $outdir/dereplicated_bowtie2_alignments/${line}.aligned.sam -p $cores -o $outdirunc/dereplicated_pstacks_output -i $sqlid" >> $log
		pstacks -t sam -f $outdir/dereplicated_bowtie2_alignments/${line}.sam -p $cores -o $outdirunc/dereplicated_pstacks_output -i $sqlid &> $outdirunc/dereplicated_pstacks_output/log_${line}_pstacks.txt
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
	else
	echo "Pstacks output directory present (dereplicated data).  Skipping step.
$outdirunc/dereplicated_pstacks_output
	"
	fi
fi

## Run ustacks for denovo samples
res2=$(date +%s.%N)
if [[ "$analysis" == "denovo" ]]; then
	if [[ ! -d $outdirunc/dereplicated_ustacks_output ]]; then
	echo "Assembling loci denovo with ustacks (dereplicated data).
	"
	echo "Assembling loci denovo with ustacks (dereplicated data).
	" >> $log
	mkdir -p $outdirunc/dereplicated_ustacks_output

		for line in `cat $repfile | cut -f1`; do
		sqlid=$(cat /dev/urandom |tr -dc '0-9' | fold -w 8 | head -n 1)
		echo "  ustacks -t fastq -f $workdir/demult-derep_output/dereplicated_combined_data/${line}.fq -p $cores -o $outdirunc/dereplicated_ustacks_output -i $sqlid -m 2 -M 4 -N 6 -r -d" >> $log
		ustacks -t fastq -f $workdir/demult-derep_output/dereplicated_combined_data/${line}.fq -p $cores -o $outdirunc/dereplicated_ustacks_output -i $sqlid -m 2 -M 4 -N 6 -r -d &> $outdirunc/dereplicated_ustacks_output/log_${line}_ustacks.txt
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

	else
	echo "Ustacks output directory present (dereplicated data).  Skipping step.
	$outdirunc/dereplicated_ustacks_output
	"

	fi
fi

## Run cstacks to catalog loci across samples
res2=$(date +%s.%N)
	if [[ -d $outdirunc/dereplicated_cstacks_output ]]; then
echo "Cstacks output directory present (dereplicated data).  Skipping step.
$outdirunc/dereplicated_cstacks_output
"
else
echo "Cataloging loci with cstacks (dereplicated data).
"
echo "Cataloging loci with cstacks (dereplicated data).
" >> $log
	mcfcount=`ls $outdirunc/dereplicated_ustacks_output/*mcf* 2>/dev/null | wc -l`
			if [[ $mcfcount -ge 1 ]]; then
	cd $outdirunc/dereplicated_ustacks_output
	rename 's/read.mcf.//' *read.mcf*
	rename 's/read1.mcf.//' *read1.mcf*
	rename 's/read2.mcf.//' *read2.mcf*
	cd $workdir
			fi
mkdir -p $outdirunc/dereplicated_cstacks_output
	samp=""
			if [[ "$analysis" == "reference" ]]; then
	for line in `cat $repfile | cut -f1`; do
	samp+="-s $outdirunc/dereplicated_pstacks_output/$line "
	done
	echo "	cstacks -g -p $cores -b ${batch} -n 1 $samp -o $outdirunc/dereplicated_cstacks_output &> $outdirunc/dereplicated_cstacks_output/log_cstacks.txt" >> $log
	cstacks -g -p $cores -b ${batch} -n 1 $samp -o $outdirunc/dereplicated_cstacks_output &> $outdirunc/dereplicated_cstacks_output/log_cstacks.txt
			fi
			if [[ "$analysis" == "denovo" ]]; then
	for line in `cat $repfile | cut -f1`; do
	samp+="-s $outdirunc/dereplicated_ustacks_output/$line "
	done
	echo "	cstacks -p $cores -b ${batch} -n 4 -m $samp -o $outdirunc/dereplicated_cstacks_output &> $outdirunc/dereplicated_cstacks_output/log_cstacks.txt" >> $log
	cstacks -p $cores -b ${batch} -n 4 -m $samp -o $outdirunc/dereplicated_cstacks_output &> $outdirunc/dereplicated_cstacks_output/log_cstacks.txt
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
res2=$(date +%s.%N)
	if [[ -d $outdirunc/dereplicated_sstacks_output ]]; then
echo "Sstacks output directory present (dereplicated data).  Skipping step.
$outdirunc/dereplicated_sstacks_output
"
else
echo "Searching cataloged loci for each sample with sstacks (dereplicated data).
"
echo "Searching cataloged loci for each sample with sstacks (dereplicated data).
" >> $log
mkdir -p $outdirunc/dereplicated_sstacks_output
	for line in `cat $repfile | cut -f1`; do
				if [[ "$analysis" == "reference" ]]; then
	echo "	sstacks -b ${batch} -c $outdirunc/dereplicated_cstacks_output/batch_${batch} -s $outdirunc/dereplicated_pstacks_output/$line -p $cores -o $outdirunc/dereplicated_sstacks_output &> $outdirunc/dereplicated_sstacks_output/log_${line}_sstacks.txt" >> $log
	sstacks -b ${batch} -c $outdirunc/dereplicated_cstacks_output/batch_${batch} -s $outdirunc/dereplicated_pstacks_output/$line -p $cores -o $outdirunc/dereplicated_sstacks_output &> $outdirunc/dereplicated_sstacks_output/log_${line}_sstacks.txt
				fi
				if [[ "$analysis" == "denovo" ]]; then
	echo "	sstacks -b ${batch} -c $outdirunc/dereplicated_cstacks_output/batch_${batch} -s $outdirunc/dereplicated_ustacks_output/$line -p $cores -o $outdirunc/dereplicated_sstacks_output &> $outdirunc/dereplicated_sstacks_output/log_${line}_sstacks.txt" >> $log
	sstacks -b ${batch} -c $outdirunc/dereplicated_cstacks_output/batch_${batch} -s $outdirunc/dereplicated_ustacks_output/$line -p $cores -o $outdirunc/dereplicated_sstacks_output &> $outdirunc/dereplicated_sstacks_output/log_${line}_sstacks.txt
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
res2=$(date +%s.%N)

## Dereplicated populations step
	if [[ -d $outdirunc/dereplicated_stacks_all_output ]]; then
echo "Populations directory present (dereplicated data).  Skipping step.
$outdirunc/dereplicated_stacks_all_output
"
else
mkdir -p $outdirunc/dereplicated_stacks_all_output
		if [[ "$analysis" == "denovo" ]]; then
cp $outdirunc/dereplicated_ustacks_output/*.tsv $outdirunc/dereplicated_stacks_all_output 2>/dev/null || true
		fi
		if [[ "$analysis" == "reference" ]]; then
cp $outdirunc/dereplicated_pstacks_output/*.tsv $outdirunc/dereplicated_stacks_all_output 2>/dev/null || true
		fi
cp $outdirunc/dereplicated_cstacks_output/*.tsv $outdirunc/dereplicated_stacks_all_output 2>/dev/null || true
cp $outdirunc/dereplicated_sstacks_output/*.tsv $outdirunc/dereplicated_stacks_all_output 2>/dev/null || true

## Run populations program to generate popgen stats plus various outputs
## Need to add a variable for the popmap file, and change path as appropriate
echo "Executing \"populations\" program to produce popgen stats and outputs
(dereplicated data).
"
echo "Executing \"populations\" program to produce popgen stats and outputs
(dereplicated data).
" >> $log
		if [[ "$analysis" == "denovo" ]]; then
	echo "	populations -t $cores -b ${batch} -P $outdirunc/dereplicated_stacks_all_output -M $popmap1 -p 1 -f p_value -k -r 0.75 -s --structure --phylip --genepop --vcf --phase --fasta --fstats --genomic &> $outdirunc/dereplicated_stacks_all_output/log_populations.txt
	" >> $log
	populations -t $cores -b ${batch} -P $outdirunc/dereplicated_stacks_all_output -M $popmap1 -p 1 -f p_value -k -r 0.75 -s --structure --phylip --genepop --vcf --phase --fasta --fstats --genomic &> $outdirunc/dereplicated_stacks_all_output/log_populations.txt
		fi
		if [[ "$analysis" == "reference" ]]; then
	echo "	populations -t $cores -b ${batch} -P $outdirunc/dereplicated_stacks_all_output -M $popmap1 -p 1 -f p_value -k -r 0.75 -s --structure --phylip --genepop --vcf --phase --fasta --fstats --merge_sites -- bootstrap --bootstrap_pifis --bootstrap_fst --bootstrap_div --bootstrap_phist --genomic &> $outdirunc/dereplicated_stacks_all_output/log_populations.txt
	" >> $log
	populations -t $cores -b ${batch} -P $outdirunc/dereplicated_stacks_all_output -M $popmap1 -p 1 -f p_value -k -r 0.75 -s --structure --phylip --genepop --vcf --phase --fasta --fstats --merge_sites -- bootstrap --bootstrap_pifis --bootstrap_fst --bootstrap_div --bootstrap_phist --genomic &> $outdirunc/dereplicated_stacks_all_output/log_populations.txt
		fi

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
res2=$(date +%s.%N)
	if [[ -d $outdircor/dereplicated_rxstacks_output ]]; then
echo "Rxstacks output directory present (dereplicated data).  Skipping step.
$outdircor/dereplicated_rxstacks_output
"
else
echo "Running rxstacks to correct SNP calls (dereplicated data).
"
echo "Running rxstacks to correct SNP calls (dereplicated data).
" >> $log

mkdir -p $outdircor/dereplicated_rxstacks_output
	echo "	rxstacks -b ${batch} -P $outdirunc/dereplicated_stacks_all_output -o $outdircor/dereplicated_rxstacks_output --conf_lim 0.25 --prune_haplo --model_type bounded --bound_high 0.1 --lnl_lim -8.0 --lnl_dist -t $cores --verbose &> $outdircor/dereplicated_rxstacks_output/log_rxstacks.txt
	" >> $log
	rxstacks -b ${batch} -P $outdirunc/dereplicated_stacks_all_output -o $outdircor/dereplicated_rxstacks_output --conf_lim 0.25 --prune_haplo --model_type bounded --bound_high 0.1 --lnl_lim -8.0 --lnl_dist -t $cores --verbose &> $outdircor/dereplicated_rxstacks_output/log_rxstacks.txt

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
res2=$(date +%s.%N)
	if [[ -d $outdircor/dereplicated_cstacks_output ]]; then
echo "Corrected cstacks output directory present (dereplicated data).  Skipping step.
$outdircor/cstacks_output
"
else
echo "Rebuilding catalog with cstacks (dereplicated data).
"
echo "Rebuilding catalog with cstacks (dereplicated data).
" >> $log
mkdir -p $outdircor/dereplicated_cstacks_output
	samp=""
	for line in `cat $repfile | cut -f1`; do
	samp+="-s $outdircor/dereplicated_rxstacks_output/$line "
	done
	echo "	cstacks -b ${batch} -n 3 -p $cores -o $outdircor/dereplicated_cstacks_output $samp &> $outdircor/dereplicated_cstacks_output/log_cstacks.txt" >> $log
	cstacks -b ${batch} -n 3 -p $cores -o $outdircor/dereplicated_cstacks_output $samp &> $outdircor/dereplicated_cstacks_output/log_cstacks.txt

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
res2=$(date +%s.%N)
	if [[ -d $outdircor/dereplicated_sstacks_output ]]; then
echo "Corrected sstacks output directory present.  Skipping step.
$outdircor/sstacks_output
"
else
echo "Searching cataloged loci for each corrected sample with sstacks
(dereplicated data).
"
echo "Searching cataloged loci for each corrected sample with sstacks
(dereplicated data).
" >> $log
mkdir -p $outdircor/dereplicated_sstacks_output
	for line in `cat $repfile | cut -f1`; do
	echo "	sstacks -b ${batch} -c $outdircor/dereplicated_cstacks_output/batch_${batch} -s $outdircor/dereplicated_rxstacks_output/$line -p $cores -o $outdircor/dereplicated_sstacks_output &> $outdircor/dereplicated_sstacks_output/log_${line}_sstacks.txt" >> $log
	sstacks -b ${batch} -c $outdircor/dereplicated_cstacks_output/batch_${batch} -s $outdircor/dereplicated_rxstacks_output/$line -p $cores -o $outdircor/dereplicated_sstacks_output &> $outdircor/dereplicated_sstacks_output/log_${line}_sstacks.txt
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
res2=$(date +%s.%N)
## Dereplicated populations
	if [[ -d $outdircor/dereplicated_stacks_all_output ]]; then
echo "Corrected populations output directory present.  Skipping step.
$outdircor/stacks_all_output
"
else
mkdir -p $outdircor/dereplicated_stacks_all_output
cp $outdircor/dereplicated_rxstacks_output/*.tsv $outdircor/dereplicated_stacks_all_output
cp $outdircor/dereplicated_cstacks_output/*.tsv $outdircor/dereplicated_stacks_all_output
cp $outdircor/dereplicated_sstacks_output/*.tsv $outdircor/dereplicated_stacks_all_output

## Rerun populations
echo "Executing \"populations\" program to produce popgen stats and outputs
for corrected data (dereplicated data).
"
echo "Executing \"populations\" program to produce popgen stats and outputs
for corrected data (dereplicated data).
" >> $log
		if [[ "$analysis" == "denovo" ]]; then
	echo "	populations -t $cores -b ${batch} -P $outdircor/dereplicated_stacks_all_output -M $popmap1 -p 1 -f p_value -k -r 0.75 -s --structure --phylip --genepop --vcf --phase --fasta --fstats &> $outdircor/dereplicated_stacks_all_output/log_populations.txt" >> $log
	populations -t $cores -b ${batch} -P $outdircor/dereplicated_stacks_all_output -M $popmap1 -p 1 -f p_value -k -r 0.75 -s --structure --phylip --genepop --vcf --phase --fasta --fstats &> $outdircor/dereplicated_stacks_all_output/log_populations.txt
		fi
		if [[ "$analysis" == "reference" ]]; then
	echo "	populations -t $cores -b ${batch} -P $outdircor/dereplicated_stacks_all_output -M $popmap1 -p 1 -f p_value -k -r 0.75 -s --structure --phylip --genepop --vcf --phase --fasta --fstats &> $outdircor/dereplicated_stacks_all_output/log_populations.txt" >> $log
	populations -t $cores -b ${batch} -P $outdircor/dereplicated_stacks_all_output -M $popmap1 -p 1 -f p_value -k -r 0.75 -s --structure --phylip --genepop --vcf --phase --fasta --fstats --merge_sites -- bootstrap --bootstrap_pifis --bootstrap_fst --bootstrap_div --bootstrap_phist &> $outdircor/dereplicated_stacks_all_output/log_populations.txt
		fi

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
	echo $db > $outdir/.mysql_database 2>/dev/null || true

	# drop existing mysql database in preparation for replacement
	mysql -e "DROP DATABASE $db" 2>/dev/null || true

	# create new mysql database
	echo "	mysql -e \"CREATE DATABASE $db\"" >> $log
	mysql -e "CREATE DATABASE $db"

	echo "	mysql $db < /usr/local/share/stacks/sql/stacks.sql" >> $log
	mysql $db < /usr/local/share/stacks/sql/stacks.sql
	echo "" >> $log
wait

## Load database (all samples)
res2=$(date +%s.%N)
echo "Loading and indexing corrected data (dereplicated data).
"
echo "	load_radtags.pl -D $db -b ${batch} -p $outdircor/dereplicated_stacks_all_output -B -e \"$db corrected and dereplicated output\" -M $popmap -c -t population" >> $log
load_radtags.pl -D $db -b ${batch} -p $outdircor/dereplicated_stacks_all_output -B -e "$db corrected output" -M $popmap -c -t population &>/dev/null
echo "	index_radtags.pl -D $db -c -t
" >> $log
index_radtags.pl -D $db -c -t &>/dev/null

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
echo "Corrected data is ready for viewing (dereplicated data).
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


