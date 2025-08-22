#!/usr/bin/env bash
# ACTION-016: Response shape alignment and timestamps
set -euo pipefail
export DOCKER_CLI_HINTS=false
LOG_LEVEL=${LOG_LEVEL:-normal}
[[ "$LOG_LEVEL" == "debug" ]] && set -x
DB="/data/apios.db"

say() { echo "$@"; }

say "ACTION-016: Align response shapes and add timestamps"
# Add created_at/updated_at to linguistic_objects and metadata if missing (no DEFAULT to avoid SQLite error)
for tbl in linguistic_objects metadata; do
  for col in created_at updated_at; do
    has=$(docker exec apios sqlite3 "$DB" "SELECT 1 FROM pragma_table_info('$tbl') WHERE name='$col' LIMIT 1;") || has=""
    if [[ -z "$has" ]]; then
      docker exec apios sqlite3 "$DB" "ALTER TABLE $tbl ADD COLUMN $col TIMESTAMP" >/dev/null 2>&1 || true
    fi
  done
done
# Ensure deleted_at exists for future pruning
for tbl in linguistic_objects metadata relations; do
  has=$(docker exec apios sqlite3 "$DB" "SELECT 1 FROM pragma_table_info('$tbl') WHERE name='deleted_at' LIMIT 1;") || has=""
  if [[ -z "$has" ]]; then
    docker exec apios sqlite3 "$DB" "ALTER TABLE $tbl ADD COLUMN deleted_at TIMESTAMP" >/dev/null 2>&1 || true
  fi
done

say "✅ ACTION-016 completed successfully"
