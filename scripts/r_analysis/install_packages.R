#!/usr/bin/env Rscript

# Install required R packages for IBDTransDB CLI
# This script installs all packages needed for the CLI analysis features

cat("IBDTransDB CLI - R Package Installer\n")
cat("=====================================\n\n")

# CRAN mirror
options(repos = c(CRAN = "https://cloud.r-project.org/"))

# Required packages by category
required_packages <- list(
  # Core Shiny packages (for full RShiny app functionality)
  shiny = c(
    "shiny",              # Core Shiny framework
    "shinyWidgets",       # Additional UI widgets
    "shinyBS",            # Bootstrap components
    "shinybusy",          # Loading indicators
    "shinyalert",         # Alert dialogs
    "shinydashboard",     # Dashboard layouts
    "shinydashboardPlus", # Enhanced dashboard
    "shinyjs",            # JavaScript operations
    "rintrojs"            # Interactive tours
  ),
  # Database
  database = c(
    "RSQLite",      # SQLite database connection
    "DBI"           # Database interface
  ),
  # Data manipulation
  data_manipulation = c(
    "dplyr",        # Data manipulation
    "tidyr",        # Data tidying
    "stringr",      # String manipulation
    "jsonlite",     # JSON export
    "optparse"      # Command-line argument parsing
  ),
  # Visualization
  visualization = c(
    "ggplot2",      # Main plotting library
    "RColorBrewer", # Color palettes
    "gridExtra",    # Multiple plots
    "ggrepel"       # Label positioning
  ),
  # Table display
  tables = c(
    "DT",           # Interactive DataTables
    "reactable",    # Modern interactive tables
    "kableExtra"    # Table formatting
  ),
  # Statistical analysis
  statistics = c(
    "poolr",        # Fisher's method for meta-analysis
    "stats"         # Base R statistics (included by default)
  ),
  # Web scraping
  web = c(
    "rvest"         # Web scraping
  ),
  # Enrichment analysis
  enrichment = c(
    "WebGestaltR"   # Pathway enrichment analysis
  ),
  # Other utilities
  utilities = c(
    "parallel",     # Parallel processing
    "rstudioapi"    # RStudio API (optional)
  ),
  # Optional but useful
  optional = c(
    "pheatmap",     # Heatmap plotting
    "ggpubr"        # Statistical annotations
  )
)

# Function to install package if not already installed
install_if_missing <- function(pkg, category = "Unknown") {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    cat(sprintf("[%s] Installing %s...\n", category, pkg))
    tryCatch({
      install.packages(pkg, dependencies = TRUE, quiet = FALSE)
      cat(sprintf("[%s] ✓ %s installed successfully\n", category, pkg))
      return(TRUE)
    }, error = function(e) {
      cat(sprintf("[%s] ✗ Failed to install %s: %s\n", category, pkg, e$message))
      return(FALSE)
    })
  } else {
    cat(sprintf("[%s] ✓ %s already installed\n", category, pkg))
    return(TRUE)
  }
}

# Track installation results
results <- list(
  success = c(),
  failed = c(),
  skipped = c()
)

# Install packages by category
for (category in names(required_packages)) {
  packages <- required_packages[[category]]

  cat(sprintf("\n%s Packages (%s):\n", toupper(category), category))
  cat(strrep("-", 60), "\n")

  for (pkg in packages) {
    # Skip base R packages
    if (pkg == "stats") {
      cat(sprintf("[%s] ✓ %s (base R package)\n", category, pkg))
      results$skipped <- c(results$skipped, pkg)
      next
    }

    success <- install_if_missing(pkg, category)

    if (success) {
      results$success <- c(results$success, pkg)
    } else {
      results$failed <- c(results$failed, pkg)
    }
  }
}

# Print summary
cat("\n")
cat(strrep("=", 60), "\n")
cat("Installation Summary\n")
cat(strrep("=", 60), "\n\n")

cat(sprintf("✓ Successfully installed/verified: %d packages\n", length(results$success)))
if (length(results$skipped) > 0) {
  cat(sprintf("  Skipped (already present): %d packages\n", length(results$skipped)))
}
if (length(results$failed) > 0) {
  cat(sprintf("✗ Failed installations: %d packages\n", length(results$failed)))
  cat("\nFailed packages:\n")
  for (pkg in results$failed) {
    cat(sprintf("  - %s\n", pkg))
  }
  cat("\nPlease try installing failed packages manually:\n")
  cat(sprintf("  install.packages(c('%s'))\n", paste(results$failed, collapse = "', '")))
}

# Verify critical packages
cat("\n")
cat(strrep("=", 60), "\n")
cat("Verifying Critical Packages\n")
cat(strrep("=", 60), "\n\n")

critical_packages <- c("RSQLite", "DBI", "dplyr", "ggplot2", "jsonlite", "optparse", "shiny")
all_critical_ok <- TRUE

for (pkg in critical_packages) {
  if (requireNamespace(pkg, quietly = TRUE)) {
    # Try to load package to verify it works
    tryCatch({
      library(pkg, character.only = TRUE, quietly = TRUE)
      cat(sprintf("✓ %s: OK\n", pkg))
    }, error = function(e) {
      cat(sprintf("✗ %s: Failed to load (%s)\n", pkg, e$message))
      all_critical_ok <- FALSE
    })
  } else {
    cat(sprintf("✗ %s: Not installed\n", pkg))
    all_critical_ok <- FALSE
  }
}

cat("\n")

if (all_critical_ok && length(results$failed) == 0) {
  cat("✓ All packages installed successfully!\n")
  cat("\nYou can now use the IBDTransDB CLI:\n")
  cat("  ibdtransdb --help\n")
  cat("  ibdtransdb explore pca GSE16879\n")
  quit(status = 0)
} else if (all_critical_ok) {
  cat("✓ Critical packages installed successfully!\n")
  cat(sprintf("⚠ %d optional packages failed to install\n", length(results$failed)))
  cat("\nYou can use most CLI features, but some may be limited.\n")
  quit(status = 0)
} else {
  cat("✗ Installation incomplete. Please resolve errors above.\n")
  quit(status = 1)
}
