# IBDCompare System Documentation

## Overview

IBDCompare is the cross-dataset comparison and meta-analysis module of IBDTransDB that enables researchers to compare differential expression results across multiple studies, identify consistent disease signatures, and perform comprehensive meta-analyses. The system provides interactive visualization and statistical integration of 122 comparisons from 34 IBD transcriptomic datasets.

## Architecture

### System Components

```
IBDTransDB/
├── IBDCompare/                      # Cross-dataset comparison interface
│   ├── IBDTransDB_Compare.R         # Main R Shiny application
│   └── app_functions/               # Core comparison functions
│       ├── database_query.R         # Data retrieval functions
│       ├── comparison_summary.R     # Summary statistics
│       ├── comparison_tables.R      # Result table generation
│       ├── plot_functions.R         # Visualization functions
│       ├── meta_analysis.R          # Statistical meta-analysis
│       └── signature_scores.R       # Gene signature analysis
└── data/
    └── IBDTransDB.db                # SQLite database (~2.9 GB)
```

### Database Content for Comparisons

**Total Resources**:
- 34 datasets from GEO and ArrayExpress
- 122 differential expression comparisons
- 2,917 samples across studies
- 3,079,348 differential expression results
- 226,505 pathway enrichment results

**Coverage Dimensions**:
- 10 disease categories (CD, UC, Healthy, Control, nonIBD, IBS, etc.)
- 8 tissue sources (Blood, Colon, Ileum, Rectum, combinations)
- 15 treatment types (biologics, in vitro treatments)
- 2 experiment types (Microarray, RNA-Seq)

## Comparison Workflow

### Standard Analysis Pipeline

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Target Selection                                         │
│    └─ Select genes, signatures, or pathways of interest    │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. Dataset Filtering                                        │
│    └─ Filter by disease, tissue, treatment, timepoint      │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. Comparison Retrieval                                     │
│    └─ Query database for matching comparisons              │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 4. Results Summary                                          │
│    └─ Generate dataset and comparison summaries            │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 5. Comparison Tables                                        │
│    └─ Display results with statistical filtering           │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 6. Visualization                                            │
│    └─ Generate expression plots and meta-analysis          │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 7. External Database Linking                                │
│    └─ Provide links to NCBI, GO, KEGG, DrugBank, etc.      │
└─────────────────────────────────────────────────────────────┘
```

## Core Comparison Functions

### Database Query Functions

**File**: `app_functions/database_query.R`

| Function | Purpose | Returns |
|----------|---------|---------|
| `get_datasets()` | Filter datasets by criteria | Dataset metadata matching filters |
| `get_comparisons()` | Retrieve comparison definitions | Case vs. control group definitions |
| `get_comparison_data()` | Get DE results for genes | logFC, p-value, adjusted p-value |
| `get_pathway_data()` | Retrieve enrichment results | NES, p-values for pathways |
| `get_selected_comparison_results()` | Get metrics for visualization | Filtered comparison data |
| `get_selected_comparison_expression()` | Retrieve expression values | Raw/normalized expression data |
| `get_sample_ann()` | Get sample metadata | Sample annotations |
| `get_exact_diseases()` | Extract disease classifications | Exact disease terms |

### Summary Generation Functions

**File**: `app_functions/comparison_summary.R`

**Dataset Summary Statistics**:
```r
generate_dataset_summary_table(comparison_data)
# Returns: Total datasets, total comparisons, genes found
```

**Results Summary Tables**:
```r
generate_results_summaries(comparison_data, gene_query)
# Returns: Two tables showing:
#   1. Proportion of datasets with ≥1 significant comparison
#   2. Proportion of significant comparisons per gene
# Organized by disease and experiment type
```

**Format**: `<# significant>/<# total> (% significant)`

**Pathway-Specific Summaries**:
```r
pathway_generate_results_summaries(pathway_data, pathway_query)
# Similar format for pathway enrichment results
```

