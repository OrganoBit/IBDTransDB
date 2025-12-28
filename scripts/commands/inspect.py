"""Database inspection commands"""
import typer
from rich.console import Console
from rich.table import Table
from scripts.db import IBDTransDB
from scripts.utils.formatters import format_output


app = typer.Typer()
console = Console()


@app.command("tables")
def list_tables(
    ctx: typer.Context,
):
    """List all tables in the database with row counts"""
    db_path = ctx.obj["db_path"]

    with IBDTransDB(db_path) as db:
        tables = db.get_table_names()

        table = Table(title="IBDTransDB Tables")
        table.add_column("Table Name", style="cyan")
        table.add_column("Row Count", justify="right", style="green")

        for table_name in tables:
            row_count = db.get_row_count(table_name)
            table.add_row(table_name, f"{row_count:,}")

    console.print(table)


@app.command("schema")
def show_schema(
    ctx: typer.Context,
    table: str = typer.Argument(..., help="Table name"),
):
    """Show schema (columns) for a specific table"""
    db_path = ctx.obj["db_path"]

    with IBDTransDB(db_path) as db:
        columns = db.get_table_info(table)

        if not columns:
            console.print(f"[red]Table '{table}' not found[/red]")
            raise typer.Exit(1)

        rich_table = Table(title=f"Schema: {table}")
        rich_table.add_column("Column", style="cyan")
        rich_table.add_column("Type", style="green")
        rich_table.add_column("Not Null", style="yellow")
        rich_table.add_column("Primary Key", style="magenta")

        for col in columns:
            rich_table.add_row(
                col['name'],
                col['type'],
                "✓" if col['notnull'] else "",
                "✓" if col['pk'] else ""
            )

    console.print(rich_table)


@app.command("query")
def run_query(
    ctx: typer.Context,
    sql: str = typer.Argument(..., help="SQL query to execute"),
    format: str = typer.Option("table", "--format", "-f", help="Output format: table, csv, json"),
    limit: int = typer.Option(100, "--limit", "-l", help="Limit results"),
):
    """Run a custom SQL query"""
    db_path = ctx.obj["db_path"]

    # Add LIMIT if not present and query is a SELECT
    if sql.strip().upper().startswith("SELECT") and "LIMIT" not in sql.upper():
        sql = f"{sql} LIMIT {limit}"

    try:
        with IBDTransDB(db_path) as db:
            df = db.query_df(sql)
        format_output(df, format)
    except Exception as e:
        console.print(f"[red]Query error: {e}[/red]")
        raise typer.Exit(1)


@app.command("stats")
def show_stats(
    ctx: typer.Context,
):
    """Show database statistics"""
    db_path = ctx.obj["db_path"]

    with IBDTransDB(db_path) as db:
        stats = [
            ("Datasets", db.get_row_count("dataset")),
            ("Comparisons", db.get_row_count("comparison")),
            ("Genes", db.get_row_count("gene_map")),
            ("Samples", db.query("SELECT COUNT(DISTINCT sample_id) FROM sample_ann")[0]['COUNT(DISTINCT sample_id)']),
            ("Expression Data Points", db.get_row_count("dataset_data")),
            ("Differential Expression Results", db.get_row_count("comparison_data")),
            ("Enrichment Results", db.get_row_count("enrichment_results")),
        ]

        table = Table(title="IBDTransDB Statistics")
        table.add_column("Metric", style="cyan")
        table.add_column("Count", justify="right", style="green")

        for metric, count in stats:
            table.add_row(metric, f"{count:,}")

    console.print(table)
