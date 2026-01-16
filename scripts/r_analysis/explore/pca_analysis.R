#!/usr/bin/env Rscript

# PCA Analysis Script for IBDTransDB CLI
# Performs PCA analysis on a dataset with optional plotting and statistical testing

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
  make_option(c("--color-by"), type = "character", default = NULL,
              help = "Sample annotation for coloring points", metavar = "character"),
  make_option(c("--pc-x"), type = "integer", default = 1,
              help = "PC for x-axis [default: %default]", metavar = "integer"),
  make_option(c("--pc-y"), type = "integer", default = 2,
              help = "PC for y-axis [default: %default]", metavar = "integer"),
  make_option(c("--plot-scree"), action = "store_true", default = FALSE,
              help = "Generate scree plot"),
  make_option(c("--plot-pca"), action = "store_true", default = FALSE,
              help = "Generate PCA biplot")
)

opt_parser <- OptionParser(option_list = option_list)
opt <- parse_args(opt_parser)

# Validate required arguments
if (is.null(opt$`db-path`) || is.null(opt$`output-dir`) || is.null(opt$`dataset-acc`)) {
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
perform_pca_analysis <- function(db_path, output_dir, dataset_acc, color_by, pc_x, pc_y, plot_scree, plot_pca) {

  # Connect to database
  db <- connect_db(db_path)

  tryCatch({

    # Get dataset ID
    dataset_info <- get_dataset(db, dataset_acc)
    if (nrow(dataset_info) == 0) {
      stop(sprintf("Dataset %s not found in database", dataset_acc))
    }
    dataset_id <- dataset_info$dataset_id[1]

    # Get expression data
    cat("Loading expression data...\n", file = stderr())
    expr_data <- get_expression_data(db, dataset_id)

    if (nrow(expr_data) == 0) {
      stop(sprintf("No expression data found for dataset %s", dataset_acc))
    }

    # Reshape to matrix (genes as rows, samples as columns)
    expr_matrix <- expr_data %>%
      pivot_wider(names_from = sample_id, values_from = expression_value) %>%
      column_to_rownames("gene") %>%
      as.matrix()

    # Remove genes with missing values
    expr_matrix <- expr_matrix[complete.cases(expr_matrix), ]

    # Transpose for PCA (samples as rows)
    expr_matrix_t <- t(expr_matrix)

    cat(sprintf("Performing PCA on %d samples and %d genes...\n",
                nrow(expr_matrix_t), ncol(expr_matrix_t)), file = stderr())

    # Perform PCA
    pca_result <- prcomp(expr_matrix_t, center = TRUE, scale. = TRUE)

    # Calculate variance explained
    variance_explained <- (pca_result$sdev^2 / sum(pca_result$sdev^2)) * 100

    # Get sample annotations
    sample_ann <- get_sample_annotations(db, dataset_id)

    # Create PCA dataframe with coordinates
    pca_df <- as.data.frame(pca_result$x)
    pca_df$sample_id <- rownames(pca_df)

    # Merge with annotations
    if (nrow(sample_ann) > 0) {
      pca_df <- pca_df %>%
        left_join(sample_ann, by = "sample_id")
    }

    # Export PCA coordinates
    output_file <- file.path(output_dir, "pca_coordinates.csv")
    write.csv(pca_df, output_file, row.names = FALSE)
    cat(sprintf("PCA coordinates saved to: %s\n", output_file), file = stderr())

    # Generate scree plot
    if (plot_scree) {
      scree_data <- data.frame(
        PC = 1:min(20, length(variance_explained)),
        Variance = variance_explained[1:min(20, length(variance_explained))]
      )

      scree_plot <- ggplot(scree_data, aes(x = PC, y = Variance)) +
        geom_bar(stat = "identity", fill = "#4472C4", color = "black") +
        geom_line(color = "#C55A11", size = 1) +
        geom_point(color = "#C55A11", size = 3) +
        labs(
          title = sprintf("PCA Scree Plot - %s", dataset_acc),
          x = "Principal Component",
          y = "Variance Explained (%)"
        ) +
        theme_minimal() +
        theme(
          plot.title = element_text(hjust = 0.5, face = "bold", size = 14),
          axis.title = element_text(size = 12),
          axis.text = element_text(size = 10)
        )

      scree_file <- file.path(output_dir, "pca_scree_plot.png")
      ggsave(scree_file, scree_plot, width = 8, height = 6, dpi = 300)
      cat(sprintf("Scree plot saved to: %s\n", scree_file), file = stderr())
    }

    # Generate PCA biplot
    if (plot_pca) {
      pc_x_label <- sprintf("PC%d (%.1f%%)", pc_x, variance_explained[pc_x])
      pc_y_label <- sprintf("PC%d (%.1f%%)", pc_y, variance_explained[pc_y])

      pca_plot <- ggplot(pca_df, aes_string(x = sprintf("PC%d", pc_x), y = sprintf("PC%d", pc_y)))

      # Add coloring if specified
      if (!is.null(color_by) && color_by %in% colnames(pca_df)) {
        pca_plot <- pca_plot +
          geom_point(aes_string(color = color_by), size = 3, alpha = 0.7) +
          scale_color_manual(values = get_ibd_palette())
      } else {
        pca_plot <- pca_plot +
          geom_point(size = 3, alpha = 0.7, color = "#4472C4")
      }

      pca_plot <- pca_plot +
        labs(
          title = sprintf("PCA Plot - %s", dataset_acc),
          x = pc_x_label,
          y = pc_y_label
        ) +
        theme_minimal() +
        theme(
          plot.title = element_text(hjust = 0.5, face = "bold", size = 14),
          axis.title = element_text(size = 12),
          axis.text = element_text(size = 10),
          legend.title = element_text(size = 12),
          legend.text = element_text(size = 10)
        )

      pca_file <- file.path(output_dir, "pca_biplot.png")
      ggsave(pca_file, pca_plot, width = 10, height = 8, dpi = 300)
      cat(sprintf("PCA biplot saved to: %s\n", pca_file), file = stderr())
    }

    # Statistical testing: PC association with annotations
    pc_tests <- list()
    if (!is.null(color_by) && color_by %in% colnames(pca_df)) {

      # Test association for first 5 PCs
      for (i in 1:min(5, ncol(pca_result$x))) {
        pc_name <- sprintf("PC%d", i)

        # Check if annotation has at least 2 groups
        groups <- pca_df[[color_by]]
        unique_groups <- unique(na.omit(groups))

        if (length(unique_groups) >= 2) {
          # Wilcoxon test for 2 groups, Kruskal-Wallis for >2 groups
          if (length(unique_groups) == 2) {
            test_result <- wilcox.test(pca_df[[pc_name]] ~ groups)
            pc_tests[[pc_name]] <- list(
              pc = pc_name,
              annotation = color_by,
              test = "Wilcoxon",
              p_value = test_result$p.value,
              variance_explained = variance_explained[i]
            )
          } else {
            test_result <- kruskal.test(pca_df[[pc_name]] ~ groups)
            pc_tests[[pc_name]] <- list(
              pc = pc_name,
              annotation = color_by,
              test = "Kruskal-Wallis",
              p_value = test_result$p.value,
              variance_explained = variance_explained[i]
            )
          }
        }
      }
    }

    # Prepare JSON summary
    summary <- list(
      dataset_acc = dataset_acc,
      n_samples = nrow(pca_df),
      n_genes = ncol(expr_matrix_t),
      variance_explained = variance_explained[1:min(10, length(variance_explained))],
      pc_tests = pc_tests,
      files = list(
        pca_coordinates = "pca_coordinates.csv"
      )
    )

    if (plot_scree) {
      summary$files$scree_plot <- "pca_scree_plot.png"
    }

    if (plot_pca) {
      summary$files$pca_biplot <- "pca_biplot.png"
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
perform_pca_analysis(
  opt$`db-path`,
  opt$`output-dir`,
  opt$`dataset-acc`,
  opt$`color-by`,
  opt$`pc-x`,
  opt$`pc-y`,
  opt$`plot-scree`,
  opt$`plot-pca`
)
