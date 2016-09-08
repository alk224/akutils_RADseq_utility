#!/usr/bin/env bash
#
#  map_check.sh - check metadata file for RADseq workflow
#
#  Version 0.9 (September 5, 2016)
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
if [[ -f $temp1 ]]; then
	rm $temp1
fi
if [[ -f $temp2 ]]; then
	rm $temp2
fi
if [[ -f $temp3 ]]; then
	rm $temp3
fi
if [[ -f $temp4 ]]; then
	rm $temp4
fi
if [[ -f $temp5 ]]; then
	rm $temp5
fi
if [[ -f $temp6 ]]; then
	rm $temp6
fi
if [[ -f $temp7 ]]; then
	rm $temp7
fi
if [[ -f $temp8 ]]; then
	rm $temp8
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
	map=($4)

	if [[ -z "$map" ]]; then
		echo "
You need to supply a valid metadata file to check:
RADseq_utility metadata_check map.file.txt
		"
	exit 1
	fi

## Define temp file(s) for different checks
	temp1="$tempdir/$randcode.dupid.check.temp"
	temp2="$tempdir/$randcode.dupid.linecount.temp"
	temp3="$tempdir/$randcode.dupid.dupsamples.temp"
	temp4="$tempdir/$randcode.repcheck0.temp"
	temp5="$tempdir/$randcode.repcheck1.temp"
	temp6="$tempdir/$randcode.repcheck2.temp"
	temp7="$tempdir/$randcode.repcheck3.temp"
	temp8="$tempdir/$randcode.repcheck4.temp"

	grep -v "#" $map | cut -f2 > $temp1
	grep -v "#" $map | cut -f2 > $temp4

##Check map file for duplicate sample ID
	for line in `cat $temp1`; do
		count=$(grep -w "$line" $temp1 | wc -l)
		echo "$line $count" >> $temp2
			if [[ $count -ge "2" ]]; then
				echo $line >> $temp3
			fi
	done

## Report on duplicate sampleIDs if present
	if [[ -f "$temp3" ]]; then
		echo "
The following sample names are duplicated within your metadata file:"
		cat $temp3 | sort | uniq -d
	fi

##Check map file for sample IDs with duplicate rep values
	for line in `cat $temp4`; do
		count=$(grep -w "$line" $temp4 | wc -l)
		echo "$line $count" >> $temp5
			if [[ $count -ge "2" ]]; then
				echo $line >> $temp6
			fi
	done

## Report on duplicate sampleID reps if present
	if [[ -f "$temp6" ]]; then
		echo "
The following sample names have duplicated replicate IDs in your metadata file:"
		cat $temp6 | sort | uniq -d
	fi

##Check map file for sample IDs missing replicate values
	for line in `cat $temp4`; do
		repcheck=$(echo $line | cut -d"." -f2)
		if [[ -z "$repcheck" ]]; then
			echo $line >> $temp8
		fi
	done

## Report on duplicate sampleID reps if present
	if [[ -f "$temp8" ]]; then
		echo "
The following sample names are missing replicate IDs in your metadata file:"
		cat $temp8 | sort | uniq -d
		echo "
Please add a replicate value to these samples like this:
SampleID0.1
SampleID0.2
		"
	fi

## If no errors, indicate success

	if [[ ! -f "$temp3" && ! -f "$temp6" && ! -f "$temp8" ]]; then
	echo "
Mapping file validated.
	"
	fi

exit 0
