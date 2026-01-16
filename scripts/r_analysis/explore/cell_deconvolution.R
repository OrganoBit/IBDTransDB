#!/usr/bin/env Rscript

# Cell Type Deconvolution Analysis Script for IBDTransDB CLI
# Retrieves and visualizes pre-computed cell type fractions

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
  make_option(c("--group-by"), type = "character", default = NULL,
              help = "Sample annotation for grouping", metavar = "character"),
  make_option(c("--groups"), type = "character", default = NULL,
              help = "Comma-separated list of groups to include", metavar = "character"),
  make_option(c("--plot"), action = "store_true", default = FALSE,
              help = "Generate stacked bar plots"),
  make_option(c("--test"), action = "store_true", default = FALSE,
              help = "Perform statistical tests between groups")
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
perform_cell_deconvolution <- function(db_path, output_dir, dataset_acc, group_by, groups_str, plot, test) {

  # Connect to database
  db <- connect_db(db_path)

  tryCatch({

    # Get dataset ID
    dataset_info <- get_dataset(db, dataset_acc)
    if (nrow(dataset_info) == 0) {
      stop(sprintf("Dataset %s not found in database", dataset_acc))
    }
    dataset_id <- dataset_info$dataset_id[1]

    cat("Loading cell type deconvolution data...\n", file = stderr())

    # Get cell deconvolution data
    deconv_query <- sprintf(
      "SELECT * FROM cell_deconvolution WHERE dataset_id = %d",
      dataset_id
    )
    deconv_data <- dbGetQuery(db, deconv_query)

    if (nrow(deconv_data) == 0) {
      stop(sprintf("No cell deconvolution data found for dataset %s", dataset_acc))
    }

    # Get sample annotations
    sample_ann <- get_sample_annotations(db, dataset_id)

    # Merge with annotations
    deconv_data <- deconv_data %>%
      left_join(sample_ann, by = "sample_id")

    # Filter by groups if specified
    if (!is.null(groups_str)) {
      groups_list <- strsplit(groups_str, ",")[[1]]
      groups_list <- trimws(groups_list)

      if (!is.null(group_by) && group_by %in% colnames(deconv_data)) {
        deconv_data <- deconv_data %>%
          filter(!!sym(group_by) %in% groups_list)

        cat(sprintf("Filtered to groups: %s\n", paste(groups_list, collapse = ", ")), file = stderr())
      }
    }

    cat(sprintf("Retrieved cell fractions for %d samples\n", length(unique(deconv_data$sample_id))), file = stderr())

    # Export deconvolution data
    output_file <- file.path(output_dir, "cell_fractions.csv")
    write.csv(deconv_data, output_file, row.names = FALSE)
    cat(sprintf("Cell fractions saved to: %s\n", output_file), file = stderr())

    # Get unique cell types
    cell_types <- unique(deconv_data$cell_type)
    cat(sprintf("Cell types: %s\n", paste(cell_types, collapse = ", ")), file = stderr())

    # Statistical tests if requested
    test_results <- list()
    if (test && !is.null(group_by) && group_by %in% colnames(deconv_data)) {

      for (cell_type in cell_types) {
        cell_data <- deconv_data %>%
          filter(cell_type == !!cell_type)

        groups <- cell_data[[group_by]]
        unique_groups <- unique(na.omit(groups))

        if (length(unique_groups) >= 2) {
          # Wilcoxon test for 2 groups, Kruskal-Wallis for >2 groups
          if (length(unique_groups) == 2) {
            test_result <- wilcox.test(cell_data$fraction ~ groups)
            test_results[[cell_type]] <- list(
              cell_type = cell_type,
              test = "Wilcoxon",
              p_value = test_result$p.value,
              n_groups = length(unique_groups)
            )
          } else {
            test_result <- kruskal.test(cell_data$fraction ~ groups)
            test_results[[cell_type]] <- list(
              cell_type = cell_type,
              test = "Kruskal-Wallis",
              p_value = test_result$p.value,
              n_groups = length(unique_groups)
            )
          }

          cat(sprintf("%s: p = %.4e\n", cell_type, test_results[[cell_type]]$p_value), file = stderr())
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

      # Stacked bar plot by sample
      stacked_data <- deconv_data %>%
        arrange(sample_id, cell_type)

      if (!is.null(group_by) && group_by %in% colnames(stacked_data)) {
        # Order samples by group
        stacked_data <- stacked_data %>%
          arrange(!!sym(group_by), sample_id)

        # Create plot with grouping
        stacked_plot <- ggplot(stacked_data, aes(x = sample_id, y = fraction, fill = cell_type)) +
          geom_bar(stat = "identity", position = "stack", width = 0.9) +
          facet_grid(. ~ !!sym(group_by), scales = "free_x", space = "free_x") +
          scale_fill_manual(values = get_ibd_palette()) +
          labs(
            title = sprintf("Cell Type Composition - %s", dataset_acc),
            x = "Sample",
            y = "Cell Fraction",
            fill = "Cell Type"
          ) +
          theme_minimal() +
          theme(
            plot.title = element_text(hjust = 0.5, face = "bold", size = 14),
            axis.title = element_text(size = 12),
            axis.text.x = element_blank(),
            axis.ticks.x = element_blank(),
            legend.position = "right",
            legend.title = element_text(size = 12),
            legend.text = element_text(size = 10),
            strip.text = element_text(size = 10, face = "bold")
          )

      } else {
        # Simple stacked plot
        stacked_plot <- ggplot(stacked_data, aes(x = sample_id, y = fraction, fill = cell_type)) +
          geom_bar(stat = "identity", position = "stack", width = 0.9) +
          scale_fill_manual(values = get_ibd_palette()) +
          labs(
            title = sprintf("Cell Type Composition - %s", dataset_acc),
            x = "Sample",
            y = "Cell Fraction",
            fill = "Cell Type"
          ) +
          theme_minimal() +
          theme(
            plot.title = element_text(hjust = 0.5, face = "bold", size = 14),
            axis.title = element_text(size = 12),
            axis.text.x = element_blank(),
            axis.ticks.x = element_blank(),
            legend.position = "right",
            legend.title = element_text(size = 12),
            legend.text = element_text(size = 10)
          )
      }

      stacked_file <- file.path(output_dir, "cell_composition_stacked.png")
      ggsave(stacked_file, stacked_plot, width = 12, height = 6, dpi = 300)
      cat(sprintf("Stacked bar plot saved to: %s\n", stacked_file), file = stderr())

      # Boxplot per cell type if groups specified
      if (!is.null(group_by) && group_by %in% colnames(deconv_data)) {

        for (cell_type in cell_types) {
          cell_data <- deconv_data %>%
            filter(cell_type == !!cell_type)

          if (nrow(cell_data) == 0) next

          boxplot <- ggplot(cell_data, aes_string(x = group_by, y = "fraction")) +
            geom_boxplot(aes_string(fill = group_by), alpha = 0.7, outlier.shape = NA) +
            geom_jitter(width = 0.2, alpha = 0.5, size = 2) +
            scale_fill_manual(values = get_ibd_palette()) +
            labs(
              title = sprintf("%s Fraction - %s", cell_type, dataset_acc),
              x = group_by,
              y = "Cell Fraction"
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
          if (cell_type %in% names(test_results)) {
            p_val <- test_results[[cell_type]]$p_value
            p_label <- ifelse(p_val < 0.001,
                             sprintf("p < 0.001"),
                             sprintf("p = %.3f", p_val))

            boxplot <- boxplot +
              labs(caption = p_label) +
              theme(plot.caption = element_text(hjust = 0.5, size = 10))
          }

          plot_file <- file.path(output_dir, sprintf("cell_fraction_%s.png", gsub(" ", "_", cell_type)))
          ggsave(plot_file, boxplot, width = 8, height = 6, dpi = 300)
          cat(sprintf("Boxplot for %s saved to: %s\n", cell_type, plot_file), file = stderr())
        }
      }
    }

    # Calculate summary statistics
    if (!is.null(group_by) && group_by %in% colnames(deconv_data)) {
      summary_stats <- deconv_data %>%
        group_by(cell_type, !!sym(group_by)) %>%
        summarise(
          n = n(),
          mean = mean(fraction, na.rm = TRUE),
          median = median(fraction, na.rm = TRUE),
          sd = sd(fraction, na.rm = TRUE),
          .groups = "drop"
        )

      summary_file <- file.path(output_dir, "cell_fraction_summary.csv")
      write.csv(summary_stats, summary_file, row.names = FALSE)
      cat(sprintf("Summary statistics saved to: %s\n", summary_file), file = stderr())
    }

    # Prepare JSON summary
    summary <- list(
      dataset_acc = dataset_acc,
      n_samples = length(unique(deconv_data$sample_id)),
      n_cell_types = length(cell_types),
      cell_types = cell_types,
      test_results = test_results,
      files = list(
        cell_fractions = "cell_fractions.csv"
      )
    )

    if (!is.null(group_by) && group_by %in% colnames(deconv_data)) {
      summary$files$summary_stats <- "cell_fraction_summary.csv"
    }

    if (test && length(test_results) > 0) {
      summary$files$statistical_tests <- "statistical_tests.csv"
    }

    if (plot) {
      summary$files$stacked_plot <- "cell_composition_stacked.png"
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
perform_cell_deconvolution(
  opt$`db-path`,
  opt$`output-dir`,
  opt$`dataset-acc`,
  opt$`group-by`,
  opt$groups,
  opt$plot,
  opt$test
)
