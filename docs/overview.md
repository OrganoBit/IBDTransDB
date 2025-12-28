# IBDTransDB Database Overview

This document provides a comprehensive overview of the IBDTransDB database structure, content, and statistics.

## Database Statistics

| Metric | Count |
|--------|-------|
| **Datasets** | 34 |
| **Comparisons** | 122 |
| **Genes** | 53,653 |
| **Samples** | 2,917 |
| **Expression Data Points** | 72,166,653 |
| **Differential Expression Results** | 3,079,348 |
| **Enrichment Results** | 226,505 |

## Available Data Dimensions

### Diseases/Conditions (10 categories)

The database includes transcriptomic data from the following disease states:

- **CD** - Crohn's Disease
- **UC** - Ulcerative Colitis
- **Healthy** - Healthy controls
- **Control** - General controls
- **nonIBD** - Non-IBD inflammatory conditions
- **IBS** - Irritable Bowel Syndrome

**Combined conditions:**
- CD;Control
- CD;Healthy
- CD;UC
- CD;UC;Healthy
- CD;nonIBD
- UC;Healthy
- UC;IBS
- UC;nonIBD

### Tissue Sources (8 categories)

Data is available from multiple tissue types:

**Single tissue sources:**
- Blood
- Colon
- Ileum
- Rectum

**Multi-tissue datasets:**
- Colon;Ileum
- Colon;Ileum;Rectum
- Colon;Ileum;Rectum;Blood
- Ileum;Rectum

### Treatment Types (15 categories)

The database includes datasets with various treatment conditions:

**Biologics:**
- AntiTNF
- Infliximab
- Golimumab
- Ustekinumab
- Vedolizumab
- Etrolizumab

**Combined treatments:**
- Infliximab;Azathioprine;Mesalamine
- Infliximab;Placebo
- Etrolizumab;Placebo
- Ustekinumab;Placebo;NoTreatment
- Vedolizumab;Infliximab;NoTreatment
- AntiTNF;NoTreatment

**In vitro treatments:**
- LPS;NoTreatment
- LPS;TPT;ETO;DMSO

**No treatment:**
- NoTreatment

## Database Schema

The IBDTransDB SQLite database contains 16 core tables organized into several functional groups:

### Core Data Tables

#### 1. **dataset** (34 rows)
Primary metadata table for transcriptomic studies.

**Key columns:**
- `id` - Primary key
- `dataset_acc` - Dataset accession (e.g., GSE16879)
- `title` - Study title
- `organism` - Species (Homo sapiens, Mus musculus)
- `experiment_type` - Microarray or RNASeq
- `disease` - Disease condition(s)
- `source` - Tissue source(s)
- `treatment` - Treatment condition(s)
- `cell_type` - Cell type (if applicable)
- `timepoint` - Time point of sample collection
- `sample_number` - Number of samples in dataset
- `platform` - Technology platform used
- `normalization_method` - Data normalization approach
- `contact_name`, `contact_email` - Study contact information

#### 2. **dataset_data** (72,166,653 rows)
Expression values storage.

**Key columns:**
- `id` - Primary key
- `dataset_acc` - Foreign key to dataset
- `gene` - Foreign key to gene_map
- `sample_acc` - Foreign key to sample_ann
- `expr` - Expression value (normalized)

**Note:** This is the largest table in the database (~2.9 GB total database size).

#### 3. **comparison** (122 rows)
Differential expression analysis comparisons.

**Key columns:**
- `id` - Primary key
- `dataset_acc` - Foreign key to dataset
- `comparison_group` - Comparison identifier
- `case_ann` - Case group annotation
- `case_sample` - Number of case samples
- `control_ann` - Control group annotation
- `control_sample` - Number of control samples
- `file_name` - Original result file
- `design` - Experimental design
- `method` - Statistical method used
- `paired` - Whether comparison is paired
- `description` - Comparison description

#### 4. **comparison_data** (3,079,348 rows)
Differential expression results.

**Key columns:**
- `id` - Primary key
- `comparison_id` - Foreign key to comparison
- `gene` - Foreign key to gene_map
- `log_fc` - Log fold change
- `p_value` - P-value
- `p_value_adj` - Adjusted p-value (FDR)

### Gene and Sample Tables

#### 5. **gene_map** (53,653 genes)
Master gene reference table.

