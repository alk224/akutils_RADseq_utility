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
	outdir3=($6)

	dbname=$(echo $db | cut -d"_" -f1)

## Search and replace functions to add links

	#output name
	sed -i "s/<!--anchor001-->/$db/g" $html

	#sumstats
	ssfilename="batch_${batch}.sumstats.tsv"
	ssfile="$outdir/$ssfilename"
	ssfile2="$outdir2/$ssfilename"
	cp $ssfile $outdir3/html/
	ssfile3="$outdir3/html/$ssfilename"
	if [[ -f "$ssfile" ]]; then 2>/dev/null
	sed -i "s|<!--anchor002-->|$ssfilename|" $html
	sed -i "s/<!--anchor002a-->/$ssfilename/" $html
	fi

	#sumsumstats
	sssfilename="batch_${batch}.sumstats_summary.tsv"
	sssfile="$outdir/$sssfilename"
	sssfile2="$outdir2/$sssfilename"
	cp $sssfile $outdir3/html/ 2>/dev/null
	sssfile3="$outdir3/html/$sssfilename"
	if [[ -f "$sssfile" ]]; then
	sed -i "s|<!--anchor003-->|$sssfilename|" $html
	sed -i "s/<!--anchor003a-->/$sssfilename/" $html
	fi

	#fst
	fstfilename="batch_${batch}.fst_summary.tsv"
	fstfile="$outdir/$fstfilename"
	fstfile2="$outdir2/$fstfilename"
	cp $fstfile $outdir3/html/ 2>/dev/null
	fstfile3="$outdir3/html/$fstfilename"
	if [[ -f "$fstfile" ]]; then
	sed -i "s|<!--anchor004-->|$fstfilename|" $html
	sed -i "s/<!--anchor004a-->/$fstfilename/" $html
	fi

	#fstpop
	cd $outdir
	fstpopfilename=$(ls batch_${batch}.fst_* 2>/dev/null | grep -v batch_${batch}.fst_summary.tsv 2>/dev/null)
	wait
	cd $workdir
	fstpopfile="$outdir/$fstpopfilename"
	fstpopfile2="$outdir2/$fstpopfilename"
	cp $fstpopfile $outdir3/html/ 2>/dev/null
	fstpopfile3="$outdir3/html/$fstpopfilename"
	if [[ -f "$fstpopfile" ]]; then
	sed -i "s|<!--anchor005-->|$fstpopfilename|" $html
	sed -i "s/<!--anchor005a-->/$fstpopfilename/" $html
	fi

	#phi
	phifilename="batch_${batch}.phistats.tsv"
	phifile="$outdir/$phifilename"
	phifile2="$outdir2/$phifilename"
	cp $phifile $outdir3/html/ 2>/dev/null
	phifile3="$outdir3/html/$phifilename"
	if [[ -f "$phifile" ]]; then
	sed -i "s|<!--anchor006-->|$phifilename|" $html
	sed -i "s/<!--anchor006a-->/$phifilename/" $html
	fi

	#phipop
	cd $outdir
	phipopfilename=$(ls batch_${batch}.phistats_*.tsv 2>/dev/null)
	wait
	cd $workdir
	phipopfile="$outdir/$phipopfilename"
	phipopfile2="$outdir2/$phipopfilename"
	cp $phipopfile $outdir3/html/ 2>/dev/null
	phipopfile3="$outdir3/html/$phipopfilename"
	if [[ -f "$phipopfile" ]]; then
	sed -i "s|<!--anchor007-->|$phipopfilename|" $html
	sed -i "s/<!--anchor007a-->/$phipopfilename/" $html
	fi

	#structure
	structurefilename="batch_${batch}.structure.tsv"
	structurefile="$outdir/$structurefilename"
	structurefile2="$outdir2/$structurefilename"
	cp $structurefile $outdir3/html/ 2>/dev/null
	structurefile3="$outdir3/html/$structurefilename"
	if [[ -f "$structurefile" ]]; then
	sed -i "s|<!--anchor008-->|$structurefilename|" $html
	sed -i "s/<!--anchor008a-->/$structurefilename/" $html
	fi

	#plink map
	plinkmapfilename="batch_${batch}.plink.map"
	plinkmapfile="$outdir/$plinkmapfilename"
	plinkmapfile2="$outdir2/$plinkmapfilename"
	cp $plinkmapfile $outdir3/html/ 2>/dev/null
	plinkmapfile3="$outdir3/html/$plinkmapfilename"
	if [[ -f "$plinkmapfile" ]]; then
	sed -i "s|<!--anchor009-->|$plinkmapfilename|" $html
	sed -i "s/<!--anchor009a-->/$plinkmapfilename/" $html
	fi

	#plink ped
	plinkpedfilename="batch_${batch}.plink.ped"
	plinkpedfile="$outdir/$plinkpedfilename"
	plinkpedfile2="$outdir2/$plinkpedfilename"
	cp $plinkpedfile $outdir3/html/ 2>/dev/null
	plinkpedfile3="$outdir3/html/$plinkpedfilename"
	if [[ -f "$plinkpedfile" ]]; then
	sed -i "s|<!--anchor010-->|$plinkpedfilename|" $html
	sed -i "s/<!--anchor010a-->/$plinkpedfilename/" $html
	fi

	#vcf
	vcffilename="batch_${batch}.vcf"
	vcffile="$outdir/$vcffilename"
	vcffile2="$outdir2/$vcffilename"
	cp $vcffile $outdir3/html/ 2>/dev/null
	vcffile3="$outdir3/html/$vcffilename"
	if [[ -f "$vcffile" ]]; then
	sed -i "s|<!--anchor011-->|$vcffilename|" $html
	sed -i "s/<!--anchor011a-->/$vcffilename/" $html
	fi

	#vcfhap
	vcfhapfilename="batch_${batch}.haplotypes.vcf"
	vcfhapfile="$outdir/$vcfhapfilename"
	vcfhapfile2="$outdir2/$vcfhapfilename"
	cp $vcfhapfile $outdir3/html/ 2>/dev/null
	vcfhapfile3="$outdir3/html/$vcfhapfilename"
	if [[ -f "$vcfhapfile" ]]; then
	sed -i "s|<!--anchor012-->|$vcfhapfilename|" $html
	sed -i "s/<!--anchor012a-->/$vcfhapfilename/" $html
	fi

	#genepop
	genepopfilename="batch_${batch}.genepop"
	genepopfile="$outdir/$genepopfilename"
	genepopfile2="$outdir2/$genepopfilename"
	cp $genepopfile $outdir3/html/ 2>/dev/null
	genepopfile3="$outdir3/html/$genepopfilename"
	if [[ -f "$genepopfile" ]]; then
	sed -i "s|<!--anchor013-->|$genepopfilename|" $html
	sed -i "s/<!--anchor013a-->/$genepopfilename/" $html
	fi

	#phylip
	phylipfilename="batch_${batch}.phylip"
	phylipfile="$outdir/$phylipfilename"
	phylipfile2="$outdir2/$phylipfilename"
	cp $phylipfile $outdir3/html/ 2>/dev/null
	phylipfile3="$outdir3/html/$phylipfilename"
	if [[ -f "$phylipfile" ]]; then
	sed -i "s|<!--anchor014-->|$phylipfilename|" $html
	sed -i "s/<!--anchor014a-->/$phylipfilename/" $html
	fi

	#haplotypes
	hapfilename="batch_${batch}.haplotypes.tsv"
	hapfile="$outdir/$hapfilename"
	hapfile2="$outdir2/$hapfilename"
	cp $hapfile $outdir3/html/ 2>/dev/null
	hapfile3="$outdir3/html/$hapfilename"
	if [[ -f "$hapfile" ]]; then
	sed -i "s|<!--anchor015-->|$hapfilename|" $html
	sed -i "s/<!--anchor015a-->/$hapfilename/" $html
	fi

	#haplotypestats
	hapsfilename="batch_${batch}.hapstats.tsv"
	hapsfile="$outdir/$hapsfilename"
	hapsfile2="$outdir2/$hapsfilename"
	cp $hapsfile $outdir3/html/ 2>/dev/null
	hapsfile3="$outdir3/html/$hapsfilename"
	if [[ -f "$hapsfile" ]]; then
	sed -i "s|<!--anchor016-->|$hapsfilename|" $html
	sed -i "s/<!--anchor016a-->/$hapsfilename/" $html
	fi

	#markers
	markfilename="batch_${batch}.markers.tsv"
	markfile="$outdir/$markfilename"
	markfile2="$outdir2/$markfilename"
	cp $markfile $outdir3/html/ 2>/dev/null
	markfile3="$outdir3/html/$markfilename"
	if [[ -f "$markfile" ]]; then
	sed -i "s|<!--anchor017-->|$markfilename|" $html
	sed -i "s/<!--anchor017a-->/$markfilename/" $html
	fi

	#fasta
	fastafilename="batch_${batch}.fa"
	fastafile="$outdir/$fastafilename"
	fastafile2="$outdir2/$fastafilename"
	cp $fastafile $outdir3/html/ 2>/dev/null
	fastafile3="$outdir3/html/$fastafilename"
	if [[ -f "$fastafile" ]]; then
	sed -i "s|<!--anchor018-->|$fastafilename|" $html
	sed -i "s/<!--anchor018a-->/$fastafilename/" $html
	fi

exit 0
