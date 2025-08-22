#!/usr/bin/env bash
# ACTION-010: Build minimal API (MVP) and integration test
set -euo pipefail
export DOCKER_CLI_HINTS=false

IMAGE="apios-api:latest"
NAME="apios-api"
PORT=8080
DB_MOUNT="$(pwd)/data:/data"

# Added: log level and JWT secret for container
LOG_LEVEL=${LOG_LEVEL:-normal}
[[ "$LOG_LEVEL" == "debug" ]] && set -x
JWT_SECRET=${JWT_SECRET:-dev-secret-change-me}

# Added: curl flags based on log level
CURL_FLAGS="-fsS"
if [[ "$LOG_LEVEL" == "debug" ]]; then
  CURL_FLAGS="-v --fail --show-error"
fi

DB_PATH="/data/apios.db"
ensure_col() {
  local col="$1"; local typ="$2"
  local has_col
  has_col=$(docker exec apios sqlite3 "$DB_PATH" "SELECT 1 FROM pragma_table_info('linguistic_objects') WHERE name='$col' LIMIT 1;") || has_col=""
  if [[ -z "$has_col" ]]; then
    echo "[MIGRATE] Adding column $col ($typ) to linguistic_objects"
    docker exec apios sqlite3 "$DB_PATH" "ALTER TABLE linguistic_objects ADD COLUMN $col $typ"
  fi
  # recheck
  has_col=$(docker exec apios sqlite3 "$DB_PATH" "SELECT 1 FROM pragma_table_info('linguistic_objects') WHERE name='$col' LIMIT 1;") || has_col=""
  if [[ -z "$has_col" ]]; then
    echo "[FAIL] Column $col not present after migration"
    echo "--- current schema (linguistic_objects) ---"
    docker exec apios sqlite3 "$DB_PATH" ".schema linguistic_objects" || true
    exit 1
  fi
}

# Ensure DB has columns that API expects (content, project_id)
ensure_col content TEXT
ensure_col project_id INTEGER

echo "Building API image"
docker build -t "$IMAGE" -f api/Dockerfile .

# Ensure network exists (align with docker-compose network)
if ! docker network inspect apios-net >/dev/null 2>&1; then
  echo "Creating network apios-net"
  docker network create apios-net >/dev/null
fi

# Restart container idempotently
if [ "$(docker ps -aq -f name=^${NAME}$)" ]; then
  docker rm -f "$NAME" >/dev/null 2>&1 || true
fi

echo "Starting API container on :$PORT"
# Added: pass JWT_SECRET into container
docker run -d --name "$NAME" --network apios-net -p ${PORT}:8000 -e JWT_SECRET="$JWT_SECRET" -v "$DB_MOUNT" "$IMAGE"

# Wait for readiness
printf "Waiting for API to be ready"
# Increased retries to 45 seconds and log container output on failure
for i in {1..45}; do
  if curl $CURL_FLAGS "http://localhost:${PORT}/health" >/dev/null 2>&1; then echo ""; break; fi
  printf "."; sleep 1
  if [[ $i -eq 45 ]]; then
    printf "\n[FAIL] API did not become ready\n"
    echo "--- docker logs ($NAME) last 100 lines ---"
    docker logs --tail=100 "$NAME" || true
    echo "--- container /data listing ---"
    docker exec "$NAME" sh -lc 'ls -l /data && ls -l /data/apios.db* || true'
    exit 1
  fi
done

# Hit endpoints
echo "[Test] GET /objects"
resp=$(curl $CURL_FLAGS "http://localhost:${PORT}/objects") || { echo "[FAIL] /objects request failed"; exit 1; }
# Basic validation: JSON array
if echo "$resp" | grep -q "^\["; then echo "[OK] /objects returned array"; else echo "[FAIL] /objects not array"; [[ "$LOG_LEVEL" == "debug" ]] && echo "$resp"; exit 1; fi

echo "[Test] GET /objects/1"
resp2=$(curl $CURL_FLAGS "http://localhost:${PORT}/objects/1") || { echo "[FAIL] /objects/1 request failed"; exit 1; }
# Basic validation: contains id and metadata_entries keys
if echo "$resp2" | grep -q '"id"' && echo "$resp2" | grep -q '"metadata_entries"'; then
  echo "[OK] /objects/1 returned expected fields"
else
  echo "[FAIL] /objects/1 response missing expected fields"; [[ "$LOG_LEVEL" == "debug" ]] && echo "$resp2"; exit 1
fi

echo "✅ ACTION-010 completed successfully"
