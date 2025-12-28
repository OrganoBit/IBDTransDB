# Dataset Expansion Guide for IBDTransDB

This guide provides comprehensive instructions for identifying, validating, and integrating new transcriptomic datasets into IBDTransDB.

## Table of Contents

- [Data Discovery](#data-discovery)
- [Deduplication Checks](#deduplication-checks)
- [Dataset Eligibility Criteria](#dataset-eligibility-criteria)
- [Required Data Structure](#required-data-structure)
- [Data Processing Pipeline](#data-processing-pipeline)
- [Quality Control](#quality-control)
- [Integration Workflow](#integration-workflow)

---

## Data Discovery

### Primary Data Sources

#### 1. Gene Expression Omnibus (GEO)
**URL**: https://www.ncbi.nlm.nih.gov/geo/

**Search strategies:**
```
("inflammatory bowel disease"[MeSH Terms] OR "IBD"[All Fields]) AND Homo sapiens[Organism]
("Crohn disease"[MeSH Terms] OR "Crohn's disease"[All Fields]) AND expression profiling
("Colitis, Ulcerative"[MeSH Terms] OR "ulcerative colitis"[All Fields]) AND transcriptome
```

**Filters to apply:**
- Study type: Expression profiling by array OR Expression profiling by high throughput sequencing
- Organism: Homo sapiens (or Mus musculus for mouse models)
- Entry type: Series

#### 2. ArrayExpress
**URL**: https://www.ebi.ac.uk/biostudies/arrayexpress

**Search strategies:**
```
inflammatory bowel disease
Crohn's disease transcriptome
ulcerative colitis RNA-seq
IBD expression profiling
```

#### 3. Additional Sources

- **SRA (Sequence Read Archive)**: For raw RNA-seq data
- **dbGaP**: For controlled-access datasets
- **Literature mining**: PubMed for IBD transcriptomic studies
- **Preprint servers**: bioRxiv, medRxiv for recent data

### Search Criteria Checklist

When searching for new datasets, ensure they meet these criteria:

- [ ] **Disease relevance**: IBD, CD, UC, or related conditions
- [ ] **Tissue types**: Intestinal (colon, ileum, rectum) or blood
- [ ] **Technology**: Microarray or RNA-seq
- [ ] **Sample size**: Minimum 10 samples (preferably 20+)
- [ ] **Metadata availability**: Clear sample annotations
- [ ] **Data accessibility**: Publicly available
- [ ] **Quality**: Well-documented, peer-reviewed preferred

---

## Deduplication Checks

**CRITICAL**: Always verify that a dataset is not already in IBDTransDB before processing.

### Step 1: Check GEO/ArrayExpress Accession

```bash
# Using CLI
ibdtransdb inspect query "SELECT dataset_acc, title FROM dataset WHERE dataset_acc = 'GSE######'"

# Using R
db <- dbConnect(RSQLite::SQLite(), "IBDTransDB.db")
existing <- dbGetQuery(db, "SELECT * FROM dataset WHERE dataset_acc = 'GSE######'")
```

### Step 2: Check by Title/Publication

```bash
# Search by title keywords
ibdtransdb inspect query "SELECT dataset_acc, title FROM dataset WHERE title LIKE '%keyword%'"

# Check all existing datasets
ibdtransdb datasets list --format csv > existing_datasets.csv
```

### Step 3: Cross-Reference Metadata

Compare the following fields to identify potential duplicates:

| Field | Description | How to Check |
|-------|-------------|--------------|
| **dataset_acc** | GEO/ArrayExpress ID | Exact match |
| **title** | Study title | Fuzzy match, check for variations |
| **contact_name** | Principal investigator | Name matching |
| **sample_number** | Number of samples | Should match |
| **platform** | Array/sequencing platform | Should match |
| **organism** | Species | Must match |

### Step 4: Publication DOI Check

- Check if the same publication is referenced
- Look for supplementary data accession numbers in the paper
- Search PubMed for the accession number

### Deduplication Decision Tree

```
Is GEO/ArrayExpress accession in database?
├─ YES → Skip dataset (already included)
└─ NO → Continue
    │
    Is there a dataset with very similar title/metadata?
    ├─ YES → Manual review required
    │   └─ Could be different analyses of same data
    └─ NO → Proceed with inclusion
```

---

## Dataset Eligibility Criteria

### Inclusion Criteria

#### 1. **Disease Relevance**
- Primary focus on IBD (Crohn's Disease, Ulcerative Colitis)
- Related conditions: IBS, non-IBD inflammatory conditions (as controls)
- Appropriate healthy controls included

#### 2. **Sample Requirements**
- **Minimum samples**: 10 total
- **Recommended**: 20+ samples
- **Optimal**: 50+ samples with balanced groups
- Clear case/control groups for differential expression

#### 3. **Tissue/Source Requirements**

**Preferred tissues:**
- Intestinal biopsies (colon, ileum, rectum)
- Blood (PBMC, whole blood)

**Acceptable:**
- Organoids or cell lines (with annotation)
- Mouse models (clearly labeled)

**Generally excluded:**
- Unrelated tissues (e.g., skin, liver) unless mechanistically relevant

#### 4. **Technology Requirements**

**Microarray:**
- Common platforms (Affymetrix, Illumina, Agilent)
- Normalized data available
- Annotation/platform files accessible

**RNA-Seq:**
- Raw counts or FPKM/TPM available
- Sequencing depth ≥10M reads (preferred ≥20M)
- Gene-level quantification

#### 5. **Metadata Requirements**

**Essential metadata:**
- Sample identifiers
- Disease state (CD, UC, healthy, etc.)
- Tissue source
- Treatment status (if applicable)

**Highly desirable:**
- Demographics (age, sex)
- Disease activity/severity
- Treatment response
- Time points

**Optional but valuable:**
- Clinical scores (CDAI, Mayo, etc.)
- Endoscopic findings
- Medication history
- Batch information

### Exclusion Criteria

- [ ] Duplicate of existing dataset
- [ ] Insufficient sample size (<10 samples)
- [ ] Poor quality data (high failure rate, low coverage)
- [ ] Missing critical metadata
- [ ] Non-IBD focus without clear relevance
- [ ] Proprietary/restricted access data
- [ ] Data from irrelevant tissue types
- [ ] Single-cell RNA-seq (different database structure needed)

---

## Required Data Structure

New datasets must be formatted to match the existing IBDTransDB schema.

### 1. Dataset Metadata

**Table**: `dataset`

| Column | Type | Required | Description | Example |
|--------|------|----------|-------------|---------|
| `dataset_acc` | TEXT | YES | GEO/ArrayExpress accession | GSE16879 |
| `title` | TEXT | YES | Study title | "Gene expression in UC colon biopsies" |
| `organism` | TEXT | YES | Species | Homo sapiens |
| `experiment_type` | TEXT | YES | Technology | Microarray or RNASeq |
| `disease` | TEXT | YES | Disease state(s) | UC;Healthy |
| `source` | TEXT | YES | Tissue source(s) | Colon |
| `treatment` | TEXT | NO | Treatment(s) | Infliximab;NoTreatment |
| `response` | TEXT | NO | Response metric | Responder;NonResponder |
| `sample_number` | INTEGER | YES | Total samples | 48 |
| `platform` | TEXT | YES | Platform/technology | Illumina HiSeq 2000 |
| `normalization_method` | TEXT | YES | Normalization approach | RMA, DESeq2, etc. |
| `cell_type` | TEXT | NO | Cell type (if sorted) | PBMC, epithelial |
| `timepoint` | TEXT | NO | Time point(s) | Week0;Week8;Week52 |
| `dose` | TEXT | NO | Dosage information | 5mg/kg |
| `age_group` | TEXT | NO | Age category | Adult, Pediatric |
| `contact_name` | TEXT | NO | PI name | John Doe |
| `contact_email` | TEXT | NO | PI email | jdoe@university.edu |

**Format notes:**
- Use semicolon (`;`) to separate multiple values
- Use consistent controlled vocabulary (see keyword table)
- Use `NoTreatment` for untreated samples

### 2. Sample Annotations

**Table**: `sample_ann`

| Column | Type | Required | Description |
|--------|------|----------|-------------|
| `dataset_acc` | TEXT | YES | Foreign key to dataset |
| `sample_id` | TEXT | YES | Sample identifier |
| `sample_ann_type` | TEXT | YES | Annotation category |
| `sample_ann_value` | TEXT | YES | Annotation value |

**Required annotation types:**
- `Disease`: CD, UC, Healthy, Control, etc.
- `Source`: Colon, Ileum, Blood, etc.

**Common annotation types:**
- `Treatment`: Drug names or NoTreatment
- `Timepoint`: Time of sampling
- `Response`: Response classification
- `SubjectID`: Patient/subject identifier
- `Age`: Age in years
- `Sex`: Male/Female
- `Activity`: Disease activity score

**Example:**
```csv
dataset_acc,sample_id,sample_ann_type,sample_ann_value
GSE16879,GSM421380,Disease,UC
GSE16879,GSM421380,Source,Colon
GSE16879,GSM421380,Treatment,NoTreatment
GSE16879,GSM421381,Disease,Healthy
GSE16879,GSM421381,Source,Colon
GSE16879,GSM421381,Treatment,NoTreatment
```

### 3. Expression Data

**Table**: `dataset_data`

| Column | Type | Required | Description |
|--------|------|----------|-------------|
| `dataset_acc` | TEXT | YES | Foreign key to dataset |
| `gene` | INTEGER | YES | Foreign key to gene_map (gene ID) |
| `sample_acc` | TEXT | YES | Sample identifier |
| `expr` | REAL | YES | Expression value (normalized) |

**Data requirements:**
- Expression values must be normalized
- Gene symbols must map to gene_map table
- One row per gene-sample pair

**Gene mapping:**
```sql
-- Get gene ID from gene symbol
SELECT id FROM gene_map WHERE gene = 'TNF';

-- Add new genes if needed
INSERT INTO gene_map (gene) VALUES ('NEW_GENE_SYMBOL');
```

### 4. Comparison Metadata

**Table**: `comparison`

| Column | Type | Required | Description |
|--------|------|----------|-------------|
| `dataset_acc` | TEXT | YES | Foreign key to dataset |
| `comparison_group` | TEXT | YES | Comparison identifier |
| `case_ann` | TEXT | YES | Case group label |
| `case_sample` | INTEGER | YES | Number of case samples |
| `control_ann` | TEXT | YES | Control group label |
| `control_sample` | INTEGER | YES | Number of control samples |
| `file_name` | TEXT | NO | Result file name |
| `design` | TEXT | NO | Experimental design |
| `method` | TEXT | YES | Statistical method |
| `paired` | TEXT | NO | Paired (Yes/No) |
| `description` | TEXT | NO | Comparison description |

**Example comparisons:**
- UC_vs_Healthy: Active UC colon vs healthy colon
- CD_Responder_vs_NonResponder: Treatment responders vs non-responders
- Week8_vs_Week0: Post-treatment vs baseline

### 5. Differential Expression Results

**Table**: `comparison_data`

| Column | Type | Required | Description |
|--------|------|----------|-------------|
| `comparison_id` | INTEGER | YES | Foreign key to comparison |
| `gene` | INTEGER | YES | Foreign key to gene_map |
| `log_fc` | REAL | YES | Log fold change |
| `p_value` | REAL | YES | P-value |
| `p_value_adj` | REAL | YES | Adjusted p-value (FDR) |

**Statistical requirements:**
- Log fold change (log2 preferred)
- Raw p-values
- FDR-adjusted p-values (Benjamini-Hochberg recommended)

---

## Data Processing Pipeline

### Step 1: Data Download

```bash
# For GEO datasets
wget "https://ftp.ncbi.nlm.nih.gov/geo/series/GSE###nnn/GSE######/matrix/GSE######_series_matrix.txt.gz"

# For raw counts (RNA-seq)
# Use GEOquery or similar tools
```

### Step 2: Data Normalization

**Microarray:**
- RMA (Robust Multi-array Average)
- Quantile normalization
- Background correction

**RNA-Seq:**
- DESeq2 normalization
- TMM (edgeR)
- TPM/FPKM for expression values

### Step 3: Gene Symbol Mapping

```r
# Example: Convert probe IDs to gene symbols
library(annotate)
library(hgu133plus2.db)

# Get probe annotations
genes <- getSYMBOL(probe_ids, 'hgu133plus2.db')

# Map to gene_map table
gene_ids <- sapply(genes, function(g) {
  dbGetQuery(db, paste0("SELECT id FROM gene_map WHERE gene = '", g, "'"))
})
```

### Step 4: Differential Expression Analysis

**Recommended tools:**
- **Microarray**: limma
- **RNA-Seq**: DESeq2, edgeR

**Standard workflow:**
```r
# Example with DESeq2
library(DESeq2)

dds <- DESeqDataSetFromMatrix(
  countData = counts,
  colData = metadata,
  design = ~ condition
)

dds <- DESeq(dds)
results <- results(dds, contrast = c("condition", "UC", "Healthy"))

# Extract required columns
comparison_data <- data.frame(
  gene = rownames(results),
  log_fc = results$log2FoldChange,
  p_value = results$pvalue,
  p_value_adj = results$padj
)
```

### Step 5: Pathway Enrichment (Optional)

```r
# GSEA or similar
library(fgsea)

# Run enrichment for KEGG and Reactome
kegg_results <- run_enrichment(genes, database = "KEGG")
reactome_results <- run_enrichment(genes, database = "Reactome")
```

---

## Quality Control

### Pre-Integration QC Checklist

#### Data Quality
- [ ] All required columns populated
- [ ] No duplicate rows (dataset_acc + gene + sample_acc unique)
- [ ] Expression values in reasonable range (not all zeros/NA)
- [ ] Gene symbols valid and mapped to gene_map
- [ ] Sample IDs consistent across tables

#### Metadata Quality
- [ ] All samples have Disease and Source annotations
- [ ] Controlled vocabulary used consistently
- [ ] No missing critical metadata
- [ ] Sample numbers match across tables

#### Statistical Quality
- [ ] Differential expression results have p-values and fold changes
- [ ] Adjusted p-values calculated (FDR)
- [ ] Reasonable number of significant genes (not 0, not 100%)
- [ ] Log fold changes in expected range (-10 to +10)

#### Referential Integrity
- [ ] All dataset_acc in child tables exist in dataset table
- [ ] All gene IDs exist in gene_map table
- [ ] All comparison_id exist in comparison table
- [ ] No orphaned records

### QC SQL Queries

```sql
-- Check for missing metadata
SELECT dataset_acc FROM dataset WHERE disease IS NULL OR source IS NULL;

-- Check for duplicate samples
SELECT dataset_acc, sample_id, COUNT(*)
FROM sample_ann
GROUP BY dataset_acc, sample_id
HAVING COUNT(*) > 1;

-- Check gene mapping
SELECT DISTINCT d.gene
FROM dataset_data d
LEFT JOIN gene_map g ON d.gene = g.id
WHERE g.id IS NULL;

-- Verify sample counts
SELECT d.dataset_acc, d.sample_number, COUNT(DISTINCT s.sample_id) as actual_samples
FROM dataset d
LEFT JOIN sample_ann s ON d.dataset_acc = s.dataset_acc
GROUP BY d.dataset_acc
HAVING d.sample_number != actual_samples;

-- Check for reasonable p-value distribution
SELECT comparison_id,
       COUNT(*) as total_genes,
       SUM(CASE WHEN p_value_adj < 0.05 THEN 1 ELSE 0 END) as sig_genes
FROM comparison_data
GROUP BY comparison_id;
```

---

## Integration Workflow

### Step-by-Step Integration Process

#### 1. Prepare Data Files

Organize your data into these files:
```
new_dataset/
├── dataset_metadata.csv       # Dataset table row
├── sample_annotations.csv     # Sample annotations
├── expression_data.csv        # Expression values (can be large)
├── comparisons.csv            # Comparison definitions
├── comparison_results.csv     # Differential expression results
└── enrichment_results.csv     # Pathway enrichment (optional)
```

#### 2. Validate Data Format

```r
# Validation script
source("scripts/validate_new_dataset.R")

validation_results <- validate_dataset(
  dataset_file = "new_dataset/dataset_metadata.csv",
  samples_file = "new_dataset/sample_annotations.csv",
  expression_file = "new_dataset/expression_data.csv",
  comparison_file = "new_dataset/comparisons.csv",
  results_file = "new_dataset/comparison_results.csv"
)

# Review validation report
print(validation_results)
```

#### 3. Test Integration (Staging Database)

```r
# Create staging database
db_staging <- dbConnect(RSQLite::SQLite(), "IBDTransDB_staging.db")

# Copy structure from production
# (SQL schema available in repository)

# Insert new dataset
insert_dataset(db_staging, "new_dataset/dataset_metadata.csv")
insert_samples(db_staging, "new_dataset/sample_annotations.csv")
insert_expression_data(db_staging, "new_dataset/expression_data.csv")
insert_comparisons(db_staging, "new_dataset/comparisons.csv")
insert_comparison_data(db_staging, "new_dataset/comparison_results.csv")

# Run QC on staging database
qc_results <- run_qc_checks(db_staging)
```

#### 4. Review and Approve

- Review QC report
- Check that dataset appears correctly in CLI:
  ```bash
  ibdtransdb --db IBDTransDB_staging.db datasets list
  ibdtransdb --db IBDTransDB_staging.db datasets info NEW_ACC
  ```
- Verify differential expression results
- Test in RShiny apps (optional)

#### 5. Production Integration

```r
# Backup production database
file.copy("IBDTransDB.db", "IBDTransDB_backup_YYYYMMDD.db")

# Connect to production
db_prod <- dbConnect(RSQLite::SQLite(), "IBDTransDB.db")

# Insert validated data
dbBegin(db_prod)
tryCatch({
  insert_dataset(db_prod, "new_dataset/dataset_metadata.csv")
  insert_samples(db_prod, "new_dataset/sample_annotations.csv")
  insert_expression_data(db_prod, "new_dataset/expression_data.csv")
  insert_comparisons(db_prod, "new_dataset/comparisons.csv")
  insert_comparison_data(db_prod, "new_dataset/comparison_results.csv")

  dbCommit(db_prod)
  message("Dataset successfully integrated!")
}, error = function(e) {
  dbRollback(db_prod)
  stop("Integration failed: ", e$message)
})
```

#### 6. Update Statistics

```bash
# Verify new dataset count
ibdtransdb inspect stats

# Update documentation if needed
# - Update docs/overview.md with new statistics
# - Add dataset to any relevant lists
```

#### 7. Testing Post-Integration

```bash
# Test CLI
ibdtransdb datasets list
ibdtransdb datasets info NEW_ACCESSION
ibdtransdb inspect query "SELECT COUNT(*) FROM comparison WHERE dataset_acc = 'NEW_ACCESSION'"

# Test RShiny apps (if applicable)
# - Run IBDExplore
# - Verify new dataset appears
# - Test all functionality
```

---

## Best Practices

### General Guidelines

1. **Document everything**: Keep notes on data source, processing steps, issues encountered
2. **Version control**: Track changes to processing scripts
3. **Reproducibility**: Script all processing steps (no manual Excel edits)
4. **Backup**: Always backup before production integration
5. **Test thoroughly**: Use staging database for testing

### Common Issues and Solutions

#### Issue: Gene symbol mismatches
**Solution**: Use HGNC official symbols, create mapping file for aliases

#### Issue: Missing metadata
**Solution**: Contact authors, check supplementary materials, use GEO annotations

#### Issue: Batch effects
**Solution**: Document batch structure, consider ComBat or similar correction

#### Issue: Different normalization
**Solution**: Document method, ensure consistency within dataset

### Contact and Support

For questions about dataset expansion:
- Review existing datasets for examples
- Check documentation: `docs/overview.md`
- Contact: [Contact information from README]

---

## Appendix: Controlled Vocabulary

### Disease Terms
- CD (Crohn's Disease)
- UC (Ulcerative Colitis)
- Healthy (healthy controls)
- Control (general controls)
- nonIBD (non-IBD inflammatory)
- IBS (Irritable Bowel Syndrome)

### Tissue/Source Terms
- Blood
- Colon
- Ileum
- Rectum
- PBMC (peripheral blood mononuclear cells)

### Treatment Terms
Use generic drug names:
- Infliximab
- Adalimumab
- Vedolizumab
- Ustekinumab
- Golimumab
- Etrolizumab
- NoTreatment (for untreated samples)
- Placebo (for placebo controls)

### Experiment Types
- Microarray
- RNASeq

### Response Terms
- Responder
- NonResponder
- PartialResponder

Use semicolons to separate multiple values in combined fields.
