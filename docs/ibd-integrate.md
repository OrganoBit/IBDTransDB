# IBDIntegrate System Documentation

## Overview

IBDIntegrate is the data integration and meta-analysis module of IBDTransDB that enables researchers to combine results across multiple datasets, rank therapeutic targets, and perform pathway-level integration. The system integrates 34 manually curated transcriptomic datasets from GEO and ArrayExpress, providing a comprehensive platform for cross-study analysis in inflammatory bowel disease (IBD) research.

## Architecture

### System Components

```
IBDTransDB/
├── IBDIntegrate/                    # Meta-analysis R Shiny interface
│   ├── IBDTransDB_Integrate.R       # Main application
│   ├── app_functions/               # Core integration functions
│   │   ├── target_ranking.R         # Fisher's method meta-analysis
│   │   ├── comparison_options.R     # Comparison selection interface
│   │   ├── data_selection.R         # Dataset filtering
│   │   └── database_query.R         # Query functions
│   ├── enrichment_gene_sets.csv     # KEGG pathway definitions
│   └── gene_groups.csv              # Predefined gene functional groups
├── scripts/                         # Python CLI tools
│   ├── db.py                        # Database connection wrapper
│   ├── cli.py                       # CLI entry point
│   └── commands/                    # CLI command modules
└── data/
    └── IBDTransDB.db                # SQLite database (~2.9 GB)
```

### Database Architecture

**Storage Format**: SQLite (2.9 GB)
**Total Content**:
- 34 datasets
- 2,917 samples
- 53,653 genes
- 72.2M expression data points
- 3.08M differential expression results

## Data Integration Pipeline

### Overview: Raw Data → IBDTransDB

The integration pipeline follows a comprehensive ETL (Extract, Transform, Load) process documented in `docs/dataset-expansion.md`.

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Data Discovery                                           │
│    └─ GEO, ArrayExpress, SRA, dbGaP, Literature            │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. Deduplication Check                                      │
│    └─ SQL query against existing dataset_acc               │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. Data Normalization                                       │
│    ├─ Microarray: RMA, Quantile normalization              │
│    └─ RNA-Seq: DESeq2, TMM (edgeR), TPM/FPKM              │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 4. Gene Symbol Mapping                                      │
│    └─ Standardize to gene_map table identifiers            │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 5. Differential Expression Analysis                         │
│    ├─ Microarray: limma                                     │
│    └─ RNA-Seq: DESeq2, edgeR                               │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 6. Pathway Enrichment (Optional)                            │
│    └─ GSEA for KEGG and Reactome                           │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 7. Quality Control Validation                               │
│    └─ SQL-based QC checks                                   │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 8. SQLite Database Integration                              │
│    └─ Insert into IBDTransDB.db tables                      │
└─────────────────────────────────────────────────────────────┘
```

## Database Schema for Integration

### Core Tables

| Table | Rows | Description |
|-------|------|-------------|
| `dataset` | 34 | Primary metadata for transcriptomic studies |
| `dataset_data` | 72,166,653 | Expression values (gene-sample pairs) |
| `sample_ann` | 2,917 | Sample metadata and annotations |
| `comparison` | 122 | Differential expression comparison definitions |
| `comparison_data` | 3,079,348 | Differential expression results |
| `gene_map` | 53,653 | Gene identifier standardization |
| `keyword` | Variable | Controlled vocabulary for harmonization |
| `database` | 9 | External database references |
| `pca` | 2,917 | Principal component coordinates |
| `cell_deconvolution` | 144,477 | Cell type fraction estimates |
| `enrichment_run` | 244 | Pathway analysis metadata |
| `enrichment_results` | 226,505 | Pathway enrichment statistics |

### Data Relationships

```
dataset (1) ──→ (N) dataset_data
   ↓
   ├──→ (N) sample_ann
   ├──→ (N) comparison
   ├──→ (N) pca
   └──→ (N) cell_deconvolution

