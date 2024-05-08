#!/bin/bash
set -e -o pipefail

#######################################
# load environment variables for EvoSeq
source ./../../env.sh

#######################################
# set project-specific variables
threads=4 # The number of threads to use. Default = 4.

#######################################


############################################################
if [[ ! -d tmp ]]
then
    mkdir tmp
fi


echo "processing FastQC for all fastq.gz files ..."
$fastqc_dir/fastqc --dir ./tmp --threads $threads *.fastq.gz
$multiqc_dir/multiqc -d -o MultiQC_outputs *fastqc.zip  


rm -r tmp


############################
# checking bash exit status
if [[ $? -eq 0 ]]
then
    echo ""
    echo "#########################################################################"
    echo ""
    echo "EvoSeq message: This bash script has been successfully processed! :)"
    echo ""
    echo "#########################################################################"
    echo ""
    exit 0
fi
############################
