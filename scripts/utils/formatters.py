"""Output formatting utilities"""
import pandas as pd
from rich.console import Console
from rich.table import Table


console = Console()


def format_output(df: pd.DataFrame, format: str):
    """Format and output DataFrame in specified format

    Args:
        df: pandas DataFrame to format
        format: Output format - 'table', 'csv', or 'json'
    """
    if format == "table":
        _format_rich_table(df)
    elif format == "csv":
        print(df.to_csv(index=False))
    elif format == "json":
        print(df.to_json(orient="records", indent=2))
    else:
        console.print(f"[red]Unknown format: {format}[/red]")


def _format_rich_table(df: pd.DataFrame):
    """Format DataFrame as Rich table for terminal display

    Args:
        df: pandas DataFrame to display
    """
    if df.empty:
        console.print("[yellow]No results found[/yellow]")
        return

    table = Table()

    # Add columns
    for col in df.columns:
        table.add_column(str(col), style="cyan")

    # Add rows (limit to prevent overwhelming output)
    for _, row in df.head(100).iterrows():
        table.add_row(*[str(val) for val in row])

    if len(df) > 100:
        console.print(f"\n[yellow]Showing first 100 of {len(df)} rows[/yellow]\n")

    console.print(table)
