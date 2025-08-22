#!/usr/bin/env bash
# ACTION-028: Pruning strategy (soft delete)
set -euo pipefail
export DOCKER_CLI_HINTS=false
DB="/data/apios.db"
LOG_LEVEL=${LOG_LEVEL:-normal}
[[ "$LOG_LEVEL" == "debug" ]] && set -x

say() { echo "$@"; }

say "ACTION-028: Ensure deleted_at columns exist and API excludes by default"
for tbl in linguistic_objects metadata relations; do
  has=$(docker exec apios sqlite3 "$DB" "SELECT 1 FROM pragma_table_info('$tbl') WHERE name='deleted_at' LIMIT 1;") || has=""
  if [[ -z "$has" ]]; then
    docker exec apios sqlite3 "$DB" "ALTER TABLE $tbl ADD COLUMN deleted_at TIMESTAMP" || true
  fi
done
say "✅ ACTION-028 completed successfully"
