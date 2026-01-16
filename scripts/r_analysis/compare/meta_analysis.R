#!/usr/bin/env Rscript

# Meta-Analysis Script for IBDTransDB CLI
# Performs Fisher's method meta-analysis across multiple comparisons

suppressPackageStartupMessages({
  library(optparse)
  library(RSQLite)
  library(DBI)
  library(dplyr)
  library(tidyr)
  library(poolr)
  library(ggplot2)
  library(ggrepel)
  library(jsonlite)
})

# Parse command-line arguments
option_list <- list(
  make_option(c("--db-path"), type = "character", default = NULL,
              help = "Path to IBDTransDB.db", metavar = "character"),
  make_option(c("--output-dir"), type = "character", default = NULL,
              help = "Output directory for results", metavar = "character"),
  make_option(c("--comparison-ids"), type = "character", default = NULL,
              help = "Comma-separated list of comparison IDs", metavar = "character"),
  make_option(c("--method"), type = "character", default = "fisher",
              help = "Meta-analysis method (fisher, stouffer) [default: %default]", metavar = "character"),
  make_option(c("--top-n"), type = "integer", default = 100,
              help = "Number of top genes to export [default: %default]", metavar = "integer"),
  make_option(c("--fdr-threshold"), type = "double", default = 0.05,
              help = "FDR threshold for significance [default: %default]", metavar = "double"),
  make_option(c("--plot-volcano"), action = "store_true", default = FALSE,
              help = "Generate volcano plot")
)

opt_parser <- OptionParser(option_list = option_list)
opt <- parse_args(opt_parser)

