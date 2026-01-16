# Plot Utility Functions for IBDTransDB CLI
# Common plotting helpers and themes

#' Get IBD color palette
#'
#' @param n Number of colors needed
#' @return Vector of color codes
get_ibd_palette <- function(n = NULL) {
  # Custom color palette for IBD analyses
  colors <- c(
    "#E41A1C", # Red
    "#377EB8", # Blue
    "#4DAF4A", # Green
    "#984EA3", # Purple
    "#FF7F00", # Orange
    "#FFFF33", # Yellow
    "#A65628", # Brown
    "#F781BF", # Pink
    "#999999"  # Grey
  )

  if (!is.null(n)) {
    if (n <= length(colors)) {
      return(colors[1:n])
    } else {
      # Use RColorBrewer for more colors
      return(RColorBrewer::brewer.pal(n, "Set3"))
    }
  }

  return(colors)
}

#' Get base theme for IBD plots
#'
#' @return ggplot2 theme object
get_ibd_theme <- function() {
  ggplot2::theme_bw() +
    ggplot2::theme(
      panel.grid.major = ggplot2::element_line(color = "grey90"),
      panel.grid.minor = ggplot2::element_blank(),
      axis.text = ggplot2::element_text(size = 10, color = "black"),
      axis.title = ggplot2::element_text(size = 12, face = "bold"),
      plot.title = ggplot2::element_text(size = 14, face = "bold", hjust = 0.5),
      legend.position = "right",
      legend.title = ggplot2::element_text(size = 11, face = "bold"),
      legend.text = ggplot2::element_text(size = 10)
    )
}

#' Save plot to file
#'
#' @param plot ggplot2 object
#' @param filename Output filename
#' @param width Width in inches
#' @param height Height in inches
#' @param dpi Resolution
save_plot <- function(plot, filename, width = 8, height = 6, dpi = 300) {
  ggplot2::ggsave(
    filename = filename,
    plot = plot,
    width = width,
    height = height,
    dpi = dpi,
    bg = "white"
  )
}

#' Create volcano plot
#'
#' @param data Data frame with log_fc, p_value, gene columns
#' @param logfc_threshold LogFC threshold for significance
#' @param pval_threshold P-value threshold for significance
#' @param title Plot title
#' @return ggplot2 object
create_volcano_plot <- function(data,
                                logfc_threshold = 1.0,
                                pval_threshold = 0.05,
                                title = "Volcano Plot") {
  # Calculate -log10(p-value)
  data$neg_log10_p <- -log10(data$p_value)

  # Classify genes
  data$significance <- "NS"
  data$significance[data$log_fc > logfc_threshold & data$p_value < pval_threshold] <- "Up"
  data$significance[data$log_fc < -logfc_threshold & data$p_value < pval_threshold] <- "Down"

  # Create plot
  p <- ggplot2::ggplot(data, ggplot2::aes(x = log_fc, y = neg_log10_p, color = significance)) +
    ggplot2::geom_point(alpha = 0.6, size = 1.5) +
    ggplot2::scale_color_manual(
      values = c("Up" = "#E41A1C", "Down" = "#377EB8", "NS" = "grey70")
    ) +
    ggplot2::geom_vline(xintercept = c(-logfc_threshold, logfc_threshold),
                       linetype = "dashed", color = "grey40") +
    ggplot2::geom_hline(yintercept = -log10(pval_threshold),
                       linetype = "dashed", color = "grey40") +
    ggplot2::labs(
      title = title,
      x = "Log2 Fold Change",
      y = "-log10(P-value)",
      color = "Significance"
    ) +
    get_ibd_theme()

  return(p)
}

#' Create boxplot for gene expression
#'
#' @param data Data frame with expression, group columns
#' @param gene_name Gene name for title
#' @param xlab X-axis label
#' @param ylab Y-axis label
#' @return ggplot2 object
create_expression_boxplot <- function(data,
                                     gene_name = NULL,
                                     xlab = "Group",
                                     ylab = "Expression") {
  title <- if (!is.null(gene_name)) {
    sprintf("Expression: %s", gene_name)
  } else {
    "Gene Expression"
  }

  p <- ggplot2::ggplot(data, ggplot2::aes(x = group, y = expression, fill = group)) +
    ggplot2::geom_boxplot(outlier.shape = NA, alpha = 0.7) +
    ggplot2::geom_jitter(width = 0.2, alpha = 0.3, size = 1) +
    ggplot2::scale_fill_manual(values = get_ibd_palette(length(unique(data$group)))) +
    ggplot2::labs(
      title = title,
      x = xlab,
      y = ylab
    ) +
    get_ibd_theme() +
    ggplot2::theme(
      axis.text.x = ggplot2::element_text(angle = 45, hjust = 1),
      legend.position = "none"
    )

  return(p)
}