### Comparison Table Functions

**File**: `app_functions/comparison_tables.R`

**Main Table Generation**:
```r
generate_comparison_tables(comparison_data, dataset_info)
# Returns: Interactive HTML table with:
#   - Rows: Genes
#   - Columns: Datasets/comparisons
#   - Cells: logFC values with color coding
#   - Popovers: Detailed statistics on hover
```

**Table Styling**:
```r
style_comparison_tables(table_data, p_threshold, logfc_threshold)
# Applies color coding:
#   - Blue: Upregulated (logFC > 0, significant)
#   - Red: Downregulated (logFC < 0, significant)
#   - Black: Non-significant (NS)
#   - Red text: Not available (NA)
```

**Gene Signature Tables**:
```r
signature_generate_comparison_tables(signature_data)
# Similar format for gene signature comparisons
```

**Pathway Tables**:
```r
pathway_generate_comparison_tables(pathway_data)
# Format for pathway enrichment comparisons
```

### Visualization Functions

**File**: `app_functions/plot_functions.R`

**Expression Boxplots**:
```r
generate_expression_plots(expression_data, comparison_info, layout = 1)
# Parameters:
#   - layout: 1 (side-by-side) or 2 (sequential)
#   - show_points: Add individual data points with jitter
#   - p_value_type: "p_value" or "p_value_adj"
# Returns: ggplot2 object with boxplots and statistical annotations
```

**Color Coding**:
- Red background: Downregulated
- Blue background: Upregulated
- Black: Non-significant
- Statistical annotations between groups

**Maximum Comparisons**: 6 per visualization session (performance limit)

### Meta-Analysis Functions

**File**: `app_functions/meta_analysis.R`

**Fisher's Method Implementation**:
```r
perform_meta_analysis(comparison_data, gene_symbol)
# Steps:
#   1. Convert two-tailed p-values to one-tailed
#   2. Test upregulation and downregulation separately
#   3. Combine p-values using Fisher's method (poolr package)
#   4. Select more significant direction
#   5. Apply Benjamini-Hochberg correction
# Returns: meta_p_value, meta_p_adj, direction, mean_logFC
```

**One-Tailed P-Value Conversion**:
```r
one_tailed_upreg <- function(p_value, log_fc) {
  ifelse(log_fc > 0, p_value / 2, 1 - p_value / 2)
}

one_tailed_downreg <- function(p_value, log_fc) {
  ifelse(log_fc < 0, p_value / 2, 1 - p_value / 2)
}
```

**Statistical Tests Used**:
- Fisher's method for p-value combination
- Benjamini-Hochberg for FDR correction
- Direction selection based on minimum meta p-value

### Signature Analysis Functions

**File**: `app_functions/signature_scores.R`

**Signature Score Calculation**:
```r
calculate_signature_scores(expression_data, gene_list)
# Returns: Mean expression across genes in signature per sample
```

**Signature Comparison**:
```r
perform_signature_comparisons(signature_scores, sample_annotations)
# Uses Wilcoxon rank sum test to compare case vs. control
# Alternative hypotheses: "two.sided", "greater", "less"
# Returns: p_value, mean_case, mean_control, logFC
```

## Comparison Types

### 1. Gene-Level Comparisons

**Target**: Individual genes
**Input**: Gene symbols (e.g., TNF, IL6, IL1B)
**Output**:
- Comparison table showing logFC per dataset
- Expression boxplots per comparison
- Meta-analysis p-values and direction

**Example Use Case**:
```
Query: TNF across all UC datasets in colon tissue
Result: TNF differential expression in 8 comparisons from 5 datasets
Meta-analysis: Significantly upregulated (meta p = 1.2e-8)
```

### 2. Gene Signature Comparisons

**Target**: Gene sets/signatures
**Input**: List of gene symbols
**Output**:
- Signature score per sample
- Comparison of signature scores case vs. control
- Summary statistics across datasets

