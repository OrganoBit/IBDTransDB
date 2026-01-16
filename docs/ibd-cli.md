# IBDTransDB CLI Documentation

## Overview

The `ibdtransdb` command-line interface (CLI) is a Python-based tool for exploring and querying the IBDTransDB SQLite database. It provides a user-friendly interface for browsing datasets, inspecting database schema, running custom SQL queries, and exporting data in multiple formats (table, CSV, JSON).

Built with **Typer** for command handling and **Rich** for beautiful terminal output, the CLI offers an intuitive alternative to direct SQL queries or the R Shiny web interface.

## Features

- **Dataset Browsing**: Filter and explore 34 IBD transcriptomic datasets
- **Database Inspection**: View tables, schemas, and statistics
- **Custom SQL Queries**: Execute arbitrary SQL with formatted output
- **Multiple Output Formats**: Table (default), CSV, and JSON
- **Rich Terminal Display**: Color-coded, formatted tables for readability
- **Context Management**: Automatic database connection handling
- **Configurable Database Path**: Override default database location

## Architecture

### Project Structure

```
IBDTransDB/
├── scripts/
│   ├── __init__.py
│   ├── cli.py                       # Main CLI entry point
│   ├── db.py                        # Database connection wrapper
│   ├── commands/
│   │   ├── __init__.py
│   │   ├── datasets.py              # Dataset browsing commands
│   │   └── inspect.py               # Database inspection commands
│   └── utils/
│       ├── __init__.py
│       └── formatters.py            # Output formatting utilities
├── data/
│   └── IBDTransDB.db                # SQLite database (~2.9 GB)
└── pyproject.toml                   # Project configuration
```

### Technology Stack

| Component | Library | Version | Purpose |
|-----------|---------|---------|---------|
| **CLI Framework** | Typer | ≥0.12.0 | Command-line interface creation |
| **Terminal UI** | Rich | ≥13.7.0 | Beautiful formatted terminal output |
| **Data Handling** | Pandas | ≥2.0.0 | DataFrame manipulation and export |
| **Database** | sqlite3 | Built-in | SQLite database connectivity |
| **Python** | Python | ≥3.9 | Required Python version |

### Core Classes

#### IBDTransDB Class

**File**: `scripts/db.py`

```python
class IBDTransDB:
    """Database connection wrapper for IBDTransDB SQLite database"""

    def __init__(self, db_path: Path):
        """Initialize with path to IBDTransDB.db"""

    def __enter__(self):
        """Context manager entry: Open database connection"""

    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit: Close database connection"""

    def query(self, sql: str, params: tuple = ()) -> List[Dict[str, Any]]:
        """Execute SQL query and return results as list of dicts"""

    def query_df(self, sql: str, params: tuple = ()) -> pd.DataFrame:
        """Execute SQL query and return pandas DataFrame"""

    def get_table_names(self) -> List[str]:
        """Get all table names in the database"""

    def get_table_info(self, table_name: str) -> List[Dict[str, Any]]:
        """Get column information for a specific table"""

    def get_row_count(self, table_name: str) -> int:
        """Get row count for a specific table"""
```

**Usage Pattern**:
```python
from scripts.db import IBDTransDB

with IBDTransDB("data/IBDTransDB.db") as db:
    results = db.query("SELECT * FROM dataset LIMIT 10")
    df = db.query_df("SELECT * FROM gene_map WHERE symbol LIKE 'TNF%'")
```

**Features**:
- Context manager support (`with` statement)
- Automatic connection handling
- Results as dicts or pandas DataFrames
- Parameterized queries for safety
- Schema inspection utilities

## Installation

### Prerequisites

- **Python**: Version 3.9 or higher
- **pip**: Python package installer
- **IBDTransDB.db**: Downloaded database file (~2.9 GB)

### Step 1: Download Database

Download the database from iCloud:
```
https://www.icloud.com/iclouddrive/013D9ewhOhNjj-5tErDEWnhow#IBDTransDB
```

Place the file in the `data/` directory:
```bash
mkdir -p data
mv ~/Downloads/IBDTransDB.db data/
```

### Step 2: Create Virtual Environment

```bash
# Navigate to project directory
cd /path/to/IBDTransDB

# Create virtual environment
python -m venv .venv

# Activate virtual environment
source .venv/bin/activate  # Unix/Mac
# OR
.venv\Scripts\activate  # Windows
```

### Step 3: Install CLI Tool

**Option A: Editable Install (Recommended for Development)**
```bash
pip install -e .
```