#' Create PCA plot
#'
#' @param data Data frame with PC1, PC2, and optional color variable
#' @param color_var Column name for coloring points
#' @param variance_exp Vector with variance explained for PC1 and PC2
#' @param title Plot title
#' @return ggplot2 object
create_pca_plot <- function(data,
                           color_var = NULL,
                           variance_exp = NULL,
                           title = "PCA Plot") {
  # Axis labels with variance explained
  if (!is.null(variance_exp) && length(variance_exp) >= 2) {
    xlab <- sprintf("PC1 (%.1f%% variance)", variance_exp[1])
    ylab <- sprintf("PC2 (%.1f%% variance)", variance_exp[2])
  } else {
    xlab <- "PC1"
    ylab <- "PC2"
  }

  # Create base plot
  if (!is.null(color_var) && color_var %in% colnames(data)) {
    p <- ggplot2::ggplot(data, ggplot2::aes(x = PC1, y = PC2, color = .data[[color_var]])) +
      ggplot2::scale_color_manual(values = get_ibd_palette())
  } else {
    p <- ggplot2::ggplot(data, ggplot2::aes(x = PC1, y = PC2))
  }

  # Add elements
  p <- p +
    ggplot2::geom_point(size = 3, alpha = 0.7) +
    ggplot2::labs(
      title = title,
      x = xlab,
      y = ylab,
      color = color_var
    ) +
    get_ibd_theme()

  return(p)
}

#' Create scree plot for PCA
#'
#' @param variance_exp Vector with variance explained per PC
#' @param n_pcs Number of PCs to display (default: all)
#' @return ggplot2 object
create_scree_plot <- function(variance_exp, n_pcs = NULL) {
  if (is.null(n_pcs)) {
    n_pcs <- length(variance_exp)
  }

  data <- data.frame(
    PC = factor(1:n_pcs, levels = 1:n_pcs),
    Variance = variance_exp[1:n_pcs]
  )

  p <- ggplot2::ggplot(data, ggplot2::aes(x = PC, y = Variance)) +
    ggplot2::geom_bar(stat = "identity", fill = "#377EB8", alpha = 0.7) +
    ggplot2::geom_line(group = 1, color = "#E41A1C", size = 1) +
    ggplot2::geom_point(color = "#E41A1C", size = 3) +
    ggplot2::labs(
      title = "Scree Plot",
      x = "Principal Component",
      y = "Variance Explained (%)"
    ) +
    get_ibd_theme() +
    ggplot2::theme(
      axis.text.x = ggplot2::element_text(angle = 0)
    )

  return(p)
}

#' Create heatmap for gene expression
#'
#' @param data Matrix or data frame with genes as rows, samples as columns
#' @param title Plot title
#' @param cluster_rows Cluster rows (default: TRUE)
#' @param cluster_cols Cluster columns (default: TRUE)
#' @return Plot object
create_heatmap <- function(data,
                          title = "Expression Heatmap",
                          cluster_rows = TRUE,
                          cluster_cols = TRUE) {
  if (!requireNamespace("pheatmap", quietly = TRUE)) {
    warning("pheatmap package not available, using basic heatmap")
    heatmap(as.matrix(data), main = title)
  } else {
    pheatmap::pheatmap(
      data,
      main = title,
      cluster_rows = cluster_rows,
      cluster_cols = cluster_cols,
      color = colorRampPalette(c("blue", "white", "red"))(100),
      fontsize = 10
    )
  }
}

#' Add statistical comparison to plot
#'
#' @param plot ggplot2 object
#' @param comparisons List of comparison pairs
#' @param test Statistical test (default: "wilcox.test")
#' @return ggplot2 object with statistical annotations
add_stat_compare <- function(plot, comparisons, test = "wilcox.test") {
  if (requireNamespace("ggpubr", quietly = TRUE)) {
    plot + ggpubr::stat_compare_means(
      comparisons = comparisons,
      method = test,
      label = "p.signif"
    )
  } else {
    warning("ggpubr package not available, skipping statistical annotations")
    plot
  }
}

#' Format p-value for display
#'
#' @param pval P-value
#' @return Formatted string
format_pvalue <- function(pval) {
  if (is.na(pval)) {
    return("NA")
  } else if (pval < 0.001) {
    return("< 0.001")
  } else {
    return(sprintf("%.3f", pval))
  }
}

#' Get plot dimensions based on number of elements
#'
#' @param n_elements Number of elements to plot
#' @param base_width Base width in inches
#' @param base_height Base height in inches
#' @return List with width and height
get_plot_dimensions <- function(n_elements, base_width = 8, base_height = 6) {
  # Adjust width for many elements
  if (n_elements > 5) {
    width <- base_width + (n_elements - 5) * 0.5
  } else {
    width <- base_width
  }

  list(width = width, height = base_height)
}
