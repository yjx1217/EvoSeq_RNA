#!/usr/bin/env Rscript
library(optparse)
library(RColorBrewer)
library(ggplot2)
library(viridis)
library(gplots)
library(stats)
library(corrplot)
library(pheatmap)
library(reshape2)
library(RUVSeq)
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
      c("--quant_summary_table"),
      type = "character",
      default = NULL,
      help = "name of the gene quant summary table file",
      metavar = "character"
   ),
   make_option(
      c("--min_sample"),
      type = "integer",
      default = 3,
      help = "the minimal sample counts to be considered",
      metavar = "character"
   ),
   make_option(
      c("--min_counts"),
      type = "integer",
      default = 10,
      help = "the minimal read counts to be considered",
      metavar = "character"
   ),
   make_option(
      c("--transformation_method"),
      type = "character",
      default = "rlog",
      help = "transformation method: 'log2', 'vst', or 'rlog'",
      metavar = "character"
   ),
   make_option(
      c("--normalization_method"),
      type = "character",
      default = "by_ERCC",
      help = "normalization method: 'by_ERCC' or 'by_replicate'",
      metavar = "character"
   ),
   make_option(
      c("--running_mode"),
      type = "character",
      default = "fast",
      help = "running mode: 'lite' or 'full'",
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

# color palette

set_palette <- colorRampPalette(brewer.pal(8, "Set2"))(8)
#spectral_palette <- colorRampPalette(brewer.pal(9, "Greens"))(11)
spectral_palette <- colorRampPalette(viridis(12))(12)

# parse input

opt_parser <- OptionParser(option_list = option_list)
opt <- parse_args(opt_parser)

# ###############
# # for local testing only
# setwd("/Users/yjx/Projects/2021_EvoSeq")
# opt$master_sample_table <- "Master_Sample_Table.Batch_H2228.txt"
# opt$quant_summary_table <- "Batch_H2228.quant_summary_table.txt"
# opt$min_sample <- 3
# opt$min_counts <- 10
# opt$transformation_method <- "vst"
# opt$normalization_method <- "by_ERCC"
# opt$batch_id <- "Batch_H2228"
# #############

samples <-
   read.table(
      opt$master_sample_table,
      header = TRUE,
      stringsAsFactors = TRUE,
      sep = "\t"
   )

#samples <- samples_raw[order(samples_raw$sample_id),]
biological_sample <- as.factor(samples$biological_sample)
treatment_condition <- as.factor(samples$treatment_condition)
sampling_timepoint <- as.factor(samples$sampling_timepoint)
biological_replicate_id <-
   as.factor(samples$biological_replicate_id)
technical_replicate_id <- as.factor(samples$technical_replicate_id)


quant_data <-
   read.table(
      opt$quant_summary_table,
      row.names = 1,
      header = TRUE,
      sep = "\t"
   )
quant_data <- quant_data[samples$sample_id]


# data filtering
quant_filter <-
   apply(quant_data, 1, function(x)
      length(x[x > opt$min_counts]) >= opt$min_sample)

filtered_quant_data <- quant_data[quant_filter, ]


# data exploration with raw counts
home_dir <- getwd()
raw_counts_out_dir <- paste0(home_dir, "/based_on_raw_counts/")
dir.create(raw_counts_out_dir)
setwd(raw_counts_out_dir)

raw_expression_set <-
   newSeqExpressionSet(
      counts = as.matrix(filtered_quant_data),
      phenoData = data.frame(samples, row.names = colnames(filtered_quant_data))
   )
annotation_coldata <- subset(
   pData(raw_expression_set),
   select = c(biological_sample, treatment_condition, sampling_timepoint)
)


# raw counts distribution plot

if (opt$running_mode == "full") {
   for (i in 1:nrow(samples)) {
      # print(i)
      s <- as.character(samples$sample_id[i])
      # print(s)
      raw_quant_data_by_single_sample <-
         data.frame(filtered_quant_data[, s])
      raw_quant_data_by_single_sample <-
         cbind(rownames(filtered_quant_data),
               raw_quant_data_by_single_sample)
      colnames(raw_quant_data_by_single_sample) <-
         c("gene_id", "counts")
      p <-
         ggplot(raw_quant_data_by_single_sample , aes(x = counts)) +
         geom_histogram(color = "white",
                        fill = "#525252",
                        stat_bin = 100) +
         xlab(paste0("sample: ", s)) +
         ylab("raw counts") +
         theme_bw()
      ggsave(
         paste0(
            opt$batch_id,
            ".raw_counts_distribution_plot.sample.",
            s,
            ".pdf"
         ),
         p,
         height = 3,
         width = 4,
         device = "pdf"
      )
   }
}

raw_quant_data_by_all_samples = melt(filtered_quant_data, variable.name = "sample_id")
p <- ggplot(raw_quant_data_by_all_samples,
            aes(x = sample_id, y = value, fill = sample_id)) +
   geom_violin() +
   geom_boxplot(width = 0.1, outlier.size = 0.5) +
   xlab("samples") +
   ylab("raw counts") +
   theme_bw() +
   theme(axis.text.x = element_text(
      angle = 90,
      vjust = 0.5,
      hjust = 1
   ),
   legend.position = "none")
ggsave(
   paste0(
      opt$batch_id,
      ".raw_counts_distribution_plot.all_samples.pdf"
   ),
   p,
   height = 6,
   width = 12,
   device = "pdf"
)

if (opt$running_mode == "full") {
   # raw counts MA plots
   for (i in 1:(nrow(samples) - 1)) {
      for (j in (i + 1):(nrow(samples))) {
         si <- as.character(samples$sample_id[i])
         sj <- as.character(samples$sample_id[j])
         # print(si)
         # print(sj)
         raw_quant_data_si <- data.frame(filtered_quant_data[, si])
         raw_quant_data_si <-
            cbind(rownames(filtered_quant_data), raw_quant_data_si)
         colnames(raw_quant_data_si) <- c("gene_id", "counts")
         raw_quant_data_sj <- data.frame(filtered_quant_data[, sj])
         raw_quant_data_sj <-
            cbind(rownames(filtered_quant_data), raw_quant_data_sj)
         colnames(raw_quant_data_sj) <- c("gene_id", "counts")
         raw_quant_data_pair <-
            merge(raw_quant_data_si, raw_quant_data_sj, by = "gene_id")
         colnames(raw_quant_data_pair) <- c("gene_id", si, sj)
         raw_quant_data_pair$M <-
            raw_quant_data_pair[, si] - raw_quant_data_pair[, sj]
         raw_quant_data_pair$A <-
            (raw_quant_data_pair[, si] + raw_quant_data_pair[, sj]) / 2
         p <- ggplot(raw_quant_data_pair , aes(x = A, y = M)) +
            geom_point(size = 1.5, alpha = 0.2) +
            geom_hline(yintercept = 0, color = "blue") +
            ggtitle(paste0(si, " vs. ", sj)) +
            stat_smooth(se = FALSE,
                        method = "loess",
                        color = "red") +
            theme_bw()
         ggsave(
            paste0(
               opt$batch_id,
               ".raw_counts_MA_plot.",
               si,
               ".vs.",
               sj,
               ".pdf"
            ),
            p,
            height = 3,
            width = 4,
            device = "pdf"
         )
      }
   }
}

# raw counts correlation_plot
raw_count_matrix <- as.matrix(counts(raw_expression_set))
raw_correlation_matrix <- cor(raw_count_matrix)

pdf(file = paste0(opt$batch_id, ".raw_counts_correlation_plot.pdf"))
corrplot(
   raw_correlation_matrix,
   method = "circle",
   order = "hclust",
   rect.col = "grey70",
   tl.cex = 0.75,
   tl.col = "black",
   addrect = 2
)
dev.off()

pdf(
   file = paste0(opt$batch_id, ".raw_counts_correlation_enhanced_plot.pdf"),
   width = 8,
   height = 6
)
pheatmap(
   raw_correlation_matrix,
   annotation_col = annotation_coldata,
   cutree_cols = 1,
   cutree_rows = 1,
   fontsize = 7,
   main = "Heatmap of raw counts correlation"
)
dev.off()

pdf(file = paste0(
   opt$batch_id,
   ".raw_counts_RLE_plot.by.biological_sample.pdf"
))
plotRLE(
   raw_expression_set,
   outline = FALSE,
   ylim = c(-4, 4),
   col = set_palette[biological_sample],
   las = 2
)
dev.off()

pdf(file = paste0(
   opt$batch_id,
   ".raw_counts_RLE_plot.by.treatment_condition.pdf"
))
plotRLE(
   raw_expression_set,
   outline = FALSE,
   ylim = c(-4, 4),
   col = set_palette[treatment_condition],
   las = 2
)
dev.off()

pdf(file = paste0(
   opt$batch_id,
   ".raw_counts_RLE_plot.by.sampling_timepoint.pdf"
))
plotRLE(
   raw_expression_set,
   outline = FALSE,
   ylim = c(-4, 4),
   col = spectral_palette[sampling_timepoint],
   las = 2
)
dev.off()

pdf(file = paste0(
   opt$batch_id,
   ".raw_counts_PCA_plot.by.biological_sample.pdf"
))
plotPCA(raw_expression_set, col = set_palette[biological_sample], cex = 1.2)
dev.off()

pdf(file = paste0(
   opt$batch_id,
   ".raw_counts_PCA_plot.by.treatment_condition.pdf"
))
plotPCA(raw_expression_set, col = set_palette[treatment_condition], cex = 1.2)
dev.off()

pdf(file = paste0(
   opt$batch_id,
   ".raw_counts_PCA_plot.by.sampling_timepoint.pdf"
))
plotPCA(raw_expression_set, col = spectral_palette[sampling_timepoint], cex = 1.2)
dev.off()


# data exploration with transformed counts
transformed_counts_out_dir <-
   paste0(home_dir, "/based_on_transformed_counts/")
dir.create(transformed_counts_out_dir)
setwd(transformed_counts_out_dir)

if (opt$transformation_method == "log2") {
   transformed_quant_data <- log2(filtered_quant_data + 1)
} else if (opt$transformation_method == "rlog") {
   transformed_quant_data <-
      as.data.frame(rlog(as.matrix(filtered_quant_data), blind = FALSE))
} else {
   opt$transformation_method <- "vst"
   transformed_quant_data <-
      as.data.frame(vst(as.matrix(filtered_quant_data), blind = FALSE))
}

transformed_quant_data <- round(transformed_quant_data)
transformed_expression_set <-
   newSeqExpressionSet(
      counts = as.matrix(transformed_quant_data),
      phenoData = data.frame(samples, row.names = colnames(filtered_quant_data))
   )


if (opt$running_mode == "full") {
   for (i in 1:nrow(samples)) {
      # print(i)
      s <- as.character(samples$sample_id[i])
      # print(s)
      transformed_quant_data_by_single_sample <-
         data.frame(transformed_quant_data[, s])
      transformed_quant_data_by_single_sample <-
         cbind(rownames(transformed_quant_data),
               transformed_quant_data_by_single_sample)
      colnames(transformed_quant_data_by_single_sample) <-
         c("gene_id", "counts")
      p <-
         ggplot(transformed_quant_data_by_single_sample ,
                aes(x = counts)) +
         xlab(paste0("sample: ", s)) +
         ylab(paste0(opt$transformation_method, " transformed counts")) +
         geom_histogram(color = "white",
                        fill = "#525252",
                        binwidth = 1) +
         theme_bw()
      ggsave(
         paste0(
            opt$batch_id,
            ".transformed_counts_distribution.sample.",
            s,
            ".pdf"
         ),
         p,
         height = 3,
         width = 4,
         device = "pdf"
      )
   }
}

transformed_quant_data_by_all_samples = melt(transformed_quant_data, variable.name = "sample_id")
p <- ggplot(transformed_quant_data_by_all_samples,
            aes(x = sample_id, y = value, fill = sample_id)) +
   geom_violin() +
   geom_boxplot(width = 0.1, outlier.size = 0.5) +
   xlab("") +
   ylab(paste0(opt$transformation_method, " transformed counts")) +
   theme_bw() +
   theme(axis.text.x = element_text(
      angle = 90,
      vjust = 0.5,
      hjust = 1
   ),
   legend.position = "none")
ggsave(
   paste0(
      opt$batch_id,
      ".transformed_counts_distribution.all_samples.pdf"
   ),
   p,
   height = 6,
   width = 12,
   device = "pdf"
)

if (opt$running_mode == "full") {
   # transformed counts MA plots
   for (i in 1:(nrow(samples) - 1)) {
      for (j in (i + 1):(nrow(samples))) {
         si <- as.character(samples$sample_id[i])
         sj <- as.character(samples$sample_id[j])
         # print(si)
         # print(sj)
         transformed_quant_data_si <-
            data.frame(transformed_quant_data[, si])
         transformed_quant_data_si <-
            cbind(rownames(transformed_quant_data),
                  transformed_quant_data_si)
         colnames(transformed_quant_data_si) <-
            c("gene_id", "counts")
         transformed_quant_data_sj <-
            data.frame(transformed_quant_data[, sj])
         transformed_quant_data_sj <-
            cbind(rownames(transformed_quant_data),
                  transformed_quant_data_sj)
         colnames(transformed_quant_data_sj) <-
            c("gene_id", "counts")
         transformed_quant_data_pair <-
            merge(transformed_quant_data_si,
                  transformed_quant_data_sj,
                  by = "gene_id")
         colnames(transformed_quant_data_pair) <-
            c("gene_id", si, sj)
         transformed_quant_data_pair$M <-
            transformed_quant_data_pair[, si] - transformed_quant_data_pair[, sj]
         transformed_quant_data_pair$A <-
            (transformed_quant_data_pair[, si] + transformed_quant_data_pair[, sj]) /
            2
         p <-
            ggplot(transformed_quant_data_pair , aes(x = A, y = M)) +
            geom_point(size = 1.5, alpha = 0.2) +
            geom_hline(yintercept = 0, color = "blue") +
            stat_smooth(se = FALSE,
                        method = "loess",
                        color = "red") +
            theme_bw()
         ggsave(
            paste0(
               opt$batch_id,
               ".transformed_counts_MA_plot.",
               si,
               ".vs.",
               sj,
               ".pdf"
            ),
            p,
            height = 3,
            width = 4,
            device = "pdf"
         )
      }
   }
}

# transformed counts correlation plot
transformed_count_matrix <-
   as.matrix(counts(transformed_expression_set))
transformed_correlation_matrix <- cor(transformed_count_matrix)

pdf(file = paste0(opt$batch_id, ".transformed_counts_correlation_plot.pdf"))
corrplot(
   transformed_correlation_matrix,
   method = "circle",
   order = "hclust",
   rect.col = "grey70",
   tl.cex = 0.75,
   tl.col = "black",
   addrect = 2
)
dev.off()

pdf(
   file = paste0(
      opt$batch_id,
      ".transformed_counts_correlation_enhanced_plot.pdf"
   ),
   width = 8,
   height = 6
)
pheatmap(
   transformed_correlation_matrix,
   annotation_col = annotation_coldata,
   cutree_cols = 1,
   cutree_rows = 1,
   fontsize = 7,
   main = "Heatmap of transformed counts correlation"
)
dev.off()


pdf(file = paste0(
   opt$batch_id,
   ".transformed_counts_RLE_plot.by.biological_sample.pdf"
))
plotRLE(
   transformed_expression_set,
   outline = FALSE,
   ylim = c(-4, 4),
   col = set_palette[biological_sample],
   las = 2
)
dev.off()

pdf(file = paste0(
   opt$batch_id,
   ".transformed_counts_RLE_plot.by.treatment_condition.pdf"
))
plotRLE(
   transformed_expression_set,
   outline = FALSE,
   ylim = c(-4, 4),
   col = set_palette[treatment_condition],
   las = 2
)
dev.off()

pdf(file = paste0(
   opt$batch_id,
   ".transformed_counts_RLE_plot.by.sampling_timepoint.pdf"
))
plotRLE(
   transformed_expression_set,
   outline = FALSE,
   ylim = c(-4, 4),
   col = spectral_palette[sampling_timepoint],
   las = 2
)
dev.off()

pdf(file = paste0(
   opt$batch_id,
   ".transformed_counts_PCA_plot.by.biological_sample.pdf"
))
plotPCA(transformed_expression_set,
        col = set_palette[biological_sample],
        cex = 1.2,)
dev.off()

pdf(file = paste0(
   opt$batch_id,
   ".transformed_counts_PCA_plot.by.treatment_condition.pdf"
))
plotPCA(transformed_expression_set,
        col = set_palette[treatment_condition],
        cex = 1.2,)
dev.off()

pdf(file = paste0(
   opt$batch_id,
   ".transformed_counts_PCA_plot.by.sampling_timepoint.pdf"
))
plotPCA(transformed_expression_set,
        col = spectral_palette[sampling_timepoint],
        cex = 1.2,)
dev.off()



# normalization
# data exploration with normalized counts

normalized_counts_out_dir <-
   paste0(home_dir, "/based_on_normalized_counts/")
dir.create(normalized_counts_out_dir)
setwd(normalized_counts_out_dir)

genes <-
   rownames(filtered_quant_data)[!grepl("^ERCC", rownames(filtered_quant_data))]
spikes <-
   rownames(filtered_quant_data)[grep("^ERCC", rownames(filtered_quant_data))]

# uq normalization

# upper-quartile (UQ) normalization
uq_expression_set <-
   betweenLaneNormalization(raw_expression_set, which = "upper")

if (opt$normalization_method == "by_ERCC") {
   # RUVg:   Estimating  the  factors  of  unwanted  variation  using control genes
   normalized_expression_set <-
      RUVg(uq_expression_set, spikes, k = 1)
} else {
   # RUVs: Estimating the factors of unwanted variation using replicate samples
   samples$replicate_group <-
      paste(
         samples$biological_sample,
         samples$treatment_condition,
         samples$sampling_timepoint,
         sep = "_"
      )
   differences <- makeGroups(samples$replicate_group)
   normalized_expression_set <-
      RUVs(uq_expression_set, genes, k = 1, differences)
}

normalized_counts <- normCounts(normalized_expression_set)
normalized_quant_data <- as.data.frame(normalized_counts)

normalized_counts_header <- colnames(normalized_counts)
normalized_counts <-
   cbind(rownames(normalized_counts),
         data.frame(normalized_counts, row.names = NULL))
colnames(normalized_counts) <-
   c("gene_id", normalized_counts_header)
write.table(
   normalized_counts,
   file = paste0(opt$batch_id, ".normalized_counts.txt"),
   sep = "\t",
   row.names = FALSE,
   quote = FALSE
)


# normalized counts distribution plot

if (opt$running_mode == "full") {
   for (i in 1:nrow(samples)) {
      # print(i)
      s <- as.character(samples$sample_id[i])
      # print(s)
      normalized_quant_data_by_single_sample <-
         data.frame(normalized_quant_data[, s])
      normalized_quant_data_by_single_sample <-
         cbind(rownames(normalized_quant_data),
               normalized_quant_data_by_single_sample)
      colnames(normalized_quant_data_by_single_sample) <-
         c("gene_id", "counts")
      p <-
         ggplot(normalized_quant_data_by_single_sample , aes(x = counts)) +
         geom_histogram(color = "white",
                        fill = "#525252",
                        stat_bin = 100) +
         xlab(paste0("sample: ", s)) +
         ylab("normalized counts") +
         theme_bw()
      ggsave(
         paste0(
            opt$batch_id,
            ".normalized_counts_distribution_plot.sample.",
            s,
            ".pdf"
         ),
         p,
         height = 3,
         width = 4,
         device = "pdf"
      )
   }
}

normalized_quant_data_by_all_samples = melt(normalized_quant_data, variable.name = "sample_id")
p <- ggplot(normalized_quant_data_by_all_samples,
            aes(x = sample_id, y = value, fill = sample_id)) +
   geom_violin() +
   geom_boxplot(width = 0.1, outlier.size = 0.5) +
   xlab("samples") +
   ylab("normalized counts") +
   theme_bw() +
   theme(axis.text.x = element_text(
      angle = 90,
      vjust = 0.5,
      hjust = 1
   ),
   legend.position = "none")
ggsave(
   paste0(
      opt$batch_id,
      ".normalized_counts_distribution_plot.all_samples.pdf"
   ),
   p,
   height = 6,
   width = 12
)

if (opt$running_mode == "full") {
   # normalized counts MA plots
   for (i in 1:(nrow(samples) - 1)) {
      for (j in (i + 1):(nrow(samples))) {
         si <- as.character(samples$sample_id[i])
         sj <- as.character(samples$sample_id[j])
         # print(si)
         # print(sj)
         normalized_quant_data_si <-
            data.frame(normalized_quant_data[, si])
         normalized_quant_data_si <-
            cbind(rownames(normalized_quant_data),
                  normalized_quant_data_si)
         colnames(normalized_quant_data_si) <-
            c("gene_id", "counts")
         normalized_quant_data_sj <-
            data.frame(normalized_quant_data[, sj])
         normalized_quant_data_sj <-
            cbind(rownames(normalized_quant_data),
                  normalized_quant_data_sj)
         colnames(normalized_quant_data_sj) <-
            c("gene_id", "counts")
         normalized_quant_data_pair <-
            merge(normalized_quant_data_si,
                  normalized_quant_data_sj,
                  by = "gene_id")
         colnames(normalized_quant_data_pair) <-
            c("gene_id", si, sj)
         normalized_quant_data_pair$M <-
            normalized_quant_data_pair[, si] - normalized_quant_data_pair[, sj]
         normalized_quant_data_pair$A <-
            (normalized_quant_data_pair[, si] + normalized_quant_data_pair[, sj]) / 2
         p <-
            ggplot(normalized_quant_data_pair , aes(x = A, y = M)) +
            geom_point(size = 1.5, alpha = 0.2) +
            geom_hline(yintercept = 0, color = "blue") +
            ggtitle(paste0(si, " vs. ", sj)) +
            stat_smooth(se = FALSE,
                        method = "loess",
                        color = "red") +
            theme_bw()
         ggsave(
            paste0(
               opt$batch_id,
               ".normalized_counts_MA_plot.",
               si,
               ".vs.",
               sj,
               ".pdf"
            ),
            p,
            height = 3,
            width = 4
         )
      }
   }
}

# normalized count correlation plot
normalized_count_matrix <-
   as.matrix(normCounts(normalized_expression_set))
normalized_correlation_matrix <- cor(normalized_count_matrix)

pdf(file = paste0(opt$batch_id, ".normalized_counts_correlation_plot.pdf"))
corrplot(
   normalized_correlation_matrix,
   method = "circle",
   order = "hclust",
   rect.col = "grey70",
   tl.cex = 0.75,
   tl.col = "black",
   addrect = 2
)
dev.off()

pdf(
   file = paste0(
      opt$batch_id,
      ".normalized_counts_correlation_enhanced_plot.pdf"
   ),
   width = 8,
   height = 6
)
pheatmap(
   normalized_correlation_matrix,
   annotation_col = annotation_coldata,
   cutree_cols = 1,
   cutree_rows = 1,
   fontsize = 7,
   main = "Heatmap of normalized counts correlation"
)
dev.off()

# normalized count RLE plot

pdf(file = paste0(
   opt$batch_id,
   ".normalized_counts_RLE_plot.by.biological_sample.pdf"
))
plotRLE(
   normalized_expression_set,
   outline = FALSE,
   ylim = c(-4, 4),
   col = set_palette[biological_sample],
   las = 2
)
dev.off()

pdf(file = paste0(
   opt$batch_id,
   ".normalized_counts_RLE_plot.by.treatment_condition.pdf"
))
plotRLE(
   normalized_expression_set,
   outline = FALSE,
   ylim = c(-4, 4),
   col = set_palette[treatment_condition],
   las = 2
)
dev.off()

pdf(file = paste0(
   opt$batch_id,
   ".normalized_counts_RLE_plot.by.sampling_timepoint.pdf"
))
plotRLE(
   normalized_expression_set,
   outline = FALSE,
   ylim = c(-4, 4),
   col = spectral_palette[sampling_timepoint],
   las = 2
)
dev.off()

# normalized count PCA plot
pdf(file = paste0(
   opt$batch_id,
   ".normalized_counts_PCA_plot.by.biological_sample.pdf"
))
plotPCA(normalized_expression_set, col = set_palette[biological_sample], cex = 1.2)
dev.off()

pdf(file = paste0(
   opt$batch_id,
   ".normalized_counts_PCA_plot.by.treatment_condition.pdf"
))
plotPCA(normalized_expression_set, col = set_palette[treatment_condition], cex = 1.2)
dev.off()

pdf(file = paste0(
   opt$batch_id,
   ".normalized_counts_PCA_plot.by.sampling_timepoint.pdf"
))
plotPCA(normalized_expression_set, col = spectral_palette[sampling_timepoint], cex = 1.2)
dev.off()


# prepare data for DEG identification
setwd(home_dir)

samples$replicate_group <-
   paste(
      samples$biological_sample,
      samples$treatment_condition,
      samples$sampling_timepoint,
      sep = "_"
   )
replicate_group_size <-
   as.data.frame(table(samples$replicate_group))
colnames(replicate_group_size) <-
   c("replicate_group", "replicate_group_size")

samples <-
   merge(samples, replicate_group_size, by = "replicate_group")
samples_filtered <- subset(samples, replicate_group_size > 1)

col_data_for_DEG <- pData(normalized_expression_set)
col_data_for_DEG_filtered <-
   col_data_for_DEG[col_data_for_DEG$sample_id %in% samples_filtered$sample_id, ]
col_data_for_DEG_filtered <-
   col_data_for_DEG_filtered[order(row.names(col_data_for_DEG_filtered)),]
write.table(
   col_data_for_DEG_filtered,
   file = paste0(opt$batch_id, ".col_data_for_DEG.txt"),
   sep = "\t",
   quote = FALSE,
   row.names = FALSE
)

count_data_for_DEG <-
   as.data.frame(counts(normalized_expression_set))
count_data_for_DEG_filtered <-
   count_data_for_DEG[, which((names(count_data_for_DEG) %in% samples_filtered$sample_id) == TRUE)]
count_data_for_DEG_filtered <-
   count_data_for_DEG_filtered[, order(colnames(count_data_for_DEG_filtered))]
count_data_for_DEG_filtered_colnames <-
   colnames(count_data_for_DEG_filtered)
count_data_for_DEG_filtered <-
   cbind(
      rownames(count_data_for_DEG_filtered),
      data.frame(count_data_for_DEG_filtered, row.names = NULL)
   )
colnames(count_data_for_DEG_filtered) <-
   c("gene_id", count_data_for_DEG_filtered_colnames)
write.table(
   count_data_for_DEG_filtered,
   file = paste0(opt$batch_id, ".count_data_for_DEG.txt"),
   sep = "\t",
   quote = FALSE,
   row.names = FALSE
)