**Example Use Case**:
```
Query: Th17 pathway signature (IL17A, IL17F, IL23R, RORC)
Result: Signature elevated in 6/10 CD comparisons
Meta-analysis: Significant upregulation (meta p = 0.003)
```

### 3. Pathway-Level Comparisons

**Target**: KEGG or Reactome pathways
**Input**: Pathway name or ID
**Output**:
- Normalized Enrichment Score (NES) per dataset
- Leading edge genes
- Pathway-level meta-analysis

**Example Use Case**:
```
Query: IL-17 signaling pathway across all IBD datasets
Result: Enriched in 18/30 comparisons
Meta-analysis: Highly significant (meta p = 2.5e-12)
```

## Statistical Methods

### Differential Expression Filtering

**Thresholds** (user-configurable):
- **p-value**: Default 0.05
- **Adjusted p-value (FDR)**: Default 0.05
- **logFC**: Default ±1.0 (2-fold change)

**Filtering Logic**:
```r
significant <- (p_value <= p_threshold | p_value_adj <= p_threshold) &
               abs(log_fc) >= logfc_threshold
```

**Significance Categories**:
- **Upregulated**: logFC > 0 & significant
- **Downregulated**: logFC < 0 & significant
- **Non-significant (NS)**: Not meeting thresholds
- **Not Available (NA)**: Gene not measured or filtered

### Meta-Analysis Methods

**Fisher's Method**:
```
Test statistic: -2 * sum(log(p_i))
Distribution: Chi-squared with 2k degrees of freedom (k = # of studies)
Null hypothesis: No association in any study
Alternative: Association in at least one study
```

**Advantages**:
- Combines evidence across studies
- Accounts for direction of effect
- Robust to heterogeneity

**Limitations**:
- Assumes independence of studies
- May be influenced by outliers
- Does not estimate pooled effect size

**Benjamini-Hochberg Correction**:
```
FDR = (rank / total) * alpha
Adjusted p-value = p-value * (total / rank)
```

**Purpose**: Control false discovery rate in multiple testing

### Wilcoxon Rank Sum Test

**Application**: Gene signature comparisons

**Formula**:
```
U = min(U1, U2)
U1 = n1*n2 + n1*(n1+1)/2 - R1
Where R1 = sum of ranks in group 1
```

**Interpretation**:
- p < 0.05: Significant difference in signature scores between groups
- Direction: Determined by comparing medians or means

## Database Schema for Comparisons

### Comparison Table

**Primary Table**: `comparison` (122 rows)

**Fields**:
- `comparison_id` - Unique identifier (Primary Key)
- `dataset_id` - Foreign key to dataset table
- `case_ann` - Case group annotation (e.g., "CD;Inflamed")
- `control_ann` - Control group annotation (e.g., "Healthy")
- `case_sample` - Number of case samples
- `control_sample` - Number of control samples
- `comparison_group` - Comparison identifier within dataset
- `description` - Human-readable description

**Example Row**:
```
comparison_id: 45
dataset_id: 12
case_ann: "UC;Inflamed;Active"
control_ann: "UC;NonInflamed;Inactive"
case_sample: 24
control_sample: 18
comparison_group: "Inflamed_vs_NonInflamed"
description: "UC inflamed vs non-inflamed mucosa"
```

### Comparison Data Table

**Primary Table**: `comparison_data` (3,079,348 rows)

**Fields**:
- `comparison_id` - Foreign key to comparison table
- `gene` - Foreign key to gene_map table
- `log_fc` - Log2 fold change
- `p_value` - Raw p-value from statistical test
- `p_value_adj` - Adjusted p-value (FDR)

**Example Row**:
```
comparison_id: 45
gene: 8754  (maps to "TNF" in gene_map)
log_fc: 2.34
p_value: 0.00012
p_value_adj: 0.0087
```

### Enrichment Results Table