# Validate required arguments
if (is.null(opt$`db-path`) || is.null(opt$`output-dir`) || is.null(opt$`comparison-ids`)) {
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
perform_meta_analysis <- function(db_path, output_dir, comp_ids_str, method, top_n, fdr_threshold, plot_volcano) {

  # Connect to database
  db <- connect_db(db_path)

  tryCatch({

    # Parse comparison IDs
    comp_ids <- as.integer(strsplit(comp_ids_str, ",")[[1]])
    comp_ids <- comp_ids[!is.na(comp_ids)]

    cat(sprintf("Running %s meta-analysis on %d comparisons\n",
                method, length(comp_ids)), file = stderr())

    # Get comparison info
    comparison_query <- sprintf(
      "SELECT c.id as comparison_id, d.dataset_acc, c.case_ann, c.control_ann
       FROM comparison c
       JOIN dataset d ON c.dataset_id = d.dataset_id
       WHERE c.id IN (%s)",
      paste(comp_ids, collapse = ", ")
    )
    comparisons <- dbGetQuery(db, comparison_query)

    if (nrow(comparisons) == 0) {
      stop("No valid comparisons found")
    }

    cat(sprintf("Found %d valid comparisons\n", nrow(comparisons)), file = stderr())

    # Get DGE data for all comparisons
    comp_data_query <- sprintf(
      "SELECT cd.comparison_id, gm.symbol, cd.log_fc, cd.p_value
       FROM comparison_data cd
       JOIN gene_map gm ON cd.gene = gm.id
       WHERE cd.comparison_id IN (%s)
         AND cd.p_value IS NOT NULL
         AND cd.log_fc IS NOT NULL",
      paste(comp_ids, collapse = ", ")
    )
    comp_data <- dbGetQuery(db, comp_data_query)

    if (nrow(comp_data) == 0) {
      stop("No comparison data found for specified comparisons")
    }

    cat(sprintf("Retrieved data for %d gene-comparison pairs\n", nrow(comp_data)), file = stderr())

    # For each gene, combine p-values across comparisons
    cat("Performing meta-analysis...\n", file = stderr())

    meta_results <- comp_data %>%
      group_by(symbol) %>%
      summarise(
        n_comparisons = n(),
        mean_logfc = mean(log_fc, na.rm = TRUE),
        median_logfc = median(log_fc, na.rm = TRUE),
        sd_logfc = sd(log_fc, na.rm = TRUE),
        n_up = sum(log_fc > 0, na.rm = TRUE),
        n_down = sum(log_fc < 0, na.rm = TRUE),
        consistent_direction = all(sign(log_fc) == sign(mean_logfc), na.rm = TRUE),
        .groups = "drop"
      )

    # Compute meta p-value using poolr
    meta_pvalues <- list()

    for (i in 1:nrow(meta_results)) {
      gene_symbol <- meta_results$symbol[i]

      # Get p-values for this gene
      gene_pvals <- comp_data %>%
        filter(symbol == gene_symbol) %>%
        pull(p_value)

      # Skip if not enough p-values
      if (length(gene_pvals) < 2) {
        meta_pvalues[[gene_symbol]] <- NA
        next
      }

      # Replace p-value = 0 with smallest non-zero p-value / 10
      min_nonzero <- min(gene_pvals[gene_pvals > 0])
      gene_pvals[gene_pvals == 0] <- min_nonzero / 10

      # Apply meta-analysis method
      if (tolower(method) == "fisher") {
        meta_result <- tryCatch({
          fisher(gene_pvals)
        }, error = function(e) {
          list(p = NA)
        })
      } else if (tolower(method) == "stouffer") {
        meta_result <- tryCatch({
          stouffer(gene_pvals)
        }, error = function(e) {
          list(p = NA)
        })
      } else {
        stop(sprintf("Unknown meta-analysis method: %s", method))
      }

      meta_pvalues[[gene_symbol]] <- meta_result$p
    }

    # Add meta p-values to results
    meta_results$meta_pval <- sapply(meta_results$symbol, function(g) {
      p <- meta_pvalues[[g]]
      ifelse(is.null(p) || length(p) == 0, NA, p)
    })

    # Compute FDR
    meta_results <- meta_results %>%
      mutate(
        meta_fdr = p.adjust(meta_pval, method = "BH"),
        direction = case_when(
          meta_fdr < fdr_threshold & mean_logfc > 0 ~ "Up",
          meta_fdr < fdr_threshold & mean_logfc < 0 ~ "Down",
          TRUE ~ "Not Significant"
        )
      ) %>%
      arrange(meta_pval)

    # Count significant genes
    n_sig_up <- sum(meta_results$direction == "Up", na.rm = TRUE)
    n_sig_down <- sum(meta_results$direction == "Down", na.rm = TRUE)

    cat(sprintf("Significant genes: %d upregulated, %d downregulated\n",
                n_sig_up, n_sig_down), file = stderr())

    # Export full results
    output_file <- file.path(output_dir, "meta_analysis_results.csv")
    write.csv(meta_results, output_file, row.names = FALSE)
    cat(sprintf("Meta-analysis results saved to: %s\n", output_file), file = stderr())

    # Export top genes
    top_genes <- meta_results %>%
      head(top_n)

    top_file <- file.path(output_dir, "top_genes.csv")
    write.csv(top_genes, top_file, row.names = FALSE)
    cat(sprintf("Top %d genes saved to: %s\n", top_n, top_file), file = stderr())

    # Export significant genes
    sig_genes <- meta_results %>%
      filter(meta_fdr < fdr_threshold)

    if (nrow(sig_genes) > 0) {
      sig_file <- file.path(output_dir, "significant_genes.csv")
      write.csv(sig_genes, sig_file, row.names = FALSE)
      cat(sprintf("Significant genes saved to: %s\n", sig_file), file = stderr())
    }

    # Generate volcano plot
    if (plot_volcano) {

      # Prepare data for plotting
      plot_data <- meta_results %>%
        filter(!is.na(meta_pval)) %>%
        mutate(
          log10_pval = -log10(meta_pval),
          color_group = direction
        )

      # Identify top genes to label
      top_up <- plot_data %>%
        filter(direction == "Up") %>%
        arrange(meta_pval) %>%
        head(10)

      top_down <- plot_data %>%
        filter(direction == "Down") %>%
        arrange(meta_pval) %>%
        head(10)

      genes_to_label <- bind_rows(top_up, top_down)

      # Create volcano plot
      volcano_plot <- ggplot(plot_data, aes(x = mean_logfc, y = log10_pval)) +
        geom_point(aes(color = color_group), alpha = 0.6, size = 2) +
        scale_color_manual(
          values = c(
            "Up" = "#E41A1C",
            "Down" = "#377EB8",
            "Not Significant" = "gray70"
          ),
          name = "Meta-Analysis Result"
        ) +
        geom_hline(yintercept = -log10(fdr_threshold),
                   linetype = "dashed", color = "black", alpha = 0.5) +
        labs(
          title = sprintf("Meta-Analysis Volcano Plot (%s method)", method),
          subtitle = sprintf("%d comparisons combined", length(comp_ids)),
          x = "Mean Log2 Fold Change",
          y = "-Log10 Meta P-value",
          caption = sprintf("Threshold: FDR < %.3f | Up: %d | Down: %d",
                           fdr_threshold, n_sig_up, n_sig_down)
        ) +
        theme_minimal() +
        theme(
          plot.title = element_text(hjust = 0.5, face = "bold", size = 14),
          plot.subtitle = element_text(hjust = 0.5, size = 11),
          axis.title = element_text(size = 12),
          axis.text = element_text(size = 10),
          legend.position = "right",
          legend.title = element_text(size = 12),
          legend.text = element_text(size = 10),
          plot.caption = element_text(hjust = 0, size = 9)
        )

      # Add gene labels
      if (nrow(genes_to_label) > 0) {
        volcano_plot <- volcano_plot +
          geom_text_repel(
            data = genes_to_label,
            aes(label = symbol),
            size = 3,
            box.padding = 0.5,
            point.padding = 0.3,
            segment.color = "grey50",
            max.overlaps = 20
          )
      }

      volcano_file <- file.path(output_dir, "meta_volcano.png")
      ggsave(volcano_file, volcano_plot, width = 10, height = 8, dpi = 300)
      cat(sprintf("Volcano plot saved to: %s\n", volcano_file), file = stderr())
    }

    # Prepare JSON summary
    summary <- list(
      method = method,
      n_comparisons = length(comp_ids),
      comparisons = comparisons$dataset_acc,
      n_genes_tested = nrow(meta_results),
      n_genes_significant = sum(meta_results$meta_fdr < fdr_threshold, na.rm = TRUE),
      n_genes_up = n_sig_up,
      n_genes_down = n_sig_down,
      fdr_threshold = fdr_threshold,
      files = list(
        meta_results = "meta_analysis_results.csv",
        top_genes = "top_genes.csv"
      )
    )

    if (nrow(sig_genes) > 0) {
      summary$files$significant_genes <- "significant_genes.csv"
      summary$top_significant_genes <- head(sig_genes$symbol, 10)
    }

    if (plot_volcano) {
      summary$files$volcano_plot <- "meta_volcano.png"
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
perform_meta_analysis(
  opt$`db-path`,
  opt$`output-dir`,
  opt$`comparison-ids`,
  opt$method,
  opt$`top-n`,
  opt$`fdr-threshold`,
  opt$`plot-volcano`
)
