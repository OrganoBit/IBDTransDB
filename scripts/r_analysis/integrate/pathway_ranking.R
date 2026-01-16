#!/usr/bin/env Rscript

# Pathway Integration Script for IBDTransDB CLI
# Integrates pathway enrichment across datasets

suppressPackageStartupMessages({
  library(optparse)
  library(RSQLite)
  library(DBI)
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(jsonlite)
})

# Parse arguments
option_list <- list(
  make_option(c("--db-path"), type = "character", default = NULL),
  make_option(c("--output-dir"), type = "character", default = NULL),
  make_option(c("--databases"), type = "character", default = "geneontology_Biological_Process"),
  make_option(c("--disease"), type = "character", default = NULL),
  make_option(c("--tissue"), type = "character", default = NULL),
  make_option(c("--min-datasets"), type = "integer", default = 2),
  make_option(c("--fdr-threshold"), type = "double", default = 0.05),
  make_option(c("--plot"), action = "store_true", default = FALSE)
)

opt <- parse_args(OptionParser(option_list = option_list))

# Get script directory in a way that works with Rscript
args <- commandArgs(trailingOnly = FALSE)
script_path <- sub("^--file=", "", args[grep("^--file=", args)])
script_dir <- dirname(normalizePath(script_path))
source(file.path(dirname(script_dir), "common", "database_utils.R"))
source(file.path(dirname(script_dir), "common", "json_utils.R"))

perform_pathway_integration <- function(db_path, output_dir, databases_str, disease, tissue, min_datasets, fdr_threshold, plot) {
  db <- connect_db(db_path)

  tryCatch({
    # Parse databases
    db_list <- strsplit(databases_str, ",")[[1]]
    db_list <- trimws(db_list)

    cat(sprintf("Integrating pathways from %d databases\n", length(db_list)), file = stderr())

    # Build filters
    filter_cond <- "1=1"
    if (!is.null(disease)) filter_cond <- paste0(filter_cond, sprintf(" AND d.disease LIKE '%%%s%%'", disease))
    if (!is.null(tissue)) filter_cond <- paste0(filter_cond, sprintf(" AND d.source LIKE '%%%s%%'", tissue))

    # Filter by databases
    filter_cond <- paste0(filter_cond, sprintf(" AND er.database IN (%s)",
                         paste(sprintf("'%s'", db_list), collapse = ", ")))

    # Get enrichment runs
    enrich_runs <- dbGetQuery(db, sprintf(
      "SELECT er.enrichment_run_id, d.dataset_acc, c.comparison_id, er.database
       FROM enrichment_run er
       JOIN comparison c ON er.comparison_id = c.comparison_id
       JOIN dataset d ON c.dataset_id = d.dataset_id
       WHERE %s", filter_cond
    ))

    if (nrow(enrich_runs) == 0) {
      stop("No enrichment runs found matching criteria")
    }

    cat(sprintf("Found %d enrichment runs from %d datasets\n",
                nrow(enrich_runs), n_distinct(enrich_runs$dataset_acc)), file = stderr())

    # Get enrichment data
    enrich_data <- dbGetQuery(db, sprintf(
      "SELECT ed.enrichment_run_id, ed.geneset, ed.description, ed.fdr, ed.enrichment_ratio
       FROM enrichment_data ed
       WHERE ed.enrichment_run_id IN (%s) AND ed.fdr < %f",
      paste(enrich_runs$enrichment_run_id, collapse = ", "),
      fdr_threshold
    ))

    # Merge with run info
    enrich_data <- enrich_data %>%
      left_join(enrich_runs, by = "enrichment_run_id")

    # Aggregate pathways
    pathway_integration <- enrich_data %>%
      group_by(geneset, description) %>%
      summarise(
        n_datasets = n_distinct(dataset_acc),
        n_comparisons = n(),
        mean_fdr = mean(fdr, na.rm = TRUE),
        median_fdr = median(fdr, na.rm = TRUE),
        mean_enrichment = mean(enrichment_ratio, na.rm = TRUE),
        .groups = "drop"
      ) %>%
      filter(n_datasets >= min_datasets) %>%
      mutate(
        consistency_score = n_datasets / max(n_datasets),
        integration_score = -log10(mean_fdr) * consistency_score
      ) %>%
      arrange(desc(integration_score))

    cat(sprintf("Integrated %d pathways meeting criteria\n", nrow(pathway_integration)), file = stderr())

    # Export
    output_file <- file.path(output_dir, "integrated_pathways.csv")
    write.csv(pathway_integration, output_file, row.names = FALSE)
    cat(sprintf("Integrated pathways saved to: %s\n", output_file), file = stderr())

    # Plot
    if (plot && nrow(pathway_integration) > 0) {
      top_pathways <- pathway_integration %>% head(30)

      pathway_plot <- ggplot(top_pathways, aes(x = reorder(description, integration_score), y = integration_score)) +
        geom_bar(stat = "identity", aes(fill = n_datasets), alpha = 0.8) +
        scale_fill_gradient(low = "#FED976", high = "#E41A1C", name = "# Datasets") +
        coord_flip() +
        labs(title = "Top Integrated Pathways", x = "Pathway", y = "Integration Score") +
        theme_minimal() +
        theme(
          plot.title = element_text(hjust = 0.5, face = "bold"),
          axis.text.y = element_text(size = 8)
        )

      ggsave(file.path(output_dir, "pathway_integration_plot.png"), pathway_plot, width = 12, height = 10, dpi = 300)
    }

    # Summary
    summary <- list(
      n_pathways = nrow(pathway_integration),
      n_comparisons = nrow(enrich_runs),
      n_datasets = n_distinct(enrich_runs$dataset_acc),
      databases = db_list,
      filters = list(disease = disease, tissue = tissue),
      files = list(integrated_pathways = "integrated_pathways.csv")
    )

    if (plot) summary$files$plot <- "pathway_integration_plot.png"

    cat(toJSON(summary, auto_unbox = TRUE, pretty = TRUE))

  }, error = function(e) {
    cat(toJSON(create_error_response(e$message), auto_unbox = TRUE))
    quit(status = 1)
  }, finally = {
    dbDisconnect(db)
  })
}

perform_pathway_integration(
  opt$`db-path`, opt$`output-dir`, opt$databases, opt$disease, opt$tissue,
  opt$`min-datasets`, opt$`fdr-threshold`, opt$plot
)
