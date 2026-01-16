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

Ensure you have R installed on your system (version 4.0.0 or higher recommended, version 4.4.2 latest as of January 2025).

#### macOS

**Option 1: Download and Install (Recommended)**
```bash
# Download R for macOS (Apple Silicon - M1/M2/M3)
curl -O https://cloud.r-project.org/bin/macosx/big-sur-arm64/base/R-4.4.2-arm64.pkg

# Or for Intel Macs
curl -O https://cloud.r-project.org/bin/macosx/big-sur-x86_64/base/R-4.4.2-x86_64.pkg

# Install the downloaded package
sudo installer -pkg R-4.4.2-arm64.pkg -target /
# or for Intel:
# sudo installer -pkg R-4.4.2-x86_64.pkg -target /
```

**Option 2: Using Homebrew**
```bash
# Install Homebrew if not already installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install R
brew install r
```

#### Linux (Ubuntu/Debian)

```bash
# Update package list
sudo apt-get update

# Install dependencies
sudo apt-get install -y software-properties-common dirmngr

# Add CRAN repository for latest R version
wget -qO- https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc | sudo tee -a /etc/apt/trusted.gpg.d/cran_ubuntu_key.asc

# Add R 4.4 repository (for Ubuntu 22.04 - Jammy)
sudo add-apt-repository "deb https://cloud.r-project.org/bin/linux/ubuntu $(lsb_release -cs)-cran40/"

# Update and install R
sudo apt-get update
sudo apt-get install -y r-base r-base-dev

# Install additional build tools for R packages
sudo apt-get install -y libcurl4-openssl-dev libssl-dev libxml2-dev libfontconfig1-dev libharfbuzz-dev libfribidi-dev
```

#### Linux (CentOS/RHEL/Fedora)

```bash
# For RHEL/CentOS 8+
sudo dnf install epel-release
sudo dnf install R

# For Fedora
sudo dnf install R

# Install development tools
sudo dnf install libcurl-devel openssl-devel libxml2-devel
```

#### Windows

**Option 1: Direct Download**
```powershell
# Download R installer for Windows
curl -O https://cloud.r-project.org/bin/windows/base/R-4.4.2-win.exe

# Run the installer (open the downloaded file)
# Or use PowerShell to install silently:
Start-Process -FilePath "R-4.4.2-win.exe" -ArgumentList "/VERYSILENT" -Wait
```

**Option 2: Using Chocolatey** (Windows package manager)
```powershell
# Install Chocolatey if not already installed
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Install R
choco install r.project
```

#### Verify R Installation

After installation, verify R is correctly installed:

```bash
# Check R version
R --version

# Should output something like:
# R version 4.4.2 (2024-10-31) -- "Pile of Leaves"

# Open R interactive console
R

# In R console, check installation:
# > version
# > q()  # to quit
```

### 2. RStudio (Recommended)

While not strictly required, RStudio provides the best development experience for RShiny apps.

#### Download RStudio Desktop

**Direct Download Links:**

- **macOS (M1/M2/M3 - Apple Silicon):**
  ```bash
  curl -L -o RStudio.dmg https://download1.rstudio.org/electron/macos/RStudio-2024.12.0-467.dmg
  open RStudio.dmg
  # Drag RStudio to Applications folder
  ```

- **macOS (Intel):**
  ```bash
  curl -L -o RStudio.dmg https://download1.rstudio.org/electron/macos/RStudio-2024.12.0-467.dmg
  open RStudio.dmg
  ```

- **Ubuntu/Debian:**
  ```bash
  # Download RStudio for Ubuntu 22
  wget https://download1.rstudio.org/electron/jammy/amd64/rstudio-2024.12.0-467-amd64.deb

  # Install
  sudo dpkg -i rstudio-2024.12.0-467-amd64.deb

  # Fix any dependency issues
  sudo apt-get install -f
  ```

- **Windows:**
  ```powershell
  # Download RStudio
  curl -L -o RStudio-Setup.exe https://download1.rstudio.org/electron/windows/RStudio-2024.12.0-467.exe

  # Run installer
  Start-Process -FilePath "RStudio-Setup.exe" -Wait
  ```

**Alternative:** Visit [posit.co/download/rstudio-desktop](https://posit.co/download/rstudio-desktop/) for the latest version.

#### Verify RStudio Installation

```bash
# macOS/Linux: Launch RStudio
open -a RStudio  # macOS
rstudio &        # Linux

# Windows: Search for "RStudio" in Start menu
```

### 3. Additional System Dependencies (Linux)

For Linux users, install additional system libraries required for R packages:

```bash
# Ubuntu/Debian
sudo apt-get install -y \
  libgit2-dev \
  libcairo2-dev \
  libxt-dev \
  libpng-dev \
  libjpeg-dev \
  libtiff-dev

# CentOS/RHEL
sudo dnf install -y \
  libgit2-devel \
  cairo-devel \
  libXt-devel \
  libpng-devel \
  libjpeg-devel \
  libtiff-devel
```

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

**Automated Installation (Recommended)**

Run the installation script to automatically install all required packages:

```bash
# From the IBDTransDB root directory
./scripts/install_R_packages.sh
```

This script will:
- Check if R is installed
- Install all required packages for both CLI and RShiny apps
- Verify critical packages are working
- Provide a detailed installation summary

**Manual Installation (Alternative)**

If you prefer to install packages manually, open R or RStudio and run:

```r
# Navigate to the scripts directory and run
setwd("scripts/r_analysis")
source("install_packages.R")
```

Or install specific packages individually:

```r
# Core packages for CLI
install.packages(c("RSQLite", "DBI", "dplyr", "ggplot2", "jsonlite"))

# Additional packages for RShiny apps
install.packages(c("shiny", "shinyWidgets", "shinydashboard", "DT"))
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
