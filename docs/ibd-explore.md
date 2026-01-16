# IBDExplore System Documentation

## Overview

IBDExplore is a dual-interface system for exploring and analyzing the IBD Translational Database (IBDTransDB). It provides both interactive web-based exploration (via R Shiny) and programmatic access (via Python CLI) to a curated collection of 34 transcriptomic datasets comprising 2,917 samples from inflammatory bowel disease (IBD) studies.

## Architecture

### Components

```
IBDTransDB
├── IBDExplore/                      # R Shiny dataset listing interface
│   └── IBDTransDB_Explore.R         # Main dataset browser
├── IBDExplore_Data/                 # R Shiny dataset analysis interface
│   └── IBDTransDB_Dataset.R         # Individual dataset explorer
├── scripts/
│   ├── cli.py                       # Python CLI entry point
│   └── db.py                        # Database connection wrapper
└── data/
    └── IBDTransDB.db                # SQLite database (~2.9 GB)
```

### Deployment

- **R Shiny Apps**: Hosted on shinyapps.io
  - Main URL: https://abbviegrc.shinyapps.io/ibdexplore_data/
- **CLI Tool**: Local Python-based command-line interface

## Data Storage & Format

### Database Technology

**Format**: SQLite database
**Location**: `data/IBDTransDB.db`
**Size**: ~2.9 GB
**Total Samples**: 2,917 across 34 datasets

### Data Sources

- **Primary Repositories**: Gene Expression Omnibus (GEO), ArrayExpress (AE)
- **Curation**: Manually curated transcriptomic datasets
- **Example Dataset**: GSE16879 (used as default demonstration dataset)

### Database Schema

| Table | Description | Record Count |
|-------|-------------|--------------|
| `dataset` | Study metadata (title, disease, organism, platform) | 34 |
| `dataset_data` | Gene expression values (normalized) | 72,166,653 |
| `sample_ann` | Sample annotations (disease, treatment, timepoint) | 2,917 |
| `comparison` | Differential expression comparison definitions | 122 |
| `comparison_data` | DE statistics (logFC, p-value, adjusted p-value) | 3,079,348 |
| `pca` | Principal component coordinates (PC1-PC5) | 2,917 |
| `cell_deconvolution` | Cell type fraction estimates | 144,477 |
| `enrichment_results` | Pathway enrichment results | 226,505 |
| `gene_map` | Gene identifier to symbol mapping | Variable |
| `keyword` | Filter keywords for metadata | Variable |

## How IBDExplore Reads Data

### R/Shiny Data Access

**Connection Method**:
```r
library(RSQLite)
db <- dbConnect(RSQLite::SQLite(), dbname = "./IBDTransDB.db")
```

**Core Query Functions** (located in `IBDExplore/app_functions/`):

| Function | Purpose | Returns |
|----------|---------|---------|
| `get_dataset_description(dataset_acc)` | Retrieve dataset metadata | Title, disease, organism, platform, normalization method |
| `get_exp_data(genes, dataset_id)` | Fetch expression values | Expression matrix (genes × samples) |
| `get_sample_ann(dataset_acc)` | Load sample annotations | Sample metadata with disease, treatment, timepoint |
| `get_comparisons(dataset_acc)` | Get available case vs control comparisons | Comparison definitions with group assignments |
| `get_comparison_data(comparison_id)` | Fetch differential expression results | logFC, p-value, adjusted p-value per gene |
| `get_pca(dataset_acc)` | Retrieve PCA coordinates | PC1-PC5 with variance explained |
| `get_gene_map()` | Gene ID to symbol mapping | ID → symbol lookup table |

### Python CLI Data Access

**Connection Method**:
```python
import sqlite3
import pandas as pd

conn = sqlite3.connect("data/IBDTransDB.db")
df = pd.read_sql_query(sql, conn, params=params)
```

**CLI Commands**:
```bash
# Browse datasets with filters
ibdtransdb datasets list --disease CD --tissue Colon

# Get detailed dataset info
ibdtransdb datasets info GSE16879

# Inspect database schema
ibdtransdb inspect schema

# Run custom SQL queries
ibdtransdb inspect query "SELECT * FROM dataset LIMIT 5"
```

## How IBDExplore Treats Data

### Data Processing Pipeline

```
1. Data Ingestion
   ↓
2. Normalization (pre-processed, stored normalized)
   ↓
3. Sample Annotation Parsing
   ↓
4. Gene Mapping (ID → Symbol)
   ↓
5. Filtering & Transformation
   ↓
6. Visualization & Analysis
```