**Primary Table**: `enrichment_results` (226,505 rows)

**Fields**:
- `enrichment_run_id` - Foreign key to enrichment_run table
- `pathway_id` - Pathway identifier (KEGG or Reactome)
- `pathway_name` - Pathway description
- `nes` - Normalized Enrichment Score
- `p_value` - Enrichment p-value
- `p_value_adj` - Adjusted p-value (FDR)
- `leading_edge` - Core enriched genes

**Example Row**:
```
enrichment_run_id: 78
pathway_id: "hsa04060"
pathway_name: "Cytokine-cytokine receptor interaction"
nes: 2.45
p_value: 0.001
p_value_adj: 0.023
leading_edge: "TNF;IL6;IL1B;CCL2;CXCL8"
```

## User Interface Components

### IBDCompare Tabs

**Tab 1: Dataset Selection**
- **Gene Input**: Text area for gene symbols (comma or newline separated)
- **Disease Filter**: Multi-select (CD, UC, Healthy, Control, etc.)
- **Tissue Filter**: Multi-select (Blood, Colon, Ileum, Rectum, etc.)
- **Treatment Filter**: Multi-select (Infliximab, Vedolizumab, etc.)
- **Timepoint Filter**: Multi-select (Baseline, Week 2, Week 6, etc.)
- **Cell Type Filter**: Multi-select (tissue-dependent)
- **Submit Button**: Execute query

**Tab 2: Results Panel**

**Sub-Tab 2.1: Summary**
- Dataset summary table
  - Total datasets found
  - Total comparisons found
  - Genes found per dataset
- Results summary tables
  - Proportion of datasets with ≥1 significant comparison
  - Proportion of significant comparisons
  - Organized by disease and experiment type

**Sub-Tab 2.2: Comparison Tables**
- Interactive HTML table (reactable or DT)
- Rows: Genes
- Columns: Datasets/comparisons
- Cell content: logFC value with color coding
- Cell popovers: logFC, p-value, adjusted p-value
- Checkbox column: Select comparisons for visualization
- Filter controls:
  - P-value threshold slider
  - LogFC threshold slider
  - P-value type toggle (raw vs. adjusted)
  - Remove NS toggle
  - Similar comparisons toggle

**Sub-Tab 2.3: Expression Visuals**
- Comparison selection: Checkboxes from comparison table (max 6)
- Layout options: Side-by-side (1) or sequential (2)
- Display options:
  - Show data points (jitter)
  - P-value type (raw vs. adjusted)
- Expression boxplots with statistical annotations
- Download button: Save plots as ZIP file

**Sub-Tab 2.4: Database View**
- Hyperlinks to external databases for each gene:
  - NCBI Gene
  - Gene Ontology (GO)
  - REACTOME
  - KEGG
  - Drug Target Commons
  - TTD (Therapeutic Target Database)
  - DrugBank
  - ChEMBL
  - PharmGKB
- Opens in new browser tab

### Comparison Table Features

**Interactive Elements**:
- **Sortable columns**: Click column headers to sort
- **Filterable rows**: Search box for gene symbols
- **Expandable rows**: Click to show detailed statistics
- **Cell tooltips**: Hover for full statistics
- **Pagination**: Navigate through large result sets
- **Export**: Download as CSV

**Color Coding**:
- **Blue background**: Upregulated (logFC > 0, significant)
- **Red background**: Downregulated (logFC < 0, significant)
- **Black text**: Non-significant (NS)
- **Red text**: Not available (NA)

**Cell Content Format**:
```
logFC value (rounded to 2 decimal places)
Example: "2.34" (blue background, upregulated)
Example: "-1.56" (red background, downregulated)
Example: "NS" (black text, non-significant)
Example: "NA" (red text, not available)
```

## Visualization Types

### 1. Expression Boxplots

**Description**: Box-and-whisker plots showing expression distribution per group

