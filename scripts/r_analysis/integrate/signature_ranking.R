#!/usr/bin/env Rscript

# Signature Ranking Script for IBDTransDB CLI
# Ranks gene signatures across datasets

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
  make_option(c("--signatures"), type = "character", default = NULL, help = "JSON file with signatures"),
  make_option(c("--disease"), type = "character", default = NULL),
  make_option(c("--tissue"), type = "character", default = NULL),
  make_option(c("--method"), type = "character", default = "mean", help = "mean, median, gsea"),
  make_option(c("--plot"), action = "store_true", default = FALSE)
)

opt <- parse_args(OptionParser(option_list = option_list))

# Get script directory in a way that works with Rscript
args <- commandArgs(trailingOnly = FALSE)
script_path <- sub("^--file=", "", args[grep("^--file=", args)])
script_dir <- dirname(normalizePath(script_path))
source(file.path(dirname(script_dir), "common", "database_utils.R"))
source(file.path(dirname(script_dir), "common", "json_utils.R"))

perform_signature_ranking <- function(db_path, output_dir, signatures_file, disease, tissue, method, plot) {
  db <- connect_db(db_path)

  tryCatch({
    # Load signatures from JSON
    signatures <- fromJSON(signatures_file)
    cat(sprintf("Loaded %d signatures\n", length(signatures)), file = stderr())

    # Get comparisons with filters
    filter_cond <- "1=1"
    if (!is.null(disease)) filter_cond <- paste0(filter_cond, sprintf(" AND d.disease LIKE '%%%s%%'", disease))
    if (!is.null(tissue)) filter_cond <- paste0(filter_cond, sprintf(" AND d.source LIKE '%%%s%%'", tissue))

    comparisons <- dbGetQuery(db, sprintf(
      "SELECT c.id as comparison_id, d.dataset_acc, d.dataset_id FROM comparison c
       JOIN dataset d ON c.dataset_id = d.dataset_id WHERE %s", filter_cond
    ))

    cat(sprintf("Found %d comparisons\n", nrow(comparisons)), file = stderr())

    # Calculate signature scores per comparison
    sig_results <- list()

    for (sig_name in names(signatures)) {
      genes <- signatures[[sig_name]]
      cat(sprintf("Processing signature: %s (%d genes)\n", sig_name, length(genes)), file = stderr())

      for (i in 1:nrow(comparisons)) {
        comp_id <- comparisons$comparison_id[i]
        dataset_acc <- comparisons$dataset_acc[i]

        # Get expression data for signature genes
        expr_query <- sprintf(
          "SELECT gm.symbol, cd.log_fc, cd.p_value FROM comparison_data cd
           JOIN gene_map gm ON cd.gene = gm.id
           WHERE cd.comparison_id = %d AND gm.symbol IN (%s)",
          comp_id, paste(sprintf("'%s'", genes), collapse = ", ")
        )
        expr_data <- dbGetQuery(db, expr_query)

        if (nrow(expr_data) == 0) next

        # Calculate signature score based on method
        if (method == "mean") {
          score <- mean(expr_data$log_fc, na.rm = TRUE)
        } else if (method == "median") {
          score <- median(expr_data$log_fc, na.rm = TRUE)
        } else {
          score <- mean(expr_data$log_fc, na.rm = TRUE)  # Default to mean
        }

        sig_results[[length(sig_results) + 1]] <- data.frame(
          signature = sig_name,
          comparison_id = comp_id,
          dataset_acc = dataset_acc,
          score = score,
          n_genes = nrow(expr_data)
        )
      }
    }

    # Combine results
    sig_df <- do.call(rbind, sig_results)

    # Rank signatures by consistency
    sig_ranking <- sig_df %>%
      group_by(signature) %>%
      summarise(
        n_comparisons = n(),
        n_datasets = n_distinct(dataset_acc),
        mean_score = mean(score, na.rm = TRUE),
        median_score = median(score, na.rm = TRUE),
        sd_score = sd(score, na.rm = TRUE),
        consistency = sum(sign(score) == sign(mean_score)) / n(),
        .groups = "drop"
      ) %>%
      mutate(rank_score = abs(mean_score) * consistency) %>%
      arrange(desc(rank_score))

    # Export
    output_file <- file.path(output_dir, "signature_rankings.csv")
    write.csv(sig_ranking, output_file, row.names = FALSE)
    cat(sprintf("Signature rankings saved to: %s\n", output_file), file = stderr())

    # Plot
    if (plot && nrow(sig_ranking) > 0) {
      sig_plot <- ggplot(sig_ranking, aes(x = reorder(signature, rank_score), y = rank_score)) +
        geom_bar(stat = "identity", fill = "#4472C4", alpha = 0.8) +
        coord_flip() +
        labs(title = "Signature Rankings", x = "Signature", y = "Rank Score") +
        theme_minimal()

      ggsave(file.path(output_dir, "signature_plot.png"), sig_plot, width = 10, height = 8, dpi = 300)
    }

    # Summary
    summary <- list(
      n_signatures = nrow(sig_ranking),
      n_comparisons = n_distinct(sig_df$comparison_id),
      n_datasets = n_distinct(sig_df$dataset_acc),
      method = method,
      files = list(signature_rankings = "signature_rankings.csv")
    )

    if (plot) summary$files$plot <- "signature_plot.png"

    cat(toJSON(summary, auto_unbox = TRUE, pretty = TRUE))

  }, error = function(e) {
    cat(toJSON(create_error_response(e$message), auto_unbox = TRUE))
    quit(status = 1)
  }, finally = {
    dbDisconnect(db)
  })
}

perform_signature_ranking(
  opt$`db-path`, opt$`output-dir`, opt$signatures, opt$disease, opt$tissue, opt$method, opt$plot
)
