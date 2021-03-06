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
if [[ -f $mapcheck ]]; then
	rm -r $mapcheck
fi
if [[ -f $sortcountfile ]]; then
	rm -r $sortcountfile
fi
if [[ -f $outlist ]]; then
	rm -r $outlist
fi
if [[ -f $seqlist ]]; then
	rm -r $seqlist
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

	# Test for errors in map file
	mapcheck="$tempdir/${randcode}_mapcheck.temp"
	RADseq_utility metadata_check $map > $mapcheck
	#if [[ ! -z "$mapcheck" ]]; then
	#	cat $mapcheck
	#	echo "
#Please correct errors and try again. Exiting.
	#	"
	#	exit 1
	#fi

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
	popmap0="$workdir/demult-derep_output/populations_file.txt"
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


## Identify any sorting steps from sort file (sortlist.txt)
	sortlist=$(ls sortlist.txt 2>/dev/null)
	if [[ ! -z "$sortlist" ]]; then
	sortdata="yes"
	sed -i "/^$/d" $sortlist
	else
	sortdata="no"
	fi

## Sort reads if sortlist is present and create list of output directories
	outlist="$tempdir/${randcode}_outlist.temp"
	if [[ "$sortdata" == "yes" ]]; then
	sortcount0=$(cat $sortlist | wc -l)
	sortcount=$(($sortcount0-1))
	sortcountfile="$tempdir/${randcode}_sortcountfile.temp"
	cat $sortlist | cut -f1 > $sortcountfile
		for i in `head -$sortcount0 $sortcountfile`; do
			name=$(grep -w "^$i" $sortlist | cut -f2)
			j="RADseq_workflow_${analysis}_${name}"
			echo $j >> $outlist
		done
	elif [[ "$sortdata" == "no" ]]; then
		echo "RADseq_workflow_${analysis}_alldata" >> $outlist	
	fi

