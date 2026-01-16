"""Explore commands - Single dataset analysis"""
import typer
from pathlib import Path
from typing import Optional, List
from rich.console import Console
from scripts.db import IBDTransDB
from scripts.utils.r_executor import RScriptExecutor
from scripts.utils.plot_handler import PlotHandler
from scripts.utils.result_parser import ResultParser
from scripts.utils.validation import Validator
import shutil

app = typer.Typer(help="Explore individual datasets (PCA, DGE, enrichment, etc.)")
console = Console()


def get_r_scripts_dir() -> Path:
    """Get path to R scripts directory"""
    return Path(__file__).parent.parent / "r_analysis"


@app.command("pca")
def pca_analysis(
    ctx: typer.Context,
    dataset_acc: str = typer.Argument(..., help="Dataset accession (e.g., GSE16879)"),
    color_by: Optional[str] = typer.Option(None, "--color-by", "-c", help="Sample annotation to color by (Disease, Source, etc.)"),
    pc_x: int = typer.Option(1, "--pc-x", help="PC for x-axis"),
    pc_y: int = typer.Option(2, "--pc-y", help="PC for y-axis"),
    plot_scree: bool = typer.Option(True, "--scree/--no-scree", help="Generate scree plot"),
    plot_pca: bool = typer.Option(True, "--pca/--no-pca", help="Generate PCA scatter plot"),
    output: Optional[Path] = typer.Option(None, "--output", "-o", help="Output CSV file for coordinates"),
    plot_file: Optional[Path] = typer.Option(None, "--plot-file", "-p", help="Output plot file (PNG)"),
):
    """
    Perform PCA analysis on a dataset

    Generates PCA plots colored by sample annotations, scree plots showing
    variance explained, and exports PCA coordinates.

    Example:
        ibdtransdb explore pca GSE16879 --color-by Disease --output pca.csv
    """
    db_path = ctx.obj["db_path"]

    # Validate dataset
    validator = Validator(db_path)
    if not validator.validate_dataset(dataset_acc):
        console.print(f"[red]Dataset {dataset_acc} not found[/red]")
        raise typer.Exit(1)

    # Check if PCA data exists
    if not validator.has_pca_data(dataset_acc):
        console.print(f"[yellow]Warning: Dataset {dataset_acc} may not have PCA data[/yellow]")

    # Get available annotations if color_by not specified
    if color_by is None:
        available = validator.get_available_annotations(dataset_acc)
        if available:
            console.print(f"[yellow]Available annotations: {', '.join(available)}[/yellow]")
            console.print("[yellow]Use --color-by to specify one[/yellow]")

    # Execute R script
    console.print(f"[cyan]Running PCA analysis on {dataset_acc}...[/cyan]")

    executor = RScriptExecutor(db_path=db_path, r_scripts_dir=get_r_scripts_dir())

    try:
        result = executor.execute_r_script(
            script_name="explore/pca_analysis.R",
            args={
                "dataset_acc": dataset_acc,
                "color_by": color_by,
                "pc_x": pc_x,
                "pc_y": pc_y,
                "plot_scree": plot_scree,
                "plot_pca": plot_pca,
            }
        )

        # Parse and display results
        stats = ResultParser.extract_statistics(result)
        if stats:
            console.print(f"\n[green]✓ Analysis complete![/green]")
            for line in ResultParser.format_statistics_display(stats):
                console.print(f"  {line}")

        # Handle output files
        plot_handler = PlotHandler()

        # Save CSV output
        if output and result["files"]["tables"]:
            shutil.copy(result["files"]["tables"][0], output)
            console.print(f"\n[green]Data exported to: {output}[/green]")

        # Save plot output
        if plot_file and result["files"]["plots"]:
            shutil.copy(result["files"]["plots"][0], plot_file)
            console.print(f"[green]Plot saved to: {plot_file}[/green]")
        elif result["files"]["plots"]:
            # Save to default location
            for plot in result["files"]["plots"]:
                saved = plot_handler.save_plot(plot, plot.stem, dataset_acc, "pca")
                console.print(f"[green]Plot saved to: {saved}[/green]")

    except Exception as e:
        console.print(f"[red]Error: {e}[/red]")
        raise typer.Exit(1)


