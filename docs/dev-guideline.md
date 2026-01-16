# IBDTransDB CLI - Developer Guide

## Overview

This guide is for developers who want to understand the CLI architecture, contribute new commands, or extend functionality. The IBDTransDB CLI uses a **wrapper-based architecture** where Python orchestrates R script execution, preserving existing tested R analysis code while providing a modern CLI interface.

**Version**: 0.2.0
**Language**: Python 3.9+ for CLI, R 4.0+ for analysis

## Table of Contents

1. [Architecture](#architecture)
2. [Project Structure](#project-structure)
3. [Development Setup](#development-setup)
4. [Adding New Commands](#adding-new-commands)
5. [R Script Development](#r-script-development)
6. [Testing](#testing)
7. [Code Style](#code-style)
8. [Contributing](#contributing)

## Architecture

### High-Level Design

```
User Command
    ↓
Python CLI (Typer)
    ↓
Command Module (explore.py/compare.py/integrate.py)
    ↓
R Script Executor (utils/r_executor.py)
    ↓
R Analysis Script (scripts/r_analysis/*.R)
    ↓
Results Parser (utils/result_parser.py)
    ↓
Output Formatter (utils/formatters.py)
    ↓
Console Output + File Exports
```

### Key Design Decisions

1. **Python for Orchestration**
   - CLI interface using Typer
   - Argument parsing and validation
   - Database connection management
   - Output formatting

2. **R for Analysis**
   - Statistical analysis (PCA, DGE, meta-analysis)
   - Plot generation (ggplot2)
   - Enrichment analysis (WebGestaltR)
   - Leverages existing Shiny app functions

3. **Subprocess Communication**
   - R scripts executed via `subprocess.run()`
   - Arguments passed as command-line flags
   - Results returned as JSON via stdout
   - Files saved to temporary directories

### Component Responsibilities

| Component | Responsibility |
|-----------|---------------|
| **cli.py** | Main entry point, registers command groups |
| **commands/*.py** | Command implementations, user-facing interface |
| **utils/r_executor.py** | Execute R scripts, handle timeouts, parse output |
| **utils/result_parser.py** | Parse R outputs, extract statistics |
| **utils/plot_handler.py** | Manage plot files, organize outputs |
| **utils/validation.py** | Validate inputs against database |
| **utils/dependency_checker.py** | Check R and package dependencies |
| **r_analysis/common/*.R** | Shared R utilities (database, plots, JSON) |
| **r_analysis/explore/*.R** | Single dataset analysis scripts |
| **r_analysis/compare/*.R** | Cross-dataset comparison scripts |
| **r_analysis/integrate/*.R** | Meta-analysis and ranking scripts |

## Project Structure

```
IBDTransDB/
├── scripts/
│   ├── cli.py                          # Main CLI entry point
│   ├── db.py                           # Database wrapper class
│   ├── commands/                       # Command modules
│   │   ├── __init__.py
│   │   ├── datasets.py                 # Dataset browsing
│   │   ├── inspect.py                  # Database inspection
│   │   ├── explore.py                  # Single dataset analysis (Phase 2)
│   │   ├── compare.py                  # Cross-dataset comparison (Phase 3)
│   │   └── integrate.py                # Meta-analysis (Phase 4)
│   ├── utils/                          # Utility modules
│   │   ├── __init__.py
│   │   ├── formatters.py               # Output formatting
│   │   ├── r_executor.py               # R script execution
│   │   ├── result_parser.py            # Result parsing
│   │   ├── plot_handler.py             # Plot management
│   │   ├── validation.py               # Input validation
│   │   └── dependency_checker.py       # Dependency checking
│   └── r_analysis/                     # R script library
│       ├── install_packages.R          # Package installer
│       ├── common/                     # Shared utilities
│       │   ├── database_utils.R        # DB connection helpers
│       │   ├── plot_utils.R            # Common plotting functions
│       │   └── json_utils.R            # JSON export helpers
│       ├── explore/                    # Single dataset analysis
│       │   ├── pca_analysis.R
│       │   ├── volcano_plot.R
│       │   ├── dge_analysis.R
│       │   ├── enrichment_analysis.R
│       │   ├── expression_plot.R
│       │   └── cell_deconvolution.R
│       ├── compare/                    # Cross-dataset comparison
│       │   ├── comparison_table.R
│       │   ├── meta_analysis.R
│       │   └── geneset_compare.R
│       └── integrate/                  # Meta-analysis
│           ├── target_ranking.R
│           ├── signature_ranking.R
│           └── pathway_ranking.R
├── data/
│   └── IBDTransDB.db                   # SQLite database
├── outputs/                            # Default output directory
│   ├── plots/                          # Generated plots
│   ├── tables/                         # Exported tables
│   └── reports/                        # Analysis reports
├── tests/                              # Test suite
│   ├── test_r_executor.py
│   ├── test_commands.py
│   └── r_tests/                        # R script tests
├── docs/                               # Documentation
│   ├── usage-guideline.md              # User guide
│   ├── dev-guideline.md                # This file
│   ├── ibd-cli.md                      # CLI reference
│   └── ibd-cli-expansion-plan.md       # Implementation plan
└── pyproject.toml                      # Python project config
```

## Development Setup

### Prerequisites

- Python 3.9+
- R 4.0+
- Git
- Virtual environment tool (venv, conda, etc.)

### Step 1: Clone Repository

```bash
git clone <repository-url>
cd IBDTransDB
```

### Step 2: Set Up Python Environment

```bash
# Create virtual environment
python -m venv .venv

# Activate
source .venv/bin/activate  # Mac/Linux
# OR
.venv\Scripts\activate  # Windows

# Install in development mode
pip install -e .

# Install dev dependencies
pip install pytest black ruff
```

### Step 3: Install R Packages

```bash
# Run package installer
Rscript scripts/r_analysis/install_packages.R
```

### Step 4: Download Database

Place `IBDTransDB.db` in `data/` directory.

### Step 5: Verify Setup

```bash
# Test CLI
ibdtransdb --help

# Test database connection
ibdtransdb inspect stats

# Check dependencies
python -c "from scripts.utils.dependency_checker import DependencyChecker; DependencyChecker.check_all_dependencies()"
```

## Adding New Commands

### Step-by-Step Guide

#### 1. Create Python Command

**File**: `scripts/commands/explore.py` (example)

```python
"""Explore commands - Single dataset analysis"""
import typer
from pathlib import Path
from typing import Optional
from rich.console import Console
from scripts.utils.r_executor import RScriptExecutor
from scripts.utils.validation import Validator

app = typer.Typer(help="Explore individual datasets")
console = Console()

@app.command("pca")
def pca_analysis(
    ctx: typer.Context,
    dataset_acc: str = typer.Argument(..., help="Dataset accession"),
    color_by: Optional[str] = typer.Option(None, "--color-by", "-c", help="Sample annotation for coloring"),
    output: Optional[Path] = typer.Option(None, "--output", "-o", help="Output CSV file"),
):
    """
    Perform PCA analysis on a dataset

    Example:
        ibdtransdb explore pca GSE16879 --color-by Disease --output pca.csv
    """
    db_path = ctx.obj["db_path"]

    # 1. Validate input
    validator = Validator(db_path)
    if not validator.validate_dataset(dataset_acc):
        console.print(f"[red]Dataset {dataset_acc} not found[/red]")
        raise typer.Exit(1)

    # 2. Execute R script
    executor = RScriptExecutor(
        db_path=db_path,
        r_scripts_dir=Path(__file__).parent.parent / "r_analysis"
    )

    try:
        result = executor.execute_r_script(
            script_name="explore/pca_analysis.R",
            args={
                "dataset_acc": dataset_acc,
                "color_by": color_by,
            }
        )

        # 3. Handle output
        if "data" in result:
            console.print(f"[green]Analysis complete![/green]")
            console.print(f"Samples: {result['data']['n_samples']}")

        # 4. Save output files
        if output and result["files"]["tables"]:
            import shutil
            shutil.copy(result["files"]["tables"][0], output)
            console.print(f"[green]Data exported to: {output}[/green]")

    except Exception as e:
        console.print(f"[red]Error: {e}[/red]")
        raise typer.Exit(1)
```

#### 2. Create R Analysis Script

**File**: `scripts/r_analysis/explore/pca_analysis.R`

```r
#!/usr/bin/env Rscript

library(optparse)

# Define options
option_list <- list(
  make_option(c("--db-path"), type="character", help="Path to database"),
  make_option(c("--output-dir"), type="character", help="Output directory"),
  make_option(c("--dataset-acc"), type="character", help="Dataset accession"),
  make_option(c("--color-by"), type="character", default=NULL, help="Color variable")
)

opt <- parse_args(OptionParser(option_list=option_list))

# Load utilities
source(file.path(dirname(sys.frame(1)$ofile), "../common/database_utils.R"))
source(file.path(dirname(sys.frame(1)$ofile), "../common/plot_utils.R"))
source(file.path(dirname(sys.frame(1)$ofile), "../common/json_utils.R"))

# Connect to database
db <- connect_db(opt$`db-path`)

tryCatch({

  # Perform analysis
  pca_data <- get_pca_data(db, opt$`dataset-acc`)
  sample_ann <- get_sample_annotations(db, opt$`dataset-acc`)

  # Merge with annotations
  pca_results <- merge(pca_data, sample_ann, by = "sample_id")

  # Save results
  output_file <- file.path(opt$`output-dir`, "pca_coordinates.csv")
  write.csv(pca_results, output_file, row.names = FALSE)

  # Create summary
  summary <- create_pca_summary(
    n_samples = nrow(pca_results),
    variance_explained = c(25.3, 15.2, 10.1, 7.5, 5.2),  # Example
    dataset_acc = opt$`dataset-acc`,
    output_files = list(
      tables = c("pca_coordinates.csv")
    )
  )

  # Export JSON summary to stdout
  export_json(summary)

}, error = function(e) {
  export_error_and_exit(e$message)
}, finally = {
  disconnect_db(db)
})
```

#### 3. Register Command in Main CLI

**File**: `scripts/cli.py`

```python
from scripts.commands import datasets, inspect, explore  # Add new import

# Register command group
app.add_typer(explore.app, name="explore", help="Explore individual datasets")
```

#### 4. Test Command

```bash
# Test help
ibdtransdb explore --help
ibdtransdb explore pca --help

# Test execution
ibdtransdb explore pca GSE16879 --color-by Disease --output test_pca.csv
```

### Command Design Patterns

#### Pattern 1: Simple Data Retrieval

For commands that query and return data without R processing:

```python
@app.command("list")
def list_items(ctx: typer.Context, format: str = typer.Option("table")):
    db_path = ctx.obj["db_path"]

    with IBDTransDB(db_path) as db:
        df = db.query_df("SELECT * FROM table")

    format_output(df, format)
```

#### Pattern 2: R Script Execution

For commands that require R analysis:

```python
@app.command("analyze")
def analyze_data(ctx: typer.Context, dataset_acc: str, output: Path):
    # 1. Validate
    validator = Validator(ctx.obj["db_path"])
    if not validator.validate_dataset(dataset_acc):
        raise typer.Exit(1)

    # 2. Execute R script
    executor = RScriptExecutor(ctx.obj["db_path"], r_scripts_dir)
    result = executor.execute_r_script("module/script.R", args)

    # 3. Handle results
    # ... save files, display summary
```

#### Pattern 3: Multiple Output Files

For commands that generate multiple outputs (plots + tables):

```python
@app.command("complex")
def complex_analysis(
    ctx: typer.Context,
    dataset_acc: str,
    output: Path = typer.Option(None),
    plot_file: Path = typer.Option(None)
):
    result = executor.execute_r_script(...)

    # Save tables
    if output and result["files"]["tables"]:
        shutil.copy(result["files"]["tables"][0], output)

    # Save plots
    plot_handler = PlotHandler()
    if plot_file and result["files"]["plots"]:
        plot_handler.save_plot(result["files"]["plots"][0], "plot_name", dataset_acc)
```

## R Script Development

### R Script Template

```r
#!/usr/bin/env Rscript

# Script: script_name.R
# Purpose: Brief description
# Usage: Rscript script_name.R --db-path <path> --output-dir <dir> [options]

library(optparse)

# Define command-line options
option_list <- list(
  make_option(c("--db-path"), type="character", help="Path to database"),
  make_option(c("--output-dir"), type="character", help="Output directory"),
  # Add script-specific options
  make_option(c("--dataset-acc"), type="character", help="Dataset accession"),
  make_option(c("--color-by"), type="character", default=NULL, help="Color variable")
)

opt_parser <- OptionParser(option_list=option_list)
opt <- parse_args(opt_parser)

# Validate required arguments
if (is.null(opt$`db-path`) || is.null(opt$`output-dir`)) {
  print_help(opt_parser)
  stop("Required arguments missing", call.=FALSE)
}

# Load required libraries
suppressPackageStartupMessages({
  library(RSQLite)
  library(dplyr)
  library(ggplot2)
  library(jsonlite)
})

# Source common utilities
script_dir <- dirname(sys.frame(1)$ofile)
source(file.path(script_dir, "../common/database_utils.R"))
source(file.path(script_dir, "../common/plot_utils.R"))
source(file.path(script_dir, "../common/json_utils.R"))

# Connect to database
db <- connect_db(opt$`db-path`)

# Main analysis
tryCatch({

  # 1. Perform analysis
  results <- perform_analysis(db, opt)

  # 2. Save outputs
  save_results(results, opt$`output-dir`)

  # 3. Create summary
  summary <- create_summary(
    analysis_type = "analysis_name",
    dataset_acc = opt$`dataset-acc`,
    stats = list(
      n_items = nrow(results),
      # ... other stats
    ),
    files = list(
      tables = c("results.csv"),
      plots = c("plot.png")
    )
  )

  # 4. Export JSON summary to stdout
  export_json(summary)

}, error = function(e) {
  # Export error and exit with non-zero status
  export_error_and_exit(e$message, exit_code = 1)
}, finally = {
  # Always disconnect database
  disconnect_db(db)
})
```

### Best Practices

1. **Use Common Utilities**
   - Source `database_utils.R`, `plot_utils.R`, `json_utils.R`
   - Don't duplicate database connection code
   - Use standard plotting themes

2. **Error Handling**
   - Wrap main code in `tryCatch()`
   - Use `export_error_and_exit()` for errors
   - Always disconnect database in `finally`

3. **Output Structure**
   - Save data files to `opt$output-dir`
   - Export JSON summary to stdout
   - Use standardized summary functions

4. **Documentation**
   - Add header comment with purpose and usage
   - Document all options
   - Include example usage

5. **Dependencies**
   - Load libraries with `suppressPackageStartupMessages()`
   - Check for required packages
   - Use common package set when possible

## Testing

### Unit Tests

**File**: `tests/test_r_executor.py`

```python
import pytest
from pathlib import Path
from scripts.utils.r_executor import RScriptExecutor

def test_r_available():
    """Test R is available"""
    executor = RScriptExecutor(Path("data/IBDTransDB.db"), Path("scripts/r_analysis"))
    assert executor.check_r_available()

def test_execute_simple_script():
    """Test executing a simple R script"""
    executor = RScriptExecutor(...)
    result = executor.execute_r_code("cat('test')")
    assert result.returncode == 0
```

### Integration Tests

**File**: `tests/test_commands.py`

```python
from typer.testing import CliRunner
from scripts.cli import app

runner = CliRunner()

def test_datasets_list():
    """Test datasets list command"""
    result = runner.invoke(app, ["datasets", "list"])
    assert result.exit_code == 0
    assert "dataset" in result.stdout.lower()

def test_dataset_info():
    """Test dataset info command"""
    result = runner.invoke(app, ["datasets", "info", "GSE16879"])
    assert result.exit_code == 0
    assert "GSE16879" in result.stdout
```

### R Script Tests

**File**: `tests/r_tests/test_pca_script.R`

```r
library(testthat)

test_that("PCA script produces valid output", {
  # Run script
  system("Rscript scripts/r_analysis/explore/pca_analysis.R --db-path data/IBDTransDB.db --output-dir /tmp/test --dataset-acc GSE16879")

  # Check outputs exist
  expect_true(file.exists("/tmp/test/pca_coordinates.csv"))

  # Validate data
  pca_data <- read.csv("/tmp/test/pca_coordinates.csv")
  expect_gt(nrow(pca_data), 0)
  expect_true("PC1" %in% colnames(pca_data))
})
```

### Running Tests

```bash
# Run Python tests
pytest tests/

# Run specific test file
pytest tests/test_commands.py -v

# Run R tests
Rscript tests/r_tests/test_pca_script.R
```

## Code Style

### Python Style

Follow **PEP 8** style guide:

```bash
# Format code with Black
black scripts/

# Lint with Ruff
ruff check scripts/
```

**Key Guidelines**:
- 4 spaces for indentation
- Max line length: 100 characters
- Use type hints
- Write docstrings for all functions
- Use descriptive variable names

### R Style

Follow **tidyverse** style guide:

**Key Guidelines**:
- 2 spaces for indentation
- `snake_case` for functions and variables
- Use `<-` for assignment
- Document all functions
- Load libraries at top

### Documentation Style

- Use Markdown for documentation
- Include code examples
- Keep lines under 100 characters
- Use headers consistently

## Contributing

### Workflow

1. **Fork repository**
2. **Create feature branch**
   ```bash
   git checkout -b feature/my-new-command
   ```
3. **Make changes**
4. **Run tests**
   ```bash
   pytest tests/
   ```
5. **Commit changes**
   ```bash
   git commit -m "Add new command for X"
   ```
6. **Push to fork**
   ```bash
   git push origin feature/my-new-command
   ```
7. **Open Pull Request**

### Commit Message Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types**:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation
- `test`: Tests
- `refactor`: Code refactoring
- `style`: Formatting

**Example**:
```
feat(explore): add PCA analysis command

Implement PCA analysis with plot generation and coordinate export.
Includes R script, Python command, and tests.

Closes #123
```

### Pull Request Checklist

- [ ] Tests pass
- [ ] Code follows style guide
- [ ] Documentation updated
- [ ] Commit messages are clear
- [ ] Changes are focused (one feature per PR)

## Debugging

### Enable Verbose Output

```bash
# Python side - add prints
console.print("[cyan]Executing R script...[/cyan]")
console.print(f"[dim]Command: {cmd}[/dim]")

# R side - add cat() statements
cat("Loading data...\n", file=stderr())
cat(sprintf("Found %d samples\n", nrow(data)), file=stderr())
```

### Debug R Scripts Directly

```bash
# Run R script manually
Rscript scripts/r_analysis/explore/pca_analysis.R \
  --db-path data/IBDTransDB.db \
  --output-dir /tmp/debug \
  --dataset-acc GSE16879 \
  --color-by Disease
```

### Use R Interactively

```r
# Source utilities
source("scripts/r_analysis/common/database_utils.R")

# Connect to database
db <- connect_db("data/IBDTransDB.db")

# Test functions
pca_data <- get_pca_data(db, "GSE16879")
head(pca_data)
```

## Resources

- **Typer Documentation**: https://typer.tiangolo.com/
- **Rich Documentation**: https://rich.readthedocs.io/
- **R Packages**:
  - ggplot2: https://ggplot2.tidyverse.org/
  - dplyr: https://dplyr.tidyverse.org/
  - WebGestaltR: https://www.webgestalt.org/
- **SQLite**: https://www.sqlite.org/docs.html

## Contact

For questions or discussions:
- **Issues**: GitHub Issues
- **Email**: Development team
- **Documentation**: See `docs/` directory

---

**Version**: 0.2.0
**Last Updated**: 2026-01-13
**Maintainers**: IBDTransDB Development Team
