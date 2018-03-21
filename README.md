### akutils_RADseq_utility  

RADseq analysis commands built on the akutils framework. Super easy to go from raw to analyzed data. Set up population data within a QIIME-inspired metadata file.  

Tested on Ubuntu OS locally and remotely on the Monsoon high performance computing system at NAU (CentOS). For local installs, follow instructions here (https://github.com/alk224/akutils_ubuntu_installer) to get all dependencies. For cluster environment just clone the repository, and call ea-utils (demultiplexing and quality filtering), bowtie2 (for reference-alignments), and stacks 1.37 or higher when issuing commands. Note that reference-based analysis remains untested as of 6-6-16 and is probably still non-functional.

Users of Monsoon at NAU can use the [slurm_builder.sh](https://github.com/alk224/akutils-v1.2/wiki/slurm_builder.sh) command from [akutils](http://alk224.github.io/akutils-v1.2/) to produce a functional slurm script for use with RADseq commands.

To get the RADseq_utility on your cluster account, simply clone this repo:  

    git clone https://github.com/alk224/akutils_RADseq_utility.git

To enable bash autocompletion for RADseq_utility, run the install script from within the cloned repository directory:  

    bash install  


Most help and usage files are in place. Use help or -h --help to view help files. Enter a command with no arguments to see usage.  

See [wiki pages](https://github.com/alk224/akutils_RADseq_utility/wiki) for specific command help and tutorial pages (coming soon).  

**Citing akutils RADseq utility:**  

Lela V. Andrews. (2018). akutils RADseq utility: Simplified processing of RADseq data through Stacks. Zenodo. 10.5281/zenodo.1205079

[![DOI](https://zenodo.org/badge/44690256.svg)](https://zenodo.org/badge/latestdoi/44690256)