@app.command("dge")
def dge_analysis(
    ctx: typer.Context,
    dataset_acc: str = typer.Argument(..., help="Dataset accession"),
    comparison_id: Optional[int] = typer.Argument(None, help="Comparison ID (optional - will show available if not provided)"),
    pval_threshold: float = typer.Option(0.05, "--pval", help="P-value threshold"),
    pval_type: str = typer.Option("adjusted", "--pval-type", help="P-value type: 'raw' or 'adjusted'"),
    logfc_threshold: float = typer.Option(1.0, "--logfc", help="LogFC threshold"),
    volcano: bool = typer.Option(False, "--volcano", help="Generate volcano plot"),
    output: Optional[Path] = typer.Option(None, "--output", "-o", help="Output CSV file"),
    plot_file: Optional[Path] = typer.Option(None, "--plot-file", "-p", help="Volcano plot output"),
):
    """
    Differential gene expression analysis

    Query pre-computed DGE results and optionally generate volcano plots.

    Example:
        ibdtransdb explore dge GSE16879 1 --volcano --output dge_results.csv
        ibdtransdb explore dge GSE16879  # Interactive - shows available comparisons
    """
    db_path = ctx.obj["db_path"]

    # Validate dataset
    validator = Validator(db_path)
    if not validator.validate_dataset(dataset_acc):
        console.print(f"[red]Dataset {dataset_acc} not found[/red]")
        raise typer.Exit(1)

    # Get available comparisons for this dataset
    comparisons = validator.get_dataset_comparisons(dataset_acc)

    if not comparisons:
        console.print(f"[red]No comparisons found for dataset {dataset_acc}[/red]")
        console.print("[yellow]This dataset has no DGE comparisons in the database.[/yellow]")
        raise typer.Exit(1)

    # If no comparison_id provided, show available and prompt
    if comparison_id is None:
        console.print(f"\n[cyan]Available comparisons for {dataset_acc}:[/cyan]\n")
        console.print("[bold]ID    | Case vs Control | Description[/bold]")
        console.print("─" * 70)
        for comp in comparisons:
            desc = comp.get('description', '') or ''
            console.print(f"{comp['comparison_id']:<6} | {comp['case_ann']} vs {comp['control_ann']:<15} | {desc[:30]}")

        console.print()
        comparison_id = typer.prompt("Select comparison ID", type=int)

    # Validate the selected comparison
    if not validator.validate_comparison(comparison_id):
        console.print(f"[red]Comparison {comparison_id} not found[/red]")
        raise typer.Exit(1)

    # Verify comparison belongs to this dataset
    comp_match = [c for c in comparisons if c['comparison_id'] == comparison_id]
    if not comp_match:
        console.print(f"[red]Comparison {comparison_id} does not belong to dataset {dataset_acc}[/red]")
        console.print(f"\n[yellow]Valid comparison IDs for {dataset_acc}:[/yellow]")
        for comp in comparisons:
            console.print(f"  {comp['comparison_id']}: {comp['case_ann']} vs {comp['control_ann']}")
        raise typer.Exit(1)

    console.print(f"[cyan]Retrieving DGE results for comparison {comparison_id}...[/cyan]")

    executor = RScriptExecutor(db_path=db_path, r_scripts_dir=get_r_scripts_dir())

    try:
        result = executor.execute_r_script(
            script_name="explore/dge_analysis.R",
            args={
                "dataset_acc": dataset_acc,
                "comparison_id": comparison_id,
                "pval_threshold": pval_threshold,
                "logfc_threshold": logfc_threshold,
                "plot_volcano": volcano,
            }
        )

        # Display statistics
        stats = ResultParser.extract_statistics(result)
        if stats:
            console.print(f"\n[green]✓ Analysis complete![/green]")
            for line in ResultParser.format_statistics_display(stats):
                console.print(f"  {line}")

        # Handle outputs
        plot_handler = PlotHandler()

        if output and result["files"]["tables"]:
            shutil.copy(result["files"]["tables"][0], output)
            console.print(f"\n[green]Results exported to: {output}[/green]")

        if volcano and result["files"]["plots"]:
            if plot_file:
                shutil.copy(result["files"]["plots"][0], plot_file)
                console.print(f"[green]Volcano plot saved to: {plot_file}[/green]")
            else:
                source_plot = Path(result["files"]["plots"][0])
                saved = plot_handler.save_plot(source_plot, source_plot.stem, dataset_acc, "dge")
                console.print(f"[green]Volcano plot saved to: {saved}[/green]")

    except Exception as e:
        console.print(f"[red]Error: {e}[/red]")
        raise typer.Exit(1)


