# Database Utility Functions for IBDTransDB CLI
# Common database connection and query helpers

#' Connect to IBDTransDB database
#'
#' @param db_path Path to IBDTransDB.db file
#' @return Database connection object
connect_db <- function(db_path) {
  if (!requireNamespace("RSQLite", quietly = TRUE)) {
    stop("RSQLite package is required but not installed")
  }

  if (!file.exists(db_path)) {
    stop(sprintf("Database not found: %s", db_path))
  }

  db <- DBI::dbConnect(RSQLite::SQLite(), dbname = db_path)
  return(db)
}

#' Safely disconnect from database
#'
#' @param db Database connection object
disconnect_db <- function(db) {
  if (!is.null(db) && DBI::dbIsValid(db)) {
    DBI::dbDisconnect(db)
  }
}

#' Execute a query and return results as data frame
#'
#' @param db Database connection
#' @param query SQL query string
#' @param params Optional query parameters
#' @return Data frame with query results
query_db <- function(db, query, params = NULL) {
  if (is.null(params)) {
    result <- DBI::dbGetQuery(db, query)
  } else {
    result <- DBI::dbGetQuery(db, query, params = params)
  }
  return(result)
}

#' Get dataset information
#'
#' @param db Database connection
#' @param dataset_acc Dataset accession (e.g., GSE16879)
#' @return Data frame with dataset info
get_dataset <- function(db, dataset_acc) {
  query <- "SELECT * FROM dataset WHERE dataset_acc = ?"
  result <- query_db(db, query, list(dataset_acc))

  if (nrow(result) == 0) {
    stop(sprintf("Dataset not found: %s", dataset_acc))
  }

  return(result)
}

#' Get sample annotations for a dataset
#'
#' @param db Database connection
#' @param dataset_acc Dataset accession
#' @return Data frame with sample annotations
get_sample_annotations <- function(db, dataset_acc) {
  query <- "SELECT * FROM sample_ann WHERE dataset_acc = ?"
  result <- query_db(db, query, list(dataset_acc))
  return(result)
}

#' Get comparisons for a dataset
#'
#' @param db Database connection
#' @param dataset_acc Dataset accession
#' @return Data frame with comparison definitions
get_comparisons <- function(db, dataset_acc) {
  query <- "SELECT * FROM comparison WHERE dataset_acc = ?"
  result <- query_db(db, query, list(dataset_acc))
  return(result)
}

#' Get comparison data (differential expression results)
#'
#' @param db Database connection
#' @param comparison_id Comparison ID
#' @param genes Optional vector of gene symbols to filter
#' @return Data frame with comparison data
get_comparison_data <- function(db, comparison_id, genes = NULL) {
  if (is.null(genes)) {
    query <- "SELECT * FROM comparison_data WHERE comparison_id = ?"
    result <- query_db(db, query, list(comparison_id))
  } else {
    # Get gene IDs for symbols
    placeholders <- paste(rep("?", length(genes)), collapse = ",")
    gene_query <- sprintf(
      "SELECT id, symbol FROM gene_map WHERE symbol IN (%s)",
      placeholders
    )
    gene_map <- query_db(db, gene_query, as.list(genes))

    # Get comparison data for these genes
    gene_ids <- gene_map$id
    if (length(gene_ids) > 0) {
      placeholders <- paste(rep("?", length(gene_ids)), collapse = ",")
      query <- sprintf(
        "SELECT * FROM comparison_data WHERE comparison_id = ? AND gene IN (%s)",
        placeholders
      )
      result <- query_db(db, query, c(list(comparison_id), as.list(gene_ids)))
    } else {
      result <- data.frame()
    }
  }

  return(result)
}

#' Get gene map (gene ID to symbol mapping)
#'
#' @param db Database connection
#' @param genes Optional vector of gene symbols
#' @return Data frame with gene mappings
get_gene_map <- function(db, genes = NULL) {
  if (is.null(genes)) {
    query <- "SELECT * FROM gene_map"
    result <- query_db(db, query)
  } else {
    placeholders <- paste(rep("?", length(genes)), collapse = ",")
    query <- sprintf("SELECT * FROM gene_map WHERE symbol IN (%s)", placeholders)
    result <- query_db(db, query, as.list(genes))
  }
  return(result)
}

