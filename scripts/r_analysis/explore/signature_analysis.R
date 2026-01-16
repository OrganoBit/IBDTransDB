#!/usr/bin/env Rscript

# Gene Signature Analysis Script for IBDTransDB CLI
# Calculates signature scores (mean expression) and compares across groups

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
              help = "Comma-separated list of gene symbols for signature", metavar = "character"),
  make_option(c("--group-by"), type = "character", default = NULL,
              help = "Sample annotation for grouping", metavar = "character"),
  make_option(c("--groups"), type = "character", default = NULL,
              help = "Comma-separated list of groups to include", metavar = "character"),
  make_option(c("--plot"), action = "store_true", default = FALSE,
              help = "Generate signature score plots"),
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
perform_signature_analysis <- function(db_path, output_dir, dataset_acc, genes_str,
                                       group_by, groups_str, plot, test) {

  # Connect to database
  db <- connect_db(db_path)

  tryCatch({

    # Parse gene list
    genes_list <- strsplit(genes_str, ",")[[1]]
    genes_list <- trimws(genes_list)

    cat(sprintf("Analyzing signature of %d genes: %s\n",
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

    cat(sprintf("Using %d valid genes for signature\n", length(valid_genes)), file = stderr())

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

    # Calculate signature scores (mean expression per sample)
    signature_scores <- expr_data %>%
      group_by(sample_id) %>%
      summarise(
        signature_score = mean(expression_value, na.rm = TRUE),
        n_genes = n_distinct(symbol),
        .groups = "drop"
      )

    cat(sprintf("Calculated signature scores for %d samples\n",
                nrow(signature_scores)), file = stderr())

    # Get sample annotations
    sample_ann <- get_sample_annotations(db, dataset_id)

    # Merge with annotations
    signature_scores <- signature_scores %>%
      left_join(sample_ann, by = "sample_id")

    # Filter by groups if specified
    if (!is.null(groups_str)) {
      groups_list <- strsplit(groups_str, ",")[[1]]
      groups_list <- trimws(groups_list)

      if (!is.null(group_by) && group_by %in% colnames(signature_scores)) {
        signature_scores <- signature_scores %>%
          filter(!!sym(group_by) %in% groups_list)

        cat(sprintf("Filtered to groups: %s\n", paste(groups_list, collapse = ", ")), file = stderr())
      }
    }

    # Export signature scores
    output_file <- file.path(output_dir, "signature_scores.csv")
    write.csv(signature_scores, output_file, row.names = FALSE)
    cat(sprintf("Signature scores saved to: %s\n", output_file), file = stderr())

    # Export gene-level expression for signature genes
    gene_expr_file <- file.path(output_dir, "signature_gene_expression.csv")
    write.csv(expr_data, gene_expr_file, row.names = FALSE)
    cat(sprintf("Gene-level expression saved to: %s\n", gene_expr_file), file = stderr())

    # Statistical tests if requested
    test_result <- NULL
    if (test && !is.null(group_by) && group_by %in% colnames(signature_scores)) {

      groups <- signature_scores[[group_by]]
      unique_groups <- unique(na.omit(groups))

      if (length(unique_groups) >= 2) {
        # Wilcoxon test for 2 groups, Kruskal-Wallis for >2 groups
        if (length(unique_groups) == 2) {
          test <- wilcox.test(signature_scores$signature_score ~ groups)
          test_result <- list(
            test = "Wilcoxon",
            p_value = test$p.value,
            n_groups = length(unique_groups),
            groups = unique_groups
          )
        } else {
          test <- kruskal.test(signature_scores$signature_score ~ groups)
          test_result <- list(
            test = "Kruskal-Wallis",
            p_value = test$p.value,
            n_groups = length(unique_groups),
            groups = unique_groups
          )
        }

        cat(sprintf("Statistical test: %s, p = %.4e\n",
                    test_result$test, test_result$p_value), file = stderr())

        # Export test result
        test_df <- data.frame(
          test = test_result$test,
          p_value = test_result$p_value,
          n_groups = test_result$n_groups
        )
        test_file <- file.path(output_dir, "statistical_test.csv")
        write.csv(test_df, test_file, row.names = FALSE)
        cat(sprintf("Statistical test saved to: %s\n", test_file), file = stderr())
      }
    }

    # Generate plots if requested
    if (plot) {

      if (!is.null(group_by) && group_by %in% colnames(signature_scores)) {

        # Boxplot of signature scores by group
        sig_plot <- ggplot(signature_scores, aes_string(x = group_by, y = "signature_score")) +
          geom_boxplot(aes_string(fill = group_by), alpha = 0.7, outlier.shape = NA) +
          geom_jitter(width = 0.2, alpha = 0.5, size = 2) +
          scale_fill_manual(values = get_ibd_palette()) +
          labs(
            title = sprintf("Gene Signature Score - %s", dataset_acc),
            subtitle = sprintf("Signature: %s", paste(head(valid_genes, 5), collapse = ", ")),
            x = group_by,
            y = "Signature Score (Mean Log2 Expression)"
          ) +
          theme_minimal() +
          theme(
            plot.title = element_text(hjust = 0.5, face = "bold", size = 14),
            plot.subtitle = element_text(hjust = 0.5, size = 10),
            axis.title = element_text(size = 12),
            axis.text = element_text(size = 10),
            axis.text.x = element_text(angle = 45, hjust = 1),
            legend.position = "none"
          )

        # Add p-value if test was performed
        if (!is.null(test_result)) {
          p_val <- test_result$p_value
          p_label <- ifelse(p_val < 0.001,
                           sprintf("p < 0.001"),
                           sprintf("p = %.3f", p_val))

          sig_plot <- sig_plot +
            labs(caption = p_label) +
            theme(plot.caption = element_text(hjust = 0.5, size = 10))
        }

      } else {
        # Simple boxplot without grouping
        sig_plot <- ggplot(signature_scores, aes(x = "", y = signature_score)) +
          geom_boxplot(fill = "#4472C4", alpha = 0.7) +
          geom_jitter(width = 0.2, alpha = 0.5, size = 2) +
          labs(
            title = sprintf("Gene Signature Score - %s", dataset_acc),
            subtitle = sprintf("Signature: %s", paste(head(valid_genes, 5), collapse = ", ")),
            x = "",
            y = "Signature Score (Mean Log2 Expression)"
          ) +
          theme_minimal() +
          theme(
            plot.title = element_text(hjust = 0.5, face = "bold", size = 14),
            plot.subtitle = element_text(hjust = 0.5, size = 10),
            axis.title = element_text(size = 12),
            axis.text = element_text(size = 10)
          )
      }

      plot_file <- file.path(output_dir, "signature_score_plot.png")
      ggsave(plot_file, sig_plot, width = 8, height = 6, dpi = 300)
      cat(sprintf("Signature plot saved to: %s\n", plot_file), file = stderr())

      # Heatmap of individual gene expression if <= 20 genes
      if (length(valid_genes) <= 20) {
        # Prepare data for heatmap
        heatmap_data <- expr_data %>%
          pivot_wider(names_from = symbol, values_from = expression_value)

        # Merge with annotations
        heatmap_data <- heatmap_data %>%
          left_join(sample_ann, by = "sample_id")

        # Filter by groups if specified
        if (!is.null(groups_str)) {
          groups_list <- strsplit(groups_str, ",")[[1]]
          groups_list <- trimws(groups_list)

          if (!is.null(group_by) && group_by %in% colnames(heatmap_data)) {
            heatmap_data <- heatmap_data %>%
              filter(!!sym(group_by) %in% groups_list)
          }
        }

        # Convert to long format for ggplot
        heatmap_long <- heatmap_data %>%
          select(sample_id, !!sym(group_by), all_of(valid_genes)) %>%
          pivot_longer(cols = all_of(valid_genes), names_to = "gene", values_to = "expression")

        # Order samples by group if available
        if (!is.null(group_by) && group_by %in% colnames(heatmap_long)) {
          heatmap_long <- heatmap_long %>%
            arrange(!!sym(group_by), sample_id)
        }

        # Create heatmap
        heatmap_plot <- ggplot(heatmap_long, aes(x = sample_id, y = gene, fill = expression)) +
          geom_tile(color = "white", size = 0.5) +
          scale_fill_gradient2(
            low = "#377EB8", mid = "white", high = "#E41A1C",
            midpoint = median(heatmap_long$expression, na.rm = TRUE),
            name = "Expression"
          ) +
          labs(
            title = sprintf("Signature Gene Expression - %s", dataset_acc),
            x = "Sample",
            y = "Gene"
          ) +
          theme_minimal() +
          theme(
            plot.title = element_text(hjust = 0.5, face = "bold", size = 14),
            axis.title = element_text(size = 12),
            axis.text.x = element_blank(),
            axis.ticks.x = element_blank(),
            axis.text.y = element_text(size = 10),
            legend.position = "right"
          )

        if (!is.null(group_by) && group_by %in% colnames(heatmap_long)) {
          heatmap_plot <- heatmap_plot +
            facet_grid(. ~ !!sym(group_by), scales = "free_x", space = "free_x")
        }

        heatmap_file <- file.path(output_dir, "signature_heatmap.png")
        ggsave(heatmap_file, heatmap_plot, width = 12, height = 8, dpi = 300)
        cat(sprintf("Signature heatmap saved to: %s\n", heatmap_file), file = stderr())
      }
    }

    # Calculate summary statistics
    if (!is.null(group_by) && group_by %in% colnames(signature_scores)) {
      summary_stats <- signature_scores %>%
        group_by(!!sym(group_by)) %>%
        summarise(
          n = n(),
          mean = mean(signature_score, na.rm = TRUE),
          median = median(signature_score, na.rm = TRUE),
          sd = sd(signature_score, na.rm = TRUE),
          min = min(signature_score, na.rm = TRUE),
          max = max(signature_score, na.rm = TRUE),
          .groups = "drop"
        )

      summary_file <- file.path(output_dir, "signature_summary.csv")
      write.csv(summary_stats, summary_file, row.names = FALSE)
      cat(sprintf("Summary statistics saved to: %s\n", summary_file), file = stderr())
    }

    # Prepare JSON summary
    summary <- list(
      dataset_acc = dataset_acc,
      n_genes_requested = length(genes_list),
      n_genes_valid = length(valid_genes),
      invalid_genes = invalid_genes,
      signature_genes = valid_genes,
      n_samples = nrow(signature_scores),
      score_range = c(
        min(signature_scores$signature_score, na.rm = TRUE),
        max(signature_scores$signature_score, na.rm = TRUE)
      ),
      files = list(
        signature_scores = "signature_scores.csv",
        gene_expression = "signature_gene_expression.csv"
      )
    )

    if (!is.null(group_by) && group_by %in% colnames(signature_scores)) {
      summary$files$summary_stats <- "signature_summary.csv"
    }

    if (!is.null(test_result)) {
      summary$test_result <- test_result
      summary$files$statistical_test <- "statistical_test.csv"
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
perform_signature_analysis(
  opt$`db-path`,
  opt$`output-dir`,
  opt$`dataset-acc`,
  opt$genes,
  opt$`group-by`,
  opt$groups,
  opt$plot,
  opt$test
)
