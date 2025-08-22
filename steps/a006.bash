#!/usr/bin/env bash
# ACTION-006: Define core entities in schema
set -euo pipefail
export DOCKER_CLI_HINTS=false

VERBOSE=false
if [[ "${1:-}" == "--verbose" ]]; then VERBOSE=true; fi

DB="/data/apios.db"
FAIL=0

echo "Step 6: Applying schema migrations for core entities"

# Ensure sqlite3 exists in container
if ! docker exec apios bash -lc 'command -v sqlite3 >/dev/null 2>&1'; then
  echo "[FAIL] sqlite3 not found in apios container"; exit 1; fi

# Ensure /data exists on host (bind mount)
mkdir -p ./data

# --- MIGRATION: Normalize linguistic_objects schema to canonical columns ---
# Target schema: id, noun, adjectives, verbs, metadata
has_noun=$(docker exec apios sqlite3 "$DB" "SELECT 1 FROM pragma_table_info('linguistic_objects') WHERE name='noun' LIMIT 1;") || has_noun=""
has_name=$(docker exec apios sqlite3 "$DB" "SELECT 1 FROM pragma_table_info('linguistic_objects') WHERE name='name' LIMIT 1;") || has_name=""
if [[ -z "$has_noun" && -n "$has_name" ]]; then
  echo "[INFO] Migrating linguistic_objects from (name,content) -> (noun,metadata)"
  if docker exec -i apios bash -lc "sqlite3 '$DB' <<'SQL'
PRAGMA foreign_keys=OFF;
BEGIN;
CREATE TABLE IF NOT EXISTS linguistic_objects_new (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  noun TEXT,
  adjectives TEXT,
  verbs TEXT,
  metadata TEXT
);
INSERT INTO linguistic_objects_new (id, noun, metadata)
SELECT id, name, content FROM linguistic_objects;
DROP TABLE linguistic_objects;
ALTER TABLE linguistic_objects_new RENAME TO linguistic_objects;
COMMIT;
PRAGMA foreign_keys=ON;
SQL"; then
    echo "[OK] linguistic_objects migrated"
  else
    echo "[FAIL] Failed to migrate linguistic_objects"; FAIL=1
  fi
else
  [[ -n "$has_noun" ]] && echo "[OK] linguistic_objects already in canonical schema" || echo "[INFO] No migration needed"
fi

# Apply migrations for new core tables idempotently
if docker exec -i apios bash -lc "sqlite3 '$DB' <<'SQL'
PRAGMA foreign_keys=ON;
PRAGMA journal_mode=WAL;
PRAGMA synchronous=NORMAL;

-- users
CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  username TEXT NOT NULL UNIQUE,
  email TEXT NOT NULL UNIQUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- projects
CREATE TABLE IF NOT EXISTS projects (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE,
  owner_id INTEGER NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (owner_id) REFERENCES users(id) ON DELETE CASCADE
);

-- metadata associated with linguistic_objects
CREATE TABLE IF NOT EXISTS metadata (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  key TEXT NOT NULL,
  value TEXT,
  object_id INTEGER NOT NULL,
  FOREIGN KEY (object_id) REFERENCES linguistic_objects(id) ON DELETE CASCADE,
  UNIQUE(key, object_id)
);

-- relations between linguistic_objects
CREATE TABLE IF NOT EXISTS relations (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  subject_id INTEGER NOT NULL,
  predicate TEXT NOT NULL,
  object_id INTEGER NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (subject_id) REFERENCES linguistic_objects(id) ON DELETE CASCADE,
  FOREIGN KEY (object_id) REFERENCES linguistic_objects(id) ON DELETE CASCADE
);

-- clean duplicates in relations before creating unique index
DELETE FROM relations
WHERE rowid NOT IN (
  SELECT MIN(rowid) FROM relations GROUP BY subject_id, predicate, object_id
);

-- helpful indexes
CREATE INDEX IF NOT EXISTS idx_projects_owner_id ON projects(owner_id);
CREATE INDEX IF NOT EXISTS idx_metadata_object_id ON metadata(object_id);
CREATE INDEX IF NOT EXISTS idx_relations_subject ON relations(subject_id);
CREATE INDEX IF NOT EXISTS idx_relations_object ON relations(object_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_relations_unique ON relations(subject_id, predicate, object_id);
SQL"; then
  echo "[OK] Migrations applied"
else
  echo "[FAIL] Failed to apply migrations"; FAIL=1
fi

# Verification: check tables exist
if docker exec apios sqlite3 "$DB" ".tables" | tr '\n' ' ' | grep -q "\busers\b" && \
   docker exec apios sqlite3 "$DB" ".tables" | tr '\n' ' ' | grep -q "\bprojects\b" && \
   docker exec apios sqlite3 "$DB" ".tables" | tr '\n' ' ' | grep -q "\bmetadata\b" && \
   docker exec apios sqlite3 "$DB" ".tables" | tr '\n' ' ' | grep -q "\brelations\b"; then
  echo "[OK] Tables present: users, projects, metadata, relations"
else
  echo "[FAIL] One or more tables missing"; FAIL=1
fi

if [[ "$VERBOSE" == true ]]; then
  echo "--- .schema linguistic_objects ---"; docker exec apios sqlite3 "$DB" ".schema linguistic_objects" || true
  echo "--- .schema users ---"; docker exec apios sqlite3 "$DB" ".schema users" || true
  echo "--- .schema projects ---"; docker exec apios sqlite3 "$DB" ".schema projects" || true
  echo "--- .schema metadata ---"; docker exec apios sqlite3 "$DB" ".schema metadata" || true
  echo "--- .schema relations ---"; docker exec apios sqlite3 "$DB" ".schema relations" || true
fi

if [[ $FAIL -ne 0 ]]; then
  echo "❌ ACTION-006 failed"; exit 1
else
  echo "✅ ACTION-006 completed successfully"; exit 0
fi