**Option B: Standard Install**
```bash
pip install .
```

**Option C: Install Dependencies Manually**
```bash
pip install typer>=0.12.0 rich>=13.7.0 pandas>=2.0.0
```

### Step 4: Verify Installation

```bash
ibdtransdb --help
```

Expected output:
```
Usage: ibdtransdb [OPTIONS] COMMAND [ARGS]...

  IBDTransDB CLI - Explore transcriptomic data for IBD research

Options:
  -d, --db PATH  Path to IBDTransDB.db file
  --help         Show this message and exit.

Commands:
  datasets  Browse and filter datasets
  inspect   Inspect database schema and run SQL
```

## Command Reference

### Global Options

The CLI supports global options that apply to all commands:

```bash
ibdtransdb [GLOBAL OPTIONS] COMMAND [COMMAND OPTIONS]
```

**Global Options**:

| Option | Alias | Description | Default |
|--------|-------|-------------|---------|
| `--db PATH` | `-d` | Path to IBDTransDB.db file | `data/IBDTransDB.db` |
| `--help` | | Show help message | |

**Examples**:
```bash
# Use default database path
ibdtransdb datasets list

# Use custom database path
ibdtransdb --db /path/to/IBDTransDB.db datasets list

# Short alias
ibdtransdb -d ~/databases/IBDTransDB.db inspect stats
```

### Command Structure

```
ibdtransdb
├── datasets                  # Dataset browsing commands
│   ├── list                  # List datasets with filters
│   ├── info                  # Get detailed dataset information
│   └── filters               # Show available filter options
└── inspect                   # Database inspection commands
    ├── tables                # List all tables with row counts
    ├── schema                # Show schema for a table
    ├── query                 # Run custom SQL query
    └── stats                 # Show database statistics
```

## Datasets Commands

### `datasets list`

List all datasets with optional filtering.

**Syntax**:
```bash
ibdtransdb datasets list [OPTIONS]
```

**Options**:

| Option | Alias | Type | Description |
|--------|-------|------|-------------|
| `--disease` | `-D` | Multiple | Filter by disease (CD, UC, Healthy, etc.) |
| `--tissue` | `-t` | Multiple | Filter by tissue/source (Blood, Colon, Ileum, Rectum) |
| `--treatment` | `-T` | Multiple | Filter by treatment (Infliximab, Vedolizumab, etc.) |
| `--format` | `-f` | String | Output format: table, csv, json (default: table) |

**Examples**:

```bash
# List all datasets (table format)
ibdtransdb datasets list

# Filter by disease
ibdtransdb datasets list --disease CD
ibdtransdb datasets list --disease UC

# Filter by multiple criteria
ibdtransdb datasets list --disease UC --tissue Colon

# Multiple diseases
ibdtransdb datasets list --disease CD --disease UC

# Export to CSV
ibdtransdb datasets list --format csv > datasets.csv

# Export to JSON
ibdtransdb datasets list --disease CD --format json > cd_datasets.json
```

**Output Columns**:
- `dataset_acc` - Dataset accession (e.g., GSE16879)
- `title` - Study title
- `disease` - Disease classification
- `source` - Tissue source
- `treatment` - Treatment condition
- `organism` - Species (Homo sapiens, Mus musculus)
- `sample_number` - Total sample count

**Sample Output**:
```
┏━━━━━━━━━━━━┳━━━━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━┳━━━━━━━━━━━┳━━━━━━━━━━━━━━┳━━━━━━━━━━━━━━┓
┃ dataset_acc┃ title                 ┃ disease  ┃ source ┃ treatment ┃ organism     ┃ sample_number┃
┡━━━━━━━━━━━━╇━━━━━━━━━━━━━━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━╇━━━━━━━━━━━╇━━━━━━━━━━━━━━╇━━━━━━━━━━━━━━┩
│ GSE16879   │ Ulcerative colitis... │ UC       │ Colon  │ None      │ Homo sapiens │ 42           │
│ GSE3365    │ Gene expression in... │ CD;UC    │ Ileum  │ None      │ Homo sapiens │ 36           │
│ GSE4183    │ Inflamed and non-...  │ UC       │ Rectum │ None      │ Homo sapiens │ 27           │
└────────────┴───────────────────────┴──────────┴────────┴───────────┴──────────────┴──────────────┘
```

### `datasets info`

Get detailed information about a specific dataset.

**Syntax**:
```bash
ibdtransdb datasets info DATASET_ACC [OPTIONS]
```

**Arguments**:
- `DATASET_ACC` - Dataset accession (e.g., GSE16879)

