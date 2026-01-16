# JSON Utility Functions for IBDTransDB CLI
# Helpers for exporting results as JSON

#' Export summary data to JSON (stdout)
#'
#' @param data List or data frame to export
#' @param pretty Pretty print JSON (default: TRUE)
export_json <- function(data, pretty = TRUE) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("jsonlite package is required for JSON export")
  }

  json_str <- jsonlite::toJSON(
    data,
    auto_unbox = TRUE,
    pretty = pretty,
    na = "null"
  )

  cat(json_str)
}

#' Create analysis summary object
#'
#' @param analysis_type Type of analysis (pca, dge, enrichment, etc.)
#' @param dataset_acc Dataset accession
#' @param comparison_id Comparison ID (optional)
#' @param stats Named list of statistics
#' @param files Named list of output files
#' @return List with standardized summary structure
create_summary <- function(analysis_type,
                          dataset_acc = NULL,
                          comparison_id = NULL,
                          stats = list(),
                          files = list()) {
  summary <- list(
    analysis_type = analysis_type,
    timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  )

  if (!is.null(dataset_acc)) {
    summary$dataset_acc <- dataset_acc
  }

  if (!is.null(comparison_id)) {
    summary$comparison_id <- comparison_id
  }

  # Add statistics
  summary <- c(summary, stats)

  # Add file information
  if (length(files) > 0) {
    summary$files <- files
  }

  return(summary)
}

#' Create PCA summary
#'
#' @param n_samples Number of samples
#' @param variance_explained Vector of variance explained per PC
#' @param dataset_acc Dataset accession
#' @param output_files List of output files
#' @return Summary list
create_pca_summary <- function(n_samples,
                              variance_explained,
                              dataset_acc,
                              output_files = list()) {
  create_summary(
    analysis_type = "pca",
    dataset_acc = dataset_acc,
    stats = list(
      n_samples = n_samples,
      n_components = length(variance_explained),
      variance_explained = variance_explained
    ),
    files = output_files
  )
}

#' Create DGE summary
#'
#' @param n_genes_tested Number of genes tested
#' @param n_significant Number of significant genes
#' @param n_upregulated Number of upregulated genes
#' @param n_downregulated Number of downregulated genes
#' @param dataset_acc Dataset accession
#' @param comparison_id Comparison ID
#' @param output_files List of output files
#' @return Summary list
create_dge_summary <- function(n_genes_tested,
                              n_significant,
                              n_upregulated,
                              n_downregulated,
                              dataset_acc,
                              comparison_id,
                              output_files = list()) {
  create_summary(
    analysis_type = "dge",
    dataset_acc = dataset_acc,
    comparison_id = comparison_id,
    stats = list(
      n_genes_tested = n_genes_tested,
      n_significant = n_significant,
      n_upregulated = n_upregulated,
      n_downregulated = n_downregulated
    ),
    files = output_files
  )
}

#' Create enrichment summary
#'
#' @param method Enrichment method (ORA or GSEA)
#' @param database Enrichment database
#' @param n_pathways Number of pathways tested
#' @param n_enriched Number of enriched pathways
#' @param dataset_acc Dataset accession
#' @param comparison_id Comparison ID
#' @param output_files List of output files
#' @return Summary list
create_enrichment_summary <- function(method,
                                     database,
                                     n_pathways,
                                     n_enriched,
                                     dataset_acc,
                                     comparison_id,
                                     output_files = list()) {
  create_summary(
    analysis_type = "enrichment",
    dataset_acc = dataset_acc,
    comparison_id = comparison_id,
    stats = list(
      method = method,
      database = database,
      n_pathways = n_pathways,
      n_enriched = n_enriched
    ),
    files = output_files
  )
}

#' Create meta-analysis summary
#'
#' @param n_comparisons Number of comparisons
#' @param n_genes Number of genes analyzed
#' @param n_significant Number of significant genes
#' @param output_files List of output files
#' @return Summary list
create_meta_analysis_summary <- function(n_comparisons,
                                        n_genes,
                                        n_significant,
                                        output_files = list()) {
  create_summary(
    analysis_type = "meta_analysis",
    stats = list(
      n_comparisons = n_comparisons,
      n_genes = n_genes,
      n_significant = n_significant
    ),
    files = output_files
  )
}

#' Create cell deconvolution summary
#'
#' @param n_samples Number of samples
#' @param n_cell_types Number of cell types
#' @param cell_types Vector of cell type names
#' @param dataset_acc Dataset accession
#' @param output_files List of output files
#' @return Summary list
create_cell_deconvolution_summary <- function(n_samples,
                                             n_cell_types,
                                             cell_types,
                                             dataset_acc,
                                             output_files = list()) {
  create_summary(
    analysis_type = "cell_deconvolution",
    dataset_acc = dataset_acc,
    stats = list(
      n_samples = n_samples,
      n_cell_types = n_cell_types,
      cell_types = cell_types
    ),
    files = output_files
  )
}

#' Save data frame to JSON file
#'
#' @param data Data frame to save
#' @param filename Output filename
#' @param pretty Pretty print (default: TRUE)
save_json <- function(data, filename, pretty = TRUE) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("jsonlite package is required")
  }

  jsonlite::write_json(
    data,
    path = filename,
    auto_unbox = TRUE,
    pretty = pretty,
    na = "null"
  )
}

#' Convert data frame to JSON string
#'
#' @param data Data frame
#' @param pretty Pretty print (default: FALSE)
#' @return JSON string
df_to_json <- function(data, pretty = FALSE) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("jsonlite package is required")
  }

  jsonlite::toJSON(
    data,
    auto_unbox = TRUE,
    pretty = pretty,
    dataframe = "rows",
    na = "null"
  )
}

#' Create error response
#'
#' @param error_message Error message string
#' @return List with error structure
create_error_response <- function(error_message) {
  list(
    error = error_message,
    timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  )
}

#' Export error as JSON and exit
#'
#' @param error_message Error message
#' @param exit_code Exit code (default: 1)
export_error_and_exit <- function(error_message, exit_code = 1) {
  error_response <- create_error_response(error_message)
  export_json(error_response)
  quit(status = exit_code)
}

#' Get list of files in directory with relative paths
#'
#' @param output_dir Output directory
#' @param pattern File pattern to match (optional)
#' @return Named list of file types and their paths
get_output_files_list <- function(output_dir, pattern = NULL) {
  files_list <- list(
    plots = c(),
    tables = c(),
    data = c()
  )

  if (!dir.exists(output_dir)) {
    return(files_list)
  }

  # Find plot files
  plot_extensions <- c("png", "pdf", "svg")
  for (ext in plot_extensions) {
    plot_files <- list.files(output_dir, pattern = paste0("\\.", ext, "$"),
                            full.names = FALSE)
    files_list$plots <- c(files_list$plots, plot_files)
  }

  # Find table files
  table_extensions <- c("csv", "tsv", "txt")
  for (ext in table_extensions) {
    table_files <- list.files(output_dir, pattern = paste0("\\.", ext, "$"),
                             full.names = FALSE)
    files_list$tables <- c(files_list$tables, table_files)
  }

  # Find data files
  data_extensions <- c("json", "rds", "RData")
  for (ext in data_extensions) {
    data_files <- list.files(output_dir, pattern = paste0("\\.", ext, "$"),
                            full.names = FALSE)
    files_list$data <- c(files_list$data, data_files)
  }

  return(files_list)
}
