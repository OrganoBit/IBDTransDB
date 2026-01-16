#!/usr/bin/env Rscript

# Target Ranking Script for IBDTransDB CLI
# Ranks therapeutic targets using meta-analysis across datasets

suppressPackageStartupMessages({
  library(optparse)
  library(RSQLite)
  library(DBI)
  library(dplyr)
  library(tidyr)
  library(poolr)
  library(ggplot2)
  library(jsonlite)
})

# Parse command-line arguments
option_list <- list(
  make_option(c("--db-path"), type = "character", default = NULL,
              help = "Path to IBDTransDB.db", metavar = "character"),
  make_option(c("--output-dir"), type = "character", default = NULL,
              help = "Output directory for results", metavar = "character"),
  make_option(c("--genes"), type = "character", default = NULL,
              help = "Comma-separated list of genes (optional)", metavar = "character"),
  make_option(c("--disease"), type = "character", default = NULL,
              help = "Filter by disease", metavar = "character"),
  make_option(c("--tissue"), type = "character", default = NULL,
              help = "Filter by tissue", metavar = "character"),
  make_option(c("--treatment"), type = "character", default = NULL,
              help = "Filter by treatment", metavar = "character"),
  make_option(c("--top-n"), type = "integer", default = 100,
              help = "Number of top targets [default: %default]", metavar = "integer"),
  make_option(c("--fdr-threshold"), type = "double", default = 0.05,
              help = "FDR threshold [default: %default]", metavar = "double"),
  make_option(c("--min-datasets"), type = "integer", default = 2,
              help = "Minimum datasets [default: %default]", metavar = "integer"),
  make_option(c("--plot"), action = "store_true", default = FALSE,
              help = "Generate plots")
)

opt_parser <- OptionParser(option_list = option_list)
opt <- parse_args(opt_parser)

# Validate required arguments
if (is.null(opt$`db-path`) || is.null(opt$`output-dir`)) {
  print_help(opt_parser)
  stop("Missing required arguments", call. = FALSE)
}

# Source common utilities
# Get script directory in a way that works with Rscript
args <- commandArgs(trailingOnly = FALSE)
script_path <- sub("^--file=", "", args[grep("^--file=", args)])
script_dir <- dirname(normalizePath(script_path))
source(file.path(dirname(script_dir), "common", "database_utils.R"))
source(file.path(dirname(script_dir), "common", "plot_utils.R"))
source(file.path(dirname(script_dir), "common", "json_utils.R"))