**Options**:
- `--format`, `-f` - Output format: table, csv, json (default: table)

**Examples**:

```bash
# Get info for specific dataset
ibdtransdb datasets info GSE16879

# Export to JSON
ibdtransdb datasets info GSE16879 --format json

# Export to CSV
ibdtransdb datasets info GSE3365 --format csv > GSE3365_info.csv
```

**Output Fields**:
- All fields from `dataset` table
- `sample_count` - Actual sample count from `sample_ann` table
- `comparison_count` - Number of comparisons for this dataset

**Sample Output**:
```
┏━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃ Field              ┃ Value                                           ┃
┡━━━━━━━━━━━━━━━━━━━━╇━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┩
│ dataset_acc        │ GSE16879                                        │
│ dataset_id         │ 12                                              │
│ title              │ Ulcerative colitis gene expression profiling   │
│ disease            │ UC                                              │
│ source             │ Colon                                           │
│ treatment          │ None                                            │
│ organism           │ Homo sapiens                                    │
│ experiment_type    │ Microarray                                      │
│ platform           │ Affymetrix HG-U133 Plus 2.0                     │
│ normalization_...  │ RMA                                             │
│ sample_number      │ 42                                              │
│ sample_count       │ 42                                              │
│ comparison_count   │ 3                                               │
└────────────────────┴─────────────────────────────────────────────────┘
```

### `datasets filters`

Show all available filter options (diseases, tissues, treatments).

**Syntax**:
```bash
ibdtransdb datasets filters
```

**No Options or Arguments**

**Example**:
```bash
ibdtransdb datasets filters
```

**Sample Output**:
```
Available Diseases:
  • CD
  • UC
  • Healthy
  • Control
  • nonIBD
  • IBS
  • CD;UC
  • UC;Healthy

Available Tissues/Sources:
  • Blood
  • Colon
  • Ileum
  • Rectum
  • Colon;Ileum
  • Blood;PBMC

Available Treatments:
  • None
  • Infliximab
  • Vedolizumab
  • Ustekinumab
  • Golimumab
  • AntiTNF
  • Etrolizumab
  • IL17A_treatment
  • TNF_treatment
```

## Inspect Commands

### `inspect tables`

List all tables in the database with row counts.

**Syntax**:
```bash
ibdtransdb inspect tables
```

**No Options or Arguments**

**Example**:
```bash
ibdtransdb inspect tables
```

**Sample Output**:
```
                    IBDTransDB Tables
┏━━━━━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━━━━┓
┃ Table Name             ┃   Row Count ┃
┡━━━━━━━━━━━━━━━━━━━━━━━━╇━━━━━━━━━━━━━┩
│ cell_deconvolution     │     144,477 │
│ comparison             │         122 │
│ comparison_data        │   3,079,348 │
│ database               │           9 │
│ dataset                │          34 │
│ dataset_data           │  72,166,653 │
│ enrichment_leading_... │     596,832 │
│ enrichment_results     │     226,505 │
│ enrichment_run         │         244 │
│ gene_map               │      53,653 │
│ keyword                │         150 │
│ pca                    │       2,917 │
│ sample_ann             │       2,917 │
└────────────────────────┴─────────────┘
```

### `inspect schema`

Show schema (columns) for a specific table.

**Syntax**:
```bash
ibdtransdb inspect schema TABLE_NAME
```

**Arguments**:
- `TABLE_NAME` - Name of the table to inspect

**Examples**:

```bash
# View dataset table schema
ibdtransdb inspect schema dataset

# View comparison table schema
ibdtransdb inspect schema comparison

# View gene_map table schema
ibdtransdb inspect schema gene_map
```

**Sample Output**:
```
                    Schema: dataset
┏━━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━━━━┓
┃ Column              ┃ Type    ┃ Not Null ┃ Primary Key ┃
┡━━━━━━━━━━━━━━━━━━━━━╇━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━━━━┩
│ dataset_id          │ INTEGER │ ✓        │ ✓           │
│ dataset_acc         │ TEXT    │ ✓        │             │
│ title               │ TEXT    │          │             │
│ disease             │ TEXT    │          │             │
│ source              │ TEXT    │          │             │
│ treatment           │ TEXT    │          │             │
│ organism            │ TEXT    │          │             │
│ experiment_type     │ TEXT    │          │             │
│ platform            │ TEXT    │          │             │
│ normalization_...   │ TEXT    │          │             │
│ sample_number       │ INTEGER │          │             │
└─────────────────────┴─────────┴──────────┴─────────────┘
```

