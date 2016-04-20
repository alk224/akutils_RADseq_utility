#!/usr/bin/env bash
#
#  metadata_builder.sh - generate metadata file for RADseq workflow
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

## Query user for information

	echo "
This will help you to build a metadata file for processing through the workflow.

Enter the number of samples in your data set (<96):
"
	read sampleno

	sampleno1=$((${sampleno}+1))

	echo "
Enter a name for these samples. This will be embedded in the sample name like
this, map.<name_you_enter_here>.txt
"
	read mapname

## Copy blank metadata file to local directory with correct number of lines
	newmap="map.${mapname}.txt"
	cat $repodir/resources/metadata.txt | head -$sampleno1 > $newmap

## Report results, further instructions
	echo "
Your new metadata file (mapping file) can be found in your local directory.
Filename: $newmap
#Samples: $sampleno

You need to review your map file in a spreadsheet to ensure the information is
correct. You need to add unique sample names, correct index sequences and
replicate structure (if you used replicates).
	"

exit 0
