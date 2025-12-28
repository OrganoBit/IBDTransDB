"""Dataset browsing commands"""
import typer
from typing import Optional, List
from rich.console import Console
from scripts.db import IBDTransDB
from scripts.utils.formatters import format_output


app = typer.Typer()
console = Console()


@app.command("list")
def list_datasets(
    ctx: typer.Context,
    disease: Optional[List[str]] = typer.Option(None, "--disease", "-D", help="Filter by disease"),
    tissue: Optional[List[str]] = typer.Option(None, "--tissue", "-t", help="Filter by tissue/source"),
    treatment: Optional[List[str]] = typer.Option(None, "--treatment", "-T", help="Filter by treatment"),
    format: str = typer.Option("table", "--format", "-f", help="Output format: table, csv, json"),
):
    """List all datasets with optional filters"""
    db_path = ctx.obj["db_path"]

    # Build query with filters
    sql = "SELECT dataset_acc, title, disease, source, treatment, organism, sample_number FROM dataset WHERE 1=1"
    params = []

    if disease:
        placeholders = ','.join('?' * len(disease))
        sql += f" AND disease IN ({placeholders})"
        params.extend(disease)

    if tissue:
        placeholders = ','.join('?' * len(tissue))
        sql += f" AND source IN ({placeholders})"
        params.extend(tissue)

    if treatment:
        placeholders = ','.join('?' * len(treatment))
        sql += f" AND treatment IN ({placeholders})"
        params.extend(treatment)

    with IBDTransDB(db_path) as db:
        df = db.query_df(sql, tuple(params))

    format_output(df, format)


@app.command("info")
def dataset_info(
    ctx: typer.Context,
    dataset_acc: str = typer.Argument(..., help="Dataset accession (e.g., GSE16879)"),
    format: str = typer.Option("table", "--format", "-f", help="Output format: table, csv, json"),
):
    """Get detailed information about a specific dataset"""
    db_path = ctx.obj["db_path"]

    with IBDTransDB(db_path) as db:
        # Dataset metadata
        sql = "SELECT * FROM dataset WHERE dataset_acc = ?"
        df = db.query_df(sql, (dataset_acc,))

        if df.empty:
            console.print(f"[red]Dataset {dataset_acc} not found[/red]")
            raise typer.Exit(1)

        # Sample count
        sample_sql = "SELECT COUNT(DISTINCT sample_id) as sample_count FROM sample_ann WHERE dataset_acc = ?"
        sample_count = db.query(sample_sql, (dataset_acc,))[0]['sample_count']

        # Comparison count
        comp_sql = "SELECT COUNT(*) as comp_count FROM comparison WHERE dataset_acc = ?"
        comp_count = db.query(comp_sql, (dataset_acc,))[0]['comp_count']

        df['sample_count'] = sample_count
        df['comparison_count'] = comp_count

    format_output(df.T, format)


@app.command("filters")
def show_filters(
    ctx: typer.Context,
):
    """Show all available filter options (diseases, tissues, treatments)"""
    db_path = ctx.obj["db_path"]

    with IBDTransDB(db_path) as db:
        console.print("\n[bold cyan]Available Diseases:[/bold cyan]")
        diseases = db.query("SELECT DISTINCT disease FROM dataset ORDER BY disease")
        for d in diseases:
            console.print(f"  • {d['disease']}")

        console.print("\n[bold cyan]Available Tissues/Sources:[/bold cyan]")
        tissues = db.query("SELECT DISTINCT source FROM dataset ORDER BY source")
        for t in tissues:
            console.print(f"  • {t['source']}")

        console.print("\n[bold cyan]Available Treatments:[/bold cyan]")
        treatments = db.query("SELECT DISTINCT treatment FROM dataset ORDER BY treatment")
        for t in treatments:
            console.print(f"  • {t['treatment']}")
