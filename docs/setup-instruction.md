# IBDTransDB Local Setup Instructions

This guide will help you set up and run the IBDTransDB RShiny applications locally on your machine.

## Overview

IBDTransDB is a manually curated transcriptomic database for inflammatory bowel disease (IBD) consisting of multiple RShiny applications:

- **IBDTransDB Home** - Main landing page and navigation hub
- **IBDExplore** - Interactive visualization tool for individual datasets
- **IBDCompare** - Dataset comparison tool across different conditions
- **IBDIntegrate** - Meta-analysis tool for target prioritization
- **IBDExplore Data** - Dataset exploration variant

## Prerequisites

### 1. R Installation

Ensure you have R installed on your system (version 4.0.0 or higher recommended).

- Download R from [CRAN](https://cran.r-project.org/)
- Verify installation by running `R --version` in your terminal

### 2. RStudio (Recommended)

While not strictly required, RStudio provides the best development experience for RShiny apps.

- Download RStudio from [posit.co](https://posit.co/download/rstudio-desktop/)

## Installation Steps

### Step 1: Clone the Repository

```bash
git clone <repository-url>
cd IBDTransDB
```

### Step 2: Download the Database

The IBDTransDB database file (`IBDTransDB.db`) must be downloaded separately and placed in each module folder.

1. Download the database from: [https://www.icloud.com/iclouddrive/013D9ewhOhNjj-5tErDEWnhow#IBDTransDB](https://www.icloud.com/iclouddrive/013D9ewhOhNjj-5tErDEWnhow#IBDTransDB)

2. Copy the `IBDTransDB.db` file to each of the following directories:
   ```
   IBDTransDB_Home/IBDTransDB.db
   IBDCompare/IBDTransDB.db
   IBDExplore/IBDTransDB.db
   IBDExplore_Data/IBDTransDB.db
   IBDIntegrate/IBDTransDB.db
   ```

   You can do this manually or use the following command (after downloading the database to your Downloads folder):

   ```bash
   # From the IBDTransDB root directory
   cp ~/Downloads/IBDTransDB.db IBDTransDB_Home/
   cp ~/Downloads/IBDTransDB.db IBDCompare/
   cp ~/Downloads/IBDTransDB.db IBDExplore/
   cp ~/Downloads/IBDTransDB.db IBDExplore_Data/
   cp ~/Downloads/IBDTransDB.db IBDIntegrate/
   ```

### Step 3: Install Required R Packages

Open R or RStudio and install the required packages. You can install all dependencies at once by running:

```r
# List of required packages
packages <- c(
  # Core Shiny packages
  "shiny",
  "shinyWidgets",
  "shinyBS",
  "shinybusy",
  "shinyalert",
  "shinydashboard",
  "shinydashboardPlus",
  "shinyjs",
  "rintrojs",

  # Database
  "RSQLite",
  "DBI",

  # Data manipulation
  "dplyr",
  "tidyr",
  "stringr",

  # Visualization
  "ggplot2",
  "RColorBrewer",
  "gridExtra",

  # Table display
  "DT",
  "reactable",
  "kableExtra",

  # Statistical analysis
  "poolr",
  "stats",

  # Web scraping
  "rvest",

  # Other utilities
  "parallel",
  "rstudioapi"
)

# Install packages that are not already installed
new_packages <- packages[!(packages %in% installed.packages()[,"Package"])]
if(length(new_packages)) install.packages(new_packages)

# Load all packages to verify installation
lapply(packages, library, character.only = TRUE)
```

## Running the Applications

### Option 1: Run Individual Apps in RStudio

1. Open RStudio
2. Navigate to the app directory you want to run:
   - `IBDTransDB_Home/IBDTransDB.R` - Home page
   - `IBDCompare/IBDTransDB_Compare.R` - Compare module
   - `IBDExplore/IBDTransDB_Explore.R` - Explore module
   - `IBDIntegrate/IBDTransDB_Integrate.R` - Integrate module
   - `IBDExplore_Data/IBDTransDB_Dataset.R` - Dataset module

3. Open the desired `.R` file in RStudio
4. Click the "Run App" button (appears in the top right of the editor), or run:
   ```r
   shiny::runApp()
   ```

### Option 2: Run from R Console

Navigate to the specific app folder and run:

```r
# For the Home page
setwd("IBDTransDB_Home")
shiny::runApp("IBDTransDB.R")

# For IBDCompare
setwd("IBDCompare")
shiny::runApp("IBDTransDB_Compare.R")

# For IBDExplore
setwd("IBDExplore")
shiny::runApp("IBDTransDB_Explore.R")

# For IBDIntegrate
setwd("IBDIntegrate")
shiny::runApp("IBDTransDB_Integrate.R")

# For IBDExplore Data
setwd("IBDExplore_Data")
shiny::runApp("IBDTransDB_Dataset.R")
```

### Option 3: Run from Terminal/Command Line

```bash
# Navigate to the app directory
cd IBDTransDB_Home

# Run the app
R -e "shiny::runApp('IBDTransDB.R')"
```

## Application Architecture

Each RShiny application follows a similar structure:

```
AppFolder/
├── App.R                    # Main app file with UI and Server
├── IBDTransDB.db           # SQLite database (must be downloaded)
├── app_functions/          # Modular R functions
├── www/                    # Static assets (CSS, images, etc.)
├── homepage.html           # HTML content (where applicable)
└── *.csv                   # Data files (enrichment sets, etc.)
```

## Accessing the Applications

Once running, the applications will be accessible in your web browser. By default:

- Local URL: `http://127.0.0.1:<port>`
- The port number will be displayed in the R console

RStudio will typically open the app automatically in a new browser window or in the RStudio Viewer pane.

## Troubleshooting

### Database Connection Issues

**Error:** `Error in dbConnect: unable to open database file`

**Solution:** Ensure the `IBDTransDB.db` file exists in the application folder you're trying to run.

```bash
# Verify database exists
ls -l IBDCompare/IBDTransDB.db
```

### Missing Package Errors

**Error:** `Error in library(packageName) : there is no package called 'packageName'`

**Solution:** Install the missing package:

```r
install.packages("packageName")
```

### Port Already in Use

**Error:** `Error: Can't listen on port XXXX`

**Solution:** Either:
1. Stop the other RShiny app using that port
2. Specify a different port:
   ```r
   shiny::runApp(port = 8888)
   ```

### Slow Performance

Running locally will be significantly faster than the hosted version on shinyapps.io. However, if you experience slowness:

1. Ensure your database file is properly placed in the app directory
2. Close other RShiny apps that might be running
3. Check your R session memory usage: `memory.size()` (Windows) or Activity Monitor/System Monitor (Mac/Linux)

## Development Tips

1. **Live Reload**: When running apps in RStudio, changes to UI elements will often auto-reload. For server logic changes, you may need to stop and restart the app.

2. **Debugging**: Use `browser()` in your server code to set breakpoints, or add `print()` statements to track variable values.

3. **Multiple Apps**: You can run multiple apps simultaneously on different ports if needed.

## Additional Resources

- [Official Tutorials](../tutorial/)
  - [IBDExplore Tutorial](../tutorial/IBDExplore_tutorial.pdf)
  - [IBDCompare Tutorial](../tutorial/IBDCompare_tutorial.pdf)
  - [IBDIntegrate Tutorial](../tutorial/IBDIntegtate_tutorial.pdf)

- [Shiny Documentation](https://shiny.rstudio.com/)
- [Project README](../README.md)

---

# Python CLI Tool

The IBDTransDB CLI provides a lightweight command-line interface to explore the database without requiring the full R visualization stack.

## Prerequisites

- Python 3.9 or higher
- uv (Python package manager) - recommended but optional

## Installation

### Option 1: Using uv (Recommended)

1. **Install uv** (if not already installed):
   ```bash
   curl -LsSf https://astral.sh/uv/install.sh | sh
   ```

2. **Download the database** to `data/IBDTransDB.db`:
   ```bash
   # Download from iCloud link and place in data/ directory
   # https://www.icloud.com/iclouddrive/013D9ewhOhNjj-5tErDEWnhow#IBDTransDB
   cp ~/Downloads/IBDTransDB.db data/
   ```

3. **Create virtual environment and install dependencies**:
   ```bash
   uv venv
   source .venv/bin/activate  # Unix/Mac
   # or
   .venv\Scripts\activate  # Windows

   uv pip install -e .
   ```

### Option 2: Using pip

```bash
# Create virtual environment
python -m venv .venv
source .venv/bin/activate  # Unix/Mac

# Install dependencies
pip install -e .
```

## Usage

### Dataset Commands

```bash
# Show all available filter options
ibdtransdb datasets filters

# List all datasets
ibdtransdb datasets list

# Filter datasets by disease
ibdtransdb datasets list --disease UC

# Filter by multiple criteria
ibdtransdb datasets list --disease UC --tissue Colon --format json

# Get detailed info about a specific dataset
ibdtransdb datasets info GSE16879
```

### Database Inspection Commands

```bash
# Show database statistics
ibdtransdb inspect stats

# List all tables with row counts
ibdtransdb inspect tables

# Show schema for a specific table
ibdtransdb inspect schema dataset
ibdtransdb inspect schema comparison

# Run custom SQL queries
ibdtransdb inspect query "SELECT * FROM dataset WHERE disease = 'UC'"
ibdtransdb inspect query "SELECT COUNT(*) FROM gene_map"

# Export results to CSV
ibdtransdb datasets list --format csv > datasets.csv

# Export results to JSON
ibdtransdb inspect query "SELECT * FROM dataset" --format json > datasets.json
```

### Output Formats

All commands support multiple output formats via the `--format` flag:

- `table` (default) - Beautiful formatted tables in the terminal
- `csv` - CSV format, perfect for piping to files or other tools
- `json` - JSON format for programmatic consumption

### Custom Database Path

By default, the CLI looks for the database at `data/IBDTransDB.db`. You can specify a different path:

```bash
ibdtransdb --db /path/to/IBDTransDB.db datasets list
```

## Examples

### Example 1: Explore Available Data

```bash
# See what's available
ibdtransdb inspect stats
ibdtransdb datasets filters

# Find Crohn's Disease studies
ibdtransdb datasets list --disease CD
```

### Example 2: Export Filtered Data

```bash
# Export UC studies from colon tissue to CSV
ibdtransdb datasets list --disease UC --tissue Colon --format csv > uc_colon_studies.csv

# Get all comparisons as JSON
ibdtransdb inspect query "SELECT * FROM comparison" --format json > comparisons.json
```

### Example 3: Database Exploration

```bash
# Explore database structure
ibdtransdb inspect tables
ibdtransdb inspect schema dataset
ibdtransdb inspect schema comparison_data

# Query specific genes
ibdtransdb inspect query "SELECT * FROM gene_map WHERE gene LIKE 'TNF%'"

# Check sample annotations
ibdtransdb inspect query "SELECT DISTINCT sample_ann_type FROM sample_ann"
```

## CLI Command Reference

### `ibdtransdb datasets`

- `list` - List datasets with optional filters
  - `--disease`, `-D` - Filter by disease (UC, CD, etc.)
  - `--tissue`, `-t` - Filter by tissue/source
  - `--treatment`, `-T` - Filter by treatment
  - `--format`, `-f` - Output format (table, csv, json)

- `info <dataset_acc>` - Show detailed information about a specific dataset
  - `--format`, `-f` - Output format

- `filters` - Show all available filter options

### `ibdtransdb inspect`

- `tables` - List all database tables with row counts
- `schema <table>` - Show schema for a specific table
- `stats` - Show database statistics
- `query <sql>` - Run a custom SQL query
  - `--format`, `-f` - Output format
  - `--limit`, `-l` - Limit number of results (default: 100)

## Troubleshooting

### Database Not Found

**Error:** `Path does not exist`

**Solution:** Ensure the database file is placed in the `data/` directory:

```bash
ls -l data/IBDTransDB.db
```

### Import Errors

**Error:** `ModuleNotFoundError: No module named 'typer'`

**Solution:** Make sure you've activated the virtual environment and installed dependencies:

```bash
source .venv/bin/activate
uv pip install -e .
# or
pip install -e .
```

---
