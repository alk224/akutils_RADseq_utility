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



exit 0
