#!/usr/bin/env bash
#
#  bowtie2_slave.sh - alignment script for RADseq workflow
#
#  Version 0.9 (April 19, 2016)
#
#  Copyright (c) 2015-2016 Andrew Krohn
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
	rm $stdout
fi
if [[ -f $stderr ]]; then
	rm $stderr
fi
}
trap finish EXIT

## Define input variables
	scriptdir="$(cd "$(dirname "$0")" && pwd)"
	repodir=`dirname $scriptdir`
	tempdir="$repodir/temp/"
	workdir=$(pwd)

	stdout=($1)
	stderr=($2)
	randcode=($3)
	config=($4)
	ref=($5)
	outdir=($6)
	mode=($7)
	mapfile=($8)
	threads=($9)

## Bowtie2 commands
## Error exists. Needs to reference the correct data source
###########################################################
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

exit 0
