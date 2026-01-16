#!/usr/bin/env Rscript

# Geneset/Pathway Comparison Script for IBDTransDB CLI
# Compares pathway enrichment across multiple datasets

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
  make_option(c("--pathway"), type = "character", default = NULL,
              help = "Specific pathway name or ID", metavar = "character"),
  make_option(c("--database"), type = "character", default = "geneontology_Biological_Process",
              help = "Pathway database [default: %default]", metavar = "character"),
  make_option(c("--datasets"), type = "character", default = NULL,
              help = "Comma-separated dataset accessions", metavar = "character"),
  make_option(c("--disease"), type = "character", default = NULL,
              help = "Filter by disease", metavar = "character"),
  make_option(c("--tissue"), type = "character", default = NULL,
              help = "Filter by tissue", metavar = "character"),
  make_option(c("--plot"), action = "store_true", default = FALSE,
              help = "Generate comparison plots")
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

# Main analysis function
perform_geneset_compare <- function(db_path, output_dir, pathway, database, datasets, disease, tissue, plot) {

  # Connect to database
  db <- connect_db(db_path)

  tryCatch({

    cat("Loading enrichment data from database...\n", file = stderr())

    # Build query for enrichment runs with filters
    filter_conditions <- "1=1"

    if (!is.null(database)) {
      filter_conditions <- paste0(filter_conditions, sprintf(" AND er.database = '%s'", database))
    }

    if (!is.null(datasets)) {
      datasets_list <- strsplit(datasets, ",")[[1]]
      datasets_list <- trimws(datasets_list)
      filter_conditions <- paste0(filter_conditions, sprintf(
        " AND d.dataset_acc IN (%s)",
        paste(sprintf("'%s'", datasets_list), collapse = ", ")
      ))
    }

    if (!is.null(disease)) {
      filter_conditions <- paste0(filter_conditions, sprintf(" AND d.disease LIKE '%%%s%%'", disease))
    }

    if (!is.null(tissue)) {
      filter_conditions <- paste0(filter_conditions, sprintf(" AND d.source LIKE '%%%s%%'", tissue))
    }

    # Get enrichment runs
    enrichment_run_query <- sprintf(
      "SELECT er.enrichment_run_id, d.dataset_acc, c.comparison_id,
              c.case_ann, c.control_ann, er.database, er.method
       FROM enrichment_run er
       JOIN comparison c ON er.comparison_id = c.comparison_id
       JOIN dataset d ON c.dataset_id = d.dataset_id
       WHERE %s",
      filter_conditions
    )
    enrichment_runs <- dbGetQuery(db, enrichment_run_query)

    if (nrow(enrichment_runs) == 0) {
      stop("No enrichment runs found matching filter criteria")
    }

    cat(sprintf("Found %d enrichment runs\n", nrow(enrichment_runs)), file = stderr())

    # Get enrichment data
    enrichment_data_query <- sprintf(
      "SELECT ed.enrichment_run_id, ed.geneset, ed.description, ed.size,
              ed.overlap, ed.expect, ed.enrichment_ratio, ed.p_value,
              ed.fdr, ed.overlap_genes
       FROM enrichment_data ed
       WHERE ed.enrichment_run_id IN (%s)",
      paste(enrichment_runs$enrichment_run_id, collapse = ", ")
    )
    enrichment_data <- dbGetQuery(db, enrichment_data_query)

    if (nrow(enrichment_data) == 0) {
      stop("No enrichment data found for specified runs")
    }

    cat(sprintf("Retrieved %d enrichment results\n", nrow(enrichment_data)), file = stderr())

    # Merge with run info
    enrichment_table <- enrichment_data %>%
      left_join(enrichment_runs, by = "enrichment_run_id") %>%
      mutate(
        comparison_label = sprintf("%s_%s_vs_%s",
                                   dataset_acc,
                                   gsub(" ", "_", case_ann),
                                   gsub(" ", "_", control_ann))
      )

    # Filter by pathway if specified
    if (!is.null(pathway)) {
      enrichment_table <- enrichment_table %>%
        filter(grepl(pathway, geneset, ignore.case = TRUE) |
               grepl(pathway, description, ignore.case = TRUE))

      if (nrow(enrichment_table) == 0) {
        stop(sprintf("No pathways matching '%s' found", pathway))
      }

      cat(sprintf("Filtered to %d results matching pathway '%s'\n",
                  nrow(enrichment_table), pathway), file = stderr())
    }

    # Export full table
    output_file <- file.path(output_dir, "geneset_comparison.csv")
    write.csv(enrichment_table, output_file, row.names = FALSE)
    cat(sprintf("Geneset comparison table saved to: %s\n", output_file), file = stderr())

    # Create summary of pathways by significance across datasets
    pathway_summary <- enrichment_table %>%
      group_by(geneset, description) %>%
      summarise(
        n_datasets = n_distinct(dataset_acc),
        n_comparisons = n(),
        n_significant = sum(fdr < 0.05, na.rm = TRUE),
        mean_fdr = mean(fdr, na.rm = TRUE),
        median_fdr = median(fdr, na.rm = TRUE),
        mean_enrichment_ratio = mean(enrichment_ratio, na.rm = TRUE),
        .groups = "drop"
      ) %>%
      arrange(desc(n_significant), mean_fdr)

    summary_file <- file.path(output_dir, "pathway_summary.csv")
    write.csv(pathway_summary, summary_file, row.names = FALSE)
    cat(sprintf("Pathway summary saved to: %s\n", summary_file), file = stderr())

    # Export pathways significant in multiple datasets
    consistent_pathways <- pathway_summary %>%
      filter(n_significant >= 2)

    if (nrow(consistent_pathways) > 0) {
      consistent_file <- file.path(output_dir, "consistent_pathways.csv")
      write.csv(consistent_pathways, consistent_file, row.names = FALSE)
      cat(sprintf("Consistent pathways saved to: %s\n", consistent_file), file = stderr())
    }

    # Generate plots if requested
    if (plot) {

      # Select top pathways by frequency
      top_pathways <- pathway_summary %>%
        arrange(desc(n_significant), mean_fdr) %>%
        head(20)

      if (nrow(top_pathways) > 0) {

        # Get data for top pathways
        plot_data <- enrichment_table %>%
          filter(geneset %in% top_pathways$geneset) %>%
          mutate(
            neg_log10_fdr = -log10(fdr),
            significant = ifelse(fdr < 0.05, "Yes", "No")
          )

        # Create heatmap of FDR values
        heatmap_plot <- ggplot(plot_data, aes(x = comparison_label, y = description, fill = neg_log10_fdr)) +
          geom_tile(color = "white", size = 0.5) +
          scale_fill_gradient2(
            low = "white", mid = "#FED976", high = "#E41A1C",
            midpoint = -log10(0.05),
            name = "-Log10 FDR",
            limits = c(0, max(plot_data$neg_log10_fdr, na.rm = TRUE))
          ) +
          labs(
            title = sprintf("Pathway Enrichment Comparison - %s", database),
            x = "Comparison",
            y = "Pathway"
          ) +
          theme_minimal() +
          theme(
            plot.title = element_text(hjust = 0.5, face = "bold", size = 14),
            axis.title = element_text(size = 12),
            axis.text.x = element_text(angle = 45, hjust = 1, size = 8),
            axis.text.y = element_text(size = 8),
            legend.position = "right"
          )

        heatmap_file <- file.path(output_dir, "geneset_plot.png")
        ggsave(heatmap_file, heatmap_plot, width = max(12, n_distinct(plot_data$comparison_label) * 0.5), height = max(8, nrow(top_pathways) * 0.4), dpi = 300)
        cat(sprintf("Heatmap saved to: %s\n", heatmap_file), file = stderr())

        # Create bar plot of pathway frequency
        frequency_plot <- ggplot(top_pathways, aes(x = reorder(description, n_significant), y = n_significant)) +
          geom_bar(stat = "identity", fill = "#4472C4", alpha = 0.8) +
          geom_text(aes(label = n_significant), hjust = -0.2, size = 3) +
          coord_flip() +
          labs(
            title = "Pathways Significantly Enriched Across Datasets",
            x = "Pathway",
            y = "Number of Comparisons (FDR < 0.05)"
          ) +
          theme_minimal() +
          theme(
            plot.title = element_text(hjust = 0.5, face = "bold", size = 14),
            axis.title = element_text(size = 12),
            axis.text = element_text(size = 10)
          )

        frequency_file <- file.path(output_dir, "pathway_frequency.png")
        ggsave(frequency_file, frequency_plot, width = 10, height = 8, dpi = 300)
        cat(sprintf("Frequency plot saved to: %s\n", frequency_file), file = stderr())
      }
    }

    # Prepare JSON summary
    summary <- list(
      database = database,
      pathway_filter = pathway,
      n_enrichment_runs = nrow(enrichment_runs),
      n_datasets = n_distinct(enrichment_runs$dataset_acc),
      n_pathways = n_distinct(enrichment_table$geneset),
      n_consistent_pathways = nrow(consistent_pathways),
      filters = list(
        datasets = datasets,
        disease = disease,
        tissue = tissue
      ),
      files = list(
        geneset_comparison = "geneset_comparison.csv",
        pathway_summary = "pathway_summary.csv"
      )
    )

    if (nrow(consistent_pathways) > 0) {
      summary$files$consistent_pathways <- "consistent_pathways.csv"
      summary$top_consistent_pathways <- head(consistent_pathways$description, 10)
    }

    if (plot) {
      summary$files$heatmap <- "geneset_plot.png"
      summary$files$frequency_plot <- "pathway_frequency.png"
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
perform_geneset_compare(
  opt$`db-path`,
  opt$`output-dir`,
  opt$pathway,
  opt$database,
  opt$datasets,
  opt$disease,
  opt$tissue,
  opt$plot
)
