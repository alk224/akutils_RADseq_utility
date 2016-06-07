#!/usr/bin/env bash
#
#  db-unload.sh - db-unload script for RADseq workflow
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

	stdout=($1)
	stderr=($2)
	randcode=($3)
	dbdir=($4)

	log=$(ls $dbdir/log_*)
	db=$(cat $dbdir/.dbname)

## Check that mysql is present before continuing
	mysqltest=$(command -v mysql 2>/dev/null | wc -l)
	if [[ "$mysqltest" == "0" ]]; then
	echo "
MySql does not seem to be present on your system. Aborting.
"
	exit 1
	fi

## Report function
	echo "
Removing your analysis from MySql.
Database: $db
"
	echo "Removing Stacks output from MySql database.
" >> $log

	# drop mysql database
	mysql -e "DROP DATABASE $db" 2>/dev/null || true

	echo "Database removed.
"

exit 0
