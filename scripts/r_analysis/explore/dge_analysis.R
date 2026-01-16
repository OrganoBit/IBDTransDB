#!/usr/bin/env Rscript

# Differential Gene Expression Analysis Script for IBDTransDB CLI
# Queries pre-computed DGE results and generates volcano plots

suppressPackageStartupMessages({
  library(optparse)
  library(RSQLite)
  library(DBI)
  library(dplyr)
  library(ggplot2)
  library(ggrepel)
  library(jsonlite)
})

# ============================================================================
# Database Utility Functions (inlined)
# ============================================================================

connect_db <- function(db_path) {
  if (!file.exists(db_path)) {
    stop(sprintf("Database not found: %s", db_path))
  }
  db <- dbConnect(SQLite(), dbname = db_path)
  return(db)
}

get_dataset <- function(db, dataset_acc) {
  query <- "SELECT * FROM dataset WHERE dataset_acc = ?"
  result <- dbGetQuery(db, query, params = list(dataset_acc))
  if (nrow(result) == 0) {
    stop(sprintf("Dataset not found: %s", dataset_acc))
  }
  return(result)
}

get_comparison_data <- function(db, comparison_id) {
  query <- "SELECT * FROM comparison_data WHERE comparison_id = ?"
  result <- dbGetQuery(db, query, params = list(comparison_id))
  return(result)
}

get_gene_map <- function(db) {
  query <- "SELECT * FROM gene_map"
  result <- dbGetQuery(db, query)
  return(result)
}

create_error_response <- function(error_message) {
  list(
    error = error_message,
    timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  )
}

# ============================================================================
# Command-line Arguments
# ============================================================================

option_list <- list(
  make_option(c("--db-path"), type = "character", default = NULL,
              help = "Path to IBDTransDB.db", metavar = "character"),
  make_option(c("--output-dir"), type = "character", default = NULL,
              help = "Output directory for results", metavar = "character"),
  make_option(c("--dataset-acc"), type = "character", default = NULL,
              help = "Dataset accession (e.g., GSE16879)", metavar = "character"),
  make_option(c("--comparison-id"), type = "integer", default = NULL,
              help = "Comparison ID", metavar = "integer"),
  make_option(c("--pval-threshold"), type = "double", default = 0.05,
              help = "P-value threshold for significance [default: %default]", metavar = "double"),
  make_option(c("--logfc-threshold"), type = "double", default = 1.0,
              help = "Log fold change threshold for significance [default: %default]", metavar = "double"),
  make_option(c("--plot-volcano"), action = "store_true", default = FALSE,
              help = "Generate volcano plot"),
  make_option(c("--top-genes"), type = "integer", default = 20,
              help = "Number of top genes to label in volcano plot [default: %default]", metavar = "integer")
)

opt_parser <- OptionParser(option_list = option_list)
opt <- parse_args(opt_parser)

# Validate required arguments
if (is.null(opt$`db-path`) || is.null(opt$`output-dir`) ||
    is.null(opt$`dataset-acc`) || is.null(opt$`comparison-id`)) {
  print_help(opt_parser)
  stop("Missing required arguments", call. = FALSE)
}

# ============================================================================
# Main Analysis Function
# ============================================================================

