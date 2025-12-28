## IBDTransDB: a manually curated transcriptomic database for inflammatory bowel disease


Transcriptomic data have been widely used to understand the pathogenesis of inflammatory bowel disease (IBD) and identify the novel drug targets. To help biologists and clinicians with limited computational knowledge to access and analyze the public datasets from Gene Expression Omnibus (GEO) and ArrayExpress (AE), we propose IBDTransDB (https://abbviegrc.shinyapps.io/ibdtransdb/), a manually curated transcriptomic database for IBD. IBDTransDB has five key features: (i) a manually curated database with 34 transcriptomic datasets (2932 samples) and 122 differential gene lists based on comparisons from different conditions; (ii) a query system supporting 35 keywords from five attributes (5 diseases/controls, 12 treatments, 10 timepoints, 4 tissues, and 4 cell types); (iii) IBDExplore: interactive visualization of differential gene, pathway enrichment, gene signature, and cell deconvolution analyses from individual dataset; (iv) IBDCompare: data set comparisons across different conditions based on selected genes or pathways; (v) IBDIntegrate: meta-analysis to prioritize a list of genes/pathways based on the selected data sets and comparisons. Based on these unique features, IBDTransDB will be a convenient and powerful tool for scientists to identify and validate IBD novel targets.<br/><br/>
![alt text](https://github.com/abbviegrc/IBDTransDB/blob/main/IBDTransDB.png?raw=true)

## Documentation

### Tutorials
<h3><p align="center">
    <br />
    <a href="https://github.com/abbviegrc/IBDTransDB/blob/main/tutorial/IBDExplore_tutorial.pdf">IBDExplore</a>
    .
    <a href="https://github.com/abbviegrc/IBDTransDB/blob/main/tutorial/IBDCompare_tutorial.pdf">IBDCompare</a>
    .
    <a href="https://github.com/abbviegrc/IBDTransDB/blob/main/tutorial/IBDIntegtate_tutorial.pdf">IBDIntegrate</a>

  </p></h3>

### Technical Documentation
- **[Database Overview](docs/overview.md)** - Comprehensive database schema, statistics, and data relationships
- **[Dataset Expansion Guide](docs/dataset-expansion.md)** - Guidelines for adding new datasets, deduplication, and quality control
- **[Setup Instructions](docs/setup-instruction.md)** - Installation and usage for both R Shiny and Python CLI

## Run locally

IBDTransDB runs in Shinyapps.io server that takes around 1 miniute to initialize each app for the first time access. To avoid any waiting time, users can also download the codes from Github and IBDTransDB database from <a href="https://www.icloud.com/iclouddrive/013D9ewhOhNjj-5tErDEWnhow#IBDTransDB" target="_blank">https://www.icloud.com/iclouddrive/013D9ewhOhNjj-5tErDEWnhow#IBDTransDB</a> and run RShiny locally. This will make analyses much faster. After downloading the codes and database, users should put the database into each module folder and run RShiny in the RStudio.

See [Setup Instructions](docs/setup-instruction.md) for detailed R setup guide.

## Python CLI Tool

For users who want to explore the database without the full R visualization interface, we provide a lightweight Python CLI tool.

### Quick Start

```bash
# Install uv (if not already installed)
curl -LsSf https://astral.sh/uv/install.sh | sh

# Download database to data/ directory
# From: https://www.icloud.com/iclouddrive/013D9ewhOhNjj-5tErDEWnhow#IBDTransDB
cp ~/Downloads/IBDTransDB.db data/

# Setup Python environment
uv venv
source .venv/bin/activate
uv pip install -e .

# Explore the database
ibdtransdb inspect stats
ibdtransdb datasets list
ibdtransdb datasets list --disease UC --tissue Colon
```

### Features

- **Dataset Browser**: Filter and explore 34 curated datasets by disease, tissue, treatment
- **Database Inspector**: View table schemas, run custom SQL queries
- **Multiple Output Formats**: Table, CSV, JSON for easy data export
- **Lightweight**: No R dependencies, fast startup, scriptable

See [Python CLI Documentation](docs/setup-instruction.md#python-cli-tool) for complete usage guide.

## Contract
Pranav Sahasrabudhe - pranav.sahasrabudhe@abbvie.com</br>
Jing Wang - wang.jing@abbvie.com