### `inspect query`

Run a custom SQL query.

**Syntax**:
```bash
ibdtransdb inspect query "SQL_QUERY" [OPTIONS]
```

**Arguments**:
- `SQL_QUERY` - SQL query string (must be quoted)

**Options**:

| Option | Alias | Type | Description |
|--------|-------|------|-------------|
| `--format` | `-f` | String | Output format: table, csv, json (default: table) |
| `--limit` | `-l` | Integer | Limit results (default: 100) |

**Features**:
- Automatic `LIMIT` clause added to SELECT queries (if not present)
- Parameterized queries supported for safety
- Error handling with clear messages
- Supports all SQL operations (SELECT, JOIN, etc.)

**Examples**:

```bash
# Simple SELECT
ibdtransdb inspect query "SELECT * FROM dataset WHERE disease = 'UC'"

# COUNT query
ibdtransdb inspect query "SELECT COUNT(*) FROM gene_map"

# JOIN query
ibdtransdb inspect query "SELECT d.dataset_acc, COUNT(*) as sample_count
  FROM dataset d
  JOIN sample_ann s ON d.dataset_acc = s.dataset_acc
  GROUP BY d.dataset_acc"

# Export to CSV
ibdtransdb inspect query "SELECT * FROM dataset" --format csv > all_datasets.csv

# Export to JSON with custom limit
ibdtransdb inspect query "SELECT * FROM comparison" --format json --limit 50 > comparisons.json

# Gene search
ibdtransdb inspect query "SELECT * FROM gene_map WHERE symbol LIKE 'TNF%'"

# Differential expression results
ibdtransdb inspect query "SELECT gm.symbol, cd.log_fc, cd.p_value
  FROM comparison_data cd
  JOIN gene_map gm ON cd.gene = gm.id
  WHERE cd.comparison_id = 1 AND cd.p_value < 0.05
  ORDER BY cd.p_value LIMIT 20"
```

**Notes**:
- Queries are read-only (no INSERT, UPDATE, DELETE)
- Use double quotes around entire query
- Single quotes for SQL string literals inside query
- LIMIT automatically added to prevent overwhelming output

### `inspect stats`

Show database statistics summary.

**Syntax**:
```bash
ibdtransdb inspect stats
```

**No Options or Arguments**

**Example**:
```bash
ibdtransdb inspect stats
```

**Sample Output**:
```
                  IBDTransDB Statistics
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━━━━┓
┃ Metric                          ┃       Count ┃
┡━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╇━━━━━━━━━━━━━┩
│ Datasets                        │          34 │
│ Comparisons                     │         122 │
│ Genes                           │      53,653 │
│ Samples                         │       2,917 │
│ Expression Data Points          │  72,166,653 │
│ Differential Expression Results │   3,079,348 │
│ Enrichment Results              │     226,505 │
└─────────────────────────────────┴─────────────┘
```

**Metrics Explained**:
- **Datasets**: Total number of studies in database
- **Comparisons**: Total differential expression comparisons
- **Genes**: Unique genes in gene_map table
- **Samples**: Unique samples across all datasets
- **Expression Data Points**: Total gene-sample expression values
- **Differential Expression Results**: Total DE statistics (logFC, p-values)
- **Enrichment Results**: Total pathway enrichment results

## Output Formats

All commands that return data support three output formats via the `--format` flag:

### Table Format (Default)

**Usage**: `--format table` or omit flag

**Features**:
- Beautifully formatted terminal tables using Rich library
- Color-coded columns for readability
- Automatically sized columns
- Limited to 100 rows for display (full data in CSV/JSON)

**Best For**:
- Interactive exploration
- Quick data inspection
- Terminal-based workflows

**Example**:
```bash
ibdtransdb datasets list --format table
```

### CSV Format

**Usage**: `--format csv`

**Features**:
- Standard comma-separated values
- Headers included as first row
- No row limits (full data)
- Easy to redirect to files

**Best For**:
- Data export for Excel/spreadsheet analysis
- Piping to other CLI tools
- Programmatic processing

**Example**:
```bash
# Export to file
ibdtransdb datasets list --format csv > datasets.csv

# Pipe to grep
ibdtransdb inspect query "SELECT * FROM dataset" --format csv | grep "UC"

# Import to pandas
ibdtransdb datasets list --format csv | python -c "
import pandas as pd
import sys
df = pd.read_csv(sys.stdin)
print(df.describe())
"
```

### JSON Format

**Usage**: `--format json`

