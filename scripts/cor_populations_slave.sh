#!/usr/bin/env bash
#
#  cor_populations_slave.sh - corrected populations script for RADseq workflow
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
	outdircor=($6)
	popmap=($7)
	analysis=($8)
	log=($9)

## Read additional variables from config file
	cores=(`grep "CPU_cores" $config | grep -v "#" | cut -f 2`)
	batch=(`grep "Batch_ID" $config | grep -v "#" | cut -f 2`)
	Min_perc_pop=(`grep "Min_perc_pop" $config | grep -v "#" | cut -f 2`)
	Min_pops=(`grep "Min_pops" $config | grep -v "#" | cut -f 2`)
	Min_stack_depth=(`grep "Min_stack_depth" $config | grep -v "#" | cut -f 2`)
	Fstats=(`grep "Fstats" $config | grep -v "#" | cut -f 2`)
		if [[ "$Fstats" == "YES" ]]; then
			fstats="--fstats"
		fi
	Single_snp=(`grep "Single_snp" $config | grep -v "#" | cut -f 2`)
		if [[ "$Single_snp" == "YES" ]]; then
			single="--write_single_snp"
		fi
	Random_snp=(`grep "Random_snp" $config | grep -v "#" | cut -f 2`)
		if [[ "$Random_snp" == "YES" ]]; then
			random="--write_random_snp"
		fi
	Kernel_smooth=(`grep "Kernel_smooth" $config | grep -v "#" | cut -f 2`)
		if [[ "$Kernel_smooth" == "YES" ]]; then
			kern="-k"
		fi
	Window_size=(`grep "Window_size" $config | grep -v "#" | cut -f 2`)
		if [[ "$Window_size" != "DEFAULT" ]]; then
			winsize="--window_size $Window_size"
		fi

## Populations command
		if [[ "$analysis" == "denovo" ]]; then
	echo "	populations -t $cores -b ${batch} -P $outdircor/dereplicated_stacks_all_output -M $popmap -p $Min_pops -f p_value -r $Min_perc_pop -s -m $Min_stack_depth --structure --phylip --genepop --vcf --vcf_haplotypes --phase --fastphase --beagle --beagle_phased --plink --fasta $fstats $single $random $kern $winsize &> $outdircor/dereplicated_stacks_all_output/log_populations.txt" >> $log
	populations -t $cores -b ${batch} -P $outdircor/dereplicated_stacks_all_output -M $popmap -p $Min_pops -f p_value -r $Min_perc_pop -s -m $Min_stack_depth --structure --phylip --genepop --vcf --vcf_haplotypes --phase --fastphase --beagle --beagle_phased --plink --fasta $fstats $single $random $kern $winsize &> $outdircor/dereplicated_stacks_all_output/log_populations.txt
		fi
		if [[ "$analysis" == "reference" ]]; then
	echo "	populations -t $cores -b ${batch} -P $outdircor/dereplicated_stacks_all_output -M $popmap -p $Min_pops -f p_value -k -r $Min_perc_pop -s -m $Min_stack_depth --structure --phylip --genepop --vcf --vcf_haplotypes --phase --fastphase --beagle --beagle_phased --plink --fasta $fstats $single $random $kern $winsize &> $outdircor/dereplicated_stacks_all_output/log_populations.txt" >> $log
	populations -t $cores -b ${batch} -P $outdircor/dereplicated_stacks_all_output -M $popmap -p $Min_pops -f p_value -k -r $Min_perc_pop -s -m $Min_stack_depth --structure --phylip --genepop --vcf --vcf_haplotypes --phase --fastphase --beagle --beagle_phased --plink --fasta $fstats $single $random $kern $winsize --merge_sites -- bootstrap --bootstrap_pifis --bootstrap_fst --bootstrap_div --bootstrap_phist &> $outdircor/dereplicated_stacks_all_output/log_populations.txt
		fi

exit 0
