#!/usr/bin/env Rscript

# Gene Expression Plot Script for IBDTransDB CLI
# Creates boxplots for selected genes across sample groups

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
  make_option(c("--dataset-acc"), type = "character", default = NULL,
              help = "Dataset accession (e.g., GSE16879)", metavar = "character"),
  make_option(c("--genes"), type = "character", default = NULL,
              help = "Comma-separated list of gene symbols", metavar = "character"),
  make_option(c("--group-by"), type = "character", default = NULL,
              help = "Sample annotation for grouping", metavar = "character"),
  make_option(c("--groups"), type = "character", default = NULL,
              help = "Comma-separated list of groups to include", metavar = "character"),
  make_option(c("--plot"), action = "store_true", default = FALSE,
              help = "Generate expression boxplots"),
  make_option(c("--test"), action = "store_true", default = FALSE,
              help = "Perform statistical tests between groups")
)

opt_parser <- OptionParser(option_list = option_list)
opt <- parse_args(opt_parser)

# Validate required arguments
if (is.null(opt$`db-path`) || is.null(opt$`output-dir`) ||
    is.null(opt$`dataset-acc`) || is.null(opt$genes)) {
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
perform_expression_plot <- function(db_path, output_dir, dataset_acc, genes_str,
                                    group_by, groups_str, plot, test) {

  # Connect to database
  db <- connect_db(db_path)

  tryCatch({

    # Parse gene list
    genes_list <- strsplit(genes_str, ",")[[1]]
    genes_list <- trimws(genes_list)

    cat(sprintf("Analyzing expression for %d genes: %s\n",
                length(genes_list), paste(genes_list, collapse = ", ")), file = stderr())

    # Get dataset ID
    dataset_info <- get_dataset(db, dataset_acc)
    if (nrow(dataset_info) == 0) {
      stop(sprintf("Dataset %s not found in database", dataset_acc))
    }
    dataset_id <- dataset_info$dataset_id[1]

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

    # Get expression data for these genes
    expr_query <- sprintf(
      "SELECT dd.sample_id, gm.symbol, dd.expression_value
       FROM dataset_data dd
       JOIN gene_map gm ON dd.gene = gm.id
       WHERE dd.dataset_id = %d AND gm.symbol IN (%s)",
      dataset_id,
      paste(sprintf("'%s'", valid_genes), collapse = ", ")
    )
    expr_data <- dbGetQuery(db, expr_query)

    if (nrow(expr_data) == 0) {
      stop("No expression data found for specified genes")
    }

    # Get sample annotations
    sample_ann <- get_sample_annotations(db, dataset_id)

    # Merge expression with annotations
    expr_data <- expr_data %>%
      left_join(sample_ann, by = "sample_id")

    # Filter by groups if specified
    if (!is.null(groups_str)) {
      groups_list <- strsplit(groups_str, ",")[[1]]
      groups_list <- trimws(groups_list)

      if (!is.null(group_by) && group_by %in% colnames(expr_data)) {
        expr_data <- expr_data %>%
          filter(!!sym(group_by) %in% groups_list)

        cat(sprintf("Filtered to groups: %s\n", paste(groups_list, collapse = ", ")), file = stderr())
      }
    }

    # Export expression data
    output_file <- file.path(output_dir, "expression_data.csv")
    write.csv(expr_data, output_file, row.names = FALSE)
    cat(sprintf("Expression data saved to: %s\n", output_file), file = stderr())

    # Statistical tests if requested
    test_results <- list()
    if (test && !is.null(group_by) && group_by %in% colnames(expr_data)) {

      for (gene in valid_genes) {
        gene_data <- expr_data %>%
          filter(symbol == gene)

        groups <- gene_data[[group_by]]
        unique_groups <- unique(na.omit(groups))

        if (length(unique_groups) >= 2) {
          # Wilcoxon test for 2 groups, Kruskal-Wallis for >2 groups
          if (length(unique_groups) == 2) {
            test_result <- wilcox.test(gene_data$expression_value ~ groups)
            test_results[[gene]] <- list(
              gene = gene,
              test = "Wilcoxon",
              p_value = test_result$p.value,
              n_groups = length(unique_groups)
            )
          } else {
            test_result <- kruskal.test(gene_data$expression_value ~ groups)
            test_results[[gene]] <- list(
              gene = gene,
              test = "Kruskal-Wallis",
              p_value = test_result$p.value,
              n_groups = length(unique_groups)
            )
          }

          cat(sprintf("%s: p = %.4e\n", gene, test_results[[gene]]$p_value), file = stderr())
        }
      }

      # Export test results
      if (length(test_results) > 0) {
        test_df <- do.call(rbind, lapply(test_results, as.data.frame))
        test_file <- file.path(output_dir, "statistical_tests.csv")
        write.csv(test_df, test_file, row.names = FALSE)
        cat(sprintf("Statistical tests saved to: %s\n", test_file), file = stderr())
      }
    }

    # Generate plots if requested
    if (plot) {

      for (gene in valid_genes) {
        gene_data <- expr_data %>%
          filter(symbol == gene)

        if (nrow(gene_data) == 0) next

        # Create boxplot
        if (!is.null(group_by) && group_by %in% colnames(gene_data)) {

          expr_plot <- ggplot(gene_data, aes_string(x = group_by, y = "expression_value")) +
            geom_boxplot(aes_string(fill = group_by), alpha = 0.7, outlier.shape = NA) +
            geom_jitter(width = 0.2, alpha = 0.5, size = 2) +
            scale_fill_manual(values = get_ibd_palette()) +
            labs(
              title = sprintf("Expression of %s - %s", gene, dataset_acc),
              x = group_by,
              y = "Expression Value (log2)"
            ) +
            theme_minimal() +
            theme(
              plot.title = element_text(hjust = 0.5, face = "bold", size = 14),
              axis.title = element_text(size = 12),
              axis.text = element_text(size = 10),
              axis.text.x = element_text(angle = 45, hjust = 1),
              legend.position = "none"
            )

          # Add p-value if test was performed
          if (gene %in% names(test_results)) {
            p_val <- test_results[[gene]]$p_value
            p_label <- ifelse(p_val < 0.001,
                             sprintf("p < 0.001"),
                             sprintf("p = %.3f", p_val))

            expr_plot <- expr_plot +
              labs(caption = p_label) +
              theme(plot.caption = element_text(hjust = 0.5, size = 10))
          }

        } else {
          # Simple boxplot without grouping
          expr_plot <- ggplot(gene_data, aes(x = "", y = expression_value)) +
            geom_boxplot(fill = "#4472C4", alpha = 0.7) +
            geom_jitter(width = 0.2, alpha = 0.5, size = 2) +
            labs(
              title = sprintf("Expression of %s - %s", gene, dataset_acc),
              x = "",
              y = "Expression Value (log2)"
            ) +
            theme_minimal() +
            theme(
              plot.title = element_text(hjust = 0.5, face = "bold", size = 14),
              axis.title = element_text(size = 12),
              axis.text = element_text(size = 10)
            )
        }

        plot_file <- file.path(output_dir, sprintf("expression_%s.png", gene))
        ggsave(plot_file, expr_plot, width = 8, height = 6, dpi = 300)
        cat(sprintf("Expression plot for %s saved to: %s\n", gene, plot_file), file = stderr())
      }
    }

    # Calculate summary statistics per gene per group
    if (!is.null(group_by) && group_by %in% colnames(expr_data)) {
      summary_stats <- expr_data %>%
        group_by(symbol, !!sym(group_by)) %>%
        summarise(
          n = n(),
          mean = mean(expression_value, na.rm = TRUE),
          median = median(expression_value, na.rm = TRUE),
          sd = sd(expression_value, na.rm = TRUE),
          .groups = "drop"
        )

      summary_file <- file.path(output_dir, "expression_summary.csv")
      write.csv(summary_stats, summary_file, row.names = FALSE)
      cat(sprintf("Summary statistics saved to: %s\n", summary_file), file = stderr())
    }

    # Prepare JSON summary
    summary <- list(
      dataset_acc = dataset_acc,
      n_genes = length(valid_genes),
      genes = valid_genes,
      invalid_genes = invalid_genes,
      n_samples = length(unique(expr_data$sample_id)),
      test_results = test_results,
      files = list(
        expression_data = "expression_data.csv"
      )
    )

    if (!is.null(group_by) && group_by %in% colnames(expr_data)) {
      summary$files$summary_stats <- "expression_summary.csv"
    }

    if (test && length(test_results) > 0) {
      summary$files$statistical_tests <- "statistical_tests.csv"
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
perform_expression_plot(
  opt$`db-path`,
  opt$`output-dir`,
  opt$`dataset-acc`,
  opt$genes,
  opt$`group-by`,
  opt$groups,
  opt$plot,
  opt$test
)
