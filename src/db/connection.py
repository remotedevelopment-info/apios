import os
from contextlib import contextmanager
from typing import Iterator

DB_BACKEND = os.getenv("DB_BACKEND", "sqlite").lower()

# SQLite backend
if DB_BACKEND == "sqlite":
    from .sqlite import get_connection as _sqlite_get_connection

    @contextmanager
    def get_connection():  # type: ignore
        with _sqlite_get_connection() as conn:
            yield conn

# Postgres stub (not implemented yet)
elif DB_BACKEND == "postgres":
    import sqlite3

    @contextmanager
    def get_connection() -> Iterator[sqlite3.Connection]:  # type: ignore
        raise NotImplementedError("Postgres backend not implemented; set DB_BACKEND=sqlite")
else:
    import sqlite3

    @contextmanager
    def get_connection() -> Iterator[sqlite3.Connection]:  # type: ignore
        raise ValueError(f"Unknown DB_BACKEND: {DB_BACKEND}")
