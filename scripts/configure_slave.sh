#!/usr/bin/env bash
#
#  configure_slave.sh - Configure local or global akutils settings - modified for RADseq utility.
#
#  Version 1.0.0 (April, 18, 2016)
#
#  Copyright (c) 2015 Andrew Krohn
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
if [[ -f $configtest ]]; then
	rm $configtest
fi
if [[ -f $templatetest ]]; then
	rm $templatetest
fi
}
trap finish EXIT

## Find scripts location and set variables
scriptdir="$( cd "$( dirname "$0" )" && pwd )"
repodir=`dirname $scriptdir`
workdir=$(pwd)
stdout="$1"
stderr="$2"
randcode="$3"
globalconfigsearch=(`ls $repodir/resources/akutils_RADseq.global.config 2>/dev/null`)
localconfigsearch=(`ls akutils_RADseq*.config 2>/dev/null`)
DATE=`date +%Y%m%d-%I%M%p`
configtest="$repodir/temp/$randcode.config"
templatetest="$repodir/temp/$randcode.template"

	bold=$(tput bold)
	normal=$(tput sgr0)
	underline=$(tput smul)

## Start configuration process
	echo "
This will help you configure your akutils RADseq config file for running akutils
RADseq workflows.

First, would you like to configure your global settings or make a local config file
to override your global settings?  A local config file will reside within your
current directory.

Or else, you can choose rebuild if you want to generate a fresh global config file.
This is useful if you recently updated akutils RADseq utility and need to integrate
newly available configuration options.

Enter \"global,\" \"local,\" or \"rebuild.\"
"
	read globallocal

## Determine user supplied input
	if [[ ! $globallocal == "global" && ! $globallocal == "local" && ! $globallocal == "rebuild" ]]; then
		echo "Invalid entry. global, local, or rebuild only."
		read yesno
	if [[ ! $globallocal == "global" && ! $globallocal == "local" && ! $globallocal == "rebuild" ]]; then
		echo "Invalid entry. Exiting.
		"
		exit 1
	fi
	fi

## Rebuild option
	if [[ $globallocal == rebuild ]]; then
	echo "
OK. Building new global config file in akutils RADseq resources directory.
($repodir/resources/)
	"
	rm $repodir/resources/akutils_RADseq.global.config 2>/dev/null
	cat $repodir/resources/blank_config.config > $repodir/resources/akutils_RADseq.global.config
	configfile=($repodir/resources/akutils_RADseq.global.config)

	fi

## Global option
	if [[ "$globallocal" == "global" ]]; then
	echo "
OK. Checking for existing global config file in akutils RADseq resources directory.
($repodir/resources/)
	"
		if [[ ! -f "$globalconfigsearch" ]]; then
		echo "
No global config file detected in akutils RADseq resources directory.
($repodir/resources/)

Creating new global config file."
		cat $repodir/resources/blank_config.config > $repodir/resources/akutils_RADseq.global.config
		configfile=($repodir/resources/akutils_RADseq.global.config)
		else
		echo "Found existing global config file.
($globalconfigsearch)
	"
	configfile=($repodir/resources/akutils_RADseq.global.config)
	fi
	fi

## Local option
	if [[ "$globallocal" == "local" ]]; then
	echo "
OK. Checking for existing config file in current directory.
($workdir/)
	"

	## Offer to copy global file to local position
	if [[ ! -f "$localconfigsearch" ]]; then
	echo "
No config file detected in local directory. Creating new local config file.
	"
	if [[ -f "$globalconfigsearch" ]]; then
	echo "		
Found existing global config file.
($globalconfigsearch)

Do you want to generate a whole new config file or make a copy of the existing
global file and modify that (new or copy)?"
	read newcopy

		if [[ ! "$newcopy" == "new" && ! "$newcopy" == "copy" ]]; then
		echo "Invalid entry. new or copy only."
		read newcopy
			if [[ ! "$newcopy" == "new" && ! "$newcopy" == "copy" ]]; then
			echo "Invalid entry. Exiting.
			"
			exit 1
			fi
		fi

		if [[ "$newcopy" == "new" ]]; then
			echo "
OK. Creating new config file in your current directory.
($workdir/akutils_RADseq.$DATE.config)
		"
		cat $repodir/resources/blank_config.config > $workdir/akutils_RADseq.$DATE.config
		configfile=($workdir/akutils_RADseq.$DATE.config)
		fi

		if [[ $newcopy == "copy" ]]; then
		echo "
OK. Copying global config file for local use in your current directory.
($workdir/akutils_RADseq.$DATE.config)
		"
		cat $repodir/resources/akutils_RADseq.global.config > $workdir/akutils_RADseq.$DATE.config
		configfile=($workdir/akutils_RADseq.$DATE.config)
		fi
	fi
	else
	echo "Found local config file.
($localconfigsearch)
	"
	configfile=($localconfigsearch)
	fi
	fi

## Check config file against blank config file to determine if any new variables are available
	grep -v "#" $configfile | cut -f1 | sed '/^$/d' > $configtest
	grep -v "#" $repodir/resources/blank_config.config | cut -f1 | sed '/^$/d' > $templatetest
	configuniq=`grep -cvFf $templatetest $configtest`
	templateuniq=`grep -cvFf $configtest $templatetest`
	if [[ "$configuniq" -ge "1" ]]; then
	echo "
Your config file contains ${bold}${configuniq}${normal} extra variable setting(s). Consider running
the config utility and rebuilding your configuration options.

The extra lines present are:"
	grep -vFf $templatetest $configtest
	echo ""
	fi
	if [[ "$templateuniq" -ge "1" ]]; then
	echo "
$templateuniq additional configuration setting(s) are available, but not present in
your configuration file. Consider running the config utility and rebuilding your
configuration options.

New configuration options available are:"
	grep -vFf $configtest $templatetest
	echo ""
	fi

## Change settings for chosen config file
	echo "
File selected is:
$configfile
Reading configurable fields...
	"
	cat $configfile | grep -v "#" | grep -E -v '^$'

	echo "
I will now go through each configurable field and require your input. Press enter
to retain the current value or enter a new value. When entering paths (say, to
greengenes database) use absolute path and remember to use tab-autocomplete to
avoid errors. Settings are cap-sensitive and must be entered correctly, or you
may experience errors with your workflow. Hit <enter> when ready to proceed.
	"
	read -e nullvariable
	tput clear

for field in `grep -v "#" $configfile | cut -f 1`; do
	fielddesc1=`grep $field $configfile | grep "#" | cut -f 2`
	fielddesc2=`grep $field $configfile | grep "#" | cut -f 3`
	setting=`grep $field $configfile | grep -v "#" | cut -f 2`

	echo "
Field: ${bold}${fielddesc1}${normal}
Current setting is: ${bold}${setting}${normal}
$fielddesc2

Enter new value (or press enter to keep current setting):"
	read -e newsetting
	if [[ ! -z "$newsetting" ]]; then
	sed -i -e "s@^$field\t$setting@$field\t$newsetting@" $configfile
	echo "Setting changed.
	"
	else
	echo "Setting unchanged.
	"
	sleep 0.2
	fi
	tput clear
done

echo "$configfile updated.
"

exit 0