comparison (1) ──→ (N) comparison_data
                      ↓
                   enrichment_run (1) ──→ (N) enrichment_results

gene_map (1) ──→ (N) dataset_data
             └──→ (N) comparison_data
```

### Dataset Table Fields

**Primary Keys**:
- `dataset_acc` - GEO/ArrayExpress accession (e.g., GSE16879)
- `dataset_id` - Internal integer ID

**Metadata Fields**:
- `title` - Study title
- `disease` - Disease state(s), semicolon-separated
- `source` - Tissue source(s), semicolon-separated
- `treatment` - Treatment condition(s), semicolon-separated
- `sample_number` - Total sample count
- `organism` - Species (Homo sapiens, Mus musculus)
- `experiment_type` - Microarray or RNASeq
- `platform` - Technology platform
- `normalization_method` - Normalization approach used

## Data Harmonization

### Controlled Vocabulary System

The `keyword` table provides ontology mapping and standardization across datasets.

**Keyword Categories**:

| Type | Examples | Count |
|------|----------|-------|
| Disease | CD, UC, Healthy, Control, nonIBD, IBS | ~10 |
| ExperimentType | Microarray, RNASeq | 2 |
| Source | Blood, Colon, Ileum, Rectum | ~8 |
| CellType | PBMC, Epithelial, T cells | Variable |
| Treatment | Infliximab, Vedolizumab, Ustekinumab, Golimumab | ~15 |
| Timepoint | Week 0, Week 2, Week 6, Week 14 | Variable |

**Keyword Fields**:
- `keyword_type` - Category of controlled term
- `keyword` - Current standardized term
- `old_keyword` - Previous/legacy term for migration
- `synonyms` - Alternative names
- `ontology_id` - External ontology identifier
- `ontology_link` - URL to ontology reference

### Sample Annotation Harmonization

The `sample_ann` table uses flexible key-value pairs for sample metadata.

**Standard Annotation Types**:
- `Disease` - Disease classification
- `Source` - Tissue or cell source
- `Treatment` - Therapeutic intervention
- `Timepoint` - Sampling timepoint
- `Dose` - Drug dosage
- `Activity` - Disease activity score
- `SubjectID` - Patient identifier
- `Age` - Patient age
- `Sex` - Patient sex
- `Response` - Treatment response metrics (e.g., W6_Response, Mayo_Response)

**Format**: Semicolon-separated for multiple values
**Example**: `"CD;Inflamed;Baseline"` → Crohn's Disease, Inflamed tissue, Baseline timepoint

### Gene Symbol Standardization

**Table**: `gene_map` (53,653 genes)

**Purpose**: Central gene identifier mapping to ensure consistency

**Process**:
1. Platform-specific identifiers (probe IDs, Ensembl IDs) collected
2. Mapped to standard gene symbols (HUGO nomenclature)
3. Foreign key referenced by `dataset_data` and `comparison_data`
4. Ensures cross-dataset gene comparability

## Data Ingestion Process

### Step 1: Data Discovery

**Sources**:
- **Gene Expression Omnibus (GEO)** - Primary source
- **ArrayExpress (AE)** - Secondary source
- **SRA** - Sequence Read Archive
- **dbGaP** - Database of Genotypes and Phenotypes
- **Literature mining** - Published studies

**Search Criteria**:
- Inflammatory Bowel Disease (IBD)
- Crohn's Disease (CD)
- Ulcerative Colitis (UC)
- Human or mouse samples
- Transcriptomic data (microarray or RNA-seq)

### Step 2: Deduplication Check

**CLI Command**:
```bash
ibdtransdb inspect query "SELECT dataset_acc, title FROM dataset WHERE dataset_acc = 'GSE######'"
```

**Purpose**: Ensure dataset not already in database

### Step 3: Data Download and Normalization

**Microarray Pipeline**:
```r
# Using affy/limma packages
library(affy)
library(limma)

# Read raw CEL files
raw_data <- ReadAffy()

