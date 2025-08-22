#!/usr/bin/env bash
# ACTION-019: Authorization model (projects_users)
set -euo pipefail
export DOCKER_CLI_HINTS=false
LOG_LEVEL=${LOG_LEVEL:-normal}
[[ "$LOG_LEVEL" == "debug" ]] && set -x
DB="/data/apios.db"

say() { echo "$@"; }

say "ACTION-019: Add projects_users table and seed roles"
# Create join table if missing
docker exec apios sqlite3 "$DB" "CREATE TABLE IF NOT EXISTS projects_users (project_id INTEGER NOT NULL, user_id INTEGER NOT NULL, role TEXT NOT NULL, PRIMARY KEY (project_id, user_id))" >/dev/null
# Seed owner membership for existing project/user combos
owner_id=$(docker exec apios sqlite3 "$DB" "SELECT id FROM users WHERE username='u012' LIMIT 1;")
proj_id=$(docker exec apios sqlite3 "$DB" "SELECT id FROM projects LIMIT 1;")
if [[ -n "$owner_id" && -n "$proj_id" ]]; then
  docker exec apios sqlite3 "$DB" "INSERT OR IGNORE INTO projects_users (project_id, user_id, role) VALUES ($proj_id, $owner_id, 'owner')" >/dev/null
fi
say "✅ ACTION-019 completed successfully"
