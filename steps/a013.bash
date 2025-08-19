#!/usr/bin/env bash
# ACTION-013: Project scoping of objects
set -euo pipefail
export DOCKER_CLI_HINTS=false

LOG_LEVEL=${LOG_LEVEL:-normal}
[[ "$LOG_LEVEL" == "debug" ]] && set -x

DB="/data/apios.db"
IMAGE="apios-api:latest"
NAME="apios-api"
PORT=8080
JWT_SECRET=${JWT_SECRET:-dev-secret-change-me}
FAIL=0

say() { echo "$@"; }
log_debug() { [[ "$LOG_LEVEL" == "debug" ]] && echo "$@" || true; }

say "ACTION-013: Project scoping"

# Ensure index on project_id
if ! docker exec apios sqlite3 "$DB" ".schema linguistic_objects" | grep -q "project_id"; then
  docker exec apios sqlite3 "$DB" "ALTER TABLE linguistic_objects ADD COLUMN project_id INTEGER" || true
fi
# optional index
docker exec apios sqlite3 "$DB" "CREATE INDEX IF NOT EXISTS idx_linguistic_objects_project ON linguistic_objects(project_id)" || true

# Ensure API running with JWT
if ! curl -fsS "http://localhost:${PORT}/objects" >/dev/null 2>&1; then
  docker rm -f "$NAME" >/dev/null 2>&1 || true
  if ! docker network inspect apios-net >/dev/null 2>&1; then docker network create apios-net >/dev/null; fi
  docker run -d --name "$NAME" --network apios-net -e JWT_SECRET="$JWT_SECRET" -p ${PORT}:8000 -v "$(pwd)/data:/data" "$IMAGE" >/dev/null
  sleep 1
fi

# Register/login (idempotent)
reg_payload='{"username":"u013","password":"p013","email":"u013@example.com"}'
reg_resp=$(curl -sS -H 'Content-Type: application/json' -d "$reg_payload" "http://localhost:${PORT}/users/register") || reg_resp=""
if echo "$reg_resp" | grep -q '"id"' && echo "$reg_resp" | grep -q '"username"'; then
  say "[OK] register succeeded"
elif echo "$reg_resp" | grep -qi 'already exists'; then
  say "[OK] user already exists"
else
  say "[WARN] register response unexpected: $reg_resp"; fi
login_payload='{"username":"u013","password":"p013"}'
login_resp=$(curl -sS -H 'Content-Type: application/json' -d "$login_payload" "http://localhost:${PORT}/users/login") || login_resp=""
# BSD/macOS compatible token extraction
token=$(printf '%s' "$login_resp" | grep -Eo '"access_token"[[:space:]]*:[[:space:]]*"[^"]*"' | head -n1 | sed -E 's/.*"access_token"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/')
[[ -n "$token" ]] || { say "[FAIL] login failed"; exit 1; }

# Ensure a project exists
proj_name="Project-013"
owner_id=$(docker exec apios sqlite3 "$DB" "SELECT id FROM users WHERE username='u013' LIMIT 1;")
if [[ -z "$owner_id" ]]; then say "[FAIL] owner not found"; exit 1; fi
proj_id=$(docker exec apios sqlite3 "$DB" "SELECT id FROM projects WHERE name='$proj_name' LIMIT 1;")
if [[ -z "$proj_id" ]]; then
  docker exec apios sqlite3 "$DB" "INSERT INTO projects (name, owner_id) VALUES ('$proj_name', $owner_id);" >/dev/null
  proj_id=$(docker exec apios sqlite3 "$DB" "SELECT id FROM projects WHERE name='$proj_name' LIMIT 1;")
fi
say "[OK] using project_id=$proj_id"

# Create 2 objects in project, 1 without project
b1=$(printf '{"name":"pobj1","content":"a","project_id":%s}' "$proj_id")
b2=$(printf '{"name":"pobj2","content":"b","project_id":%s}' "$proj_id")
b3='{"name":"noproj","content":"c"}'

curl -sS -H "Authorization: Bearer $token" -H 'Content-Type: application/json' -d "$b1" "http://localhost:${PORT}/objects" >/dev/null
curl -sS -H "Authorization: Bearer $token" -H 'Content-Type: application/json' -d "$b2" "http://localhost:${PORT}/objects" >/dev/null
curl -sS -H "Authorization: Bearer $token" -H 'Content-Type: application/json' -d "$b3" "http://localhost:${PORT}/objects" >/dev/null

# Query project-scoped objects
resp=$(curl -sS "http://localhost:${PORT}/projects/${proj_id}/objects") || resp="[]"
count=$(echo "$resp" | grep -o '"id"' | wc -l | tr -d ' ')
log_debug "Project objects response: $resp"
if [[ "$count" -ge 2 ]]; then
  say "[OK] project-scoped listing returned >=2 objects"
else
  say "[FAIL] project-scoped listing returned $count objects"; FAIL=1
fi

if [[ $FAIL -ne 0 ]]; then
  say "❌ ACTION-013 failed"; exit 1
else
  say "✅ ACTION-013 completed successfully"; exit 0
fi