# RMA normalization
eset <- rma(raw_data)

# Extract expression matrix
expr_matrix <- exprs(eset)
```

**RNA-Seq Pipeline**:
```r
# Using DESeq2
library(DESeq2)

# Create DESeq2 object
dds <- DESeqDataSetFromMatrix(countData = counts,
                               colData = metadata,
                               design = ~ condition)

# Normalization and transformation
dds <- DESeq(dds)
norm_counts <- counts(dds, normalized = TRUE)

# Or use vst/rlog transformation
vsd <- vst(dds)
```

**Supported Normalization Methods**:
- **Microarray**: RMA, Quantile normalization, Background correction
- **RNA-Seq**: DESeq2, TMM (edgeR), TPM, FPKM

### Step 4: Gene Mapping

**Process**:
1. Extract gene identifiers from platform annotation
2. Map to standard gene symbols using Bioconductor annotation packages
3. Handle multiple probes per gene (average or select representative)
4. Insert into `gene_map` table if new symbols

**Example Mapping**:
```
Platform ID → Gene Symbol
1007_s_at → DDR1
1053_at → RFC2
117_at → HSPA6
```

### Step 5: Differential Expression Analysis

**Microarray (limma)**:
```r
library(limma)

# Design matrix
design <- model.matrix(~ 0 + condition, data = metadata)

# Fit linear model
fit <- lmFit(expr_matrix, design)

# Define contrasts
contrast.matrix <- makeContrasts(CD_vs_Control, UC_vs_Control, levels = design)
fit2 <- contrasts.fit(fit, contrast.matrix)

# Empirical Bayes moderation
fit2 <- eBayes(fit2)

# Extract results
results <- topTable(fit2, number = Inf)
```

**RNA-Seq (DESeq2)**:
```r
library(DESeq2)

# DESeq2 analysis
dds <- DESeq(dds)

# Extract results for specific contrast
res <- results(dds, contrast = c("condition", "CD", "Control"))

# Extract logFC, p-value, adjusted p-value
results <- as.data.frame(res)
```

**Stored Metrics**:
- `log_fc` - Log2 fold change
- `p_value` - Raw p-value
- `p_value_adj` - Adjusted p-value (FDR, Benjamini-Hochberg)

### Step 6: Pathway Enrichment (Optional)

**Methods**:
- Gene Set Enrichment Analysis (GSEA)
- Over-representation analysis (ORA)

**Pathway Databases**:
- **KEGG** - Kyoto Encyclopedia of Genes and Genomes
- **Reactome** - Biological pathway database

**Results Stored**:
- `enrichment_results` table
- Normalized Enrichment Score (NES)
- P-values and FDR
- Leading edge genes

### Step 7: Quality Control

**QC Checks** (SQL-based):

```sql
-- Check for missing metadata
SELECT dataset_acc FROM dataset
WHERE disease IS NULL OR source IS NULL;

-- Check for duplicate samples
SELECT dataset_acc, sample_id, COUNT(*)
FROM sample_ann
GROUP BY dataset_acc, sample_id
HAVING COUNT(*) > 1;

-- Check gene mapping completeness
SELECT DISTINCT d.gene
FROM dataset_data d
LEFT JOIN gene_map g ON d.gene = g.id
WHERE g.id IS NULL;

-- Verify sample counts match metadata
SELECT d.dataset_acc, d.sample_number,
       COUNT(DISTINCT s.sample_id) as actual_samples
FROM dataset d
LEFT JOIN sample_ann s ON d.dataset_acc = s.dataset_acc
GROUP BY d.dataset_acc
HAVING d.sample_number != actual_samples;

-- Check p-value distribution
SELECT comparison_id, COUNT(*) as total_genes,
       SUM(CASE WHEN p_value_adj < 0.05 THEN 1 ELSE 0 END) as sig_genes
FROM comparison_data
GROUP BY comparison_id;