@app.command("expression")
def expression_plot(
    ctx: typer.Context,
    dataset_acc: str = typer.Argument(..., help="Dataset accession"),
    genes: str = typer.Option(..., "--genes", "-g", help="Comma-separated gene symbols (e.g., TNFA,IL6,IL1B)"),
    comparison_id: Optional[int] = typer.Option(None, "--comparison", "-c", help="Comparison ID for grouping"),
    output: Optional[Path] = typer.Option(None, "--output", "-o", help="Output CSV file"),
    plot_file: Optional[Path] = typer.Option(None, "--plot-file", "-p", help="Plot output"),
):
    """
    Plot gene expression across sample groups

    Generate boxplots showing expression levels for selected genes.

    Example:
        ibdtransdb explore expression GSE16879 --genes TNFA,IL6,IL1B --comparison 1
    """
    db_path = ctx.obj["db_path"]

    # Parse genes
    gene_list = [g.strip() for g in genes.split(",")]

    # Validate
    validator = Validator(db_path)
    if not validator.validate_dataset(dataset_acc):
        console.print(f"[red]Dataset {dataset_acc} not found[/red]")
        raise typer.Exit(1)

    # Validate genes
    gene_validation = validator.validate_genes(gene_list)
    if gene_validation["invalid"]:
        console.print(f"[yellow]Warning: Genes not found: {', '.join(gene_validation['invalid'])}[/yellow]")

    if not gene_validation["valid"]:
        console.print("[red]No valid genes provided[/red]")
        raise typer.Exit(1)

    console.print(f"[cyan]Plotting expression for {len(gene_validation['valid'])} genes...[/cyan]")

    executor = RScriptExecutor(db_path=db_path, r_scripts_dir=get_r_scripts_dir())

    try:
        result = executor.execute_r_script(
            script_name="explore/expression_plot.R",
            args={
                "dataset_acc": dataset_acc,
                "genes": ",".join(gene_validation["valid"]),
                "comparison_id": comparison_id,
            }
        )

        console.print(f"\n[green]✓ Expression plots generated![/green]")

        # Handle outputs
        plot_handler = PlotHandler()

        if output and result["files"]["tables"]:
            shutil.copy(result["files"]["tables"][0], output)
            console.print(f"Expression data exported to: {output}")

        if result["files"]["plots"]:
            if plot_file:
                shutil.copy(result["files"]["plots"][0], plot_file)
                console.print(f"[green]Plot saved to: {plot_file}[/green]")
            else:
                source_plot = Path(result["files"]["plots"][0])
                saved = plot_handler.save_plot(source_plot, source_plot.stem, dataset_acc, "expression")
                console.print(f"[green]Plot saved to: {saved}[/green]")

    except Exception as e:
        console.print(f"[red]Error: {e}[/red]")
        raise typer.Exit(1)


