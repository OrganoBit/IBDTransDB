#!/usr/bin/env Rscript

# Pathway Enrichment Analysis Script for IBDTransDB CLI
# Performs ORA or GSEA using WebGestaltR

suppressPackageStartupMessages({
  library(optparse)
  library(RSQLite)
  library(DBI)
  library(dplyr)
  library(WebGestaltR)
  library(jsonlite)
})

# Parse command-line arguments
option_list <- list(
  make_option(c("--db-path"), type = "character", default = NULL,
              help = "Path to IBDTransDB.db", metavar = "character"),
  make_option(c("--output-dir"), type = "character", default = NULL,
              help = "Output directory for results", metavar = "character"),
  make_option(c("--dataset-acc"), type = "character", default = NULL,
              help = "Dataset accession (e.g., GSE16879)", metavar = "character"),
  make_option(c("--comparison-id"), type = "integer", default = NULL,
              help = "Comparison ID", metavar = "integer"),
  make_option(c("--method"), type = "character", default = "ORA",
              help = "Enrichment method: ORA or GSEA [default: %default]", metavar = "character"),
  make_option(c("--database"), type = "character", default = "geneontology_Biological_Process",
              help = "Pathway database [default: %default]", metavar = "character"),
  make_option(c("--pval-threshold"), type = "double", default = 0.05,
              help = "P-value threshold for input genes [default: %default]", metavar = "double"),
  make_option(c("--fdr-threshold"), type = "double", default = 0.05,
              help = "FDR threshold for enriched pathways [default: %default]", metavar = "double"),
  make_option(c("--top-pathways"), type = "integer", default = 20,
              help = "Number of top pathways to export [default: %default]", metavar = "integer"),
  make_option(c("--min-overlap"), type = "integer", default = 5,
              help = "Minimum gene overlap for pathways [default: %default]", metavar = "integer")
)

opt_parser <- OptionParser(option_list = option_list)
opt <- parse_args(opt_parser)

# Validate required arguments
if (is.null(opt$`db-path`) || is.null(opt$`output-dir`) ||
    is.null(opt$`dataset-acc`) || is.null(opt$`comparison-id`)) {
  print_help(opt_parser)
  stop("Missing required arguments", call. = FALSE)
}

# Source common utilities
# Get script directory in a way that works with Rscript
args <- commandArgs(trailingOnly = FALSE)
script_path <- sub("^--file=", "", args[grep("^--file=", args)])
script_dir <- dirname(normalizePath(script_path))
source(file.path(dirname(script_dir), "common", "database_utils.R"))
source(file.path(dirname(script_dir), "common", "json_utils.R"))

