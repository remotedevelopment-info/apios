import os
import sqlite3
from contextlib import contextmanager

DB_PATH = os.getenv("APISQLITE_DB_PATH", "/data/apios.db")

@contextmanager
def get_connection():
    # Allow usage across threads in FastAPI
    conn = sqlite3.connect(DB_PATH, check_same_thread=False)
    conn.row_factory = sqlite3.Row
    try:
        # Enforce constraints and performance settings per-connection
        conn.execute("PRAGMA foreign_keys=ON;")
        try:
            conn.execute("PRAGMA journal_mode=WAL;")
        except sqlite3.DatabaseError:
            pass
        conn.execute("PRAGMA synchronous=NORMAL;")
        yield conn
    finally:
        conn.close()
