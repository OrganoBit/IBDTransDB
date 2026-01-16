#!/usr/bin/env Rscript

# Cross-Dataset Comparison Table Script for IBDTransDB CLI
# Generates comparison tables for genes across multiple datasets/comparisons

suppressPackageStartupMessages({
  library(optparse)
  library(RSQLite)
  library(DBI)
  library(dplyr)
  library(tidyr)
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
              help = "Comma-separated list of gene symbols", metavar = "character"),
  make_option(c("--disease"), type = "character", default = NULL,
              help = "Filter by disease", metavar = "character"),
  make_option(c("--tissue"), type = "character", default = NULL,
              help = "Filter by tissue/source", metavar = "character"),
  make_option(c("--treatment"), type = "character", default = NULL,
              help = "Filter by treatment", metavar = "character"),
  make_option(c("--plot"), action = "store_true", default = FALSE,
              help = "Generate heatmap visualization")
)

opt_parser <- OptionParser(option_list = option_list)
opt <- parse_args(opt_parser)

# Validate required arguments
if (is.null(opt$`db-path`) || is.null(opt$`output-dir`) || is.null(opt$genes)) {
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

# Main analysis function
perform_comparison_table <- function(db_path, output_dir, genes_str, disease, tissue, treatment, plot) {

  # Connect to database
  db <- connect_db(db_path)

  tryCatch({

    # Parse gene list
    genes_list <- strsplit(genes_str, ",")[[1]]
    genes_list <- trimws(genes_list)

    cat(sprintf("Creating comparison table for %d genes\n", length(genes_list)), file = stderr())

    # Get gene IDs
    gene_query <- sprintf(
      "SELECT id, symbol FROM gene_map WHERE symbol IN (%s)",
      paste(sprintf("'%s'", genes_list), collapse = ", ")
    )
    gene_info <- dbGetQuery(db, gene_query)

    if (nrow(gene_info) == 0) {
      stop(sprintf("None of the specified genes found in database: %s",
                   paste(genes_list, collapse = ", ")))
    }

    valid_genes <- gene_info$symbol
    invalid_genes <- setdiff(genes_list, valid_genes)

    if (length(invalid_genes) > 0) {
      cat(sprintf("Warning: %d genes not found: %s\n",
                  length(invalid_genes),
                  paste(invalid_genes, collapse = ", ")), file = stderr())
    }

    cat(sprintf("Found %d valid genes\n", length(valid_genes)), file = stderr())

    # Build query for comparisons with filters
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

    # Get all relevant comparisons
    comparison_query <- sprintf(
      "SELECT c.id as comparison_id, d.dataset_acc, c.case_ann, c.control_ann,
              d.disease, d.source, d.treatment
       FROM comparison c
       JOIN dataset d ON c.dataset_id = d.dataset_id
       WHERE %s",
      filter_conditions
    )
    comparisons <- dbGetQuery(db, comparison_query)

    if (nrow(comparisons) == 0) {
      stop("No comparisons found matching filter criteria")
    }

    cat(sprintf("Found %d comparisons matching criteria\n", nrow(comparisons)), file = stderr())

    # Get comparison data for all genes across all comparisons
    comp_data_query <- sprintf(
      "SELECT cd.comparison_id, gm.symbol, cd.log_fc, cd.p_value, cd.p_value_adj
       FROM comparison_data cd
       JOIN gene_map gm ON cd.gene = gm.id
       WHERE cd.comparison_id IN (%s)
         AND gm.symbol IN (%s)",
      paste(comparisons$comparison_id, collapse = ", "),
      paste(sprintf("'%s'", valid_genes), collapse = ", ")
    )
    comp_data <- dbGetQuery(db, comp_data_query)

    if (nrow(comp_data) == 0) {
      stop("No comparison data found for specified genes and comparisons")
    }

    # Merge with comparison info
    comparison_table <- comp_data %>%
      left_join(comparisons, by = "comparison_id") %>%
      mutate(
        comparison_label = sprintf("%s_%s_vs_%s",
                                   dataset_acc,
                                   gsub(" ", "_", case_ann),
                                   gsub(" ", "_", control_ann))
      )

    # Export full table
    output_file <- file.path(output_dir, "comparison_table.csv")
    write.csv(comparison_table, output_file, row.names = FALSE)
    cat(sprintf("Comparison table saved to: %s\n", output_file), file = stderr())

    # Create summary tables for logFC and p-values
    # LogFC table (genes as rows, comparisons as columns)
    logfc_table <- comparison_table %>%
      select(symbol, comparison_label, log_fc) %>%
      pivot_wider(names_from = comparison_label, values_from = log_fc)

    logfc_file <- file.path(output_dir, "logfc_matrix.csv")
    write.csv(logfc_table, logfc_file, row.names = FALSE)
    cat(sprintf("LogFC matrix saved to: %s\n", logfc_file), file = stderr())

    # P-value table
    pval_table <- comparison_table %>%
      select(symbol, comparison_label, p_value_adj) %>%
      pivot_wider(names_from = comparison_label, values_from = p_value_adj)

    pval_file <- file.path(output_dir, "pvalue_matrix.csv")
    write.csv(pval_table, pval_file, row.names = FALSE)
    cat(sprintf("P-value matrix saved to: %s\n", pval_file), file = stderr())

    # Generate heatmap if requested
    if (plot) {

      # Prepare data for heatmap (logFC values)
      heatmap_data <- comparison_table %>%
        select(symbol, comparison_label, log_fc, p_value_adj) %>%
        mutate(
          # Cap extreme values for better visualization
          log_fc_capped = pmax(pmin(log_fc, 5), -5),
          significance = ifelse(p_value_adj < 0.05, "*", "")
        )

      # Create heatmap
      heatmap_plot <- ggplot(heatmap_data, aes(x = comparison_label, y = symbol, fill = log_fc_capped)) +
        geom_tile(color = "white", size = 0.5) +
        geom_text(aes(label = significance), size = 6, vjust = 0.75) +
        scale_fill_gradient2(
          low = "#377EB8", mid = "white", high = "#E41A1C",
          midpoint = 0,
          limits = c(-5, 5),
          name = "Log2 FC",
          breaks = c(-5, -2.5, 0, 2.5, 5),
          labels = c("≤-5", "-2.5", "0", "2.5", "≥5")
        ) +
        labs(
          title = "Cross-Dataset Gene Expression Comparison",
          subtitle = sprintf("Genes: %s", paste(head(valid_genes, 5), collapse = ", ")),
          x = "Comparison",
          y = "Gene",
          caption = "* FDR < 0.05"
        ) +
        theme_minimal() +
        theme(
          plot.title = element_text(hjust = 0.5, face = "bold", size = 14),
          plot.subtitle = element_text(hjust = 0.5, size = 10),
          axis.title = element_text(size = 12),
          axis.text.x = element_text(angle = 45, hjust = 1, size = 8),
          axis.text.y = element_text(size = 10),
          legend.position = "right",
          plot.caption = element_text(hjust = 0, size = 9)
        )

      heatmap_file <- file.path(output_dir, "comparison_heatmap.png")
      ggsave(heatmap_file, heatmap_plot, width = max(12, nrow(comparisons) * 0.5), height = max(6, length(valid_genes) * 0.4), dpi = 300)
      cat(sprintf("Heatmap saved to: %s\n", heatmap_file), file = stderr())
    }

    # Calculate summary statistics
    summary_stats <- comparison_table %>%
      group_by(symbol) %>%
      summarise(
        n_comparisons = n(),
        n_significant = sum(p_value_adj < 0.05, na.rm = TRUE),
        mean_logfc = mean(log_fc, na.rm = TRUE),
        median_logfc = median(log_fc, na.rm = TRUE),
        consistent_direction = all(sign(log_fc) == sign(mean_logfc), na.rm = TRUE),
        .groups = "drop"
      )

    summary_file <- file.path(output_dir, "gene_summary.csv")
    write.csv(summary_stats, summary_file, row.names = FALSE)
    cat(sprintf("Gene summary saved to: %s\n", summary_file), file = stderr())

    # Prepare JSON summary
    summary <- list(
      n_genes = length(valid_genes),
      invalid_genes = invalid_genes,
      genes = valid_genes,
      n_comparisons = nrow(comparisons),
      filters = list(
        disease = disease,
        tissue = tissue,
        treatment = treatment
      ),
      files = list(
        comparison_table = "comparison_table.csv",
        logfc_matrix = "logfc_matrix.csv",
        pvalue_matrix = "pvalue_matrix.csv",
        gene_summary = "gene_summary.csv"
      )
    )

    if (plot) {
      summary$files$heatmap <- "comparison_heatmap.png"
    }

    # Output JSON to stdout
    cat(toJSON(summary, auto_unbox = TRUE, pretty = TRUE))

  }, error = function(e) {
    error_response <- create_error_response(e$message)
    cat(toJSON(error_response, auto_unbox = TRUE))
    quit(status = 1)

  }, finally = {
    dbDisconnect(db)
  })
}

# Execute analysis
perform_comparison_table(
  opt$`db-path`,
  opt$`output-dir`,
  opt$genes,
  opt$disease,
  opt$tissue,
  opt$treatment,
  opt$plot
)
