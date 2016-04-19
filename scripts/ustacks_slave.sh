#!/usr/bin/env bash
#
#  ustacks_slave.sh - ustacks script for RADseq workflow
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
	outdir=($5)
	outdirunc=($6)
	repfile=($7)
	log=($8)

## Read additional variables from config file
	cores=(`grep "CPU_cores" $config | grep -v "#" | cut -f 2`)
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

## Ustacks command
	mkdir -p $outdirunc/dereplicated_ustacks_output

		for line in `cat $repfile | cut -f1`; do
		sqlid=$(cat /dev/urandom |tr -dc '0-9' | fold -w 8 | head -n 1)
		echo "  ustacks -t fastq -f $workdir/demult-derep_output/dereplicated_combined_data/${line}.fq -p $cores -o $outdirunc/dereplicated_ustacks_output -i $sqlid -m $Min_depth -M $Max_stacks_dist -N $Max_dist_align $remov $delev" >> $log
		ustacks -t fastq -f $workdir/demult-derep_output/dereplicated_combined_data/${line}.fq -p $cores -o $outdirunc/dereplicated_ustacks_output -i $sqlid -m $Min_depth -M $Max_stacks_dist -N $Max_dist_align $remov $delev &> $outdirunc/dereplicated_ustacks_output/log_${line}_ustacks.txt
		done

exit 0
