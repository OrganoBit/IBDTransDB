"""
Integrate Commands for IBDTransDB CLI
Meta-analysis and target ranking across datasets
"""

import typer
from rich.console import Console
from rich.table import Table
from pathlib import Path
from typing import Optional
import sys

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from utils.r_executor import RScriptExecutor, get_r_scripts_dir
from utils.result_parser import ResultParser
from utils.plot_handler import PlotHandler
from utils.validation import Validator

app = typer.Typer(help="Meta-analysis and target ranking")
console = Console()


@app.command("rank")
def target_ranking(
    ctx: typer.Context,
    genes: Optional[str] = typer.Option(None, "--genes", "-g", help="Comma-separated gene list or file path"),
    disease: Optional[str] = typer.Option(None, "--disease", "-D", help="Filter by disease (CD, UC, etc.)"),
    tissue: Optional[str] = typer.Option(None, "--tissue", "-t", help="Filter by tissue/source"),
    treatment: Optional[str] = typer.Option(None, "--treatment", "-T", help="Filter by treatment"),
    output: Optional[Path] = typer.Option(None, "--output", "-o", help="Output CSV file path"),
    top_n: int = typer.Option(100, "--top-n", "-n", help="Number of top targets to export"),
    fdr_threshold: float = typer.Option(0.05, "--fdr-threshold", help="FDR threshold for meta-analysis"),
    min_datasets: int = typer.Option(2, "--min-datasets", help="Minimum number of supporting datasets"),
    plot: bool = typer.Option(False, "--plot", help="Generate ranking visualizations"),
):
    """
    Rank targets using meta-analysis across datasets.

    Combines evidence across multiple studies to identify robust therapeutic targets.
    Uses Fisher's method for meta-analysis with consistency scoring.

    Example:
        ibdtransdb integrate rank --disease CD --tissue Colon --top-n 50 --plot
        ibdtransdb integrate rank --genes targets.txt --disease UC --plot
    """
    db_path = ctx.obj["db_path"]

    console.print("[bold blue]Running target ranking analysis[/bold blue]")

    # Handle gene list input (file or comma-separated)
    gene_list = None
    if genes:
        if Path(genes).exists():
            # Read from file
            with open(genes, 'r') as f:
                gene_list = [line.strip() for line in f if line.strip()]
            console.print(f"Loaded {len(gene_list)} genes from file: {genes}")
        else:
            # Parse as comma-separated list
            gene_list = [g.strip() for g in genes.split(",")]
            console.print(f"Using {len(gene_list)} genes from input")

        # Validate genes
        validator = Validator(db_path)
        validation = validator.validate_genes(gene_list)

        if validation["invalid"]:
            console.print(f"[yellow]Warning: {len(validation['invalid'])} genes not found[/yellow]")

        if not validation["valid"]:
            console.print("[red]Error: No valid genes provided[/red]")
            raise typer.Exit(1)

        genes = ",".join(validation["valid"])

    # Prepare arguments for R script
    args = {
        "genes": genes,
        "disease": disease,
        "tissue": tissue,
        "treatment": treatment,
        "top_n": top_n,
        "fdr_threshold": fdr_threshold,
        "min_datasets": min_datasets,
        "plot": plot,
    }

    # Execute R script
    console.print("Running target ranking with meta-analysis...")
    executor = RScriptExecutor(db_path=db_path, r_scripts_dir=get_r_scripts_dir())

    try:
        result = executor.execute_r_script("integrate/target_ranking.R", args=args, timeout=600)
    except Exception as e:
        console.print(f"[red]Error running target ranking: {e}[/red]")
        raise typer.Exit(1)

    # Extract statistics
    stats = ResultParser.extract_statistics(result)

    # Handle output files
    plot_handler = PlotHandler()

    if output and "ranked_targets.csv" in result.get("files", {}).get("tables", []):
        source_file = Path(result["output_dir"]) / "ranked_targets.csv"
        source_file.rename(output)
        console.print(f"[green]Ranked targets saved to: {output}[/green]")

    # Handle plot files
    if plot:
        for plot_name in ["target_ranking_plot.png", "consistency_plot.png"]:
            if plot_name in result.get("files", {}).get("plots", []):
                source_file = Path(result["output_dir"]) / plot_name
                saved_plot = plot_handler.save_plot(
                    source_file=source_file,
                    plot_name=plot_name,
                    subdirectory="integrate"
                )
                console.print(f"[green]Plot saved to: {saved_plot}[/green]")

    # Display summary
    console.print("\n[bold green]Target Ranking Complete![/bold green]")
    if stats:
        table = Table(title="Ranking Summary")
        table.add_column("Metric", style="cyan")
        table.add_column("Value", style="magenta")

        for key, value in stats.items():
            table.add_row(str(key), str(value))

        console.print(table)