@app.command("enrichment")
def enrichment_analysis(
    ctx: typer.Context,
    dataset_acc: str = typer.Argument(..., help="Dataset accession"),
    comparison_id: int = typer.Argument(..., help="Comparison ID"),
    method: str = typer.Option("gsea", "--method", "-m", help="Enrichment method: 'ora' or 'gsea'"),
    database: str = typer.Option("geneontology_Biological_Process", "--database", "-d", help="Enrichment database"),
    organism: str = typer.Option("hsapiens", "--organism", help="Organism: 'hsapiens' or 'mmusculus'"),
    pval_threshold: float = typer.Option(0.05, "--pval", help="P-value threshold for gene filtering (ORA)"),
    output: Optional[Path] = typer.Option(None, "--output", "-o", help="Output CSV file"),
):
    """
    Pathway enrichment analysis (ORA or GSEA)

    Run over-representation analysis (ORA) or gene set enrichment analysis (GSEA)
    using WebGestaltR.

    Example:
        ibdtransdb explore enrichment GSE16879 1 --method gsea --database pathway_KEGG
    """
    db_path = ctx.obj["db_path"]

    # Validate
    validator = Validator(db_path)
    if not validator.validate_dataset(dataset_acc):
        console.print(f"[red]Dataset {dataset_acc} not found[/red]")
        raise typer.Exit(1)

    if not validator.validate_comparison(comparison_id):
        console.print(f"[red]Comparison {comparison_id} not found[/red]")
        raise typer.Exit(1)

    console.print(f"[cyan]Running {method.upper()} enrichment analysis...[/cyan]")
    console.print(f"[dim]Database: {database}, Organism: {organism}[/dim]")

    executor = RScriptExecutor(db_path=db_path, r_scripts_dir=get_r_scripts_dir())

    try:
        result = executor.execute_r_script(
            script_name="explore/enrichment_analysis.R",
            args={
                "dataset_acc": dataset_acc,
                "comparison_id": comparison_id,
                "method": method,
                "database": database,
                "organism": organism,
                "pval_threshold": pval_threshold,
            },
            timeout=600  # 10 minutes for enrichment
        )

        # Display statistics
        stats = ResultParser.extract_statistics(result)
        if stats:
            console.print(f"\n[green]✓ Enrichment analysis complete![/green]")
            for line in ResultParser.format_statistics_display(stats):
                console.print(f"  {line}")

        # Handle output
        if output and result["files"]["tables"]:
            shutil.copy(result["files"]["tables"][0], output)
            console.print(f"\n[green]Results exported to: {output}[/green]")

    except Exception as e:
        console.print(f"[red]Error: {e}[/red]")
        raise typer.Exit(1)


@app.command("deconvolution")
def cell_deconvolution(
    ctx: typer.Context,
    dataset_acc: str = typer.Argument(..., help="Dataset accession"),
    comparison_id: Optional[int] = typer.Option(None, "--comparison", "-c", help="Comparison ID for testing"),
    test: bool = typer.Option(False, "--test", help="Perform statistical tests between groups"),
    output: Optional[Path] = typer.Option(None, "--output", "-o", help="Output CSV file"),
    plot_file: Optional[Path] = typer.Option(None, "--plot-file", "-p", help="Plot output"),
):
    """
    Cell type deconvolution analysis

    Query and visualize pre-computed cell type fractions (e.g., from SCADEN).

    Example:
        ibdtransdb explore deconvolution GSE16879 --comparison 1 --test
    """
    db_path = ctx.obj["db_path"]

    # Validate
    validator = Validator(db_path)
    if not validator.validate_dataset(dataset_acc):
        console.print(f"[red]Dataset {dataset_acc} not found[/red]")
        raise typer.Exit(1)

    if not validator.has_cell_deconvolution_data(dataset_acc):
        console.print(f"[yellow]Warning: Dataset {dataset_acc} may not have cell deconvolution data[/yellow]")

    console.print(f"[cyan]Retrieving cell deconvolution results...[/cyan]")

    executor = RScriptExecutor(db_path=db_path, r_scripts_dir=get_r_scripts_dir())

    try:
        result = executor.execute_r_script(
            script_name="explore/cell_deconvolution.R",
            args={
                "dataset_acc": dataset_acc,
                "comparison_id": comparison_id,
                "test": test,
            }
        )

        # Display statistics
        stats = ResultParser.extract_statistics(result)
        if stats:
            console.print(f"\n[green]✓ Cell deconvolution complete![/green]")
            for line in ResultParser.format_statistics_display(stats):
                console.print(f"  {line}")

        # Handle outputs
        plot_handler = PlotHandler()

        if output and result["files"]["tables"]:
            shutil.copy(result["files"]["tables"][0], output)
            console.print(f"\n[green]Results exported to: {output}[/green]")

        if result["files"]["plots"]:
            if plot_file:
                shutil.copy(result["files"]["plots"][0], plot_file)
                console.print(f"[green]Plot saved to: {plot_file}[/green]")
            else:
                source_plot = Path(result["files"]["plots"][0])
                saved = plot_handler.save_plot(source_plot, source_plot.stem, dataset_acc, "deconvolution")
                console.print(f"[green]Plot saved to: {saved}[/green]")

    except Exception as e:
        console.print(f"[red]Error: {e}[/red]")
        raise typer.Exit(1)


