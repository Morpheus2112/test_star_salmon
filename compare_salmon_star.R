suppressMessages(library(ggplot2))
suppressMessages(library(tidyr))
suppressMessages(library(dplyr))

cat("Reading samplesheet...\n")
samples_df <- read.csv("samplesheet_batch1.csv", stringsAsFactors = FALSE)
samples <- samples_df$sample
strandedness <- samples_df$strandedness
names(strandedness) <- samples

calc_cpm <- function(df) {
  counts <- as.matrix(df[, -1, drop=FALSE])
  cpm <- sweep(counts, 2, colSums(counts, na.rm=TRUE), FUN = "/") * 1e6
  res <- cbind(df[, 1, drop=FALSE], as.data.frame(cpm))
  return(res)
}

process_cor <- function(star_data, salmon_data, level, metric) {
  cat("Processing", level, metric, "\n")
  
  common_samples <- intersect(colnames(star_data), samples)
  common_samples <- intersect(common_samples, colnames(salmon_data))
  
  id_col <- colnames(star_data)[1]
  
  merged <- merge(star_data[, c(id_col, common_samples)], 
                  salmon_data[, c(id_col, common_samples)], 
                  by = id_col, suffixes = c(".star", ".salmon"))
  
  cor_list <- lapply(common_samples, function(s) {
    star_val <- merged[[paste0(s, ".star")]]
    salmon_val <- merged[[paste0(s, ".salmon")]]
    
    spearman_cor <- cor(star_val, salmon_val, method = "spearman", use = "complete.obs")
    pearson_cor_log <- cor(log2(star_val + 1), log2(salmon_val + 1), method = "pearson", use = "complete.obs")
    
    data.frame(
      sample = s,
      strandedness = strandedness[s],
      spearman_cor = spearman_cor,
      pearson_cor_log = pearson_cor_log,
      level = level,
      metric = metric,
      stringsAsFactors = FALSE
    )
  })
  
  do.call(rbind, cor_list)
}

star_gene_counts <- read.delim("results_star_salmon_batch1/star_salmon/salmon.merged.gene_counts.tsv", check.names=FALSE, stringsAsFactors=FALSE)
salmon_gene_counts <- read.delim("results_salmon_pseudo_batch1/salmon/salmon.merged.gene_counts.tsv", check.names=FALSE, stringsAsFactors=FALSE)
star_tx_counts <- read.delim("results_star_salmon_batch1/star_salmon/salmon.merged.transcript_counts.tsv", check.names=FALSE, stringsAsFactors=FALSE)
salmon_tx_counts <- read.delim("results_salmon_pseudo_batch1/salmon/salmon.merged.transcript_counts.tsv", check.names=FALSE, stringsAsFactors=FALSE)

star_gene_counts <- star_gene_counts[, !colnames(star_gene_counts) %in% c("gene_name", "tx_name", "gene_id.1")]
salmon_gene_counts <- salmon_gene_counts[, !colnames(salmon_gene_counts) %in% c("gene_name", "tx_name", "gene_id.1")]
star_tx_counts <- star_tx_counts[, !colnames(star_tx_counts) %in% c("gene_name", "tx_name", "gene_id")]
salmon_tx_counts <- salmon_tx_counts[, !colnames(salmon_tx_counts) %in% c("gene_name", "tx_name", "gene_id")]

star_gene_cpm <- calc_cpm(star_gene_counts)
salmon_gene_cpm <- calc_cpm(salmon_gene_counts)
star_tx_cpm <- calc_cpm(star_tx_counts)
salmon_tx_cpm <- calc_cpm(salmon_tx_counts)

all_cor <- rbind(
  process_cor(star_gene_counts, salmon_gene_counts, "Gene", "Raw Count"),
  process_cor(star_gene_cpm, salmon_gene_cpm, "Gene", "CPM"),
  process_cor(star_tx_counts, salmon_tx_counts, "Transcript", "Raw Count"),
  process_cor(star_tx_cpm, salmon_tx_cpm, "Transcript", "CPM")
)

all_cor$metric <- factor(all_cor$metric, levels = c("Raw Count", "CPM"))
all_cor$level <- factor(all_cor$level, levels = c("Gene", "Transcript"))

write.csv(all_cor, "STAR_vs_Salmon_correlation_data.csv", row.names = FALSE)

p <- ggplot(all_cor, aes(x = strandedness, y = pearson_cor_log, fill = strandedness)) +
  geom_violin(alpha = 0.5, trim = FALSE) +
  geom_boxplot(width = 0.2, alpha = 0.8, outlier.shape = NA) +
  geom_jitter(width = 0.1, size = 2, alpha = 0.6) +
  facet_grid(metric ~ level) +
  theme_bw(base_size = 14) +
  labs(
    title = "Correlation between STAR and Salmon (Pseudo) Quantification",
    subtitle = "Pearson correlation on log2(value + 1) across Batch 1 samples",
    y = "Pearson Correlation (log2)",
    x = "Strandedness Protocol"
  ) +
  scale_fill_manual(values = c("unstranded" = "#1f77b4", "reverse" = "#ff7f0e")) +
  theme(legend.position = "bottom")

ggsave("STAR_vs_Salmon_correlation_ggplot.pdf", plot = p, width = 10, height = 8)
cat("Correlation analysis complete! Plots saved as STAR_vs_Salmon_correlation_ggplot.pdf\n")

# New plot without considering strandedness
all_cor$condition <- paste(all_cor$level, all_cor$metric, sep="\n")
all_cor$condition <- factor(all_cor$condition, levels = c("Gene\nRaw Count", "Gene\nCPM", "Transcript\nRaw Count", "Transcript\nCPM"))

p2 <- ggplot(all_cor, aes(x = condition, y = pearson_cor_log)) +
  geom_boxplot(width = 0.4, alpha = 0.8, fill = "#2ca02c", outlier.shape = NA) +
  geom_jitter(width = 0.1, size = 2, alpha = 0.6) +
  theme_bw(base_size = 14) +
  labs(
    title = "Overall Correlation between STAR and Salmon",
    subtitle = "Pearson correlation on log2(value + 1) (All Batch 1 samples combined)",
    y = "Pearson Correlation (log2)",
    x = ""
  )

ggsave("STAR_vs_Salmon_correlation_overall.pdf", plot = p2, width = 8, height = 6)
cat("Overall correlation plot saved as STAR_vs_Salmon_correlation_overall.pdf\n")