perform_dge_analysis <- function(db_path, output_dir, dataset_acc, comparison_id,
                                 pval_threshold, logfc_threshold, plot_volcano, top_genes) {

  # Connect to database
  db <- connect_db(db_path)

  tryCatch({

    # Get dataset info
    dataset_info <- get_dataset(db, dataset_acc)
    dataset_id <- dataset_info$id[1]

    # Get comparison info for this specific dataset
    comparison_query <- sprintf(
      "SELECT * FROM comparison WHERE dataset_acc = '%s' AND id = %d",
      dataset_acc, comparison_id
    )
    comparison_info <- dbGetQuery(db, comparison_query)

    # If not found, check if comparison exists but belongs to different dataset
    if (nrow(comparison_info) == 0) {
      check_comp <- dbGetQuery(db, sprintf("SELECT * FROM comparison WHERE id = %d", comparison_id))
      if (nrow(check_comp) > 0) {
        # Comparison exists but belongs to different dataset
        cat(sprintf("\nERROR: Comparison %d belongs to dataset %s, not %s!\n",
                    comparison_id, check_comp$dataset_acc[1], dataset_acc), file = stderr())

        # Show available comparisons for the requested dataset
        available_comps <- dbGetQuery(db, sprintf(
          "SELECT id, case_ann, control_ann, description FROM comparison WHERE dataset_acc = '%s'",
          dataset_acc))

        if (nrow(available_comps) > 0) {
          cat(sprintf("\nAvailable comparisons for dataset %s:\n", dataset_acc), file = stderr())
          cat("Comparison ID | Case | Control | Description\n", file = stderr())
          cat("-------------|------|---------|-------------\n", file = stderr())
          for (i in 1:nrow(available_comps)) {
            cat(sprintf("%-13d | %-20s | %-20s | %s\n",
                        available_comps$id[i],
                        substr(available_comps$case_ann[i], 1, 20),
                        substr(available_comps$control_ann[i], 1, 20),
                        substr(ifelse(is.na(available_comps$description[i]), "", available_comps$description[i]), 1, 30)),
                file = stderr())
          }
        } else {
          cat(sprintf("No comparisons found for dataset %s in the database!\n", dataset_acc), file = stderr())
        }
        stop(sprintf("Comparison %d does not belong to dataset %s", comparison_id, dataset_acc))
      } else {
        stop(sprintf("Comparison %d not found in database", comparison_id))
      }
    }

    cat(sprintf("Loading DGE results for comparison: %s vs %s...\n",
                comparison_info$case_ann[1], comparison_info$control_ann[1]), file = stderr())

    # Get DGE data
    dge_data <- get_comparison_data(db, comparison_id)

    if (nrow(dge_data) == 0) {
      stop(sprintf("No DGE data found for comparison %d", comparison_id))
    }

    # Map gene IDs to symbols
    gene_map <- get_gene_map(db)

    # Check what column has gene symbols
    if ("gene_symbol" %in% colnames(gene_map)) {
      dge_data <- dge_data %>%
        left_join(gene_map %>% select(id, gene_symbol), by = c("gene" = "id")) %>%
        select(-gene) %>%
        rename(gene = gene_symbol) %>%
        relocate(gene)
    } else if ("gene_name" %in% colnames(gene_map)) {
      dge_data <- dge_data %>%
        left_join(gene_map %>% select(id, gene_name), by = c("gene" = "id")) %>%
        select(-gene) %>%
        rename(gene = gene_name) %>%
        relocate(gene)
    } else {
      # Keep gene IDs as-is
      dge_data <- dge_data %>%
        rename(gene_id = gene) %>%
        mutate(gene = as.character(gene_id)) %>%
        relocate(gene)
    }

    # Add significance column
    dge_data <- dge_data %>%
      mutate(
        significant = ifelse(
          p_value_adj < pval_threshold & abs(log_fc) > logfc_threshold,
          "Significant",
          "Not Significant"
        ),
        direction = case_when(
          p_value_adj < pval_threshold & log_fc > logfc_threshold ~ "Up",
          p_value_adj < pval_threshold & log_fc < -logfc_threshold ~ "Down",
          TRUE ~ "Not Significant"
        )
      )

    # Count significant genes
    n_up <- sum(dge_data$direction == "Up", na.rm = TRUE)
    n_down <- sum(dge_data$direction == "Down", na.rm = TRUE)
    n_total <- nrow(dge_data)

    cat(sprintf("Total genes: %d\n", n_total), file = stderr())
    cat(sprintf("Upregulated: %d\n", n_up), file = stderr())
    cat(sprintf("Downregulated: %d\n", n_down), file = stderr())

    # Export DGE results
    dge_filename <- sprintf("dge_results_comparison_%d.csv", comparison_id)
    output_file <- file.path(output_dir, dge_filename)
    write.csv(dge_data, output_file, row.names = FALSE)
    cat(sprintf("DGE results saved to: %s\n", output_file), file = stderr())

    # Generate volcano plot
    if (plot_volcano) {

      # Prepare data for plotting
      plot_data <- dge_data %>%
        filter(!is.na(p_value) & !is.na(log_fc)) %>%
        mutate(
          log10_pval = -log10(p_value),
          color_group = case_when(
            direction == "Up" ~ "Upregulated",
            direction == "Down" ~ "Downregulated",
            TRUE ~ "Not Significant"
          )
        )

      # Identify top genes to label
      top_up <- plot_data %>%
        filter(direction == "Up") %>%
        arrange(p_value) %>%
        head(top_genes / 2)

      top_down <- plot_data %>%
        filter(direction == "Down") %>%
        arrange(p_value) %>%
        head(top_genes / 2)

      genes_to_label <- bind_rows(top_up, top_down)

      # Create volcano plot
      volcano_plot <- ggplot(plot_data, aes(x = log_fc, y = log10_pval)) +
        geom_point(aes(color = color_group), alpha = 0.6, size = 2) +
        scale_color_manual(
          values = c(
            "Upregulated" = "#E41A1C",
            "Downregulated" = "#377EB8",
            "Not Significant" = "gray70"
          ),
          name = "Gene Regulation"
        ) +
        geom_vline(xintercept = c(-logfc_threshold, logfc_threshold),
                   linetype = "dashed", color = "black", alpha = 0.5) +
        geom_hline(yintercept = -log10(pval_threshold),
                   linetype = "dashed", color = "black", alpha = 0.5) +
        labs(
          title = sprintf("Volcano Plot - %s\n%s vs %s",
                         dataset_acc,
                         comparison_info$case_ann[1],
                         comparison_info$control_ann[1]),
          x = "Log2 Fold Change",
          y = "-Log10 P-value",
          caption = sprintf("Thresholds: |log2FC| > %.1f, P-value < %.3f\nUp: %d | Down: %d",
                           logfc_threshold, pval_threshold, n_up, n_down)
        ) +
        theme_minimal() +
        theme(
          plot.title = element_text(hjust = 0.5, face = "bold", size = 14),
          axis.title = element_text(size = 12),
          axis.text = element_text(size = 10),
          legend.position = "right",
          legend.title = element_text(size = 12),
          legend.text = element_text(size = 10),
          plot.caption = element_text(hjust = 0, size = 9)
        )

      # Add gene labels if available
      if (nrow(genes_to_label) > 0) {
        volcano_plot <- volcano_plot +
          geom_text_repel(
            data = genes_to_label,
            aes(label = gene),
            size = 3,
            box.padding = 0.5,
            point.padding = 0.3,
            segment.color = "grey50",
            max.overlaps = 20
          )
      }

      volcano_filename <- sprintf("volcano_plot_comparison_%d.png", comparison_id)
      volcano_file <- file.path(output_dir, volcano_filename)
      ggsave(volcano_file, volcano_plot, width = 10, height = 8, dpi = 300)
      cat(sprintf("Volcano plot saved to: %s\n", volcano_file), file = stderr())
    }

    # Export top significant genes
    top_sig_genes <- dge_data %>%
      filter(significant == "Significant") %>%
      arrange(p_value_adj) %>%
      head(50)

    if (nrow(top_sig_genes) > 0) {
      top_genes_filename <- sprintf("top_significant_genes_comparison_%d.csv", comparison_id)
      top_genes_file <- file.path(output_dir, top_genes_filename)
      write.csv(top_sig_genes, top_genes_file, row.names = FALSE)
      cat(sprintf("Top significant genes saved to: %s\n", top_genes_file), file = stderr())
    }

    # Prepare JSON summary
    summary <- list(
      dataset_acc = dataset_acc,
      comparison_id = comparison_id,
      case_annotation = comparison_info$case_ann[1],
      control_annotation = comparison_info$control_ann[1],
      n_genes_total = n_total,
      n_genes_upregulated = n_up,
      n_genes_downregulated = n_down,
      thresholds = list(
        pval_threshold = pval_threshold,
        logfc_threshold = logfc_threshold
      ),
      files = list(
        dge_results = dge_filename
      )
    )

    if (nrow(top_sig_genes) > 0) {
      summary$files$top_genes <- top_genes_filename
    }

    if (plot_volcano) {
      summary$files$volcano_plot <- volcano_filename
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

# ============================================================================
# Execute Analysis
# ============================================================================

perform_dge_analysis(
  opt$`db-path`,
  opt$`output-dir`,
  opt$`dataset-acc`,
  opt$`comparison-id`,
  opt$`pval-threshold`,
  opt$`logfc-threshold`,
  opt$`plot-volcano`,
  opt$`top-genes`
)
