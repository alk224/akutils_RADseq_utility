#!/usr/bin/env bash
#
#  combine-data.sh - combine-data script for RADseq workflow
#
#  Version 0.9 (June 07, 2016)
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
if [[ -f $sourceids ]]; then
	rm $sourceids
fi
if [[ -f $targetids ]]; then
	rm $targetids
fi
if [[ -f $dupids ]]; then
	rm $dupids
fi
if [[ -f $copyrec ]]; then
	rm $copyrec
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
	source=($4)
	target=($5)

## Test that source directory is valid or exit
	if [[ ! -d "$source" ]]; then
		echo "
Your supplied source directory does not appear to be valid.
Exiting.

Source dir as supplied:
$source
		"
		exit 1
	fi

## Test that demult-derep has been run in source directory or exit
	if [[ ! -d "$source/demult-derep_output" ]]; then
		echo "
No demult-derep_output directory in supplied source directory. Run the demult-
derep script first before attempting to combine data. Exiting
		"
		cat $repodir/docs/demult-derep.usage
		exit 1
	fi

## Test for target directory and create if necessary
	if [[ ! -d "$target" ]]; then
		istarget="no"
		echo "
Target directory does not exist. Creating new directory for combining data into.

New target dir: $target"
		mkdir -p $target/demult-derep_output/dereplicated_combined_data
	else
		istarget="yes"
	fi

## If samples already present in target, check that no two sample names are alike
	targetpop="$target/demult-derep_output/populations_file.txt"
	sourcepop="$source/demult-derep_output/populations_file.txt"
	sourceids="$tempdir/${randcode}_sourceids"
	cat $sourcepop | cut -f1 > $sourceids
	if [[ "$istarget" == "yes" ]]; then
	if [[ -f "$targetpop" ]]; then
		targetids="$tempdir/${randcode}_targetids"
		cat $sourcepop | cut -f1 > $sourceids
		cat $targetpop | cut -f1 > $targetids
		dupids="$tempdir/${randcode}_dupids"
		for line in `cat $sourceids`; do
		comptest=$(grep -w "$line" $targetids 2>/dev/null | wc -l)
			if [[ "$comptest" -ge "1" ]]; then
			grep -w "$line" $targetids >> $dupids
			fi
		done
	fi

	## If duplicates found, filter against existing samples and report
	if [[ -f "$dupids" ]]; then
		echo "
Duplicate sample IDs found. Skipping these samples:"
		cat $dupids
		echo ""
			for line in `cat $dupids`; do
			sed -i "/$line/d" $sourceids
			done
	fi
	fi

## Copy populations and metadata to target directory
	if [[ "$istarget" == "no" ]]; then
		cp $source/demult-derep_output/populations_file.txt $target/demult-derep_output/populations_file.txt
		cp $source/demult-derep_output/metadata_file.txt $target/demult-derep_output/metadata_file.txt
		cp $source/demult-derep_output/repfile.txt $target/demult-derep_output/repfile.txt
	else

		mkdir $target/demult-derep_output
		for line in `cat $sourceids`; do
		grep -w $line $source/demult-derep_output/populations_file.txt >> $target/demult-derep_output/populations_file.txt
		grep -w $line $source/demult-derep_output/metadata_file.txt >> $target/demult-derep_output/metadata_file.txt
		grep -w $line $source/demult-derep_output/repfile.txt >> $target/demult-derep_output/repfile.txt
		done
	fi

## Copy sample data to target directory
	echo "
Copying sample fastq data to target directory.
	"
cat $sourceids
	copyrec="$tempdir/${randcode}_copyrecord"
	for line in `cat $sourceids`; do
		if [[ -f ${source}/demult-derep_output/dereplicated_combined_data/${line}.fq ]]; then
			if [[ ! -d ${target}/demult-derep_output/dereplicated_combined_data ]]; then
				mkdir -p ${target}/demult-derep_output/dereplicated_combined_data
			fi
		cp ${source}/demult-derep_output/dereplicated_combined_data/${line}.fq ${target}/demult-derep_output/dereplicated_combined_data/${line}.fq
		echo "cp ${source}/demult-derep_output/dereplicated_combined_data/${line}.fq ${target}/demult-derep_output/dereplicated_combined_data/${line}.fq"
		echo $line.fq >> $copyrec
		fi
		wait
	done
echo "copyrec file:"
cat $copyrec
## Report completion
	if [[ -f $copyrec ]]; then
	echo "Combine-data function complete.

Copied the following fastq files to target directory:"
	cat $copyrec
	echo ""
	else
	echo "There may have been a problem. Check your data and retry the command.
	"
	fi

exit 0