### Key Processing Steps

#### 1. Sample Annotation Parsing

**Location**: `IBDExplore/app_functions/pca.R` (lines 18-40)

```r
# Split semicolon-separated annotation values
# Match annotations to samples
# Add annotation columns dynamically to analysis data
```

**Process**:
- Annotations stored as semicolon-separated strings (e.g., "CD;Inflamed;Baseline")
- Parsed and split into individual categorical features
- Dynamically added as columns for filtering and coloring in visualizations

#### 2. Gene Identifier Mapping

**Location**: `IBDExplore/app_functions/dataset_database_query.R` (lines 73-97)

```r
# Convert internal gene IDs to human-readable gene symbols
exp_data <- merge(exp_data, gene_map, by = "gene_id")
exp_data <- merge(exp_data, sample_ann, by = "sample_id")
```

**Purpose**:
- Maps database-internal gene IDs to standard gene symbols (HUGO nomenclature)
- Enables user-friendly gene selection and interpretation

#### 3. Expression Data Normalization

**Status**: Pre-normalized before storage
**Methods**: Varies by dataset (RMA, TPM, DESeq2, etc.)
**Storage**: Normalized values stored directly in `dataset_data` table
**No runtime normalization**: Data ready for analysis upon retrieval

#### 4. Differential Expression Filtering

**Location**: `IBDExplore_Data/modules/DGE_viewer.R`

**Filter Criteria**:
```r
# Significance threshold
significant <- p_value <= threshold & abs(log_fc) >= logfc_threshold

# Direction filtering
upregulated <- log_fc > 0 & significant
downregulated <- log_fc < 0 & significant
```

**Parameters**:
- **logFC threshold**: Typically ±0.5 to ±2.0
- **p-value threshold**: Often 0.05
- **Adjusted p-value (FDR)**: For multiple testing correction

#### 5. Statistical Transformations

**For GSEA (Gene Set Enrichment Analysis)**:
```r
# Rank genes by signed -log10(p-value)
rank_metric <- sign(log_fc) * -log10(p_value)
genes_ranked <- genes[order(rank_metric, decreasing = TRUE)]
```

**For Gene Signatures**:
```r
# Average expression across multiple genes
signature_score <- rowMeans(exp_data[, selected_genes])
```

#### 6. Text Formatting for Visualization

**Location**: Various modules

```r
# Wrap sample annotations for plot labels
gsub(";", "; ", annotation_text)  # Add space after semicolon
```

**Purpose**: Improve readability in plots with long annotation strings

### Filtering Capabilities

#### Dataset-Level Filters

**Available Filters** (from `keyword` table):

