#!/usr/bin/env bash
export DOCKER_CLI_HINTS=false
set -euo pipefail

echo "Step 3: Initialize SQLite schema"

DB_FILE="/data/apios.db"

# ensure sqlite3 is available
if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "Error: sqlite3 is not installed or not in PATH"
  exit 1
fi

# ensure /data exists
mkdir -p ./data 

# create tables (idempotent with IF NOT EXISTS)
docker exec -it apios bash -c "sqlite3 \"$DB_FILE\" <<'SQL'
CREATE TABLE IF NOT EXISTS linguistic_objects (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS library_definitions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    key TEXT NOT NULL UNIQUE,
    definition TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS user_interactions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT NOT NULL,
    action TEXT NOT NULL,
    details TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
SQL"

echo "SQLite schema initialized in $DB_FILE"

