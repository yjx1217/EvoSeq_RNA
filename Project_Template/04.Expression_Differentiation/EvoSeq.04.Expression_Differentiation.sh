#!/bin/bash
# set -e -o pipefail

#######################################
# load environment variables for EvoSeq
source ./../../env.sh

#######################################
# set project-specific variables
batch_id="Batch_PRJNA928788" # The batch id for this analysis. This batch id will also be used as the output directory name. Default = "Batch_TEST".
master_sample_table="Master_Sample_Table.${batch_id}.txt" # The master sample table for this batch. Default = "Master_Sample_Table.${batch_id}.txt".
contrast="biological_sample,OE,CT" # contrasting_variable,test_group_tag,control_group_tag  
deseq_test_method="LRT" # either "Wald" or "LRT", which will then use either Wald significance tests, or the likelihood ratio test. Default = "LRT".
log2foldchange_cutoff=0.58 # The cutoff for log2 fold change. Default = 0.58.
adj_p_value_cutoff=0.05 # The cutoff for multiple-test adjusted p-value. Default = 0.05. 

##################################
#top_n_genes=20 # The number of top differentiated genes to show with heatmap. Default = 20.
#reduced_model_formula="W_1"
#reduced_model_formula="W_1+treatment_condition+sampling_timepoint" # The reduced model formula for DEseq2 (but without "-" and "~" characters). For EvoSeq, this option should normally be one of the following: "W_1+biological_sample+sampling_timepoint" or "W_1+treatment_condition+sampling_timepoint". Default = "~W_1+treatment_condition+sampling_timepoint".
#full_model_formula_extra_term="treatment_condition:sampling_timepoint" # The additional term of the full model formula for DEseq2. With EvoSeq, we use this term to specify the time-dependent interaction term such as "biological_sample:sampling_timepoint" and "treatment_condition:sampling_timepoint". Default = "treatment_conditon:sampling_timepoint".
#full_model_formula_extra_term="treatment_condition" 


#######################################

#######################################
# process the pipeline
# normally, no need to change the following parameters
reference_preprocessing_dir="./../01.Reference_Preprocessing"
expression_exploration_dir="./../03.Expression_Exploration"
transcript2gene_map="./../01.Reference_Preprocessing/ref.transcript2gene_map.txt" # The ref.transcript2gene_map.txt file generated in ./../01.Reference_Preprocessing. 
#######################################

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

echo "master_sample_table=$master_sample_table"
echo "transcript2gene_map=$transcript2gene_map"
echo "count_data_for_DEG=$expression_exploration_dir/$batch_id/$batch_id.count_data_for_DEG.txt"
echo "col_data_for_DEG=$expression_exploration_dir/$batch_id/$batch_id.col_data_for_DEG.txt"
echo ""

mkdir $batch_id
cd $batch_id

Rscript $EVOSEQ_HOME/scripts/expression_differentiation.R \
    --master_sample_table ./../$master_sample_table \
    --transcript2gene_map ./../$transcript2gene_map \
    --count_data_for_DEG ./../$expression_exploration_dir/$batch_id/$batch_id.count_data_for_DEG.txt \
    --col_data_for_DEG ./../$expression_exploration_dir/$batch_id/$batch_id.col_data_for_DEG.txt \
    --contrast $contrast \
    --log2foldchange_cutoff $log2foldchange_cutoff \
    --adj_p_value_cutoff $adj_p_value_cutoff \
    --batch_id $batch_id || exit 1

#   --reduced_model_formula $reduced_model_formula \
#    --full_model_formula_extra_term $full_model_formula_extra_term \

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
