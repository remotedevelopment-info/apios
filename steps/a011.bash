#!/usr/bin/env bash
# ACTION-011: Extend API with write endpoints and DB migration for project_id/content
set -euo pipefail
export DOCKER_CLI_HINTS=false

LOG_LEVEL=${LOG_LEVEL:-normal}
[[ "$LOG_LEVEL" == "debug" ]] && set -x

DB="/data/apios.db"
IMAGE="apios-api:latest"
NAME="apios-api"
PORT=8080
FAIL=0

say() { echo "$@"; }
log_debug() { [[ "$LOG_LEVEL" == "debug" ]] && echo "$@" || true; }
show_logs() { echo "--- docker logs ($NAME) last 100 lines ---"; docker logs --tail=100 "$NAME" || true; }

say "ACTION-011: API write endpoints and migration"

# Ensure column project_id exists; add if missing
has_proj=$(docker exec apios sqlite3 "$DB" "SELECT 1 FROM pragma_table_info('linguistic_objects') WHERE name='project_id' LIMIT 1;") || has_proj=""
if [[ -z "$has_proj" ]]; then
  log_debug "Adding project_id column to linguistic_objects"
  if docker exec apios sqlite3 "$DB" "ALTER TABLE linguistic_objects ADD COLUMN project_id INTEGER"; then
    say "[OK] Added project_id column"
  else
    say "[FAIL] Failed to add project_id column"; FAIL=1
  fi
else
  say "[OK] project_id column already present"
fi

# Ensure column content exists; add if missing
has_content=$(docker exec apios sqlite3 "$DB" "SELECT 1 FROM pragma_table_info('linguistic_objects') WHERE name='content' LIMIT 1;") || has_content=""
if [[ -z "$has_content" ]]; then
  log_debug "Adding content column to linguistic_objects"
  if docker exec apios sqlite3 "$DB" "ALTER TABLE linguistic_objects ADD COLUMN content TEXT"; then
    say "[OK] Added content column"
  else
    say "[FAIL] Failed to add content column"; FAIL=1
  fi
else
  say "[OK] content column already present"
fi

# Rebuild API and restart container
say "Building API image"
docker build -t "$IMAGE" -f api/Dockerfile . >/dev/null

if ! docker network inspect apios-net >/dev/null 2>&1; then
  docker network create apios-net >/dev/null
fi

if [ "$(docker ps -aq -f name=^${NAME}$)" ]; then
  docker rm -f "$NAME" >/dev/null 2>&1 || true
fi

# Start API with RW data mount (WAL + writes required)
docker run -d --name "$NAME" --network apios-net -p ${PORT}:8000 -v "$(pwd)/data:/data" "$IMAGE" >/dev/null

# Small wait loop
for i in {1..20}; do
  if curl -fsS "http://localhost:${PORT}/objects" >/dev/null 2>&1; then break; fi
  sleep 0.5
done

# Create an object (no auth yet)
payload='{"name":"gamma","content":"c","metadata":{"k":"v"}}'
[[ "$LOG_LEVEL" == "debug" ]] && echo "Payload: $payload"
resp=$(curl -fsS -H 'Content-Type: application/json' -d "$payload" "http://localhost:${PORT}/objects") || resp=""
[[ "$LOG_LEVEL" == "debug" ]] && echo "Response: $resp"
if echo "$resp" | grep -q '"id"' && echo "$resp" | grep -q '"name"'; then
  say "[OK] POST /objects created object"
else
  say "[FAIL] POST /objects failed"; show_logs; FAIL=1
fi

# Add metadata
obj_id=$(printf '%s' "$resp" | grep -o '"id"[[:space:]]*:[[:space:]]*[0-9]\+' | head -n1 | tr -cd '0-9')
if [[ -n "$obj_id" ]]; then
  mbody='{"object_id":'$obj_id',"key":"stage","value":"a011"}'
  [[ "$LOG_LEVEL" == "debug" ]] && echo "Payload: $mbody"
  mresp=$(curl -fsS -H 'Content-Type: application/json' -d "$mbody" "http://localhost:${PORT}/metadata") || mresp=""
  [[ "$LOG_LEVEL" == "debug" ]] && echo "Response: $mresp"
  if echo "$mresp" | grep -q '"key"' && echo "$mresp" | grep -q '"value"'; then
    say "[OK] POST /metadata added row"
  else
    say "[FAIL] POST /metadata failed"; show_logs; FAIL=1
  fi
else
  say "[FAIL] Could not parse created object id"; FAIL=1
fi

# Create relation between two known objects if present
if docker exec apios sqlite3 "$DB" "SELECT COUNT(*) FROM linguistic_objects WHERE id IN (1,2);" | grep -q '2'; then
  rbody='{"subject_id":1,"predicate":"related_to","object_id":2}'
  [[ "$LOG_LEVEL" == "debug" ]] && echo "Payload: $rbody"
  rresp=$(curl -fsS -H 'Content-Type: application/json' -d "$rbody" "http://localhost:${PORT}/relations") || rresp=""
  [[ "$LOG_LEVEL" == "debug" ]] && echo "Response: $rresp"
  if echo "$rresp" | grep -q '"predicate"'; then
    say "[OK] POST /relations created relation"
  else
    say "[FAIL] POST /relations failed"; show_logs; FAIL=1
  fi
else
  say "[OK] Skipped relation test (insufficient baseline objects)"
fi

if [[ $FAIL -ne 0 ]]; then
  say "❌ ACTION-011 failed"; exit 1
else
  say "✅ ACTION-011 completed successfully"; exit 0
fi