**Features**:
- Structured JSON array of objects
- Indented for readability
- No row limits (full data)
- Type-safe (preserves integers, nulls, etc.)

**Best For**:
- API integration
- JavaScript/web application consumption
- Complex data structures
- Programmatic processing with type safety

**Example**:
```bash
# Export to file
ibdtransdb datasets list --format json > datasets.json

# Pipe to jq for processing
ibdtransdb inspect stats --format json | jq '.[0]'

# Use in Python
python << EOF
import json
import subprocess

result = subprocess.run(
    ["ibdtransdb", "datasets", "list", "--format", "json"],
    capture_output=True,
    text=True
)
datasets = json.loads(result.stdout)
print(f"Found {len(datasets)} datasets")
EOF
```

## Usage Examples

### Example 1: Dataset Discovery

Explore what datasets are available in the database.

```bash
# Step 1: Check database statistics
ibdtransdb inspect stats

# Step 2: See available filter options
ibdtransdb datasets filters

# Step 3: Find Crohn's Disease studies
ibdtransdb datasets list --disease CD

# Step 4: Find UC studies in colon tissue
ibdtransdb datasets list --disease UC --tissue Colon

# Step 5: Get detailed info for specific dataset
ibdtransdb datasets info GSE16879
```

### Example 2: Gene Expression Analysis

Extract expression data for genes of interest.

```bash
# Find genes of interest
ibdtransdb inspect query "
  SELECT id, symbol, description
  FROM gene_map
  WHERE symbol IN ('TNF', 'IL6', 'IL1B')
"

# Get differential expression results
ibdtransdb inspect query "
  SELECT
    gm.symbol,
    cd.log_fc,
    cd.p_value,
    cd.p_value_adj,
    c.case_ann,
    c.control_ann,
    d.dataset_acc
  FROM comparison_data cd
  JOIN gene_map gm ON cd.gene = gm.id
  JOIN comparison c ON cd.comparison_id = c.comparison_id
  JOIN dataset d ON c.dataset_id = d.dataset_id
  WHERE gm.symbol = 'TNF'
    AND cd.p_value_adj < 0.05
  ORDER BY cd.p_value_adj
" --format table
```

### Example 3: Data Export Pipeline

Export filtered data for downstream analysis.

```bash
# Export UC colon datasets to CSV
ibdtransdb datasets list \
  --disease UC \
  --tissue Colon \
  --format csv > uc_colon_datasets.csv

# Export all comparisons for these datasets
ibdtransdb inspect query "
  SELECT c.*, d.dataset_acc, d.disease, d.source
  FROM comparison c
  JOIN dataset d ON c.dataset_id = d.dataset_id
  WHERE d.disease LIKE '%UC%' AND d.source LIKE '%Colon%'
" --format json > uc_colon_comparisons.json

# Export top DE genes across all comparisons
ibdtransdb inspect query "
  SELECT
    gm.symbol,
    cd.log_fc,
    cd.p_value_adj,
    c.comparison_id
  FROM comparison_data cd
  JOIN gene_map gm ON cd.gene = gm.id
  JOIN comparison c ON cd.comparison_id = c.comparison_id
  WHERE cd.p_value_adj < 0.01 AND ABS(cd.log_fc) > 1
  ORDER BY cd.p_value_adj
  LIMIT 1000
" --format csv > top_de_genes.csv
```

### Example 4: Database Schema Exploration

Understand the database structure before writing queries.

```bash
# Step 1: List all tables
ibdtransdb inspect tables

# Step 2: Examine key tables
ibdtransdb inspect schema dataset
ibdtransdb inspect schema comparison
ibdtransdb inspect schema comparison_data
ibdtransdb inspect schema gene_map

# Step 3: Sample data from each table
ibdtransdb inspect query "SELECT * FROM dataset LIMIT 5"
ibdtransdb inspect query "SELECT * FROM comparison LIMIT 5"
ibdtransdb inspect query "SELECT * FROM gene_map LIMIT 10"
```

### Example 5: Cross-Dataset Meta-Analysis Preparation

Prepare data for meta-analysis across multiple datasets.