**Key columns:**
- `id` - Primary key
- `gene` - Gene symbol/name

This table serves as the central gene identifier mapping used throughout the database.

#### 6. **sample_ann** (2,917 rows)
Sample metadata and annotations.

**Key columns:**
- `id` - Primary key
- `dataset_acc` - Foreign key to dataset
- `sample_id` - Sample identifier
- `sample_ann_type` - Annotation type (Disease, Source, Treatment, etc.)
- `sample_ann_value` - Annotation value
- `created_by` - Creator
- `created_at` - Creation timestamp

**Common annotation types:**
- Disease
- Source (tissue)
- Treatment
- Timepoint
- Dose
- Activity
- Subject ID
- Age
- Sex
- Response metrics (W6_Response, Mayo_Response, etc.)

### Analysis Results Tables

#### 7. **cell_deconvolution** (144,477 rows)
Cell type composition estimates.

**Key columns:**
- `id` - Primary key
- `dataset_acc` - Foreign key to dataset
- `sample_id` - Sample identifier
- `cell_type` - Cell type name
- `fraction` - Estimated fraction/proportion

#### 8. **pca** (2,917 rows)
Principal Component Analysis coordinates.

**Key columns:**
- `id` - Primary key
- `dataset_acc` - Foreign key to dataset
- `sample_id` - Sample identifier
- `pc1` to `pc10` - Principal component coordinates

#### 9. **pca_variance**
PCA variance explained.

**Key columns:**
- `id` - Primary key
- `dataset_acc` - Foreign key to dataset
- `pc` - Principal component number
- `variance` - Variance explained

### Pathway Enrichment Tables

#### 10. **enrichment_run** (244 rows)
Pathway enrichment analysis metadata.

**Key columns:**
- `id` - Primary key
- `dataset_acc` - Foreign key to dataset
- `comparison_id` - Foreign key to comparison
- `database` - Pathway database (KEGG or Reactome)

**Databases:**
- pathway_KEGG (122 runs)
- pathway_Reactome (122 runs)

#### 11. **enrichment_results** (226,505 rows)
Pathway enrichment results.

**Key columns:**
- `id` - Primary key
- `enrichment_run_id` - Foreign key to enrichment_run
- `geneset` - Pathway/gene set ID
- `description` - Pathway description
- `size` - Gene set size
- `leading_edge_number` - Number of leading edge genes
- `es` - Enrichment score
- `nes` - Normalized enrichment score
- `p_value` - P-value
- `p_value_adj` - Adjusted p-value

#### 12. **enrichment_leading_edge**
Leading edge genes from enrichment.

**Key columns:**
- `id` - Primary key
- `enrichment_results_id` - Foreign key to enrichment_results
- `gene` - Gene symbol
- `score` - Gene score

### Reference and Metadata Tables

#### 13. **keyword**
Controlled vocabulary and ontology mappings.

**Key columns:**
- `keyword_id` - Primary key
- `ontology_id` - Ontology identifier
- `ontology_group` - Ontology group
- `ontology_link` - Link to ontology resource
- `keyword_type` - Type (Disease, Source, CellType, etc.)
- `arch_keyword` - Archived keyword
- `keyword` - Current keyword
- `old_keyword` - Previous keyword
- `synonyms` - Alternative terms

**Keyword types:**
- Disease
- ExperimentType
- Source (tissue)
- CellType
- Treatment
- Timepoint

#### 14. **gene_type**
Predefined gene functional groups.

**Key columns:**
- `id` - Primary key
- `type` - Gene group type
- `gene` - Gene symbol

**Predefined groups:**
- chemokine
- interleukin
- TNF super family

#### 15. **database**
External database references.

**Key columns:**
- `database_name` - Database short name
- `database_full_name` - Full database name
- `type` - Database type
- `summary` - Description
- `link` - Database URL

**Referenced databases:**
- NCBI
- GO (Gene Ontology)
- REACTOME
- KEGG
- Drug Target Commons
- TTD (Therapeutic Target Database)
- DrugBank
- ChEMBL
- PharmGKB

## Data Relationships

### Primary Relationships

