"""
Compare Commands for IBDTransDB CLI
Cross-dataset comparison and meta-analysis
"""

import typer
from rich.console import Console
from rich.table import Table
from pathlib import Path
from typing import Optional, List
import sys

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from utils.r_executor import RScriptExecutor, get_r_scripts_dir
from utils.result_parser import ResultParser
from utils.plot_handler import PlotHandler
from utils.validation import Validator

app = typer.Typer(help="Cross-dataset comparison and meta-analysis")
console = Console()


@app.command("table")
def comparison_table(
    ctx: typer.Context,
    genes: str = typer.Argument(..., help="Comma-separated list of gene symbols"),
    disease: Optional[str] = typer.Option(None, "--disease", "-D", help="Filter by disease (CD, UC, etc.)"),
    tissue: Optional[str] = typer.Option(None, "--tissue", "-t", help="Filter by tissue/source"),
    treatment: Optional[str] = typer.Option(None, "--treatment", "-T", help="Filter by treatment"),
    output: Optional[Path] = typer.Option(None, "--output", "-o", help="Output CSV file path"),
    plot: bool = typer.Option(False, "--plot", help="Generate heatmap visualization"),
    plot_file: Optional[Path] = typer.Option(None, "--plot-file", help="Custom plot file path"),
):
    """
    Generate cross-dataset comparison table for specific genes.

    Shows logFC and p-values across multiple datasets/comparisons.
    Useful for comparing gene regulation patterns across studies.

    Example:
        ibdtransdb compare table TNFA,IL6,IL1B --disease CD --tissue Colon --plot
    """
    db_path = ctx.obj["db_path"]

    console.print(f"[bold blue]Generating comparison table for genes: {genes}[/bold blue]")

    # Parse gene list
    gene_list = [g.strip() for g in genes.split(",")]

    # Validate genes
    validator = Validator(db_path)
    validation = validator.validate_genes(gene_list)

    if validation["invalid"]:
        console.print(f"[yellow]Warning: {len(validation['invalid'])} genes not found: {', '.join(validation['invalid'])}[/yellow]")

    if not validation["valid"]:
        console.print("[red]Error: No valid genes provided[/red]")
        raise typer.Exit(1)

    console.print(f"Using {len(validation['valid'])} valid genes")

    # Prepare arguments for R script
    args = {
        "genes": ",".join(validation["valid"]),
        "disease": disease,
        "tissue": tissue,
        "treatment": treatment,
        "plot": plot,
    }

    # Execute R script
    console.print("Running cross-dataset comparison...")
    executor = RScriptExecutor(db_path=db_path, r_scripts_dir=get_r_scripts_dir())

    try:
        result = executor.execute_r_script("compare/comparison_table.R", args=args, timeout=300)
    except Exception as e:
        console.print(f"[red]Error running comparison: {e}[/red]")
        raise typer.Exit(1)

    # Extract statistics
    stats = ResultParser.extract_statistics(result)

    # Handle output files
    plot_handler = PlotHandler()

    if output and "comparison_table.csv" in result.get("files", {}).get("tables", []):
        source_file = Path(result["output_dir"]) / "comparison_table.csv"
        source_file.rename(output)
        console.print(f"[green]Comparison table saved to: {output}[/green]")

    # Handle plot files
    if plot and "comparison_heatmap.png" in result.get("files", {}).get("plots", []):
        source_file = Path(result["output_dir"]) / "comparison_heatmap.png"
        saved_plot = plot_handler.save_plot(
            source_file=source_file,
            plot_name="comparison_heatmap.png" if not plot_file else plot_file.name,
            subdirectory="compare"
        )
        console.print(f"[green]Heatmap saved to: {saved_plot}[/green]")

    # Display summary
    console.print("\n[bold green]Comparison Complete![/bold green]")
    if stats:
        table = Table(title="Comparison Summary")
        table.add_column("Metric", style="cyan")
        table.add_column("Value", style="magenta")

        for key, value in stats.items():
            table.add_row(str(key), str(value))

        console.print(table)