#' Get expression data for specific genes
#'
#' @param db Database connection
#' @param dataset_acc Dataset accession
#' @param genes Vector of gene symbols
#' @return Data frame with expression data
get_expression_data <- function(db, dataset_acc, genes) {
  # Get gene IDs
  gene_map <- get_gene_map(db, genes)

  if (nrow(gene_map) == 0) {
    warning("No genes found in database")
    return(data.frame())
  }

  # Get dataset ID
  dataset <- get_dataset(db, dataset_acc)
  dataset_id <- dataset$dataset_id[1]

  # Get expression data
  gene_ids <- gene_map$id
  placeholders <- paste(rep("?", length(gene_ids)), collapse = ",")
  query <- sprintf(
    "SELECT * FROM dataset_data WHERE dataset_id = ? AND gene IN (%s)",
    placeholders
  )
  result <- query_db(db, query, c(list(dataset_id), as.list(gene_ids)))

  # Merge with gene symbols
  result <- merge(result, gene_map[, c("id", "symbol")],
                  by.x = "gene", by.y = "id", all.x = TRUE)

  return(result)
}

#' Get PCA data for a dataset
#'
#' @param db Database connection
#' @param dataset_acc Dataset accession
#' @return Data frame with PCA coordinates
get_pca_data <- function(db, dataset_acc) {
  query <- "SELECT * FROM pca WHERE dataset_acc = ?"
  result <- query_db(db, query, list(dataset_acc))
  return(result)
}

#' Get cell deconvolution data for a dataset
#'
#' @param db Database connection
#' @param dataset_acc Dataset accession
#' @return Data frame with cell type fractions
get_cell_deconvolution <- function(db, dataset_acc) {
  query <- "SELECT * FROM cell_deconvolution WHERE dataset_acc = ?"
  result <- query_db(db, query, list(dataset_acc))
  return(result)
}

#' Get enrichment results for a dataset
#'
#' @param db Database connection
#' @param dataset_acc Dataset accession
#' @param database_name Optional enrichment database filter (e.g., "KEGG")
#' @return Data frame with enrichment results
get_enrichment_results <- function(db, dataset_acc, database_name = NULL) {
  # Get dataset ID
  dataset <- get_dataset(db, dataset_acc)
  dataset_id <- dataset$dataset_id[1]

  if (is.null(database_name)) {
    query <- "
      SELECT er.*
      FROM enrichment_results er
      JOIN enrichment_run run ON er.enrichment_run_id = run.enrichment_run_id
      WHERE run.dataset_id = ?
    "
    result <- query_db(db, query, list(dataset_id))
  } else {
    query <- "
      SELECT er.*
      FROM enrichment_results er
      JOIN enrichment_run run ON er.enrichment_run_id = run.enrichment_run_id
      WHERE run.dataset_id = ? AND run.database = ?
    "
    result <- query_db(db, query, list(dataset_id, database_name))
  }

  return(result)
}

#' Check if dataset exists
#'
#' @param db Database connection
#' @param dataset_acc Dataset accession
#' @return Logical indicating if dataset exists
dataset_exists <- function(db, dataset_acc) {
  query <- "SELECT COUNT(*) as count FROM dataset WHERE dataset_acc = ?"
  result <- query_db(db, query, list(dataset_acc))
  return(result$count[1] > 0)
}

#' Check if comparison exists
#'
#' @param db Database connection
#' @param comparison_id Comparison ID
#' @return Logical indicating if comparison exists
comparison_exists <- function(db, comparison_id) {
  query <- "SELECT COUNT(*) as count FROM comparison WHERE id = ?"
  result <- query_db(db, query, list(comparison_id))
  return(result$count[1] > 0)
}

#' Get available filter options
#'
#' @param db Database connection
#' @return List with available diseases, tissues, treatments, organisms
get_filter_options <- function(db) {
  list(
    diseases = unique(query_db(db, "SELECT DISTINCT disease FROM dataset")$disease),
    tissues = unique(query_db(db, "SELECT DISTINCT source FROM dataset")$source),
    treatments = unique(query_db(db, "SELECT DISTINCT treatment FROM dataset")$treatment),
    organisms = unique(query_db(db, "SELECT DISTINCT organism FROM dataset")$organism)
  )
}