```bash
# Extract all CD vs Healthy comparisons
ibdtransdb inspect query "
  SELECT
    c.comparison_id,
    d.dataset_acc,
    d.source,
    d.experiment_type,
    c.case_ann,
    c.control_ann,
    c.case_sample,
    c.control_sample
  FROM comparison c
  JOIN dataset d ON c.dataset_id = d.dataset_id
  WHERE c.case_ann LIKE '%CD%'
    AND c.control_ann LIKE '%Healthy%'
" --format csv > cd_healthy_comparisons.csv

# Extract DE results for cytokine genes
ibdtransdb inspect query "
  SELECT
    c.comparison_id,
    gm.symbol,
    cd.log_fc,
    cd.p_value,
    cd.p_value_adj
  FROM comparison_data cd
  JOIN gene_map gm ON cd.gene = gm.id
  JOIN comparison c ON cd.comparison_id = c.comparison_id
  WHERE c.comparison_id IN (
    SELECT comparison_id FROM comparison WHERE case_ann LIKE '%CD%'
  )
  AND gm.symbol IN ('TNF', 'IL1B', 'IL6', 'IL10', 'IL12A', 'IL17A')
" --format json > cytokine_de_results.json
```

### Example 6: Treatment Response Analysis

Analyze datasets with treatment information.

```bash
# Find all datasets with anti-TNF treatment
ibdtransdb datasets list --treatment AntiTNF

# Get details for Infliximab studies
ibdtransdb datasets list --treatment Infliximab --format table

# Extract gene expression changes post-treatment
ibdtransdb inspect query "
  SELECT
    d.dataset_acc,
    d.treatment,
    gm.symbol,
    cd.log_fc,
    cd.p_value_adj
  FROM comparison_data cd
  JOIN gene_map gm ON cd.gene = gm.id
  JOIN comparison c ON cd.comparison_id = c.comparison_id
  JOIN dataset d ON c.dataset_id = d.dataset_id
  WHERE d.treatment LIKE '%Infliximab%'
    AND cd.p_value_adj < 0.05
  ORDER BY cd.p_value_adj
  LIMIT 100
" --format csv > infliximab_response.csv
```

## Programmatic Usage

### Python Scripts

Use the CLI from Python scripts or Jupyter notebooks.

**Option 1: Subprocess**

```python
import subprocess
import json
import pandas as pd

# Run CLI command and capture output
def run_cli(command: list) -> str:
    """Run ibdtransdb CLI command and return output"""
    result = subprocess.run(
        ["ibdtransdb"] + command,
        capture_output=True,
        text=True,
        check=True
    )
    return result.stdout

# Example: Get datasets as JSON
datasets_json = run_cli(["datasets", "list", "--format", "json"])
datasets = json.loads(datasets_json)
print(f"Found {len(datasets)} datasets")

# Example: Get CSV as pandas DataFrame
csv_output = run_cli([
    "inspect", "query",
    "SELECT * FROM dataset",
    "--format", "csv"
])
df = pd.read_csv(pd.io.common.StringIO(csv_output))
print(df.head())
```

**Option 2: Direct Import**

```python
from scripts.db import IBDTransDB
from pathlib import Path

# Use database wrapper directly
db_path = Path("data/IBDTransDB.db")

with IBDTransDB(db_path) as db:
    # Get datasets as DataFrame
    datasets = db.query_df("SELECT * FROM dataset")

    # Get specific dataset info
    dataset = db.query(
        "SELECT * FROM dataset WHERE dataset_acc = ?",
        ("GSE16879",)
    )

    # Get row counts
    tables = db.get_table_names()
    for table in tables:
        count = db.get_row_count(table)
        print(f"{table}: {count:,} rows")
```

### Bash Scripts

Integrate CLI into bash scripts for automated workflows.

```bash
#!/bin/bash
# export_uc_data.sh - Export all UC-related data

OUTPUT_DIR="uc_export_$(date +%Y%m%d)"
mkdir -p "$OUTPUT_DIR"

# Export UC datasets
echo "Exporting UC datasets..."
ibdtransdb datasets list --disease UC --format csv > "$OUTPUT_DIR/uc_datasets.csv"

# Export comparisons
echo "Exporting UC comparisons..."
ibdtransdb inspect query "
  SELECT c.*, d.dataset_acc
  FROM comparison c
  JOIN dataset d ON c.dataset_id = d.dataset_id
  WHERE d.disease LIKE '%UC%'
" --format json > "$OUTPUT_DIR/uc_comparisons.json"

# Export DE results for key genes
echo "Exporting DE results..."
GENES=("TNF" "IL1B" "IL6" "IL10" "IL17A" "IFNG")

for gene in "${GENES[@]}"; do
    echo "  - $gene"
    ibdtransdb inspect query "
      SELECT cd.*, gm.symbol, c.comparison_id
      FROM comparison_data cd
      JOIN gene_map gm ON cd.gene = gm.id
      JOIN comparison c ON cd.comparison_id = c.comparison_id
      JOIN dataset d ON c.dataset_id = d.dataset_id
      WHERE gm.symbol = '$gene' AND d.disease LIKE '%UC%'
    " --format csv > "$OUTPUT_DIR/${gene}_de_results.csv"
done

echo "Export complete: $OUTPUT_DIR"
```

