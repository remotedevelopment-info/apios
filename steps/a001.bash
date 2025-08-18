#!/bin/bash
# steps/a001.bash - Initialize ApiOS environment
# Works with src/ folder structure

set -e

echo "Step 1: Build Docker environment"

# Containers to check
containers=("apios" "apios-mongo" "apios-sqlite")

for c in "${containers[@]}"; do
    if [ "$(docker ps -aq -f name=$c)" ]; then
        echo "Container $c exists. Removing..."
        docker rm -f $c || true
    fi
done

# Build image only if it doesn't exist
if [ -z "$(docker images -q apios-apios)" ]; then
    echo "Docker image does not exist. Building..."
    docker compose build
else
    echo "Docker image exists. Skipping build."
fi

# Build if image does not exist
if [ -z "$(docker images -q apios-apios)" ]; then
    echo "Building Docker image..."
    docker compose build
else
    echo "Docker image exists, skipping build."
fi

echo "Step 2: Start containers"
docker compose up -d

# make Docker CLI stop printing "What's next" hints
export DOCKER_CLI_HINTS=false

echo "Step 3: Initialize MongoDB collections via Python"
docker exec -i apios bash -c "\
python3 - <<'PYTHON'
from pymongo import MongoClient
client = MongoClient('mongodb://apios-mongo:27017/')
db = client.apios_db
for coll in ['linguistic_objects','library_definitions','user_interactions']:
    if coll not in db.list_collection_names():
        db.create_collection(coll)
print('MongoDB initialized:', db.list_collection_names())
PYTHON
"

echo "Step 4: Ensure /data exists for SQLite"
docker exec -i apios bash -c 'mkdir -p /data' >/dev/null 2>&1

echo "Step 5: Initialize SQLite database"
docker exec -i apios bash -c "\
sqlite3 /data/apios.db <<'SQL'
CREATE TABLE IF NOT EXISTS linguistic_objects (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    noun TEXT,
    adjectives TEXT,
    verbs TEXT,
    metadata TEXT
);
CREATE TABLE IF NOT EXISTS library_definitions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT,
    version TEXT,
    definition TEXT
);
CREATE TABLE IF NOT EXISTS user_interactions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT,
    action TEXT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
);
SQL
" >/dev/null 2>&1

echo "Step 6: Verify SQLite tables"
docker exec -i apios bash -c \
"sqlite3 /data/apios.db \"SELECT name FROM sqlite_master WHERE type='table';\""

echo "ApiOS environment initialized successfully!"

