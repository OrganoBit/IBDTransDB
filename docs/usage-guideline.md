# IBDTransDB CLI - User Guide

## Overview

The IBDTransDB Command Line Interface (CLI) provides comprehensive access to the IBD Translational Database for analyzing inflammatory bowel disease (IBD) transcriptomic data. This tool enables researchers to perform various analyses including PCA, differential expression, enrichment analysis, meta-analysis, and more—all from the command line.

**Version**: 0.2.0
**Database**: IBDTransDB (34 datasets, 2,917 samples, 53,653 genes)

## Table of Contents

1. [Installation](#installation)
2. [Quick Start](#quick-start)
3. [Available Commands](#available-commands)
4. [Common Workflows](#common-workflows)
5. [Output Formats](#output-formats)
6. [Examples](#examples)
7. [Troubleshooting](#troubleshooting)
8. [FAQs](#faqs)

## Installation

### Prerequisites

- **Python**: Version 3.9 or higher
- **R**: Version 4.0 or higher ([Download R](https://www.r-project.org/))
- **Database**: IBDTransDB.db file (download from iCloud)

### Step 1: Clone or Download Repository

```bash
cd /path/to/IBDTransDB
```

### Step 2: Install Python CLI

```bash
# Create virtual environment
python -m venv .venv

# Activate virtual environment
source .venv/bin/activate  # On Mac/Linux
# OR
.venv\Scripts\activate  # On Windows

# Install CLI
pip install -e .
```

### Step 3: Install R Packages

```bash
# Run R package installer
Rscript scripts/r_analysis/install_packages.R
```

This will install all required R packages:
- **Core**: RSQLite, dplyr, ggplot2, jsonlite
- **Statistics**: poolr (for meta-analysis)
- **Enrichment**: WebGestaltR
- **Visualization**: RColorBrewer, gridExtra, ggrepel
- **Tables**: reactable, DT, kableExtra

### Step 4: Download Database

Download `IBDTransDB.db` from the project's iCloud storage and place it in:
```
data/IBDTransDB.db
```

### Step 5: Verify Installation

```bash
# Check CLI is installed
ibdtransdb --help

# Check dependencies
ibdtransdb inspect stats
```

## Quick Start

### Browse Available Datasets

```bash
# List all datasets
ibdtransdb datasets list

# Filter by disease
ibdtransdb datasets list --disease CD

# Get dataset details
ibdtransdb datasets info GSE16879
```

### Run Your First Analysis

```bash
# PCA analysis
ibdtransdb explore pca GSE16879 --color-by Disease --output pca_results.csv

# Differential expression
ibdtransdb explore dge GSE16879 1 --volcano --output dge_results.csv

# Expression plot
ibdtransdb explore expression GSE16879 --genes TNFA,IL6,IL1B --output expression.csv
```

## Available Commands

### Command Structure

```
ibdtransdb [GLOBAL OPTIONS] COMMAND [COMMAND OPTIONS]
```

### Global Options

| Option | Description | Default |
|--------|-------------|---------|
| `--db PATH` | Path to IBDTransDB.db | `data/IBDTransDB.db` |
| `--help` | Show help message | |

### Command Groups

The CLI is organized into 5 main command groups:

1. **`datasets`** - Browse and filter datasets
2. **`inspect`** - Inspect database schema and run queries
3. **`explore`** - Single dataset analysis (Phase 2 - Coming Soon)
4. **`compare`** - Cross-dataset comparisons (Phase 3 - Coming Soon)
5. **`integrate`** - Meta-analysis and target ranking (Phase 4 - Coming Soon)

## Datasets Commands

### `datasets list`

List all datasets with optional filtering.

**Usage**:
```bash
ibdtransdb datasets list [OPTIONS]
```

**Options**:
- `--disease`, `-D`: Filter by disease (CD, UC, Healthy, etc.)
- `--tissue`, `-t`: Filter by tissue/source (Blood, Colon, Ileum, Rectum)
- `--treatment`, `-T`: Filter by treatment (Infliximab, Vedolizumab, etc.)
- `--format`, `-f`: Output format (table, csv, json) [default: table]

**Examples**:
```bash
# List all datasets
ibdtransdb datasets list

# Filter by Crohn's Disease
ibdtransdb datasets list --disease CD

# Filter by multiple criteria
ibdtransdb datasets list --disease UC --tissue Colon

# Export to CSV
ibdtransdb datasets list --format csv > datasets.csv
```

### `datasets info`

Get detailed information about a specific dataset.

**Usage**:
```bash
ibdtransdb datasets info DATASET_ACC [OPTIONS]
```

**Arguments**:
- `DATASET_ACC`: Dataset accession (e.g., GSE16879)

**Options**:
- `--format`, `-f`: Output format (table, csv, json)

**Examples**:
```bash
# Get dataset info
ibdtransdb datasets info GSE16879

# Export as JSON
ibdtransdb datasets info GSE16879 --format json > GSE16879_info.json
```

### `datasets filters`

Show all available filter options.

**Usage**:
```bash
ibdtransdb datasets filters
```

**Output**: Lists all available diseases, tissues, treatments, and organisms.

## Inspect Commands

### `inspect tables`

List all database tables with row counts.

**Usage**:
```bash
ibdtransdb inspect tables
```

### `inspect schema`

Show schema (columns) for a specific table.

**Usage**:
```bash
ibdtransdb inspect schema TABLE_NAME
```

**Examples**:
```bash
# View dataset table structure
ibdtransdb inspect schema dataset

# View comparison table structure
ibdtransdb inspect schema comparison
```

### `inspect query`

Run custom SQL queries.

**Usage**:
```bash
ibdtransdb inspect query "SQL_QUERY" [OPTIONS]
```

**Options**:
- `--format`, `-f`: Output format (table, csv, json)
- `--limit`, `-l`: Limit results [default: 100]

**Examples**:
```bash
# Count datasets by disease
ibdtransdb inspect query "SELECT disease, COUNT(*) FROM dataset GROUP BY disease"

# Get top differentially expressed genes
ibdtransdb inspect query "
  SELECT gm.symbol, cd.log_fc, cd.p_value
  FROM comparison_data cd
  JOIN gene_map gm ON cd.gene = gm.id
  WHERE cd.comparison_id = 1
  ORDER BY cd.p_value
  LIMIT 10
"

# Export results to CSV
ibdtransdb inspect query "SELECT * FROM dataset" --format csv > all_datasets.csv
```

### `inspect stats`

Show database statistics summary.

**Usage**:
```bash
ibdtransdb inspect stats
```

**Output**: Shows total datasets, comparisons, genes, samples, and data points.

## Explore Commands (Phase 2 - In Development)

The `explore` command group will provide single dataset analysis capabilities:

### Planned Commands

- **`pca`** - PCA analysis with plots
- **`dge`** - Differential expression with volcano plots
- **`expression`** - Gene expression boxplots
- **`enrichment`** - Pathway enrichment (ORA/GSEA)
- **`deconvolution`** - Cell type deconvolution
- **`signature`** - Gene signature analysis

**Example Usage** (coming soon):
```bash
# PCA colored by disease
ibdtransdb explore pca GSE16879 --color-by Disease --output pca.csv

# Volcano plot
ibdtransdb explore dge GSE16879 1 --volcano --pval-threshold 0.05

# Expression boxplots
ibdtransdb explore expression GSE16879 --genes TNFA,IL6 --groups "CD" "Healthy"
```

## Compare Commands (Phase 3 - In Development)

The `compare` command group will provide cross-dataset comparison capabilities:

### Planned Commands

- **`table`** - Cross-dataset comparison tables
- **`meta`** - Meta-analysis using Fisher's method
- **`geneset`** - Pathway comparison across datasets

**Example Usage** (coming soon):
```bash
# Compare gene across datasets
ibdtransdb compare table TNFA,IL6 --disease CD --tissue Colon

# Meta-analysis
ibdtransdb compare meta 1,2,3,4 --method fisher --output meta.csv
```

## Integrate Commands (Phase 4 - In Development)

The `integrate` command group will provide meta-analysis and target ranking:

### Planned Commands

- **`rank`** - Target ranking across datasets
- **`signature-rank`** - Signature-based ranking
- **`pathways`** - Pathway integration

**Example Usage** (coming soon):
```bash
# Rank targets
ibdtransdb integrate rank --genes targets.txt --disease CD --tissue Colon

# Signature ranking
ibdtransdb integrate signature-rank --signatures sigs.json --disease CD
```

## Output Formats

All data-returning commands support three output formats:

### 1. Table Format (Default)

Beautiful formatted tables displayed in terminal using Rich library.

```bash
ibdtransdb datasets list
```

**Features**:
- Color-coded columns
- Auto-sized columns
- Limited to 100 rows for display

**Best for**: Interactive exploration

### 2. CSV Format

Standard comma-separated values.

```bash
ibdtransdb datasets list --format csv > datasets.csv
```

**Features**:
- Headers included
- No row limits
- Easy to import into Excel/R/Python

**Best for**: Data export and analysis

### 3. JSON Format

Structured JSON array.

```bash
ibdtransdb datasets list --format json > datasets.json
```

**Features**:
- Structured data
- Type-safe (preserves integers, nulls)
- No row limits

**Best for**: Programmatic processing

## Common Workflows

### Workflow 1: Dataset Discovery

```bash
# Step 1: Check database statistics
ibdtransdb inspect stats

# Step 2: See available filters
ibdtransdb datasets filters

# Step 3: Find relevant datasets
ibdtransdb datasets list --disease CD --tissue Ileum

# Step 4: Get details for specific dataset
ibdtransdb datasets info GSE16879
```

### Workflow 2: Gene Expression Analysis

```bash
# Step 1: Find gene of interest
ibdtransdb inspect query "
  SELECT * FROM gene_map
  WHERE symbol LIKE 'TNF%'
"

# Step 2: Get expression data (when explore commands available)
# ibdtransdb explore expression GSE16879 --genes TNFA,TNFRSF1A

# Step 3: Compare across conditions
# ibdtransdb explore dge GSE16879 1 --volcano
```

### Workflow 3: Cross-Study Meta-Analysis

```bash
# Step 1: Find relevant comparisons
ibdtransdb inspect query "
  SELECT c.comparison_id, d.dataset_acc, c.case_ann, c.control_ann
  FROM comparison c
  JOIN dataset d ON c.dataset_id = d.dataset_id
  WHERE d.disease LIKE '%CD%'
"

# Step 2: Run meta-analysis (when compare commands available)
# ibdtransdb compare meta 1,2,3,4,5 --output meta_analysis.csv

# Step 3: Rank targets (when integrate commands available)
# ibdtransdb integrate rank --disease CD --output targets_ranked.csv
```

### Workflow 4: Data Export for R/Python

```bash
# Export datasets
ibdtransdb datasets list --format csv > datasets.csv

# Export all comparisons
ibdtransdb inspect query "SELECT * FROM comparison" --format json > comparisons.json

# Export gene expression for specific genes
ibdtransdb inspect query "
  SELECT gm.symbol, dd.sample_id, dd.expression_value
  FROM dataset_data dd
  JOIN gene_map gm ON dd.gene = gm.id
  WHERE gm.symbol IN ('TNFA', 'IL6', 'IL1B')
  AND dd.dataset_id = 1
" --format csv > gene_expression.csv
```

## Examples

### Example 1: Find IBD Studies in Blood

```bash
ibdtransdb datasets list --disease CD --tissue Blood --format table
```

### Example 2: Export UC Colon Datasets

```bash
ibdtransdb datasets list --disease UC --tissue Colon --format csv > uc_colon_studies.csv
```

### Example 3: Check Database Structure

```bash
# List all tables
ibdtransdb inspect tables

# Check dataset table schema
ibdtransdb inspect schema dataset

# View sample of data
ibdtransdb inspect query "SELECT * FROM dataset LIMIT 5"
```

### Example 4: Gene Search

```bash
# Find IL genes
ibdtransdb inspect query "SELECT * FROM gene_map WHERE symbol LIKE 'IL%'" --limit 20

# Count genes
ibdtransdb inspect query "SELECT COUNT(*) as gene_count FROM gene_map"
```

### Example 5: Comparison Statistics

```bash
# Get comparison details
ibdtransdb inspect query "
  SELECT
    d.dataset_acc,
    c.comparison_id,
    c.case_ann,
    c.control_ann,
    c.case_sample,
    c.control_sample
  FROM comparison c
  JOIN dataset d ON c.dataset_id = d.dataset_id
  WHERE d.disease = 'CD'
"
```

## Troubleshooting

### Issue: Command not found

**Error**: `ibdtransdb: command not found`

**Solution**:
```bash
# Ensure virtual environment is activated
source .venv/bin/activate

# Reinstall CLI
pip install -e .
```

### Issue: Database not found

**Error**: `Path 'data/IBDTransDB.db' does not exist`

**Solution**:
```bash
# Download database from iCloud
# Place in data/ directory

# OR specify custom path
ibdtransdb --db /path/to/IBDTransDB.db datasets list
```

### Issue: R not found

**Error**: `R is not installed or not in PATH`

**Solution**:
1. Install R from https://www.r-project.org/
2. Ensure R is in your system PATH
3. Verify: `Rscript --version`

### Issue: Missing R packages

**Error**: Warnings about missing R packages

**Solution**:
```bash
# Run package installer
Rscript scripts/r_analysis/install_packages.R

# OR install manually in R
R
> install.packages(c("RSQLite", "dplyr", "ggplot2", "jsonlite"))
```

### Issue: Query syntax error

**Error**: `Query error: near "WHERE": syntax error`

**Solution**:
- Check SQL syntax
- Use double quotes around entire query
- Use single quotes for string literals inside query

```bash
# Correct
ibdtransdb inspect query "SELECT * FROM dataset WHERE disease = 'CD'"

# Incorrect
ibdtransdb inspect query SELECT * FROM dataset WHERE disease = 'CD'
```

## FAQs

### Q: How do I update the CLI?

```bash
cd /path/to/IBDTransDB
git pull  # If using git
pip install -e . --upgrade
```

### Q: Can I use the CLI without R?

Partially. You can use `datasets` and `inspect` commands without R. However, `explore`, `compare`, and `integrate` commands require R for analysis.

### Q: How do I export large result sets?

Use CSV or JSON format and redirect to file:

```bash
ibdtransdb inspect query "SELECT * FROM dataset_data" --format csv > large_data.csv
```

### Q: Can I run multiple analyses in parallel?

Yes, you can run multiple CLI instances simultaneously:

```bash
# Terminal 1
ibdtransdb datasets list --disease CD > cd_datasets.csv &

# Terminal 2
ibdtransdb datasets list --disease UC > uc_datasets.csv &
```

### Q: How do I specify a custom database location?

Use the `--db` global option:

```bash
ibdtransdb --db /path/to/custom/IBDTransDB.db datasets list
```

### Q: Where are plots saved?

Plots are saved to `outputs/plots/` directory by default. This can be customized per command with the `--plot-file` option (when available in Phase 2+).

### Q: How do I get help for a specific command?

```bash
# General help
ibdtransdb --help

# Command group help
ibdtransdb datasets --help

# Specific command help
ibdtransdb datasets list --help
```

## Getting Help

- **Documentation**: See `docs/` directory for detailed guides
- **Issues**: Report bugs on GitHub Issues
- **Questions**: Contact the development team
- **Updates**: Check `CHANGELOG.md` for version updates

## Next Steps

1. **Explore your data**: Use `datasets list` and `datasets info` to find relevant datasets
2. **Run queries**: Use `inspect query` for custom data extraction
3. **Wait for Phase 2**: Try PCA, DGE, and enrichment commands when available
4. **Contribute**: Check `docs/dev-guideline.md` for development guide

---

**Version**: 0.2.0
**Last Updated**: 2026-01-13
**License**: See LICENSE file
**Citation**: See CITATION.md