@app.command("meta")
def meta_analysis(
    ctx: typer.Context,
    comparison_ids: str = typer.Argument(..., help="Comma-separated list of comparison IDs"),
    method: str = typer.Option("fisher", "--method", "-m", help="Meta-analysis method (fisher, stouffer)"),
    output: Optional[Path] = typer.Option(None, "--output", "-o", help="Output CSV file path"),
    top_n: int = typer.Option(100, "--top-n", "-n", help="Number of top genes to export"),
    fdr_threshold: float = typer.Option(0.05, "--fdr-threshold", help="FDR threshold for significance"),
    plot_volcano: bool = typer.Option(False, "--volcano", help="Generate volcano plot of meta-analysis results"),
):
    """
    Perform meta-analysis across multiple comparisons using Fisher's method.

    Combines p-values across studies to identify consistently regulated genes.
    Useful for finding robust biomarkers across multiple datasets.

    Example:
        ibdtransdb compare meta 1,2,3,4,5 --method fisher --fdr-threshold 0.05 --volcano
    """
    db_path = ctx.obj["db_path"]

    console.print(f"[bold blue]Running meta-analysis on {len(comparison_ids.split(','))} comparisons[/bold blue]")

    # Parse comparison IDs
    comp_ids = [int(c.strip()) for c in comparison_ids.split(",")]

    # Validate comparison IDs
    validator = Validator(db_path)
    for comp_id in comp_ids:
        if not validator.validate_comparison(comp_id):
            console.print(f"[red]Error: Comparison {comp_id} not found[/red]")
            raise typer.Exit(1)

    # Prepare arguments for R script
    args = {
        "comparison_ids": ",".join(map(str, comp_ids)),
        "method": method,
        "top_n": top_n,
        "fdr_threshold": fdr_threshold,
        "plot_volcano": plot_volcano,
    }

    # Execute R script
    console.print(f"Running {method} meta-analysis...")
    executor = RScriptExecutor(db_path=db_path, r_scripts_dir=get_r_scripts_dir())

    try:
        result = executor.execute_r_script("compare/meta_analysis.R", args=args, timeout=600)
    except Exception as e:
        console.print(f"[red]Error running meta-analysis: {e}[/red]")
        raise typer.Exit(1)

    # Extract statistics
    stats = ResultParser.extract_statistics(result)

    # Handle output files
    plot_handler = PlotHandler()

    if output and "meta_analysis_results.csv" in result.get("files", {}).get("tables", []):
        source_file = Path(result["output_dir"]) / "meta_analysis_results.csv"
        source_file.rename(output)
        console.print(f"[green]Meta-analysis results saved to: {output}[/green]")

    # Handle plot files
    if plot_volcano and "meta_volcano.png" in result.get("files", {}).get("plots", []):
        source_file = Path(result["output_dir"]) / "meta_volcano.png"
        saved_plot = plot_handler.save_plot(
            source_file=source_file,
            plot_name="meta_volcano.png",
            subdirectory="compare"
        )
        console.print(f"[green]Volcano plot saved to: {saved_plot}[/green]")

    # Display summary
    console.print("\n[bold green]Meta-Analysis Complete![/bold green]")
    if stats:
        table = Table(title="Meta-Analysis Summary")
        table.add_column("Metric", style="cyan")
        table.add_column("Value", style="magenta")

        for key, value in stats.items():
            table.add_row(str(key), str(value))

        console.print(table)


@app.command("geneset")
def geneset_compare(
    ctx: typer.Context,
    pathway: Optional[str] = typer.Option(None, "--pathway", "-p", help="Pathway name or ID to compare"),
    database: str = typer.Option("geneontology_Biological_Process", "--database", "-d", help="Pathway database"),
    datasets: Optional[str] = typer.Option(None, "--datasets", help="Comma-separated dataset accessions to compare"),
    disease: Optional[str] = typer.Option(None, "--disease", "-D", help="Filter by disease"),
    tissue: Optional[str] = typer.Option(None, "--tissue", "-t", help="Filter by tissue"),
    output: Optional[Path] = typer.Option(None, "--output", "-o", help="Output CSV file path"),
    plot: bool = typer.Option(False, "--plot", help="Generate comparison plot"),
):
    """
    Compare pathway/geneset enrichment across multiple datasets.

    Shows how specific pathways are enriched across different studies.
    Useful for understanding pathway consistency across conditions.

    Example:
        ibdtransdb compare geneset --pathway "TNF signaling" --disease CD --plot
        ibdtransdb compare geneset --database KEGG --datasets GSE16879,GSE20881 --plot
    """
    db_path = ctx.obj["db_path"]

    if pathway:
        console.print(f"[bold blue]Comparing pathway enrichment: {pathway}[/bold blue]")
    else:
        console.print(f"[bold blue]Comparing pathway enrichment across datasets[/bold blue]")

    # Parse dataset list if provided
    dataset_list = None
    if datasets:
        dataset_list = [d.strip() for d in datasets.split(",")]

        # Validate datasets
        validator = Validator(db_path)
        for dataset_acc in dataset_list:
            if not validator.validate_dataset(dataset_acc):
                console.print(f"[red]Error: Dataset {dataset_acc} not found[/red]")
                raise typer.Exit(1)

    # Prepare arguments for R script
    args = {
        "pathway": pathway,
        "database": database,
        "datasets": datasets,
        "disease": disease,
        "tissue": tissue,
        "plot": plot,
    }

    # Execute R script
    console.print("Running geneset comparison...")
    executor = RScriptExecutor(db_path=db_path, r_scripts_dir=get_r_scripts_dir())

    try:
        result = executor.execute_r_script("compare/geneset_compare.R", args=args, timeout=600)
    except Exception as e:
        console.print(f"[red]Error running geneset comparison: {e}[/red]")
        raise typer.Exit(1)

    # Extract statistics
    stats = ResultParser.extract_statistics(result)

    # Handle output files
    plot_handler = PlotHandler()

    if output and "geneset_comparison.csv" in result.get("files", {}).get("tables", []):
        source_file = Path(result["output_dir"]) / "geneset_comparison.csv"
        source_file.rename(output)
        console.print(f"[green]Geneset comparison saved to: {output}[/green]")

    # Handle plot files
    if plot and "geneset_plot.png" in result.get("files", {}).get("plots", []):
        source_file = Path(result["output_dir"]) / "geneset_plot.png"
        saved_plot = plot_handler.save_plot(
            source_file=source_file,
            plot_name="geneset_plot.png",
            subdirectory="compare"
        )
        console.print(f"[green]Plot saved to: {saved_plot}[/green]")

    # Display summary
    console.print("\n[bold green]Geneset Comparison Complete![/bold green]")
    if stats:
        table = Table(title="Comparison Summary")
        table.add_column("Metric", style="cyan")
        table.add_column("Value", style="magenta")

        for key, value in stats.items():
            table.add_row(str(key), str(value))

        console.print(table)


if __name__ == "__main__":
    app()