@app.command("signature-rank")
def signature_ranking(
    ctx: typer.Context,
    signatures: str = typer.Argument(..., help="JSON file with gene signatures"),
    disease: Optional[str] = typer.Option(None, "--disease", "-D", help="Filter by disease"),
    tissue: Optional[str] = typer.Option(None, "--tissue", "-t", help="Filter by tissue"),
    output: Optional[Path] = typer.Option(None, "--output", "-o", help="Output CSV file path"),
    method: str = typer.Option("mean", "--method", "-m", help="Aggregation method (mean, median, gsea)"),
    plot: bool = typer.Option(False, "--plot", help="Generate ranking visualizations"),
):
    """
    Rank gene signatures across datasets.

    Evaluates multi-gene signatures for consistency and significance across studies.
    Useful for comparing pathway activities or biological processes.

    Example:
        ibdtransdb integrate signature-rank signatures.json --disease CD --plot
    """
    db_path = ctx.obj["db_path"]

    # Validate signatures file
    signatures_path = Path(signatures)
    if not signatures_path.exists():
        console.print(f"[red]Error: Signatures file not found: {signatures}[/red]")
        raise typer.Exit(1)

    console.print(f"[bold blue]Ranking gene signatures from: {signatures}[/bold blue]")

    # Prepare arguments for R script
    args = {
        "signatures": str(signatures_path.absolute()),
        "disease": disease,
        "tissue": tissue,
        "method": method,
        "plot": plot,
    }

    # Execute R script
    console.print("Running signature ranking analysis...")
    executor = RScriptExecutor(db_path=db_path, r_scripts_dir=get_r_scripts_dir())

    try:
        result = executor.execute_r_script("integrate/signature_ranking.R", args=args, timeout=600)
    except Exception as e:
        console.print(f"[red]Error running signature ranking: {e}[/red]")
        raise typer.Exit(1)

    # Extract statistics
    stats = ResultParser.extract_statistics(result)

    # Handle output files
    plot_handler = PlotHandler()

    if output and "signature_rankings.csv" in result.get("files", {}).get("tables", []):
        source_file = Path(result["output_dir"]) / "signature_rankings.csv"
        source_file.rename(output)
        console.print(f"[green]Signature rankings saved to: {output}[/green]")

    # Handle plot files
    if plot and "signature_plot.png" in result.get("files", {}).get("plots", []):
        source_file = Path(result["output_dir"]) / "signature_plot.png"
        saved_plot = plot_handler.save_plot(
            source_file=source_file,
            plot_name="signature_plot.png",
            subdirectory="integrate"
        )
        console.print(f"[green]Plot saved to: {saved_plot}[/green]")

    # Display summary
    console.print("\n[bold green]Signature Ranking Complete![/bold green]")
    if stats:
        table = Table(title="Ranking Summary")
        table.add_column("Metric", style="cyan")
        table.add_column("Value", style="magenta")

        for key, value in stats.items():
            table.add_row(str(key), str(value))

        console.print(table)


@app.command("pathways")
def pathway_integration(
    ctx: typer.Context,
    databases: str = typer.Option("geneontology_Biological_Process,pathway_KEGG", "--databases", "-d",
                                  help="Comma-separated pathway databases"),
    disease: Optional[str] = typer.Option(None, "--disease", "-D", help="Filter by disease"),
    tissue: Optional[str] = typer.Option(None, "--tissue", "-t", help="Filter by tissue"),
    output: Optional[Path] = typer.Option(None, "--output", "-o", help="Output CSV file path"),
    min_datasets: int = typer.Option(2, "--min-datasets", help="Minimum datasets for pathway"),
    fdr_threshold: float = typer.Option(0.05, "--fdr-threshold", help="FDR threshold per dataset"),
    plot: bool = typer.Option(False, "--plot", help="Generate pathway visualizations"),
):
    """
    Integrate pathway enrichment across datasets.

    Identifies pathways consistently enriched across multiple studies.
    Combines enrichment results to find robust biological insights.

    Example:
        ibdtransdb integrate pathways --disease CD,UC --min-datasets 3 --plot
        ibdtransdb integrate pathways --databases pathway_KEGG,pathway_Reactome --tissue Colon
    """
    db_path = ctx.obj["db_path"]

    console.print("[bold blue]Integrating pathway enrichment across datasets[/bold blue]")

    # Parse database list
    db_list = [d.strip() for d in databases.split(",")]
    console.print(f"Using databases: {', '.join(db_list)}")

    # Prepare arguments for R script
    args = {
        "databases": databases,
        "disease": disease,
        "tissue": tissue,
        "min_datasets": min_datasets,
        "fdr_threshold": fdr_threshold,
        "plot": plot,
    }

    # Execute R script
    console.print("Running pathway integration...")
    executor = RScriptExecutor(db_path=db_path, r_scripts_dir=get_r_scripts_dir())

    try:
        result = executor.execute_r_script("integrate/pathway_ranking.R", args=args, timeout=600)
    except Exception as e:
        console.print(f"[red]Error running pathway integration: {e}[/red]")
        raise typer.Exit(1)

    # Extract statistics
    stats = ResultParser.extract_statistics(result)

    # Handle output files
    plot_handler = PlotHandler()

    if output and "integrated_pathways.csv" in result.get("files", {}).get("tables", []):
        source_file = Path(result["output_dir"]) / "integrated_pathways.csv"
        source_file.rename(output)
        console.print(f"[green]Integrated pathways saved to: {output}[/green]")

    # Handle plot files
    if plot and "pathway_integration_plot.png" in result.get("files", {}).get("plots", []):
        source_file = Path(result["output_dir"]) / "pathway_integration_plot.png"
        saved_plot = plot_handler.save_plot(
            source_file=source_file,
            plot_name="pathway_integration_plot.png",
            subdirectory="integrate"
        )
        console.print(f"[green]Plot saved to: {saved_plot}[/green]")

    # Display summary
    console.print("\n[bold green]Pathway Integration Complete![/bold green]")
    if stats:
        table = Table(title="Integration Summary")
        table.add_column("Metric", style="cyan")
        table.add_column("Value", style="magenta")

        for key, value in stats.items():
            table.add_row(str(key), str(value))

        console.print(table)


if __name__ == "__main__":
    app()
