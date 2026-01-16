"""Input validation utilities"""
from pathlib import Path
from typing import List, Optional, Dict, Any
from scripts.db import IBDTransDB


class Validator:
    """Validate CLI inputs against database"""

    def __init__(self, db_path: Path):
        """
        Initialize validator

        Args:
            db_path: Path to IBDTransDB.db
        """
        self.db_path = db_path

    def validate_dataset(self, dataset_acc: str) -> bool:
        """
        Check if dataset exists

        Args:
            dataset_acc: Dataset accession (e.g., GSE16879)

        Returns:
            True if dataset exists
        """
        with IBDTransDB(self.db_path) as db:
            result = db.query(
                "SELECT COUNT(*) as count FROM dataset WHERE dataset_acc = ?",
                (dataset_acc,)
            )
            return result[0]["count"] > 0

    def validate_comparison(self, comparison_id: int) -> bool:
        """
        Check if comparison exists

        Args:
            comparison_id: Comparison ID

        Returns:
            True if comparison exists
        """
        with IBDTransDB(self.db_path) as db:
            result = db.query(
                "SELECT COUNT(*) as count FROM comparison WHERE id = ?",
                (comparison_id,)
            )
            return result[0]["count"] > 0

    def validate_genes(self, genes: List[str]) -> Dict[str, List[str]]:
        """
        Check which genes exist in database

        Args:
            genes: List of gene symbols

        Returns:
            Dictionary with 'valid' and 'invalid' gene lists
        """
        with IBDTransDB(self.db_path) as db:
            if not genes:
                return {"valid": [], "invalid": []}

            # Query for existing genes
            placeholders = ','.join('?' * len(genes))
            result = db.query(
                f"SELECT DISTINCT symbol FROM gene_map WHERE symbol IN ({placeholders})",
                tuple(genes)
            )

            valid_genes = {row["symbol"] for row in result}
            invalid_genes = [g for g in genes if g not in valid_genes]

            return {
                "valid": list(valid_genes),
                "invalid": invalid_genes
            }

    def get_dataset_info(self, dataset_acc: str) -> Optional[Dict[str, Any]]:
        """
        Get dataset information

        Args:
            dataset_acc: Dataset accession

        Returns:
            Dictionary with dataset info, or None if not found
        """
        with IBDTransDB(self.db_path) as db:
            result = db.query(
                "SELECT * FROM dataset WHERE dataset_acc = ?",
                (dataset_acc,)
            )

            if result:
                return result[0]
            return None

    def get_available_annotations(self, dataset_acc: str) -> List[str]:
        """
        Get available sample annotation types for a dataset

        Args:
            dataset_acc: Dataset accession

        Returns:
            List of annotation types (e.g., Disease, Source, Treatment)
        """
        with IBDTransDB(self.db_path) as db:
            result = db.query(
                """SELECT DISTINCT annotation_type
                   FROM sample_ann
                   WHERE dataset_acc = ?""",
                (dataset_acc,)
            )

            # Parse semicolon-separated annotation types
            ann_types = set()
            for row in result:
                if row["annotation_type"]:
                    types = str(row["annotation_type"]).split(";")
                    ann_types.update(t.strip() for t in types if t.strip())

            return sorted(ann_types)

    def get_dataset_comparisons(self, dataset_acc: str) -> List[Dict[str, Any]]:
        """
        Get all comparisons for a dataset

        Args:
            dataset_acc: Dataset accession

        Returns:
            List of comparison dictionaries
        """
        with IBDTransDB(self.db_path) as db:
            result = db.query(
                """SELECT id as comparison_id, case_ann, control_ann,
                          case_sample, control_sample, description
                   FROM comparison
                   WHERE dataset_acc = ?""",
                (dataset_acc,)
            )
            return result

    def validate_filters(
        self,
        diseases: Optional[List[str]] = None,
        tissues: Optional[List[str]] = None,
        treatments: Optional[List[str]] = None,
        organisms: Optional[List[str]] = None
    ) -> Dict[str, Dict[str, List[str]]]:
        """
        Validate filter values against available options

        Args:
            diseases: List of disease filters
            tissues: List of tissue/source filters
            treatments: List of treatment filters
            organisms: List of organism filters

        Returns:
            Dictionary with valid and invalid values for each filter type
        """
        results = {}

        with IBDTransDB(self.db_path) as db:
            # Validate diseases
            if diseases:
                valid_diseases = {
                    row["disease"]
                    for row in db.query("SELECT DISTINCT disease FROM dataset")
                }
                results["diseases"] = {
                    "valid": [d for d in diseases if d in valid_diseases],
                    "invalid": [d for d in diseases if d not in valid_diseases]
                }

            # Validate tissues
            if tissues:
                valid_tissues = {
                    row["source"]
                    for row in db.query("SELECT DISTINCT source FROM dataset")
                }
                results["tissues"] = {
                    "valid": [t for t in tissues if t in valid_tissues],
                    "invalid": [t for t in tissues if t not in valid_tissues]
                }

            # Validate treatments
            if treatments:
                valid_treatments = {
                    row["treatment"]
                    for row in db.query("SELECT DISTINCT treatment FROM dataset")
                }
                results["treatments"] = {
                    "valid": [t for t in treatments if t in valid_treatments],
                    "invalid": [t for t in treatments if t not in valid_treatments]
                }

            # Validate organisms
            if organisms:
                valid_organisms = {
                    row["organism"]
                    for row in db.query("SELECT DISTINCT organism FROM dataset")
                }
                results["organisms"] = {
                    "valid": [o for o in organisms if o in valid_organisms],
                    "invalid": [o for o in organisms if o not in valid_organisms]
                }

        return results

    def get_filter_options(self) -> Dict[str, List[str]]:
        """
        Get all available filter options

        Returns:
            Dictionary with available diseases, tissues, treatments, organisms
        """
        with IBDTransDB(self.db_path) as db:
            return {
                "diseases": sorted({
                    row["disease"]
                    for row in db.query("SELECT DISTINCT disease FROM dataset")
                    if row["disease"]
                }),
                "tissues": sorted({
                    row["source"]
                    for row in db.query("SELECT DISTINCT source FROM dataset")
                    if row["source"]
                }),
                "treatments": sorted({
                    row["treatment"]
                    for row in db.query("SELECT DISTINCT treatment FROM dataset")
                    if row["treatment"]
                }),
                "organisms": sorted({
                    row["organism"]
                    for row in db.query("SELECT DISTINCT organism FROM dataset")
                    if row["organism"]
                })
            }

    def validate_enrichment_database(self, database: str) -> bool:
        """
        Check if enrichment database name is valid

        Args:
            database: Database name (e.g., "geneontology_Biological_Process")

        Returns:
            True if valid
        """
        # Common WebGestaltR databases
        valid_databases = {
            # Gene Ontology
            "geneontology_Biological_Process",
            "geneontology_Molecular_Function",
            "geneontology_Cellular_Component",
            # Pathways
            "pathway_KEGG",
            "pathway_Reactome",
            "pathway_Wikipathway",
            "pathway_Panther",
            # Others
            "network_PPI_BIOGRID",
            "community-contributed_GTEx_Tissue",
            "phenotype_Human_Phenotype_Ontology",
        }

        return database in valid_databases

    def get_available_enrichment_databases(self) -> List[str]:
        """
        Get list of available enrichment databases

        Returns:
            List of database names
        """
        return [
            "geneontology_Biological_Process",
            "geneontology_Molecular_Function",
            "geneontology_Cellular_Component",
            "pathway_KEGG",
            "pathway_Reactome",
            "pathway_Wikipathway",
            "network_PPI_BIOGRID",
        ]

    def validate_pvalue_threshold(self, threshold: float) -> bool:
        """
        Validate p-value threshold

        Args:
            threshold: P-value threshold (should be between 0 and 1)

        Returns:
            True if valid
        """
        return 0.0 < threshold <= 1.0

    def validate_logfc_threshold(self, threshold: float) -> bool:
        """
        Validate logFC threshold

        Args:
            threshold: LogFC threshold (should be non-negative)

        Returns:
            True if valid
        """
        return threshold >= 0.0

    def has_pca_data(self, dataset_acc: str) -> bool:
        """
        Check if dataset has PCA data

        Args:
            dataset_acc: Dataset accession

        Returns:
            True if PCA data exists
        """
        with IBDTransDB(self.db_path) as db:
            result = db.query(
                "SELECT COUNT(*) as count FROM pca WHERE dataset_acc = ?",
                (dataset_acc,)
            )
            return result[0]["count"] > 0

    def has_enrichment_data(self, dataset_acc: str) -> bool:
        """
        Check if dataset has enrichment data

        Args:
            dataset_acc: Dataset accession

        Returns:
            True if enrichment data exists
        """
        with IBDTransDB(self.db_path) as db:
            result = db.query(
                """SELECT COUNT(*) as count
                   FROM enrichment_run er
                   JOIN dataset d ON er.dataset_id = d.dataset_id
                   WHERE d.dataset_acc = ?""",
                (dataset_acc,)
            )
            return result[0]["count"] > 0

    def has_cell_deconvolution_data(self, dataset_acc: str) -> bool:
        """
        Check if dataset has cell deconvolution data

        Args:
            dataset_acc: Dataset accession

        Returns:
            True if cell deconvolution data exists
        """
        with IBDTransDB(self.db_path) as db:
            result = db.query(
                "SELECT COUNT(*) as count FROM cell_deconvolution WHERE dataset_acc = ?",
                (dataset_acc,)
            )
            return result[0]["count"] > 0
