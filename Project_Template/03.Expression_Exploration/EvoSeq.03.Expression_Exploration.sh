#!/bin/bash
set -e -o pipefail

#######################################
# load environment variables for EvoSeq
source ./../../env.sh

#######################################
# set project-specific variables
batch_id="Batch_PRJNA928788" # The batch id for this analysis. This batch id will also be used as the output directory name. Default = "Batch_TEST".
master_sample_table="Master_Sample_Table.${batch_id}.txt" # The master sample table for this batch. Default = "Master_Sample_Table.${batch_id}.txt".
min_sample="3" # The minimal number of comparable samples to be considered. Default = "3". 
min_counts="5" # The minimal number of gene-specific read counts to be considered. Default = "5".
transformation_method="log2" # The read count transformation method for data exploration: "log2", "rlog", or "vst". Default = "rlog".
normalization_method="by_replicate" # The normalization method: "by_ERCC" or "by_replicate". Default = "by_replicate". 
running_mode="lite" # The running mode: "lite" (with less diagnostic plots) or "full" (with more diagnostic plots). Default = "lite".
transcript2gene_map="./../01.Reference_Preprocessing/ref.transcript2gene_map.txt" # The ref.transcript2gene_map.txt file generated in ./../01.Reference_Preprocessing. 
########################################

########################################
# process the pipeline
# normally, no need to change the following parameters
reference_preprocessing_dir="./../01.Reference_Preprocessing"
expression_quantification_dir="./../02.Expression_Quantification/${batch_id}"
########################################

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

test -d $batch_id || mkdir $batch_id
cd $batch_id

#perl $EVOSEQ_HOME/scripts/assemble_counts_for_all_samples.pl \
#     -i ./../$master_sample_table \
#     -b $batch_id \
#     -q ./../$expression_quantification_dir \
#     -o $batch_id.quant_summary_table.txt

Rscript --vanilla --slave ../../../scripts/transcript_quant2gene_quant.R \
	--indir ./../$expression_quantification_dir \
	--tx2gene_map ./../$transcript2gene_map \
	--output $batch_id.quant_summary_table.txt
    
echo "master_sample_table=$master_sample_table"
echo "quant_summary_table=$batch_id.quant_summary_table.txt"
echo ""

Rscript $EVOSEQ_HOME/scripts/expression_exploration.R \
    --master_sample_table ./../$master_sample_table \
    --quant_summary_table "$batch_id.quant_summary_table.txt" \
    --min_sample $min_sample \
    --min_counts $min_counts \
    --transformation_method $transformation_method \
    --normalization_method $normalization_method \
    --running_mode $running_mode \
    --batch_id $batch_id

if [[ -e Rplots.pdf ]]
then
    rm Rplots.pdf
fi

cd ..


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