### R Scripts

Use CLI from R for integration with statistical analysis.

```r
library(jsonlite)
library(data.table)

# Function to run CLI command
run_cli <- function(command) {
  cmd <- paste("ibdtransdb", command)
  result <- system(cmd, intern = TRUE)
  return(result)
}

# Get datasets as JSON
datasets_json <- run_cli("datasets list --format json")
datasets <- fromJSON(datasets_json)
print(head(datasets))

# Get expression data for analysis
query <- "
  SELECT gm.symbol, cd.log_fc, cd.p_value
  FROM comparison_data cd
  JOIN gene_map gm ON cd.gene = gm.id
  WHERE cd.comparison_id = 1
"
de_data <- fread(
  cmd = paste0("ibdtransdb inspect query \"", query, "\" --format csv")
)

# Perform analysis
sig_genes <- de_data[p_value < 0.05]
print(paste("Found", nrow(sig_genes), "significant genes"))
```

## Advanced Usage

### Custom Database Path

By default, the CLI looks for `data/IBDTransDB.db`. Override this with `--db`:

```bash
# Use database in different location
ibdtransdb --db ~/databases/IBDTransDB.db datasets list

# Use database from network drive
ibdtransdb --db /mnt/shared/IBDTransDB.db inspect stats

# Use temporary database copy
ibdtransdb --db /tmp/IBDTransDB_backup.db datasets info GSE16879
```

### Query Optimization

Tips for efficient queries:

**Use Indexes**:
```bash
# Indexed columns: dataset_acc, comparison_id, gene
# These are fast:
ibdtransdb inspect query "SELECT * FROM dataset WHERE dataset_acc = 'GSE16879'"
ibdtransdb inspect query "SELECT * FROM comparison_data WHERE comparison_id = 1"

# These may be slow (full table scans):
ibdtransdb inspect query "SELECT * FROM dataset WHERE title LIKE '%colitis%'"
```

**Limit Results**:
```bash
# Always use LIMIT for large tables
ibdtransdb inspect query "SELECT * FROM dataset_data LIMIT 1000"

# CLI auto-adds LIMIT 100 to SELECT queries without LIMIT
```

**Use Specific Columns**:
```bash
# Fast (only retrieves needed columns)
ibdtransdb inspect query "SELECT dataset_acc, disease FROM dataset"

# Slower (retrieves all columns)
ibdtransdb inspect query "SELECT * FROM dataset"
```

### Piping and Chaining

Combine with standard Unix tools:

```bash
# Count datasets by disease
ibdtransdb datasets list --format csv | cut -d',' -f3 | sort | uniq -c

# Filter results with grep
ibdtransdb inspect query "SELECT * FROM gene_map" --format csv | grep "IL"

# Parse JSON with jq
ibdtransdb datasets list --format json | jq '.[].dataset_acc'

# Sort by sample number
ibdtransdb datasets list --format csv | sort -t',' -k7 -n

# Export to compressed file
ibdtransdb datasets list --format json | gzip > datasets.json.gz
```

### Batch Processing

Process multiple datasets in parallel:

```bash
# Get all dataset accessions
DATASETS=$(ibdtransdb datasets list --format csv | tail -n +2 | cut -d',' -f1)

# Process each dataset
for dataset in $DATASETS; do
    echo "Processing $dataset..."
    ibdtransdb datasets info $dataset --format json > "info_${dataset}.json"
done

# Parallel processing with GNU parallel
ibdtransdb datasets list --format csv | tail -n +2 | cut -d',' -f1 | \
  parallel "ibdtransdb datasets info {} --format json > info_{}.json"
```

## Troubleshooting

### Common Issues

**Issue 1: Command not found**
```bash
$ ibdtransdb datasets list
bash: ibdtransdb: command not found
```
**Solution**: Ensure CLI is installed and virtual environment is activated
```bash
pip install -e .
source .venv/bin/activate
```

**Issue 2: Database not found**
```bash
Error: Invalid value for '-d' / '--db': Path 'data/IBDTransDB.db' does not exist.
```
**Solution**: Download database and place in correct location
```bash
mkdir -p data
# Download from iCloud and move to data/
# OR specify custom path:
ibdtransdb --db /path/to/IBDTransDB.db datasets list
```

