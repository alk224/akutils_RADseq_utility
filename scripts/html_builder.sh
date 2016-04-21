#!/usr/bin/env bash
#
#  html_builder.sh - html building script for RADseq workflow
#
#  Version 0.9 (April 20, 2016)
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

	html=($1)
	outdir=($2)
	batch=($3)
	db=($4)
	outdir2=($5)

## Search and replace functions to add links

	#output name
	sed -i "s/<!--anchor001-->/$db/g" $html

	#structure
	structurefilename="batch_${batch}.structure.tsv"
	structurefile="$outdir/$structurefilename"
	structurefile2="$outdir2/$structurefilename"
	if [[ -f "$structurefile" ]]; then
	sed -i "s|<!--anchor002-->|$structurefile2|" $html
	sed -i "s/<!--anchor002a-->/$structurefilename/" $html
	fi

	#plink map
	plinkmapfilename="batch_${batch}.plink.map"
	plinkmapfile="$outdir/$plinkmapfilename"
	plinkmapfile2="$outdir2/$plinkmapfilename"
	if [[ -f "$plinkmapfile" ]]; then
	sed -i "s|<!--anchor003-->|$plinkmapfile2|" $html
	sed -i "s/<!--anchor003a-->/$plinkmapfilename/" $html
	fi

	#plink ped
	plinkpedfilename="batch_${batch}.plink.ped"
	plinkpedfile="$outdir/$plinkpedfilename"
	plinkpedfile2="$outdir2/$plinkpedfilename"
	if [[ -f "$plinkpedfile" ]]; then
	sed -i "s|<!--anchor004-->|$plinkpedfile2|" $html
	sed -i "s/<!--anchor004a-->/$plinkpedfilename/" $html
	fi

	#vcf
	vcffilename="batch_${batch}.vcf"
	vcffile="$outdir/$vcffilename"
	vcffile2="$outdir2/$vcffilename"
	if [[ -f "$vcffile" ]]; then
	sed -i "s|<!--anchor005-->|$vcffile2|" $html
	sed -i "s/<!--anchor005a-->/$vcffilename/" $html
	fi

	#genepop
	genepopfilename="batch_${batch}.genepop"
	genepopfile="$outdir/$genepopfilename"
	genepopfile2="$outdir2/$genepopfilename"
	if [[ -f "$vcffile" ]]; then
	sed -i "s|<!--anchor006-->|$genepopfile2|" $html
	sed -i "s/<!--anchor006a-->/$genepopfilename/" $html
	fi

	#phylip
	phylipfilename="batch_${batch}.phylip"
	phylipfile="$outdir/$phylipfilename"
	phylipfile2="$outdir2/$phylipfilename"
	if [[ -f "$vcffile" ]]; then
	sed -i "s|<!--anchor007-->|$phylipfile2|" $html
	sed -i "s/<!--anchor007a-->/$phylipfilename/" $html
	fi

	#fasta
	fastafilename="batch_${batch}.fa"
	fastafile="$outdir/$fastafilename"
	fastafile2="$outdir2/$fastafilename"
	if [[ -f "$vcffile" ]]; then
	sed -i "s|<!--anchor008-->|$fastafile2|" $html
	sed -i "s/<!--anchor008a-->/$fastafilename/" $html
	fi

exit 0