## Map to references (read sorting)
	cores=(`grep "CPU_cores" $config | grep -v "#" | cut -f 2`)

	if [[ "$sortdata" == "yes" ]]; then
	echo "Mapping raw files against $sortcount reference(s).
	"
	i="1"
	while [[ "$i" -le "$sortcount" ]]; do
		j=$[$i-1]
		k=$[$i+1]

	## For i in `head -$sortcount $sortcountfile`; do
		count=$(grep -w "^$i" $sortlist | cut -f1)
		name=$(grep -w "^$i" $sortlist | cut -f2)
		path=$(grep -w "^$i" $sortlist | cut -f3)
		countj=$(grep -w "^$j" $sortlist | cut -f1)
		namej=$(grep -w "^$j" $sortlist | cut -f2)
		countk=$(grep -w "^$k" $sortlist | cut -f1)
		namek=$(grep -w "^$k" $sortlist | cut -f2)
		pathext="${path##*.}"
		pathdir=$(dirname $path)
		namebase=$(basename $path .$pathext)
		refname="$pathdir/$namebase"
		seqlist="$tempdir/${randcode}_seqlist.temp"

		## Iterated inputs
		if [[ "$i" -ge "2" ]]; then
			seqdir="$workdir/read_sorting/${countj}_mapping_${namej}"
		ls $seqdir/*.unmapped.fq 1> $seqlist 2>/dev/null
		fi

## Index reference if necessary
		if [[ ! -f "$refname.sma" && ! -f "$refname.smi" ]]; then
			echo "Indexing reference genome ($name)
			"
			smalt index -k 20 -s 13 $refname $path &> $pathdir/log_smalt_indexing.txt
		fi

## Set out directory and map reads
		mapdir="read_sorting/${count}_mapping_${name}"

	## Define outputs depending on interation
		if [[ "$i" == "1" ]]; then
			seqdir="$workdir/demult-derep_output/dereplicated_combined_data"
			ls $seqdir/*.fq > $seqlist
		fi

		if [[ ! -d "$mapdir" ]]; then
		mkdir -p $mapdir
		echo "Mapping reads against reference genome ($name)
		"
			for seqfile in `cat $seqlist`; do
				if [[ "$i" == "1" ]]; then
				seqname=$(basename $seqfile .fq)
				elif [[ "$i" -ge "2" ]]; then
				seqname=$(basename $seqfile .unmapped.fq)
				fi

				echo "
$seqname output:" >> $mapdir/log_smalt_mapping_${name}.txt
				## Smalt command (bam output)
				smalt map -f sam -n $cores -o $mapdir/$seqname.sam $refname $seqfile &>> $mapdir/log_smalt_mapping_${name}.txt
				## Convert output to bam (could be avoided if bambamc library becomes available)
				samtools view -b -S -o $mapdir/$seqname.bam $mapdir/$seqname.sam &>/dev/null
				#rm $mapdir/$seqname.sam
				## Sort result into mapped and unmapped fastq files
				## Mapped reads
				samtools view -F 4 -b $mapdir/$seqname.bam > $mapdir/$seqname.mapped.bam
				## Unmapped reads
				samtools view -f 4 -b $mapdir/$seqname.bam > $mapdir/$seqname.unmapped.bam
				## Convert mapped reads to fastq
				bedtools bamtofastq -i $mapdir/$seqname.mapped.bam -fq $mapdir/$seqname.fq
				## Convert unmapped reads to fastq
				bedtools bamtofastq -i $mapdir/$seqname.unmapped.bam -fq $mapdir/$seqname.unmapped.fq
				## Remove excess files
				rm $mapdir/$seqname.mapped.bam
				rm $mapdir/$seqname.unmapped.bam
				rm $mapdir/$seqname.bam
				if [[ "$i" -ge "2" ]]; then
				rm $seqfile
				fi

				## Move output to final directory on last iteration
				if [[ "$i" == "$sortcount" ]]; then
				finaldir="read_sorting/${countk}_mapping_${namek}/"
				mkdir -p $finaldir
				mv $mapdir/$seqname.unmapped.fq $finaldir/$seqname.fq
				fi
			done
		else
		echo "
Output directory already present for mapping against $name. Skipping.
$mapdir		"
		fi
	
	## Iterate
	i=$[$i+1]

	done
	fi

## Define output directory, log file, and database name
	k="1"
	for i in `cat $outlist`; do

	## Set source if reads were mapped or not
	if [[ "$sortdata" == "no" && "$analysis" == "denovo" ]]; then
		sourcedir="$workdir/demult-derep_output/dereplicated_combined_data/"
	else
		count=$(grep -w "^$k" $sortlist | cut -f1)
		name=$(grep -w "^$k" $sortlist | cut -f2)
		sourcedir="$workdir/read_sorting/${count}_mapping_${name}/"
		ref0="$ref"

		if [[  "$analysis" == "denovo" ]]; then
			analysis2="denovo"
			analysis3="De novo"
			ref2="denovo"
		fi

		if [[  "$analysis2" == "denovo" ]]; then
			analysis="denovo"
			analysis1="De novo"
			ref="denovo"
		fi		

		if [[ "$k" -le "$sortcount" ]]; then
			analysis="reference"
			analysis1="Reference-based"
			ref="Controlled by sortfile.txt"
		fi		
	fi

	## Set other variables
	outdir="$workdir/${i}_${dbname}/"
	popmap="$outdir/populations_file.txt"
	outdirname="${i}_${dbname}"
	outdirunc=($outdir/uncorrected_output)
	outdircor=($outdir/corrected_output)

	if [[ -d "$outdir" ]]; then
	echo "
Output directory already exists. Attempting to use previously generated
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

		if [[ "$sortdata" == "yes" ]]; then
		if [[  "$ref" == "denovo" ]]; then
			db=(${dbname}_DENOVO_${name}_radtags)
			echo "$db" > $outdir/.dbname
		else
			db=(${dbname}_REFERENCE_${name}_radtags)
			echo "$db" > $outdir/.dbname
		fi
		else
		if [[  "$ref" == "denovo" ]]; then
			db=(${dbname}_DENOVO_alldata_radtags)
			echo "$db" > $outdir/.dbname
		else
			db=(${dbname}_REFERENCE_alldata_radtags)
			echo "$db" > $outdir/.dbname
		fi
		fi
	fi

	## Copy in popmap file from source
	cp $popmap0 $popmap

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

## Read configured variables to log
	echo "****************************
Configuration file settings:" >> $log
	RADseq_utility print_config >> $log
	echo "" >> $log

## Read configured variables into script
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
	Load_mysql=(`grep "Load_mysql" $config | grep -v "#" | cut -f 2`)
	Compress_output=(`grep "Compress_output" $config | grep -v "#" | cut -f 2`)

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
	if [[ "$sortdata" == "no" ]]; then
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
		bash $scriptdir/bowtie2_slave.sh $stdout $stderr $randcode $config $ref $outdir $mode $mapfile $threads $log
	fi
	fi
	fi
wait

## Align each sample to reference (reference-based analysis only)
	res2=$(date +%s.%N)
	if [[ "$sortdata" == "yes" ]]; then
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
$ref0
"
echo "Aligning sequence data to supplied reference sequence.
$ref0
" >> $log
		bash $scriptdir/bowtie2_slave.sh $stdout $stderr $config $ref0 $outdir $mapfile $threads $log $sortdata
	fi
	fi
	fi
wait

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
	if [[ -d $outdirunc/pstacks_output ]]; then
	echo "Pstacks output directory present. Skipping step.
$outdirunc/pstacks_output"
	echo "Pstacks output directory present. Skipping step.
$outdirunc/pstacks_output" >> $log
	else
	echo "Extracting stacks from sam files with pstacks.
	"
	echo "Extracting stacks from sam files with pstacks.
	" >> $log
		bash $scriptdir/pstacks_slave.sh $stdout $stderr $randcode $config $outdir $outdirunc $sourcedir $repfile $log
	fi
	fi
wait

## Run ustacks for denovo samples
	res2=$(date +%s.%N)
	if [[ "$analysis" == "denovo" ]]; then
	if [[ -d $outdirunc/ustacks_output ]]; then
	echo "Ustacks output directory present. Skipping step.
$outdirunc/ustacks_output
"
	echo "Ustacks output directory present. Skipping step.
$outdirunc/ustacks_output
" >> $log
	else
	echo "Assembling loci denovo with ustacks.
	"
	echo "Assembling loci denovo with ustacks.
	" >> $log
		bash $scriptdir/ustacks_slave.sh $stdout $stderr $randcode $config $outdir $outdirunc $sourcedir $repfile $log
	fi
	fi
wait

## Run cstacks to catalog loci across samples
	res2=$(date +%s.%N)
	if [[ -d $outdirunc/cstacks_output ]]; then
	echo "Cstacks output directory present.  Skipping step.
$outdirunc/cstacks_output
"
	echo "Cstacks output directory present.  Skipping step.
$outdirunc/cstacks_output
" >> $log
	else
	echo "Cataloging loci with cstacks.
"
	echo "
Cataloging loci with cstacks.
" >> $log
		bash $scriptdir/cstacks_slave.sh $stdout $stderr $randcode $config $outdir $outdirunc $repfile $analysis $log
	fi
wait

## Search individual stacks against population catalog (sstacks)
	res2=$(date +%s.%N)
	if [[ -d $outdirunc/sstacks_output ]]; then
	echo "Sstacks output directory present. Skipping step.
$outdirunc/sstacks_output
"
	echo "Sstacks output directory present. Skipping step.
$outdirunc/sstacks_output
" >> $log
	else
	echo "Searching cataloged loci for each sample with sstacks.
"
	echo "
Searching cataloged loci for each sample with sstacks.
" >> $log
		bash $scriptdir/sstacks_slave.sh $stdout $stderr $randcode $config $outdir $outdirunc $repfile $analysis $log
	fi
wait

## Copy all useful outputs to same directory for populations calculations
	res2=$(date +%s.%N)
	if [[ -d $outdirunc/stacks_all_output ]]; then
	echo "Populations output directory present. Skipping step.
$outdirunc/stacks_all_output
"
	echo "Populations output directory present. Skipping step.
$outdirunc/stacks_all_output
" >> $log
	else
	echo "Copying all output to new directory for populations calculations.
$outdirunc/stacks_all_output
"
	echo "Copying all output to new directory for populations calculations.
$outdirunc/stacks_all_output
" >> $log
	mkdir -p $outdirunc/stacks_all_output
		if [[ "$analysis" == "denovo" ]]; then
		cp $outdirunc/ustacks_output/*.tsv $outdirunc/stacks_all_output 2>/dev/null || true
		fi
		if [[ "$analysis" == "reference" ]]; then
		cp $outdirunc/pstacks_output/*.tsv $outdirunc/stacks_all_output 2>/dev/null || true
		fi
		cp $outdirunc/cstacks_output/*.tsv $outdirunc/stacks_all_output 2>/dev/null || true
		cp $outdirunc/sstacks_output/*.tsv $outdirunc/stacks_all_output 2>/dev/null || true
wait

## Run populations program to generate popgen stats plus various outputs
	echo "Executing \"populations\" program to produce popgen stats and outputs.
"
	echo "Executing \"populations\" program to produce popgen stats and outputs.
" >> $log
		bash $scriptdir/populations_slave.sh $stdout $stderr $randcode $config $outdir $outdirunc $popmap $analysis $log
	fi
wait

#################################
## START OF CORRECTED ANALYSIS ##
#################################
echo "Start of corrected analysis steps.
"
echo "Start of corrected analysis steps.
" >> $log

## Population-based corrections using rxstacks
	res2=$(date +%s.%N)
	if [[ -d $outdircor/rxstacks_output ]]; then
echo "Rxstacks output directory present.  Skipping step.
$outdircor/rxstacks_output
"
echo "Rxstacks output directory present.  Skipping step.
$outdircor/rxstacks_output
" >> $log
else
echo "Running rxstacks to correct SNP calls.
"
echo "Running rxstacks to correct SNP calls.
" >> $log
		bash $scriptdir/rxstacks_slave.sh $stdout $stderr $randcode $config $outdir $outdircor $outdirunc $log
	fi
wait

## Rerun cstacks to rebuild catalog
	res2=$(date +%s.%N)
	if [[ -d $outdircor/cstacks_output ]]; then
	echo "Corrected cstacks output directory present.  Skipping step.
$outdircor/cstacks_output
"
	echo "Corrected cstacks output directory present.  Skipping step.
$outdircor/cstacks_output
" >> $log
	else
	echo "Rebuilding catalog with cstacks.
"
	echo "Rebuilding catalog with cstacks.
" >> $log
		bash $scriptdir/cor_cstacks_slave.sh $stdout $stderr $randcode $config $outdir $outdircor $repfile $log
	fi
wait

## Rerun sstacks
	res2=$(date +%s.%N)
	if [[ -d $outdircor/sstacks_output ]]; then
	echo "Corrected sstacks output directory present.  Skipping step.
$outdircor/sstacks_output
"
	echo "Corrected sstacks output directory present.  Skipping step.
$outdircor/sstacks_output
" >> $log
	else
	echo "Searching cataloged loci for each corrected sample with sstacks.
"
	echo "Searching cataloged loci for each corrected sample with sstacks.
" >> $log
		bash $scriptdir/cor_sstacks_slave.sh $stdout $stderr $randcode $config $outdir $outdircor $repfile $analysis $log
	fi
wait

## Copy all useful outputs to same directory for populations calculations
	res2=$(date +%s.%N)
## Dereplicated populations
	if [[ -d $outdircor/stacks_all_output ]]; then
	echo "Corrected populations output directory present.  Skipping step.
$outdircor/stacks_all_output
"
	echo "Corrected populations output directory present.  Skipping step.
$outdircor/stacks_all_output
" >> $log
	else
	mkdir -p $outdircor/stacks_all_output
	cp $outdircor/rxstacks_output/*.tsv $outdircor/stacks_all_output
	cp $outdircor/cstacks_output/*.tsv $outdircor/stacks_all_output
	cp $outdircor/sstacks_output/*.tsv $outdircor/stacks_all_output
wait

## Rerun populations
	echo "Executing \"populations\" program to produce popgen stats and outputs
for corrected data.
"
	echo "Executing \"populations\" program to produce popgen stats and outputs
for corrected data.
" >> $log
		bash $scriptdir/cor_populations_slave.sh $stdout $stderr $randcode $config $outdir $outdircor $popmap $analysis $log
	fi
wait

## Generate html output for alternative data formats from populations script
	mkdir -p $outdir/html
	cp $repodir/resources/html_template.html $outdir/html/index.html

	bash $repodir/scripts/html_builder.sh $outdir/html/index.html $outdirname/corrected_output/stacks_all_output $batch $db corrected_output/stacks_all_output $outdir
wait

###################################
## Add results to mysql database ##
###################################

	## Optional compression for non-loading analysis
	if [[ "$Load_mysql" == "NO" ]]; then
	echo "Database will not be loaded to MySql according to your configuration settings.
Workflow processing complete.
	"
	echo "Database will not be loaded to MySql according to your configuration settings.
Workflow processing complete.
	" >> $log
	if [[ "$Compress_output" == "YES" ]]; then
	ipad=$(dig +short myip.opendns.com @resolver1.opendns.com 2>/dev/null)
	if [[ ! -f ${dbname}_${outdirname}.tar.gz ]]; then
	echo "Compressing output for download (.tar.gz format).
Please be patient.
"
	echo "Compressing output for download (.tar.gz format).
" >> $log
	tar -czvf ${dbname}_${outdirname}.tar.gz $outdir &>/dev/null
	echo "Compression complete."
	else 
	echo "Compressed output already present.
	"
	fi
	echo "Using a terminal window not connected to a server, use the following
command to transfer the output to your local home directory. Should work natively
on Linux or Mac systems. Windows users should install pscp, winscp or MobaXterm.

scp ${USER}@${ipad}:${outdir}.tar.gz ./
"
	fi
	exit 0
	fi

	## Optional compression for web-loading analysis
	if [[ "$Compress_output" == "YES" ]]; then
	ipad=$(dig +short myip.opendns.com @resolver1.opendns.com)
	if [[ ! -f ${dbname}_${outdirname}.tar.gz ]]; then
	echo "Compressing output for download (.tar.gz format).
Please be patient.
"
	echo "Compressing output for download (.tar.gz format).
" >> $log
	tar -czvf ${dbname}_${outdirname}.tar.gz $outdir &>/dev/null
	echo "Compression complete."
	else 
	echo "Compressed output already present.
	"
	fi
	fi

	## Add load-db command here
	if [[ "$Load_mysql" == "YES" ]]; then
	bash $scriptdir/load-db.sh $stdout $stderr $randcode $outdirname
	fi

	k=$[$k+1]
	done

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