**Issue 3: Query syntax error**
```bash
Query error: near "WHERE": syntax error
```
**Solution**: Check SQL syntax, ensure proper quoting
```bash
# Correct: Use double quotes around entire query
ibdtransdb inspect query "SELECT * FROM dataset WHERE disease = 'UC'"

# Incorrect: Missing quotes or wrong quote type
ibdtransdb inspect query SELECT * FROM dataset WHERE disease = 'UC'
```

**Issue 4: Output too large**
```bash
# Terminal overwhelmed with data
```
**Solution**: Use LIMIT, export to file, or use CSV/JSON format
```bash
# Add LIMIT
ibdtransdb inspect query "SELECT * FROM dataset_data LIMIT 100"

# Export to file
ibdtransdb datasets list --format csv > datasets.csv

# The CLI auto-limits to 100 rows for table display
```

**Issue 5: Python version incompatibility**
```bash
ERROR: This package requires Python >=3.9
```
**Solution**: Upgrade Python or use compatible environment
```bash
# Check Python version
python --version

# Use specific Python version
python3.9 -m venv .venv
source .venv/bin/activate
pip install -e .
```

### Error Messages

| Error | Meaning | Solution |
|-------|---------|----------|
| `Dataset {acc} not found` | Dataset accession doesn't exist | Check spelling, use `datasets list` |
| `Table '{name}' not found` | Invalid table name | Use `inspect tables` to see valid names |
| `Query error: ...` | SQL syntax error | Check SQL syntax, use proper quoting |
| `No results found` | Query returned empty result | Check filters, verify data exists |

## Performance Considerations

### Database Size

- **File Size**: ~2.9 GB
- **Memory Usage**: SQLite memory-maps the file; ~100-500 MB RAM for typical queries
- **Disk I/O**: SSD recommended for faster queries

### Query Performance

| Operation | Speed | Notes |
|-----------|-------|-------|
| List datasets | Fast (<1s) | Small table (34 rows) |
| Get dataset info | Fast (<1s) | Indexed lookups |
| Query gene_map | Fast (<1s) | 53K rows, well-indexed |
| Query comparison_data | Moderate (1-5s) | 3M rows, use filters |
| Query dataset_data | Slow (5-30s) | 72M rows, always use LIMIT |

### Optimization Tips

1. **Use specific columns**: `SELECT col1, col2` instead of `SELECT *`
2. **Add WHERE clauses**: Filter early to reduce data scanned
3. **Use LIMIT**: Always limit large table queries
4. **Leverage indexes**: Query on `dataset_acc`, `comparison_id`, `gene`
5. **Export large results**: Use CSV/JSON instead of table format

## Future Enhancements

### Planned Features

1. **Comparison Commands**: Direct comparison queries without raw SQL
   ```bash
   ibdtransdb comparisons list --dataset GSE16879
   ibdtransdb comparisons results --comparison-id 1 --gene TNF
   ```

2. **Gene Commands**: Simplified gene expression queries
   ```bash
   ibdtransdb genes search "TNF*"
   ibdtransdb genes expression TNF --dataset GSE16879
   ```

3. **Export Templates**: Pre-defined export workflows
   ```bash
   ibdtransdb export meta-analysis --disease UC --output uc_meta/
   ibdtransdb export pathway-analysis --pathway "IL-17 signaling"
   ```

4. **Interactive Mode**: REPL-style interface for exploration
   ```bash
   ibdtransdb interactive
   > list datasets
   > info GSE16879
   > query "SELECT * FROM dataset"
   ```

5. **Visualization**: Generate plots directly from CLI
   ```bash
   ibdtransdb plot volcano --comparison-id 1
   ibdtransdb plot boxplot --gene TNF --comparison-id 1,2,3
   ```

## References

- **Source Code**: `scripts/` directory
- **Database Schema**: `docs/overview.md`
- **Dataset Expansion Guide**: `docs/dataset-expansion.md`
- **Web Interface**: https://abbviegrc.shinyapps.io/ibdexplore_data/
- **Project Repository**: IBDTransDB GitHub (if available)

## Support

For CLI issues:
- Check this documentation
- Review error messages carefully
- Verify database path and version
- Ensure proper installation with `pip install -e .`

For data questions:
- Refer to `docs/overview.md` for database schema
- Check `docs/dataset-expansion.md` for data provenance
- Use `ibdtransdb inspect stats` and `inspect tables` for data overview

---

**Last Updated**: 2026-01-12
**CLI Version**: 0.1.0
**Documentation Author**: IBDTransDB Development Team
