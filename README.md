# akutils_RADseq_utility
RADseq commands built on the akutils framework

Major restructuring underway as of 4-18-2016 ##
Expect major improvements in functionality as well
as allowing for combining of runs. RADseq workflow
now has its own config system to facilitate better
flexibility. Replicates are properly handled at
present by combining them according to your map file.

To enable bash autocompletion for RADseq_utility, run
the install script from within the repository
directory:

    bash install  


Most help and usage files are in place. Use help or
-h --help to view help files. Enter a command with
no arguments to see usage.

Script is functional if basic.  Need to add in variation on analysis that allow 
for analysis via samtools and for proper handling of replicate samples.

Also want a tool that allows reloading of existing data in case of system crash
which requires reinstallation.