**Components**:
- **Box**: Interquartile range (IQR, 25th-75th percentile)
- **Line inside box**: Median
- **Whiskers**: 1.5 * IQR or min/max values
- **Points**: Individual samples (optional jitter)
- **Statistical annotation**: P-value between groups

**Color Scheme**:
- Case group: Red
- Control group: Blue
- Or colored by annotation type (tissue, treatment, etc.)

**Layout Options**:
- **Layout 1**: Side-by-side (all comparisons in one row)
- **Layout 2**: Sequential (each comparison in separate row)

**Example**:
```
Gene: TNF
Comparison 1: CD vs Healthy (p = 0.003)
Comparison 2: UC vs Healthy (p = 0.012)
Layout: Side-by-side
```

### 2. Comparison Heatmaps

**Description**: Color-coded matrix showing logFC values

**Axes**:
- **Rows**: Genes
- **Columns**: Datasets/comparisons

**Color Scale**:
- **Blue**: Positive logFC (upregulated)
- **Red**: Negative logFC (downregulated)
- **White**: logFC ≈ 0
- **Gray**: Non-significant or NA

**Cell Annotations**:
- Asterisks for significance levels
  - `*`: p < 0.05
  - `**`: p < 0.01
  - `***`: p < 0.001

### 3. Meta-Analysis Forest Plots

**Description**: Visual representation of effect sizes and meta-analysis results

**Components**:
- **Study labels**: Left side (dataset IDs)
- **Effect sizes**: Squares (area proportional to weight)
- **Confidence intervals**: Horizontal lines
- **Meta-analysis diamond**: Bottom, showing pooled effect
- **Reference line**: Vertical line at logFC = 0

**Example**:
```
TNF in UC datasets:
GSE16879:  logFC = 2.1  [1.5, 2.7]  ■───────■
GSE3365:   logFC = 1.8  [1.2, 2.4]  ■──────■
GSE4183:   logFC = 2.5  [1.9, 3.1]  ■────────■
Meta:      logFC = 2.1  [1.7, 2.5]  ◆────◆
                        |
                        0
```

## External Database Integration

### Database Links

**File**: `app_functions/comparison_tables.R`

**Integrated Databases**:

1. **NCBI Gene**
   - URL: `https://www.ncbi.nlm.nih.gov/gene/?term={gene_symbol}`
   - Purpose: Gene information, genomic location, expression

2. **Gene Ontology (GO)**
   - URL: `http://amigo.geneontology.org/amigo/search/annotation?q={gene_symbol}`
   - Purpose: Biological process, molecular function, cellular component

3. **REACTOME**
   - URL: `https://reactome.org/content/query?q={gene_symbol}`
   - Purpose: Pathway participation, interactions

4. **KEGG**
   - URL: `https://www.genome.jp/dbget-bin/www_bget?hsa:{gene_symbol}`
   - Purpose: Metabolic and signaling pathways

5. **Drug Target Commons**
   - URL: `http://drugtargetcommons.fimm.fi/search?query={gene_symbol}`
   - Purpose: Drug-target associations

6. **TTD (Therapeutic Target Database)**
   - URL: `http://db.idrblab.net/ttd/search/ttd/target?search_api_fulltext={gene_symbol}`
   - Purpose: Therapeutic target information

7. **DrugBank**
   - URL: `https://go.drugbank.com/unearth/q?query={gene_symbol}`
   - Purpose: Drug-target interactions, pharmacology

8. **ChEMBL**
   - URL: `https://www.ebi.ac.uk/chembl/target_report_card/{gene_symbol}`
   - Purpose: Bioactivity data, compound screening

9. **PharmGKB**
   - URL: `https://www.pharmgkb.org/gene/{gene_symbol}`
   - Purpose: Pharmacogenomics, drug response