# Main function
perform_target_ranking <- function(db_path, output_dir, genes_str, disease, tissue, treatment,
                                   top_n, fdr_threshold, min_datasets, plot) {

  db <- connect_db(db_path)

  tryCatch({

    cat("Loading comparison data with filters...\n", file = stderr())

    # Build filter conditions
    filter_conditions <- "1=1"
    if (!is.null(disease)) {
      filter_conditions <- paste0(filter_conditions, sprintf(" AND d.disease LIKE '%%%s%%'", disease))
    }
    if (!is.null(tissue)) {
      filter_conditions <- paste0(filter_conditions, sprintf(" AND d.source LIKE '%%%s%%'", tissue))
    }
    if (!is.null(treatment)) {
      filter_conditions <- paste0(filter_conditions, sprintf(" AND d.treatment LIKE '%%%s%%'", treatment))
    }

    # Get comparisons
    comparison_query <- sprintf(
      "SELECT c.id as comparison_id, d.dataset_acc, d.dataset_id
       FROM comparison c
       JOIN dataset d ON c.dataset_id = d.dataset_id
       WHERE %s",
      filter_conditions
    )
    comparisons <- dbGetQuery(db, comparison_query)

    if (nrow(comparisons) == 0) {
      stop("No comparisons found matching criteria")
    }

    cat(sprintf("Found %d comparisons from %d datasets\n",
                nrow(comparisons), n_distinct(comparisons$dataset_acc)), file = stderr())

    # Get comparison data
    genes_filter <- ""
    if (!is.null(genes_str)) {
      genes_list <- strsplit(genes_str, ",")[[1]]
      genes_list <- trimws(genes_list)
      genes_filter <- sprintf(" AND gm.symbol IN (%s)",
                             paste(sprintf("'%s'", genes_list), collapse = ", "))
    }

    comp_data_query <- sprintf(
      "SELECT cd.comparison_id, gm.symbol, cd.log_fc, cd.p_value
       FROM comparison_data cd
       JOIN gene_map gm ON cd.gene = gm.id
       WHERE cd.comparison_id IN (%s)
         AND cd.p_value IS NOT NULL
         AND cd.log_fc IS NOT NULL
         %s",
      paste(comparisons$comparison_id, collapse = ", "),
      genes_filter
    )
    comp_data <- dbGetQuery(db, comp_data_query)

    if (nrow(comp_data) == 0) {
      stop("No comparison data found")
    }

    # Merge with dataset info
    comp_data <- comp_data %>%
      left_join(comparisons, by = "comparison_id")

    cat(sprintf("Loaded data for %d genes\n", n_distinct(comp_data$symbol)), file = stderr())

    # Meta-analysis per gene
    cat("Performing meta-analysis...\n", file = stderr())

    ranking <- comp_data %>%
      group_by(symbol) %>%
      summarise(
        n_comparisons = n(),
        n_datasets = n_distinct(dataset_acc),
        mean_logfc = mean(log_fc, na.rm = TRUE),
        median_logfc = median(log_fc, na.rm = TRUE),
        sd_logfc = sd(log_fc, na.rm = TRUE),
        n_up = sum(log_fc > 0, na.rm = TRUE),
        n_down = sum(log_fc < 0, na.rm = TRUE),
        consistency_score = sum(sign(log_fc) == sign(mean(log_fc))) / n(),
        .groups = "drop"
      )

    # Fisher's meta p-value
    meta_pvals <- list()
    for (i in 1:nrow(ranking)) {
      gene <- ranking$symbol[i]
      pvals <- comp_data %>% filter(symbol == gene) %>% pull(p_value)

      if (length(pvals) < 2) {
        meta_pvals[[gene]] <- NA
        next
      }

      min_nonzero <- min(pvals[pvals > 0])
      pvals[pvals == 0] <- min_nonzero / 10

      meta_result <- tryCatch({
        fisher(pvals)
      }, error = function(e) list(p = NA))

      meta_pvals[[gene]] <- meta_result$p
    }

    ranking$meta_pval <- sapply(ranking$symbol, function(g) meta_pvals[[g]])
    ranking$meta_fdr <- p.adjust(ranking$meta_pval, method = "BH")

    # Filter by min datasets and rank
    ranking <- ranking %>%
      filter(n_datasets >= min_datasets) %>%
      mutate(
        rank_score = -log10(meta_pval) * abs(mean_logfc) * consistency_score,
        direction = ifelse(mean_logfc > 0, "Up", "Down"),
        significant = ifelse(meta_fdr < fdr_threshold, "Yes", "No")
      ) %>%
      arrange(desc(rank_score))

    cat(sprintf("Ranked %d targets meeting criteria\n", nrow(ranking)), file = stderr())

    # Export
    output_file <- file.path(output_dir, "ranked_targets.csv")
    write.csv(ranking, output_file, row.names = FALSE)
    cat(sprintf("Rankings saved to: %s\n", output_file), file = stderr())

    # Top targets
    top_targets <- ranking %>% head(top_n)
    top_file <- file.path(output_dir, "top_targets.csv")
    write.csv(top_targets, top_file, row.names = FALSE)

    # Plots
    if (plot && nrow(top_targets) > 0) {
      # Ranking plot
      rank_plot <- ggplot(head(top_targets, 30), aes(x = reorder(symbol, rank_score), y = rank_score)) +
        geom_bar(stat = "identity", aes(fill = direction), alpha = 0.8) +
        scale_fill_manual(values = c("Up" = "#E41A1C", "Down" = "#377EB8")) +
        coord_flip() +
        labs(title = "Top Ranked Targets", x = "Gene", y = "Rank Score") +
        theme_minimal() +
        theme(plot.title = element_text(hjust = 0.5, face = "bold"))

      ggsave(file.path(output_dir, "target_ranking_plot.png"), rank_plot, width = 10, height = 8, dpi = 300)

      # Consistency plot
      cons_plot <- ggplot(head(top_targets, 30), aes(x = abs(mean_logfc), y = -log10(meta_pval))) +
        geom_point(aes(color = consistency_score, size = n_datasets), alpha = 0.7) +
        scale_color_gradient(low = "gray", high = "#E41A1C") +
        labs(title = "Target Consistency", x = "|Mean LogFC|", y = "-Log10 Meta P-value") +
        theme_minimal()

      ggsave(file.path(output_dir, "consistency_plot.png"), cons_plot, width = 8, height = 6, dpi = 300)
    }

    # Summary
    summary <- list(
      n_targets_ranked = nrow(ranking),
      n_significant = sum(ranking$meta_fdr < fdr_threshold, na.rm = TRUE),
      n_comparisons = nrow(comparisons),
      n_datasets = n_distinct(comparisons$dataset_acc),
      filters = list(disease = disease, tissue = tissue, treatment = treatment),
      files = list(ranked_targets = "ranked_targets.csv", top_targets = "top_targets.csv")
    )

    if (plot) {
      summary$files$plots <- c("target_ranking_plot.png", "consistency_plot.png")
    }

    cat(toJSON(summary, auto_unbox = TRUE, pretty = TRUE))

  }, error = function(e) {
    cat(toJSON(create_error_response(e$message), auto_unbox = TRUE))
    quit(status = 1)
  }, finally = {
    dbDisconnect(db)
  })
}

# Execute
perform_target_ranking(
  opt$`db-path`, opt$`output-dir`, opt$genes, opt$disease, opt$tissue, opt$treatment,
  opt$`top-n`, opt$`fdr-threshold`, opt$`min-datasets`, opt$plot
)