# Main analysis function
perform_enrichment_analysis <- function(db_path, output_dir, dataset_acc, comparison_id,
                                        method, database, pval_threshold, fdr_threshold,
                                        top_pathways, min_overlap) {

  # Connect to database
  db <- connect_db(db_path)

  tryCatch({

    # Get dataset ID
    dataset_info <- get_dataset(db, dataset_acc)
    if (nrow(dataset_info) == 0) {
      stop(sprintf("Dataset %s not found in database", dataset_acc))
    }
    dataset_id <- dataset_info$dataset_id[1]

    # Get comparison info
    comparison_query <- sprintf(
      "SELECT * FROM comparison WHERE dataset_id = %d AND id = %d",
      dataset_id, comparison_id
    )
    comparison_info <- dbGetQuery(db, comparison_query)

    if (nrow(comparison_info) == 0) {
      stop(sprintf("Comparison %d not found for dataset %s", comparison_id, dataset_acc))
    }

    cat(sprintf("Loading DGE results for enrichment analysis...\n"), file = stderr())

    # Get DGE data
    dge_data <- get_comparison_data(db, comparison_id)

    if (nrow(dge_data) == 0) {
      stop(sprintf("No DGE data found for comparison %d", comparison_id))
    }

    # Prepare gene list based on method
    if (toupper(method) == "ORA") {
      # Over-Representation Analysis: use significant genes only
      sig_genes <- dge_data %>%
        filter(p_value_adj < pval_threshold) %>%
        pull(symbol)

      if (length(sig_genes) == 0) {
        stop(sprintf("No significant genes found at p-value threshold %.3f", pval_threshold))
      }

      cat(sprintf("Using %d significant genes for ORA\n", length(sig_genes)), file = stderr())

      interest_gene <- sig_genes
      interest_gene_type <- "genesymbol"

    } else if (toupper(method) == "GSEA") {
      # Gene Set Enrichment Analysis: use all genes ranked by statistic
      ranked_genes <- dge_data %>%
        filter(!is.na(log_fc) & !is.na(p_value)) %>%
        mutate(
          # Compute ranking score: -log10(p) * sign(logFC)
          rank_score = -log10(p_value) * sign(log_fc)
        ) %>%
        arrange(desc(rank_score))

      if (nrow(ranked_genes) == 0) {
        stop("No valid genes for GSEA ranking")
      }

      cat(sprintf("Using %d ranked genes for GSEA\n", nrow(ranked_genes)), file = stderr())

      # WebGestaltR expects named vector for GSEA
      interest_gene <- setNames(ranked_genes$rank_score, ranked_genes$symbol)
      interest_gene_type <- "genesymbol"

    } else {
      stop(sprintf("Unknown enrichment method: %s. Use ORA or GSEA.", method))
    }

    # Get reference gene set (all genes in dataset)
    ref_genes <- dge_data %>%
      pull(symbol)

    cat(sprintf("Reference set: %d genes\n", length(ref_genes)), file = stderr())
    cat(sprintf("Running %s enrichment for database: %s\n", method, database), file = stderr())

    # Run WebGestalt enrichment
    enrichment_result <- WebGestaltR(
      enrichMethod = method,
      organism = "hsapiens",
      enrichDatabase = database,
      interestGene = interest_gene,
      interestGeneType = interest_gene_type,
      referenceGene = ref_genes,
      referenceGeneType = "genesymbol",
      minNum = min_overlap,
      maxNum = 500,
      fdrThr = 1.0,  # Get all results, filter later
      isOutput = FALSE,
      projectName = NULL,
      hostName = "https://www.webgestalt.org/"
    )

    if (is.null(enrichment_result) || nrow(enrichment_result) == 0) {
      cat("Warning: No enriched pathways found\n", file = stderr())

      summary <- list(
        dataset_acc = dataset_acc,
        comparison_id = comparison_id,
        method = method,
        database = database,
        n_input_genes = ifelse(method == "ORA", length(sig_genes), nrow(ranked_genes)),
        n_enriched_pathways = 0,
        message = "No enriched pathways found",
        files = list()
      )

      cat(toJSON(summary, auto_unbox = TRUE, pretty = TRUE))
      quit(status = 0)
    }

    cat(sprintf("Found %d enriched pathways\n", nrow(enrichment_result)), file = stderr())

    # Filter by FDR threshold
    sig_pathways <- enrichment_result %>%
      filter(FDR < fdr_threshold) %>%
      arrange(FDR)

    cat(sprintf("Significant pathways (FDR < %.3f): %d\n", fdr_threshold, nrow(sig_pathways)), file = stderr())

    # Export full results
    output_file <- file.path(output_dir, "enrichment_results.csv")
    write.csv(enrichment_result, output_file, row.names = FALSE)
    cat(sprintf("Full enrichment results saved to: %s\n", output_file), file = stderr())

    # Export significant pathways
    if (nrow(sig_pathways) > 0) {
      sig_file <- file.path(output_dir, "significant_pathways.csv")
      write.csv(sig_pathways, sig_file, row.names = FALSE)
      cat(sprintf("Significant pathways saved to: %s\n", sig_file), file = stderr())
    }

    # Export top pathways
    top_results <- enrichment_result %>%
      arrange(FDR) %>%
      head(top_pathways)

    top_file <- file.path(output_dir, "top_pathways.csv")
    write.csv(top_results, top_file, row.names = FALSE)
    cat(sprintf("Top %d pathways saved to: %s\n", top_pathways, top_file), file = stderr())

    # Prepare JSON summary
    summary <- list(
      dataset_acc = dataset_acc,
      comparison_id = comparison_id,
      case_annotation = comparison_info$case_ann[1],
      control_annotation = comparison_info$control_ann[1],
      method = method,
      database = database,
      n_input_genes = ifelse(method == "ORA", length(sig_genes), nrow(ranked_genes)),
      n_enriched_pathways = nrow(enrichment_result),
      n_significant_pathways = nrow(sig_pathways),
      thresholds = list(
        pval_threshold = pval_threshold,
        fdr_threshold = fdr_threshold,
        min_overlap = min_overlap
      ),
      files = list(
        enrichment_results = "enrichment_results.csv",
        top_pathways = "top_pathways.csv"
      )
    )

    if (nrow(sig_pathways) > 0) {
      summary$files$significant_pathways <- "significant_pathways.csv"

      # Add top 5 pathway names to summary
      summary$top_pathways <- head(sig_pathways$description, 5)
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
perform_enrichment_analysis(
  opt$`db-path`,
  opt$`output-dir`,
  opt$`dataset-acc`,
  opt$`comparison-id`,
  opt$method,
  opt$database,
  opt$`pval-threshold`,
  opt$`fdr-threshold`,
  opt$`top-pathways`,
  opt$`min-overlap`
)