**Implementation**:
```r
# Generate hyperlink for each database
create_database_links <- function(gene_symbol) {
  databases <- c("NCBI", "GO", "REACTOME", "KEGG",
                 "DrugTarget", "TTD", "DrugBank", "ChEMBL", "PharmGKB")
  urls <- c(
    sprintf("https://www.ncbi.nlm.nih.gov/gene/?term=%s", gene_symbol),
    sprintf("http://amigo.geneontology.org/amigo/search/annotation?q=%s", gene_symbol),
    # ... etc.
  )

  links <- sapply(1:length(databases), function(i) {
    sprintf('<a href="%s" target="_blank">%s</a>', urls[i], databases[i])
  })

  return(paste(links, collapse = " | "))
}
```

## Usage Examples

### Example 1: Single Gene Comparison

**Objective**: Compare TNF expression across all UC datasets

**Steps**:
1. Navigate to IBDCompare interface
2. Input gene: "TNF"
3. Select disease: "UC"
4. Click "Submit"

**Results**:
```
Dataset Summary:
- 8 datasets found
- 12 comparisons found
- TNF found in all datasets

Comparison Results:
- 10/12 comparisons significant (83%)
- 8/8 datasets with ≥1 significant comparison (100%)

Meta-analysis:
- Meta p-value: 1.2e-8
- Direction: Upregulated
- Mean logFC: 2.15
```

### Example 2: Gene Signature Comparison

**Objective**: Compare Th17 pathway signature across CD datasets in ileum

**Steps**:
1. Navigate to IBDCompare interface
2. Input genes: "IL17A, IL17F, IL23R, RORC, CCR6"
3. Select disease: "CD"
4. Select tissue: "Ileum"
5. Click "Submit"

**Results**:
```
Signature Summary:
- 5 datasets found
- 8 comparisons found
- 4/5 genes found in all datasets (CCR6 missing in 1)

Signature Analysis:
- 6/8 comparisons significant (75%)
- Mean signature score: Case=5.2, Control=3.8
- Wilcoxon p-value: 0.003
```

### Example 3: Pathway Comparison

**Objective**: Compare IL-17 signaling pathway enrichment across all IBD datasets

**Steps**:
1. Navigate to IBDCompare interface
2. Input pathway: "IL-17 signaling pathway" or "hsa04657"
3. Select disease: "CD;UC" (both)
4. Click "Submit"

**Results**:
```
Pathway Summary:
- 30 datasets found
- 45 comparisons found
- Pathway enriched in 18/45 comparisons (40%)

Meta-analysis:
- Meta p-value: 2.5e-12
- Mean NES: 2.34
- Direction: Upregulated
- Leading edge genes: IL17A, IL17F, TNF, CXCL1, CXCL2
```

## Performance Considerations

### Query Optimization

**Database Indexing**:
- Primary keys: `comparison_id`, `dataset_id`, `gene`
- Foreign keys indexed for fast joins
- `p_value` and `log_fc` indexed for filtering

**Query Performance**:
- Gene-level queries: Fast (<1 second for 1-10 genes)
- Signature queries: Moderate (1-5 seconds for 10-50 genes)
- Pathway queries: Fast (pre-computed enrichment results)
- Genome-wide queries: Slow (30+ seconds, not recommended)

### Memory Management

**R Shiny Considerations**:
- Load data on-demand per query
- Use reactive expressions to cache intermediate results
- Limit visualization to 6 comparisons simultaneously
- Implement pagination for large result tables

**Recommended Limits**:
- Genes per query: 1-50 (optimal), up to 100 (acceptable)
- Comparisons for visualization: 1-6 (enforced)
- Datasets selected: No hard limit, but 10-20 recommended

### Visualization Performance

**Plot Rendering**:
- ggplot2 boxplots: Fast for 6 comparisons
- Large heatmaps: Use clustering and subsetting
- Interactive plots: Consider plotly for smaller datasets

**Export Considerations**:
- PNG: Fast, moderate file size
- PDF: Vector graphics, publication quality
- SVG: Editable, large file size for complex plots

## Best Practices