```
dataset (1) ──→ (N) dataset_data
dataset (1) ──→ (N) comparison
dataset (1) ──→ (N) sample_ann
dataset (1) ──→ (N) cell_deconvolution
dataset (1) ──→ (N) pca
dataset (1) ──→ (N) enrichment_run

comparison (1) ──→ (N) comparison_data
comparison (1) ──→ (N) enrichment_run

enrichment_run (1) ──→ (N) enrichment_results
enrichment_results (1) ──→ (N) enrichment_leading_edge

gene_map (1) ──→ (N) dataset_data
gene_map (1) ──→ (N) comparison_data
```

### Data Flow

1. **Dataset** → Contains metadata about the study
2. **Samples** → Sample annotations linked to dataset
3. **Expression Data** → Raw expression values for each gene/sample
4. **Comparisons** → Define case vs. control comparisons within dataset
5. **Differential Expression** → Statistical results for each comparison
6. **Enrichment** → Pathway analysis results for significant genes

## Data Access Patterns

### Common Query Patterns

**1. Find datasets by criteria:**
```sql
SELECT * FROM dataset
WHERE disease LIKE '%UC%'
  AND source = 'Colon';
```

**2. Get expression data for specific genes:**
```sql
SELECT d.gene, d.sample_acc, d.expr
FROM dataset_data d
JOIN gene_map g ON d.gene = g.id
WHERE d.dataset_acc = 'GSE16879'
  AND g.gene IN ('TNF', 'IL6', 'IL1B');
```

**3. Find differential expression results:**
```sql
SELECT c.comparison_group, g.gene, cd.log_fc, cd.p_value_adj
FROM comparison_data cd
JOIN comparison c ON cd.comparison_id = c.id
JOIN gene_map g ON cd.gene = g.id
WHERE c.dataset_acc = 'GSE16879'
  AND cd.p_value_adj < 0.05
ORDER BY ABS(cd.log_fc) DESC;
```

**4. Get pathway enrichment:**
```sql
SELECT er.description, er.nes, er.p_value_adj
FROM enrichment_results er
JOIN enrichment_run en ON er.enrichment_run_id = en.id
WHERE en.comparison_id = 1
  AND en.database = 'pathway_KEGG'
  AND er.p_value_adj < 0.05
ORDER BY er.nes DESC;
```

## Data Quality and Coverage

### Platform Distribution
- **Microarray**: Earlier datasets (GEO, ArrayExpress)
- **RNA-Seq**: More recent datasets

### Species Coverage
- **Homo sapiens**: Human IBD studies
- **Mus musculus**: Mouse model studies (if applicable)

### Temporal Coverage
The database includes datasets spanning multiple years of IBD research, providing both historical context and recent findings.

### Sample Size Distribution
- Small studies: 10-50 samples
- Medium studies: 50-200 samples
- Large studies: 200+ samples
- Total samples: 2,917 across all datasets

## Database Characteristics

### Size and Performance
- **Database file size**: ~2.9 GB
- **Largest table**: `dataset_data` (72M rows)
- **Indexing**: Optimized for foreign key relationships
- **Read-only access**: Database designed for query-only operations

### Data Integrity
- **Foreign key constraints**: Maintain referential integrity
- **Controlled vocabulary**: Standardized through keyword table
- **Gene mapping**: Central gene_map ensures consistent identifiers
- **Unique identifiers**: Dataset accessions (GEO/ArrayExpress IDs)

## Using the Database

### CLI Tool
Use the `ibdtransdb` CLI to explore the database:

```bash
# View statistics
ibdtransdb inspect stats

# List all tables
ibdtransdb inspect tables

# View table schema
ibdtransdb inspect schema dataset

# Browse datasets
ibdtransdb datasets list --disease UC --tissue Colon

# Run custom queries
ibdtransdb inspect query "SELECT COUNT(DISTINCT gene) FROM comparison_data WHERE p_value_adj < 0.05"
```

### R Shiny Applications
The database powers four web applications:
- **IBDExplore**: Single dataset exploration
- **IBDCompare**: Multi-dataset comparison
- **IBDIntegrate**: Meta-analysis and target prioritization
- **IBDTransDB Home**: Navigation and overview

## References

For dataset-specific information, contact information, and original publications, query the `dataset` table or use the IBDTransDB web interface.

## Next Steps

- **Dataset Expansion**: See [Dataset Expansion Guide](dataset-expansion.md) for adding new data
- **Setup Instructions**: See [Setup Guide](setup-instruction.md) for installation
- **Main README**: See [README](../README.md) for project overview