-- Check for extreme outliers in expression data
SELECT dataset_acc, gene, MAX(expression_value) as max_expr
FROM dataset_data
GROUP BY dataset_acc, gene
HAVING max_expr > 20;  -- For log2 scale
```

### Step 8: Database Integration

**File Organization for New Dataset**:
```
new_dataset_GSE#####/
├── dataset_metadata.csv       # Single row for dataset table
├── sample_annotations.csv     # Rows for sample_ann table
├── expression_data.csv        # Rows for dataset_data table
├── comparisons.csv            # Rows for comparison table
├── comparison_results.csv     # Rows for comparison_data table
└── enrichment_results.csv     # Rows for enrichment_results table (optional)
```

**SQL Insertion**:
```sql
-- Insert dataset metadata
INSERT INTO dataset (dataset_acc, title, disease, source, ...)
VALUES ('GSE#####', 'Study title', 'CD;UC', 'Colon;Ileum', ...);

-- Insert sample annotations
INSERT INTO sample_ann (dataset_acc, sample_id, annotation_type, annotation_value)
SELECT dataset_acc, sample_id, annotation_type, annotation_value
FROM temp_sample_ann;

-- Insert expression data
INSERT INTO dataset_data (dataset_id, gene, sample_id, expression_value)
SELECT dataset_id, gene_id, sample_id, expression_value
FROM temp_expression_data
JOIN gene_map ON temp_expression_data.gene_symbol = gene_map.symbol;

-- Insert comparisons
INSERT INTO comparison (dataset_id, case_ann, control_ann, ...)
SELECT dataset_id, case_ann, control_ann, ...
FROM temp_comparisons;

-- Insert comparison results
INSERT INTO comparison_data (comparison_id, gene, log_fc, p_value, p_value_adj)
SELECT comparison_id, gene_id, log_fc, p_value, p_value_adj
FROM temp_comparison_results
JOIN gene_map ON temp_comparison_results.gene_symbol = gene_map.symbol;
```

## External Database Integration

### Integrated Databases

The `database` table references 9 external databases:

| Database | URL | Purpose |
|----------|-----|---------|
| **NCBI** | http://www.ncbi.nlm.nih.gov | Gene information, GEO data source |
| **GO** | http://amigo.geneontology.org | Biological process, molecular function ontologies |
| **KEGG** | https://www.genome.jp | Pathway enrichment (122 runs) |
| **Reactome** | https://reactome.org | Pathway analysis (122 runs) |
| **Drug Target Commons** | http://drugtargetcommons.fimm.fi | Target discovery |
| **TTD** | http://db.idrblab.net/ttd | Therapeutic targets |
| **DrugBank** | https://go.drugbank.com | Drug-target interactions |
| **ChEMBL** | https://www.ebi.ac.uk/chembl | Bioactivity data |
| **PharmGKB** | https://www.pharmgkb.org | Pharmacogenomics |

### WebGestalt Integration

**Tool**: WebGestalt (https://www.webgestalt.org/)

**Purpose**: Interactive pathway enrichment visualization

**Integration Points**:
- Used in IBDCompare and IBDIntegrate R Shiny modules
- Provides enrichment visualization for KEGG and Reactome pathways
- Integrated in `enrichment.R` modules

## Batch Processing Tools

### Python CLI Tools

**Installation**:
```bash
# From project root
pip install -e .

# Or install dependencies manually
pip install typer rich pandas
```

**Core Module**: `scripts/db.py`

```python
class IBDTransDB:
    """Database connection and query utilities"""

    def __init__(self, db_path: str):
        self.conn = sqlite3.connect(db_path)

    def query(self, sql: str, params: tuple = None) -> list:
        """Execute SQL query, return list of dicts"""

    def query_df(self, sql: str, params: tuple = None) -> pd.DataFrame:
        """Execute SQL query, return pandas DataFrame"""

    def get_table_names(self) -> list:
        """List all tables in database"""

    def get_table_info(self, table: str) -> pd.DataFrame:
        """Get column information for table"""

    def get_row_count(self, table: str) -> int:
        """Get total row count for table"""
