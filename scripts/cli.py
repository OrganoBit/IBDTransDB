"""
IBDTransDB CLI - Main entry point
"""
import typer
from pathlib import Path
from scripts.commands import datasets, inspect


app = typer.Typer(
    name="ibdtransdb",
    help="CLI tool to explore IBDTransDB database",
    add_completion=False,
)

# Add sub-commands
app.add_typer(datasets.app, name="datasets", help="Browse and filter datasets")
app.add_typer(inspect.app, name="inspect", help="Inspect database schema and run SQL")

# Global options
DATABASE_PATH = Path(__file__).parent.parent / "data" / "IBDTransDB.db"


@app.callback()
def main(
    ctx: typer.Context,
    db_path: Path = typer.Option(
        DATABASE_PATH,
        "--db",
        "-d",
        help="Path to IBDTransDB.db file",
        exists=True,
    ),
):
    """IBDTransDB CLI - Explore transcriptomic data for IBD research"""
    ctx.obj = {"db_path": db_path}


if __name__ == "__main__":
    app()
