#!/usr/bin/env Rscript
# last update: 20240221
library(optparse)
library(RColorBrewer)
library(ggplot2)
library(ggrepel)
library(gplots)
library(corrplot)
library(stats)
library(reshape2)
library(pheatmap)
library(DESeq2)

option_list <- list(
  make_option(
    c("--master_sample_table"),
    type = "character",
    default = NULL,
    help = "name of the sample table file",
    metavar = "character"
  ),
  make_option(
    c("--transcript2gene_map"),
    type = "character",
    default = NULL,
    help = "the transcript2gene map generated by module 01.Reference_Preprocessing",
    metavar = "character"
  ),
  make_option(
    c("--count_data_for_DEG"),
    type = "character",
    default = NULL,
    help = "name of the sample table file",
    metavar = "character"
  ),
  make_option(
    c("--col_data_for_DEG"),
    type = "character",
    default = NULL,
    help = "name of the gene quant summary table file",
    metavar = "character"
  ),
  make_option(
    c("--contrast"),
    type = "character",
    default = "treatment_condition,treated,control",
    help = "contrast specification for differential expression detection",
    metavar = "character"
  ),
  make_option(
    c("--deseq_test_method"),
    type = "character",
    default = "LRT",
    help = "Statistical method used to test differential expression",
    metavar = "character"
  ),
  make_option(
    c("--reduced_model_formula"),
    type = "character",
    default = "~ W_1 + treatment_condition + sampling_timepoint",
    help = "reduced design formula for DEseq2",
    metavar = "character"
  ),
  make_option(
    c("--full_model_formula_extra_term"),
    type = "character",
    default = "treatment_conditon:sampling_timepoint",
    help = "the extra_term for DEseq2's full design formula",
    metavar = "character"
  ),
  make_option(
    c("--top_n_genes"),
    type = "integer",
    default = 20,
    help = "the number of top DEGs to show in heatmap",
    metavar = "character"
  ),
  make_option(
    c("--log2foldchange_cutoff"),
    type = "double",
    default = "1",
    help = "log2foldchange cutoff",
    metavar = "character"
  ),
  make_option(
    c("--adj_p_value_cutoff"),
    type = "double",
    default = "0.05",
    help = "adjusted p-value cutoff",
    metavar = "character"
  ),
  make_option(
    c("--batch_id"),
    type = "character",
    default = NULL,
    help = "batch_id",
    metavar = "character"
  )
)

opt_parser <- OptionParser(option_list = option_list)
opt <- parse_args(opt_parser)
log2foldchange_bound <- 5

###############
# # for local testing only
# setwd("/Users/yjx/Downloads/Evoseq_Debug")
# opt$master_sample_table <- "Master_Sample_Table.Batch1_Aneup_T0_test.txt"
# opt$transcript2gene_map <- "ref.transcript2gene_map.txt"
# opt$count_data_for_DEG <- "Batch1_Aneup_T0.count_data_for_DEG.txt"
# opt$col_data_for_DEG <- "Batch1_Aneup_T0.col_data_for_DEG.txt"
# opt$contrast <- "treatment_condition,RM,YPD"
# opt$reduced_model_formula <-
#   "W_1"
# opt$full_model_formula_extra_term <-
#   opt$contrast[1]
# opt$top_n_genes <- 20
# opt$batch_id <- "Batch1_Aneup_T0"
#############


opt$contrast <- unlist(strsplit(opt$contrast, ",")[[1]])
opt$reduced_model_formula <- "W_1"
opt$full_model_formula_extra_term <- opt$contrast[1]

transcript2gene_map <-
  read.table(
    opt$transcript2gene_map,
    header = TRUE,
    stringsAsFactors = TRUE,
    sep = "\t"
  )

gene_id2gene_name <-
  unique(data.frame(transcript2gene_map$gene_id, transcript2gene_map$gene_name))
colnames(gene_id2gene_name) <- c("gene_id", "gene_name")


query_sample_id <- read.table(opt$master_sample_table, sep="\t", header=TRUE)  # for subset col & count data
query_sample_id <- subset(query_sample_id, eval(as.name(opt$contrast[1])) %in% opt$contrast[2:3])

count_data_for_DEG_raw <-
  read.table(
    opt$count_data_for_DEG,
    header = TRUE,
    row.names = 1,
    stringsAsFactors = TRUE,
    sep = "\t"
  )
count_data_for_DEG <- count_data_for_DEG_raw[query_sample_id$sample_id]

count_data_for_DEG <-
  count_data_for_DEG[, order(colnames(count_data_for_DEG))]


col_data_for_DEG_raw <-
  read.table(
    opt$col_data_for_DEG,
    header = TRUE,
    row.names = NULL,
    stringsAsFactors = TRUE,
    sep = "\t"
  )

col_data_for_DEG <- subset(col_data_for_DEG_raw, sample_id %in% query_sample_id$sample_id)

col_data_for_DEG$biological_replicate_group <-
  paste(
    col_data_for_DEG$biological_sample,
    col_data_for_DEG$treatment_condition,
    col_data_for_DEG$sampling_timepoint,
    col_data_for_DEG$biological_replicate_id,
    sep = "_"
  )

#################
rownames(col_data_for_DEG) <-
  col_data_for_DEG$biological_replicate_group
col_data_for_DEG <-
  col_data_for_DEG[order(row.names(col_data_for_DEG)), ]
