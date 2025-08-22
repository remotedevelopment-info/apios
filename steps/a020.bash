#!/usr/bin/env bash
# ACTION-020: Migration versioning
set -euo pipefail
export DOCKER_CLI_HINTS=false
DB="/data/apios.db"
LOG_LEVEL=${LOG_LEVEL:-normal}
[[ "$LOG_LEVEL" == "debug" ]] && set -x

say() { echo "$@"; }

say "ACTION-020: Create migrations table and backfill"
# Create migrations table
docker exec apios sqlite3 "$DB" "CREATE TABLE IF NOT EXISTS migrations (version TEXT PRIMARY KEY)" >/dev/null
# Backfill 001-015
for v in $(seq -w 001 015); do
  docker exec apios sqlite3 "$DB" "INSERT OR IGNORE INTO migrations(version) VALUES ('$v')" >/dev/null
done
say "✅ ACTION-020 completed successfully"