```

### CLI Commands

**Dataset Operations** (`commands/datasets.py`):

```bash
# List all datasets
ibdtransdb datasets list

# Filter datasets by criteria
ibdtransdb datasets list --disease UC --tissue Colon --format json

# Get detailed info for specific dataset
ibdtransdb datasets info GSE16879

# Show available filter options
ibdtransdb datasets filters

# Export to CSV
ibdtransdb datasets list --output datasets.csv
```

**Database Inspection** (`commands/inspect.py`):

```bash
# Database statistics
ibdtransdb inspect stats

# Table schema
ibdtransdb inspect schema dataset

# Custom SQL query
ibdtransdb inspect query "SELECT * FROM dataset WHERE disease LIKE '%UC%'"

# Query with output to file
ibdtransdb inspect query "SELECT * FROM dataset" --output results.csv
```

### R-Based Batch Operations

**Location**: `IBDIntegrate/app_functions/`

**Key Functions**:

1. **data_selection.R**:
   - `generate_dataset_table()` - Creates interactive dataset selection table
   - `generate_comparison_table()` - Creates comparison selection interface
   - `format_comparison()` - Harmonizes comparison annotations

2. **database_query.R**:
   - `get_keywords()` - Fetch controlled vocabulary
   - `format_query_ExactMatch()` - Exact string matching queries
   - `format_query_SoftMatch()` - Pattern matching (LIKE queries)
   - `get_datasets()` - Batch dataset retrieval with filters

3. **target_ranking.R**:
   - `rank_targets()` - Gene-level meta-analysis
   - `rank_signature()` - Signature-based integration
   - `rank_pathways()` - Pathway-level integration

## Meta-Analysis Capabilities

### Fisher's Method Implementation

**Function**: `rank_targets()` in `target_ranking.R`

**Algorithm**:
```r
# Convert two-tailed p-values to one-tailed
one_tailed_upreg <- function(p_value, log_fc) {
  ifelse(log_fc > 0, p_value / 2, 1 - p_value / 2)
}

one_tailed_downreg <- function(p_value, log_fc) {
  ifelse(log_fc < 0, p_value / 2, 1 - p_value / 2)
}

# Apply Fisher's method using poolr package
library(poolr)
meta_p_upreg <- fisher(one_tailed_upreg_pvalues)$p
meta_p_downreg <- fisher(one_tailed_downreg_pvalues)$p

# Select more significant direction
meta_p <- pmin(meta_p_upreg, meta_p_downreg)
direction <- ifelse(meta_p_upreg < meta_p_downreg, "up", "down")

