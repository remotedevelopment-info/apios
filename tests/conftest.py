import os
import sys
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

os.environ.setdefault("APISQLITE_DB_PATH", ":memory:")
os.environ.setdefault("JWT_SECRET", "test-secret")

# Ensure `src` is on sys.path
ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src"
if str(SRC) not in sys.path:
    sys.path.insert(0, str(SRC))

from api.main import app
from db.connection import get_connection

# Minimal schema builder for tests
SCHEMA_SQL = """
CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  username TEXT UNIQUE NOT NULL,
  email TEXT UNIQUE,
  password_hash TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS projects (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT UNIQUE NOT NULL,
  owner_id INTEGER NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS linguistic_objects (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  noun TEXT,
  content TEXT,
  project_id INTEGER,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP,
  deleted_at TIMESTAMP
);
CREATE TABLE IF NOT EXISTS metadata (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  key TEXT NOT NULL,
  value TEXT,
  object_id INTEGER NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP,
  deleted_at TIMESTAMP,
  UNIQUE(key, object_id)
);
CREATE TABLE IF NOT EXISTS relations (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  subject_id INTEGER NOT NULL,
  predicate TEXT NOT NULL,
  object_id INTEGER NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  deleted_at TIMESTAMP
);
CREATE TABLE IF NOT EXISTS projects_users (
  project_id INTEGER NOT NULL,
  user_id INTEGER NOT NULL,
  role TEXT NOT NULL,
  PRIMARY KEY (project_id, user_id)
);
"""

@pytest.fixture(autouse=True)
def _init_db():
    with get_connection() as conn:
        for stmt in SCHEMA_SQL.strip().split(";\n"):
            s = stmt.strip()
            if s:
                conn.execute(s)
        conn.commit()
    yield

@pytest.fixture()
def client():
    return TestClient(app)