######################

col_data_for_DEG[, c(
  "sampling_timepoint",
  "biological_replicate_id",
  "technical_replicate_id",
  "biological_replicate_group"
)] <-
  lapply(col_data_for_DEG[, c(
    "sampling_timepoint",
    "biological_replicate_id",
    "technical_replicate_id",
    "biological_replicate_group"
  )], factor)


rownames(col_data_for_DEG) <- NULL

reduced_model_formula <-
  gsub("\\+", " \\+ ", opt$reduced_model_formula)
reduced_model_formula <- paste0("~ ", reduced_model_formula)
full_model_formula <-
  paste0(reduced_model_formula,
         " + ",
         opt$full_model_formula_extra_term)


# DEG identification

if(opt$deseq_test_method == "LRT") {
  dds <-
  DESeqDataSetFromMatrix(
    countData = count_data_for_DEG,
    colData = col_data_for_DEG,
    design = as.formula(full_model_formula)
  )

  # collapsing technical replicates if any
  dds_collapsed <-
    collapseReplicates(dds,
                       col_data_for_DEG$biological_replicate_group,
                       dds$technical_replicate_id)

  dds <-
  DESeq(dds,
        test = "LRT",
        reduced = as.formula(reduced_model_formula))
  dds_clean <- dds[which(mcols(dds)$fullBetaConv),]
  betas <- coef(dds_clean)
  res0 <- results(dds_clean, contrast=opt$contrast)
  res <- lfcShrink(dds_clean, contrast = opt$contrast, res = res0, type = "normal")

} else if (opt$deseq_test_method == "Wald") {
  dds <-
    DESeqDataSetFromMatrix(
      countData = count_data_for_DEG,
      colData = col_data_for_DEG,
      design = formula(paste0("~", opt$contrast[1]))
    )
  
  dds <- DESeq(dds)
  res0 <- results(dds, contrast=opt$contrast)
  res <- lfcShrink(dds, contrast = opt$contrast, res = res0, type = "normal")

} else {
  print("Invalid parameters. Please use 'LRT' or 'Wald' as the test method.")
}


res_sorted <- as.data.frame(res[order(res$padj), ])
res_sorted <- cbind(rownames(res_sorted), res_sorted)
colnames(res_sorted) <-
  c("gene_id",
    "base_mean",
    "log2FoldChange",
    "lfcSE",
    "stat",
    "p_value",
    "adj_p_value")

res_sorted <-
  merge(res_sorted, gene_id2gene_name, by = "gene_id", sort = FALSE)



# set along_timecourse out dir
home_dir <- getwd()
along_timecourse_out_dir <-
  paste0(home_dir, "/contrast_DEG_out/")
dir.create(along_timecourse_out_dir)
setwd(along_timecourse_out_dir)

write.table(
  res_sorted,
  file = paste0(opt$batch_id, ".contrast_DEG.full_table.txt"),
  sep = "\t",
  quote = FALSE,
  row.names = FALSE
)

res_sorted_for_volcanoplot <- res_sorted
res_sorted_for_volcanoplot$class <- "no"
res_sorted_for_volcanoplot$class[res_sorted_for_volcanoplot$log2FoldChange > opt$log2foldchange_cutoff &
                                   res_sorted_for_volcanoplot$adj_p_value < opt$adj_p_value_cutoff] <-
  "up"
res_sorted_for_volcanoplot$class[res_sorted_for_volcanoplot$log2FoldChange < -opt$log2foldchange_cutoff &
                                   res_sorted_for_volcanoplot$adj_p_value < opt$adj_p_value_cutoff] <-
  "down"

res_sorted_for_volcanoplot$label <-
  res_sorted_for_volcanoplot$gene_name
res_sorted_for_volcanoplot$label[res_sorted_for_volcanoplot$class == "no"] <-
  NA

volcanoplot_palette <- c("blue", "red", "grey")
names(volcanoplot_palette) <- c("down", "up", "no")

p <- ggplot(data = res_sorted_for_volcanoplot,
            aes(
              x = log2FoldChange,
              y = -log10(adj_p_value),
              col = class,
              label = label
            )) +
  geom_point(alpha = 0.3) +
  geom_text_repel() +
  geom_vline(
    xintercept = c(-opt$log2foldchange_cutoff, opt$log2foldchange_cutoff),
    col = "black",
    linetype = "dashed"
  ) +
  geom_hline(
    yintercept = -log10(opt$adj_p_value_cutoff),
    col = "black",
    linetype = "dashed"
  ) +
  scale_x_continuous(limits = c(-10, 10)) +
  scale_color_manual(values = volcanoplot_palette) +
  ggtitle(paste0("contrast> ", opt$contrast[1], " : ", opt$contrast[2], " against ", opt$contrast[3])) +
  theme_bw()
ggsave(paste0(opt$batch_id, ".contrast_DEG.volcanoplot.pdf"),
       p)

res_sorted_sig <-
  subset(
    res_sorted,
    adj_p_value < opt$adj_p_value_cutoff &
      (
        log2FoldChange < -opt$log2foldchange_cutoff |
          log2FoldChange > opt$log2foldchange_cutoff
      )
  )
write.table(
  res_sorted_sig,
  file = paste0(opt$batch_id, ".contrast_DEG.significant_table.txt"),
  sep = "\t",
  quote = FALSE,
  row.names = FALSE
)


