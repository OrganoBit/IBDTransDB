"""Parse R script outputs and extract statistics"""
import json
import pandas as pd
from pathlib import Path
from typing import Dict, Any, Optional, List


class ResultParser:
    """Parse and format R script results"""

    @staticmethod
    def parse_json_output(output_file: Path) -> Dict[str, Any]:
        """
        Parse JSON output from R script

        Args:
            output_file: Path to JSON file

        Returns:
            Parsed JSON data as dictionary
        """
        with open(output_file, 'r') as f:
            return json.load(f)

    @staticmethod
    def parse_csv_output(output_file: Path) -> pd.DataFrame:
        """
        Parse CSV output from R script

        Args:
            output_file: Path to CSV file

        Returns:
            pandas DataFrame
        """
        return pd.read_csv(output_file)

    @staticmethod
    def extract_statistics(result: Dict[str, Any]) -> Dict[str, Any]:
        """
        Extract key statistics from R script output

        Args:
            result: Output dictionary from RScriptExecutor

        Returns:
            Dictionary of extracted statistics
        """
        stats = {}

        if "data" not in result:
            return stats

        data = result["data"]

        # Extract PCA statistics
        if "pca" in data or "variance_explained" in data:
            stats["analysis_type"] = "pca"
            stats["n_samples"] = data.get("n_samples", 0)
            stats["variance_explained"] = data.get("variance_explained", [])
            stats["n_components"] = len(stats["variance_explained"])

        # Extract DGE statistics
        if "dge" in data or "n_significant" in data:
            stats["analysis_type"] = "dge"
            stats["n_genes_tested"] = data.get("n_genes", 0)
            stats["n_significant"] = data.get("n_significant", 0)
            stats["n_upregulated"] = data.get("n_upregulated", 0)
            stats["n_downregulated"] = data.get("n_downregulated", 0)

        # Extract enrichment statistics
        if "enrichment" in data or "n_enriched_pathways" in data:
            stats["analysis_type"] = "enrichment"
            stats["n_pathways_tested"] = data.get("n_pathways", 0)
            stats["n_enriched"] = data.get("n_enriched_pathways", 0)
            stats["enrichment_method"] = data.get("method", "unknown")

        # Extract meta-analysis statistics
        if "meta_analysis" in data or "meta_p_value" in data:
            stats["analysis_type"] = "meta_analysis"
            stats["n_comparisons"] = data.get("n_comparisons", 0)
            stats["n_genes"] = data.get("n_genes", 0)
            stats["n_significant"] = data.get("n_significant", 0)

        # Extract cell deconvolution statistics
        if "cell_fractions" in data or "cell_types" in data:
            stats["analysis_type"] = "cell_deconvolution"
            stats["n_samples"] = data.get("n_samples", 0)
            stats["n_cell_types"] = data.get("n_cell_types", 0)
            stats["cell_types"] = data.get("cell_types", [])

        # Extract general statistics
        stats["dataset_acc"] = data.get("dataset_acc")
        stats["comparison_id"] = data.get("comparison_id")

        return stats

    @staticmethod
    def extract_summary_table(result: Dict[str, Any]) -> Optional[pd.DataFrame]:
        """
        Extract summary table from R script output

        Args:
            result: Output dictionary from RScriptExecutor

        Returns:
            Summary table as DataFrame, or None if not available
        """
        # Check for CSV files in output
        if "files" in result and "tables" in result["files"]:
            tables = result["files"]["tables"]
            if tables:
                # Return first table found
                return pd.read_csv(tables[0])

        # Check for tabular data in JSON
        if "data" in result:
            data = result["data"]

            # Look for common table structures
            for key in ["results", "summary", "table", "data"]:
                if key in data and isinstance(data[key], list):
                    try:
                        return pd.DataFrame(data[key])
                    except (ValueError, TypeError):
                        continue

        return None

    @staticmethod
    def format_statistics_display(stats: Dict[str, Any]) -> List[str]:
        """
        Format statistics for terminal display

        Args:
            stats: Statistics dictionary

        Returns:
            List of formatted strings for display
        """
        lines = []

        analysis_type = stats.get("analysis_type", "unknown")
        lines.append(f"Analysis Type: {analysis_type.upper()}")

        # Dataset info
        if "dataset_acc" in stats and stats["dataset_acc"]:
            lines.append(f"Dataset: {stats['dataset_acc']}")
        if "comparison_id" in stats and stats["comparison_id"]:
            lines.append(f"Comparison: {stats['comparison_id']}")

        # Analysis-specific statistics
        if analysis_type == "pca":
            lines.append(f"Samples: {stats.get('n_samples', 0)}")
            lines.append(f"Components: {stats.get('n_components', 0)}")
            if "variance_explained" in stats:
                var_exp = stats["variance_explained"][:5]  # First 5 PCs
                var_str = ", ".join(f"{v:.1f}%" for v in var_exp)
                lines.append(f"Variance Explained (PC1-5): {var_str}")

        elif analysis_type == "dge":
            lines.append(f"Genes Tested: {stats.get('n_genes_tested', 0):,}")
            lines.append(f"Significant Genes: {stats.get('n_significant', 0):,}")
            lines.append(f"  Upregulated: {stats.get('n_upregulated', 0):,}")
            lines.append(f"  Downregulated: {stats.get('n_downregulated', 0):,}")

        elif analysis_type == "enrichment":
            lines.append(f"Method: {stats.get('enrichment_method', 'unknown')}")
            lines.append(f"Pathways Tested: {stats.get('n_pathways_tested', 0):,}")
            lines.append(f"Enriched Pathways: {stats.get('n_enriched', 0):,}")

        elif analysis_type == "meta_analysis":
            lines.append(f"Comparisons: {stats.get('n_comparisons', 0)}")
            lines.append(f"Genes Analyzed: {stats.get('n_genes', 0):,}")
            lines.append(f"Significant (FDR < 0.05): {stats.get('n_significant', 0):,}")

        elif analysis_type == "cell_deconvolution":
            lines.append(f"Samples: {stats.get('n_samples', 0)}")
            lines.append(f"Cell Types: {stats.get('n_cell_types', 0)}")
            if "cell_types" in stats and stats["cell_types"]:
                lines.append(f"Types: {', '.join(stats['cell_types'][:5])}")

        return lines

    @staticmethod
    def get_output_files(result: Dict[str, Any]) -> Dict[str, List[Path]]:
        """
        Get categorized list of output files

        Args:
            result: Output dictionary from RScriptExecutor

        Returns:
            Dictionary with keys: plots, tables, data
        """
        if "files" in result:
            return result["files"]
        else:
            return {"plots": [], "tables": [], "data": []}

    @staticmethod
    def get_primary_output(result: Dict[str, Any]) -> Optional[Path]:
        """
        Get the primary output file (first table or data file)

        Args:
            result: Output dictionary from RScriptExecutor

        Returns:
            Path to primary output file, or None
        """
        files = ResultParser.get_output_files(result)

        # Prefer tables over other types
        if files["tables"]:
            return files["tables"][0]
        elif files["data"]:
            return files["data"][0]
        elif files["plots"]:
            return files["plots"][0]

        return None

    @staticmethod
    def validate_output(result: Dict[str, Any], expected_files: Optional[List[str]] = None) -> bool:
        """
        Validate that R script produced expected output

        Args:
            result: Output dictionary from RScriptExecutor
            expected_files: List of expected filename patterns (optional)

        Returns:
            True if output is valid
        """
        # Check for successful execution
        if result.get("return_code", 1) != 0:
            return False

        # Check for data or files
        has_data = "data" in result and result["data"]
        has_files = any(result.get("files", {}).values())

        if not has_data and not has_files:
            return False

        # Check for specific expected files
        if expected_files:
            output_dir = result.get("output_dir")
            if not output_dir:
                return False

            for pattern in expected_files:
                matching = list(output_dir.glob(pattern))
                if not matching:
                    return False

        return True