# Apply Benjamini-Hochberg correction
meta_p_adj <- p.adjust(meta_p, method = "BH")
```

**Output Metrics**:
1. `meta_p_value` - Fisher's combined p-value
2. `meta_p_adj` - Benjamini-Hochberg adjusted p-value
3. `mean_logFC` - Average log fold change across comparisons
4. `direction` - Regulation direction ("up" or "down")
5. `n_comparisons` - Number of comparisons supporting the target
6. `n_datasets` - Number of unique datasets

**Parallel Processing**: 8-core parallelization via `mclapply` for performance

### Signature-Based Integration

**Function**: `rank_signature()` in `target_ranking.R`

**Method**: Wilcoxon rank sum test on signature scores

**Process**:
1. Calculate signature score per sample (mean expression of signature genes)
2. Compare case vs. control groups using Wilcoxon test
3. Test alternative hypotheses: "two.sided", "greater", "less"
4. Combine p-values using Fisher's method
5. Apply FDR correction

### Pathway-Level Integration

**Function**: `rank_pathways()` in `target_ranking.R`

**Method**: Meta-analysis of enrichment scores

**Process**:
1. Retrieve pre-computed enrichment results from database
2. Extract Normalized Enrichment Scores (NES) and p-values
3. Apply Fisher's method to combine p-values across datasets
4. Rank pathways by meta p-value
5. Filter by significance threshold

## Configuration Files

### Pathway Definitions

**File**: `IBDIntegrate/enrichment_gene_sets.csv`

**Format**:
```csv
pathway_id,pathway_name,genes
hsa04060,Cytokine-cytokine receptor interaction,"TNF;IL1A;IL1B;IL6;..."
hsa04657,IL-17 signaling pathway,"IL17A;IL17F;TNF;CXCL1;..."
...
```

**Content**: 20+ KEGG pathways relevant to IBD

### Gene Functional Groups

**File**: `IBDIntegrate/gene_groups.csv`

**Format**:
```csv
group_name,genes
chemokine,"CCL1;CCL2;CCL3;CCL3L1;CCL4;CCL5;CXCL1;CXCL2;CXCL3;..."
interleukin,"IL1A;IL1B;IL2;IL4;IL6;IL10;IL12A;IL12B;IL13;IL17A;..."
TNF_superfamily,"TNF;TNFSF4;TNFSF8;TNFSF10;TNFSF13;TNFSF13B;..."
```

**Purpose**: Predefined gene signatures for common analyses

### Python Configuration

**File**: `pyproject.toml`

```toml
[project]
name = "ibdtransdb-cli"
version = "0.1.0"
description = "CLI tool for IBDTransDB"
requires-python = ">=3.9"
dependencies = [
    "typer>=0.12.0",
    "rich>=13.7.0",
    "pandas>=2.0.0",
]

[project.scripts]
ibdtransdb = "scripts.cli:app"

[build-system]
requires = ["setuptools>=65.0"]
build-backend = "setuptools.build_meta"
```

### R Package Dependencies

**Core Packages** (from `setup-instruction.md`):

**Shiny Framework**:
- shiny, shinyWidgets, shinyBS, shinybusy, shinyalert
- shinydashboard, shinydashboardPlus, shinyjs

**Database**:
- RSQLite, DBI

**Data Manipulation**:
- dplyr, tidyr, stringr

**Visualization**:
- ggplot2, RColorBrewer, gridExtra

**Statistical**:
- poolr (for Fisher's method)
- stats

**Tables**:
- DT, reactable, kableExtra

## Database Deployment

### Download Location

**iCloud Storage**:
https://www.icloud.com/iclouddrive/013D9ewhOhNjj-5tErDEWnhow#IBDTransDB

**File**: IBDTransDB.db (~2.9 GB)

### Installation Paths

**For Python CLI**:
```bash
# Place database in data directory
mkdir -p data
cp IBDTransDB.db data/
```

**For R Shiny Apps**:
```bash
# Each module needs its own copy
cp IBDTransDB.db IBDTransDB_Home/
cp IBDTransDB.db IBDCompare/
cp IBDTransDB.db IBDExplore/
cp IBDTransDB.db IBDExplore_Data/
cp IBDTransDB.db IBDIntegrate/
```

**Alternative**: Use symbolic links to save space
```bash
# Create symlink instead of copying
cd IBDIntegrate/
ln -s ../data/IBDTransDB.db IBDTransDB.db
```

## Usage Examples

### Python CLI: Batch Data Extraction

```python
from scripts.db import IBDTransDB
import pandas as pd

# Initialize database
db = IBDTransDB("data/IBDTransDB.db")

# Extract all CD datasets
datasets = db.query_df("""
    SELECT dataset_acc, title, organism, experiment_type, source
    FROM dataset
    WHERE disease LIKE '%CD%'
""")

# Get expression data for specific genes across all samples
genes_of_interest = ["TNF", "IL6", "IL1B"]
sql = """
SELECT d.dataset_acc, gm.symbol as gene, dd.sample_id, dd.expression_value
FROM dataset_data dd
JOIN gene_map gm ON dd.gene = gm.id
JOIN dataset d ON dd.dataset_id = d.dataset_id
WHERE gm.symbol IN (?, ?, ?)
"""
expression_data = db.query_df(sql, params=tuple(genes_of_interest))