### Query Design

**Effective Queries**:
- Start with specific disease and tissue filters
- Use 1-10 genes for initial exploration
- Expand to signatures or pathways for comprehensive analysis
- Check dataset summary before proceeding to visualization

**Ineffective Queries**:
- No filters (retrieves all datasets, overwhelming)
- >100 genes without filters (slow, too much data)
- Conflicting filters (e.g., "Blood" tissue + "Colon" treatment)

### Statistical Interpretation

**p-value Considerations**:
- Use adjusted p-values (FDR) for multiple testing
- Consider both statistical significance and effect size (logFC)
- Meta-analysis p-values account for multiple studies
- Interpret non-significant results cautiously (may be underpowered)

**Effect Size Guidelines**:
- logFC > 1 or < -1: 2-fold change (typically meaningful)
- logFC > 0.5 or < -0.5: 1.5-fold change (moderate)
- logFC < 0.5 and > -0.5: Small effect (may not be biologically significant)

**Heterogeneity Assessment**:
- Check consistency of direction across studies
- Large variation in logFC suggests heterogeneity
- Consider tissue, treatment, and disease subtype differences

### Reproducibility

**Documentation**:
- Record query parameters (genes, filters, thresholds)
- Save comparison tables and summary statistics
- Export visualizations with captions
- Note database version and access date

**Reporting**:
- Report both individual study results and meta-analysis
- Include number of datasets and comparisons
- Specify statistical methods and thresholds used
- Acknowledge heterogeneity if present

## Troubleshooting

### Common Issues

**Issue 1: No results found**
- Check spelling of gene symbols (case-sensitive)
- Verify filters are not too restrictive
- Ensure gene is measured in selected platform types
- Try broader disease or tissue categories

**Issue 2: Visualization fails to render**
- Reduce number of selected comparisons (<6)
- Check for missing data (NA values)
- Try different layout option
- Clear browser cache and reload

**Issue 3: Slow query performance**
- Reduce number of genes queried
- Add more specific filters
- Avoid genome-wide queries
- Check database connection

**Issue 4: Inconsistent results across studies**
- Expected due to biological heterogeneity
- Check for differences in tissue, treatment, timepoint
- Consider microarray vs. RNA-seq platform differences
- Examine individual study designs

## Future Enhancements

### Planned Features

1. **Advanced Filtering**
   - Filter by sample size (min case/control samples)
   - Filter by effect size (min/max logFC)
   - Filter by platform (specific microarray or RNA-seq methods)

2. **Additional Visualizations**
   - Volcano plots for each comparison
   - MA plots (average expression vs. logFC)
   - Network visualization of gene-gene interactions
   - Correlation heatmaps across datasets

3. **Enhanced Meta-Analysis**
   - Random effects models (account for heterogeneity)
   - I² statistic (quantify heterogeneity)
   - Publication bias assessment (funnel plots)
   - Subgroup meta-analysis (by tissue, treatment, etc.)

4. **Export Functionality**
   - Export all results as Excel workbook
   - Generate automated reports (PDF)
   - Save session state for reproducibility
   - Batch export for multiple genes

5. **Integration with Other Tools**
   - Direct link to STRING for network analysis
   - Export to Cytoscape format
   - Integration with Enrichr for pathway analysis
   - Link to single-cell datasets

## References

- **Database**: `data/IBDTransDB.db`
- **Web Interface**: https://abbviegrc.shinyapps.io/ibdexplore_data/
- **Documentation**: `docs/overview.md`, `docs/dataset-expansion.md`
- **Comparison Module**: `IBDCompare/app_functions/`
- **Statistical Methods**: Fisher's method (poolr R package), Benjamini-Hochberg correction

## Support

For comparison questions or interpretation assistance, refer to the main project documentation or contact the development team.

---

**Last Updated**: 2026-01-12
**Version**: 1.0
**Documentation Author**: IBDTransDB Development Team
