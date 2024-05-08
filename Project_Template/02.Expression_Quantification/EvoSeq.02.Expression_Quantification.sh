#!/bin/bash
set -e -o pipefail

#######################################
# load environment variables for EvoSeq
source ./../../env.sh

#######################################
# set project-specific variables
batch_id="Batch_PRJNA928788" # The batch id for this analysis. This batch id will also be used as the output directory name. Default = "Batch_SRP029880".
master_sample_table="Master_Sample_Table.${batch_id}.txt" # The master sample table for this batch. Default = "Master_Sample_Table.${batch_id}.txt".
threads=4 # The number of threads to use. Default = "4".
library_type="PE"  # The library layout of the sequecing data: "PE" or "SE". Default = "PE".
#######################################

#######################################
# process the pipeline
rnaseq_reads_dir="./../00.RNAseq_Reads"
reference_preprocessing_dir="./../01.Reference_Preprocessing"


test_file_existence () {
    filename=$1
    if [[ ! -f $filename ]]
    then
        echo "the file $filename does not exists! process terminated!"
        exit
    else
        echo "test pass."
    fi
}

if [[ $library_type == "PE" ]]; then
    while read -r line
    do
    [[ $line == \#* ]] && continue
    [[ $line == "" ]] && continue
    [[ $line == sample_id* ]] && continue
    IFS=$'\t' read -r sample_id PE_read_files biological_sample treatment_condition sampling_timepoint replicate_line sequencing_run note <<<"$line"
    echo "processing the sample $sample_id ..."
    R1_read_file=$(echo $PE_read_files|cut -d ',' -f 1)
    R2_read_file=$(echo $PE_read_files|cut -d ',' -f 2)

    echo ""
    echo "check the existence of reference_raw_assembly: $R1_read_file at $rnaseq_reads_dir"
    test_file_existence "$rnaseq_reads_dir/$R1_read_file"
    echo "check the existence of reference_raw_assembly: $R2_read_file at $rnaseq_reads_dir"
    test_file_existence "$rnaseq_reads_dir/$R2_read_file"
    echo ""

    $salmon_dir/salmon quant \
	-i $reference_preprocessing_dir/SalmonIndex \
	-p $threads \
	-l A \
	-1 $rnaseq_reads_dir/$R1_read_file \
	-2 $rnaseq_reads_dir/$R2_read_file \
	--validateMappings \
	--gcBias \
	--seqBias \
	--posBias \
	--quiet \
	-o $sample_id.transcripts_quant

    if [[ ! -d $batch_id ]]
    then
	mkdir $batch_id
	mv $sample_id.transcripts_quant $batch_id
    else
	mv $sample_id.transcripts_quant $batch_id
    fi
    
    done < $master_sample_table
else
    while read -r line
    do
    [[ $line == \#* ]] && continue
    [[ $line == "" ]] && continue
    [[ $line == sample_id* ]] && continue
    IFS=$'\t' read -r sample_id PE_read_files biological_sample treatment_condition sampling_timepoint replicate_line sequencing_run note <<<"$line"

    echo ""
    echo "check the existence of reference_raw_assembly: $PE_read_files at $rnaseq_reads_dir"
    test_file_existence "$rnaseq_reads_dir/$PE_read_files"
    echo ""

    $salmon_dir/salmon quant \
	-i $reference_preprocessing_dir/SalmonIndex \
	-p $threads \
	-l A \
	-r $rnaseq_reads_dir/$PE_read_files \
	--validateMappings \
	--gcBias \
	--seqBias \
	--posBias \
	--quiet \
	-o $sample_id.transcripts_quant

    if [[ ! -d $batch_id ]]
    then
	mkdir $batch_id
	mv $sample_id.transcripts_quant $batch_id
    else
	mv $sample_id.transcripts_quant $batch_id
    fi
    
    done < $master_sample_table
fi

##################################
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