@app.command("signature")
def signature_analysis(
    ctx: typer.Context,
    dataset_acc: str = typer.Argument(..., help="Dataset accession"),
    genes: str = typer.Option(..., "--genes", "-g", help="Comma-separated gene symbols for signature"),
    signature_name: str = typer.Option("Custom_Signature", "--name", "-n", help="Signature name"),
    comparison_id: Optional[int] = typer.Option(None, "--comparison", "-c", help="Comparison ID for testing"),
    output: Optional[Path] = typer.Option(None, "--output", "-o", help="Output CSV file"),
    plot_file: Optional[Path] = typer.Option(None, "--plot-file", "-p", help="Plot output"),
):
    """
    Gene signature analysis

    Calculate and compare gene signature scores (mean expression) across groups.

    Example:
        ibdtransdb explore signature GSE16879 --genes TNFA,IL6,IL1B --name Inflammatory --comparison 1
    """
    db_path = ctx.obj["db_path"]

    # Parse genes
    gene_list = [g.strip() for g in genes.split(",")]

    # Validate
    validator = Validator(db_path)
    if not validator.validate_dataset(dataset_acc):
        console.print(f"[red]Dataset {dataset_acc} not found[/red]")
        raise typer.Exit(1)

    gene_validation = validator.validate_genes(gene_list)
    if not gene_validation["valid"]:
        console.print("[red]No valid genes provided[/red]")
        raise typer.Exit(1)

    console.print(f"[cyan]Calculating {signature_name} signature scores ({len(gene_validation['valid'])} genes)...[/cyan]")

    executor = RScriptExecutor(db_path=db_path, r_scripts_dir=get_r_scripts_dir())

    try:
        result = executor.execute_r_script(
            script_name="explore/signature_analysis.R",
            args={
                "dataset_acc": dataset_acc,
                "genes": ",".join(gene_validation["valid"]),
                "signature_name": signature_name,
                "comparison_id": comparison_id,
            }
        )

        console.print(f"\n[green]✓ Signature analysis complete![/green]")

        # Handle outputs
        plot_handler = PlotHandler()

        if output and result["files"]["tables"]:
            shutil.copy(result["files"]["tables"][0], output)
            console.print(f"Signature scores exported to: {output}")

        if result["files"]["plots"]:
            if plot_file:
                shutil.copy(result["files"]["plots"][0], plot_file)
                console.print(f"[green]Plot saved to: {plot_file}[/green]")
            else:
                source_plot = Path(result["files"]["plots"][0])
                saved = plot_handler.save_plot(source_plot, source_plot.stem, dataset_acc, "signatures")
                console.print(f"[green]Plot saved to: {saved}[/green]")

    except Exception as e:
        console.print(f"[red]Error: {e}[/red]")
        raise typer.Exit(1)
