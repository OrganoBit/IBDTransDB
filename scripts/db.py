"""Database connection and query utilities"""
import sqlite3
from pathlib import Path
from typing import List, Dict, Any
import pandas as pd


class IBDTransDB:
    """Database connection wrapper for IBDTransDB SQLite database"""

    def __init__(self, db_path: Path):
        self.db_path = db_path
        self.conn = None

    def __enter__(self):
        self.conn = sqlite3.connect(self.db_path)
        self.conn.row_factory = sqlite3.Row
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        if self.conn:
            self.conn.close()

    def query(self, sql: str, params: tuple = ()) -> List[Dict[str, Any]]:
        """Execute SQL query and return results as list of dicts"""
        cursor = self.conn.cursor()
        cursor.execute(sql, params)
        columns = [desc[0] for desc in cursor.description]
        return [dict(zip(columns, row)) for row in cursor.fetchall()]

    def query_df(self, sql: str, params: tuple = ()) -> pd.DataFrame:
        """Execute SQL query and return pandas DataFrame"""
        return pd.read_sql_query(sql, self.conn, params=params)

    def get_table_names(self) -> List[str]:
        """Get all table names in the database"""
        sql = "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name"
        return [row['name'] for row in self.query(sql)]

    def get_table_info(self, table_name: str) -> List[Dict[str, Any]]:
        """Get column information for a specific table"""
        return self.query(f"PRAGMA table_info({table_name})")

    def get_row_count(self, table_name: str) -> int:
        """Get row count for a specific table"""
        result = self.query(f"SELECT COUNT(*) as count FROM {table_name}")
        return result[0]['count']