# Export to CSV
expression_data.to_csv("tnf_il_expression.csv", index=False)
```

### R Shiny: Meta-Analysis Workflow

```r
# Load required libraries
library(RSQLite)
library(dplyr)
library(poolr)

# Connect to database
db <- dbConnect(RSQLite::SQLite(), "IBDTransDB.db")

# Get all UC vs Healthy comparisons in colon tissue
comparisons <- dbGetQuery(db, "
    SELECT c.comparison_id, d.dataset_acc
    FROM comparison c
    JOIN dataset d ON c.dataset_id = d.dataset_id
    WHERE d.disease LIKE '%UC%'
      AND d.source LIKE '%Colon%'
      AND c.case_ann LIKE '%UC%'
      AND c.control_ann LIKE '%Healthy%'
")

# Extract comparison results for gene of interest
gene_results <- dbGetQuery(db, "
    SELECT cd.comparison_id, cd.log_fc, cd.p_value, gm.symbol
    FROM comparison_data cd
    JOIN gene_map gm ON cd.gene = gm.id
    WHERE cd.comparison_id IN (?)
      AND gm.symbol = 'TNF'
", params = list(paste(comparisons$comparison_id, collapse = ",")))

# Perform meta-analysis using Fisher's method
p_values <- gene_results$p_value
fisher_result <- fisher(p_values)

cat("Meta p-value for TNF:", fisher_result$p, "\n")
cat("Mean logFC:", mean(gene_results$log_fc), "\n")
```

## Performance Considerations

### Database Optimization

**Indexing Strategy**:
- Primary keys: `dataset_id`, `comparison_id`, `gene`
- Foreign keys indexed for fast joins
- `dataset_acc` indexed for quick lookup

**Query Performance**:
- Expression data queries: Fast for gene-specific queries, slower for genome-wide
- Comparison data: Optimized for filtering by p-value and logFC
- Sample annotations: Indexed by dataset_acc and sample_id

### Memory Management

**Considerations**:
- Database size: 2.9 GB (ensure sufficient disk space)
- R Shiny: Load data on-demand, not all at once
- Python: Use `query_df()` for large result sets (pandas optimized)
- Parallel processing: `mclapply` with 8 cores for meta-analysis

### Scalability

**Current System**: Single-user, SQLite backend
**Future Enhancements**:
- PostgreSQL for multi-user deployment
- Database sharding for larger datasets
- API endpoints for programmatic access
- Caching layer for frequent queries

## Future Development

### Planned Enhancements

1. **Automated Data Updates**
   - Periodic GEO/ArrayExpress queries for new datasets
   - Automated ETL pipeline execution

2. **Enhanced Integration**
   - Single-cell RNA-seq datasets
   - Proteomics data integration
   - Microbiome data

3. **Advanced Meta-Analysis**
   - Random effects models
   - Heterogeneity assessment (I² statistic)
   - Publication bias analysis (funnel plots)

4. **Machine Learning Integration**
   - Predictive models for treatment response
   - Biomarker discovery algorithms
   - Network-based target prioritization

5. **API Development**
   - RESTful API for programmatic access
   - GraphQL endpoints for flexible queries
   - Batch data export functionality

## References

- **Database**: `data/IBDTransDB.db`
- **Documentation**: `docs/dataset-expansion.md`, `docs/overview.md`
- **Web Interface**: https://abbviegrc.shinyapps.io/ibdexplore_data/
- **CLI Tool**: `scripts/cli.py`
- **Meta-Analysis Module**: `IBDIntegrate/app_functions/target_ranking.R`

## Support

For integration questions or to contribute new datasets, refer to `docs/dataset-expansion.md` for detailed instructions.

---

**Last Updated**: 2026-01-12
**Version**: 1.0
**Documentation Author**: IBDTransDB Development Team