| Filter Type | Examples |
|------------|----------|
| **Disease** | CD (Crohn's Disease), UC (Ulcerative Colitis), Healthy, Control, nonIBD, IBS |
| **Tissue** | Blood, Colon, Ileum, Rectum |
| **Cell Type** | Tissue-dependent (e.g., Epithelial, Immune cells) |
| **Treatment** | AntiTNF, Infliximab, Golimumab, Ustekinumab, Vedolizumab, Etrolizumab |
| **Timepoint** | Baseline, Week 2, Week 6, Week 14, etc. |

#### Gene-Level Filters

**Methods**:
1. **Manual Selection**: Choose from dropdown of available genes
2. **Gene List Input**: Paste list of gene symbols
3. **Top DE Genes**: Automatically select top 50 differentially expressed genes
4. **Maximum Selection**: Up to 9 genes for simultaneous expression plotting

## Analysis Modules

### 1. Principal Component Analysis (PCA)

**Function**: `get_pca(dataset_acc)`

**Features**:
- Pre-computed PCA coordinates (PC1-PC5)
- Variance explained per component
- Sample annotations integrated for coloring/labeling
- Interactive 2D scatter plots

### 2. Differential Gene Expression (DGE)

**Function**: `get_comparison_data(comparison_id)`

**Features**:
- Volcano plots (logFC vs -log10 p-value)
- MA plots (average expression vs logFC)
- Statistical filtering (p-value, FDR, logFC thresholds)
- Up/down-regulated gene lists

### 3. Gene Expression Viewer

**Function**: `get_exp_data(genes, dataset_id)`

**Features**:
- Box plots of expression per sample group
- Heatmaps for multiple genes
- Sample annotation overlay
- Expression value export

### 4. Gene Signature Analysis

**Features**:
- Input: Custom gene lists or predefined signatures
- Output: Averaged signature scores per sample
- Visualization: Box plots grouped by annotation

### 5. Pathway Enrichment

**Source**: Pre-computed results in `enrichment_results` table

**Features**:
- Over-representation analysis (ORA)
- Gene Set Enrichment Analysis (GSEA)
- Multiple pathway databases (GO, KEGG, Reactome)
- Adjusted p-values (FDR)

### 6. Cell Type Deconvolution

**Source**: Pre-computed results in `cell_deconvolution` table

**Features**:
- Cell type fraction estimates per sample
- Stacked bar plots
- Integration with sample annotations
- Supports multiple deconvolution methods

## Usage Examples

### R Shiny Interface

**Workflow**:
1. Navigate to https://abbviegrc.shinyapps.io/ibdexplore_data/
2. Select dataset from table (filtered by disease, tissue, etc.)
3. Choose analysis type (PCA, DGE, Expression, etc.)
4. Adjust parameters (thresholds, genes, comparisons)
5. Download results or plots

### Python CLI Interface

**Basic Commands**:

```bash
# List all datasets
ibdtransdb datasets list

# Filter datasets by disease
ibdtransdb datasets list --disease CD

# Get detailed info about a specific dataset
ibdtransdb datasets info GSE16879

# Inspect database schema
ibdtransdb inspect schema

# Run custom SQL query
ibdtransdb inspect query "SELECT COUNT(*) FROM dataset"

# Export query results
ibdtransdb inspect query "SELECT * FROM dataset" --output datasets.csv
```

**Programmatic Access** (from Python scripts):

```python
from scripts.db import DatabaseWrapper

# Initialize database connection
db = DatabaseWrapper("data/IBDTransDB.db")

# Query datasets
datasets = db.query("SELECT * FROM dataset WHERE Disease LIKE '%CD%'")

# Get expression data for specific genes
sql = """
SELECT gene_symbol, sample_id, expression_value
FROM dataset_data
JOIN gene_map USING (gene_id)
WHERE dataset_acc = ? AND gene_symbol IN (?, ?, ?)
"""
exp_data = db.query(sql, params=("GSE16879", "TNFA", "IL6", "IL1B"))
```

## Default Dataset: GSE16879

**Hardcoded Location**: `IBDExplore_Data/IBDTransDB_Dataset.R`, line 316

```r
dataset_acc <- "GSE16879"
global_dataset_acc <<- "GSE16879"
```

**Purpose**: Demonstration and testing dataset
**Usage**: Automatically loaded when dataset exploration app starts
**Features**: Available for all analysis modules (PCA, DGE, signatures, enrichment, deconvolution)

## Data Quality & Normalization

### Pre-Processing Standards

- **Expression Values**: Log-transformed and normalized before storage
- **Normalization Methods**: Vary by platform (RMA for microarray, TPM/DESeq2 for RNA-seq)
- **Quality Control**: Manual curation ensures high-quality datasets
- **Missing Values**: Handled during pre-processing; not present in stored data

### Statistical Standards

- **Multiple Testing Correction**: Adjusted p-values (FDR) provided for all DE analyses
- **Effect Size**: LogFC (log2 fold change) reported for all comparisons
- **Sample Size**: Documented in `dataset` table for each study
- **Batch Effects**: Addressed during normalization where applicable

## Technical Specifications

### R Shiny Requirements

```r
# Required packages
library(shiny)
library(RSQLite)
library(DBI)
library(dplyr)
library(ggplot2)
library(plotly)
```

### Python CLI Requirements

```python
# Required packages
import sqlite3
import pandas as pd
import click  # For CLI interface
```

### Performance Considerations

- **Database Size**: 2.9 GB requires sufficient disk space
- **Query Optimization**: Indexed columns for fast filtering
- **Memory Usage**: Expression data loaded on-demand per selected genes
- **Scalability**: SQLite suitable for single-user access; consider PostgreSQL for multi-user deployment

## Future Development

Potential enhancements:
- Cross-dataset meta-analysis capabilities
- Integration with external databases (STRING, BioGRID)
- Machine learning model integration
- Real-time data updates from GEO/ArrayExpress
- Multi-user session management
- API endpoints for programmatic access

## References

- **Database**: IBDTransDB.db (SQLite)
- **Web Interface**: https://abbviegrc.shinyapps.io/ibdexplore_data/
- **CLI Tool**: `scripts/cli.py`
- **Function Library**: `IBDExplore/app_functions/`

## Support

For issues or questions, refer to the main project documentation or contact the development team.

---

**Last Updated**: 2026-01-11
**Version**: 1.0
**Documentation Author**: IBDTransDB Development Team
