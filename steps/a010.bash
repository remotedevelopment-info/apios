#!/usr/bin/env bash
# ACTION-010: Build minimal API (MVP) and integration test
set -euo pipefail
export DOCKER_CLI_HINTS=false

IMAGE="apios-api:latest"
NAME="apios-api"
PORT=8080
DB_MOUNT="$(pwd)/data:/data:ro"

echo "Building API image"
docker build -t "$IMAGE" -f api/Dockerfile .

# Restart container idempotently
if [ "$(docker ps -aq -f name=^${NAME}$)" ]; then
  docker rm -f "$NAME" >/dev/null 2>&1 || true
fi

echo "Starting API container on :$PORT"
docker run -d --name "$NAME" --network apios-net -p ${PORT}:8000 -v "$DB_MOUNT" "$IMAGE"

# Wait for readiness
printf "Waiting for API to be ready"
for i in {1..30}; do
  if curl -fsS "http://localhost:${PORT}/objects" >/dev/null 2>&1; then echo ""; break; fi
  printf "."; sleep 1
  if [[ $i -eq 30 ]]; then echo "\n[FAIL] API did not become ready"; exit 1; fi
done

# Hit endpoints
echo "[Test] GET /objects"
resp=$(curl -fsS "http://localhost:${PORT}/objects") || { echo "[FAIL] /objects request failed"; exit 1; }
# Basic validation: JSON array
if echo "$resp" | grep -q "^\["; then echo "[OK] /objects returned array"; else echo "[FAIL] /objects not array"; exit 1; fi

echo "[Test] GET /objects/1"
resp2=$(curl -fsS "http://localhost:${PORT}/objects/1") || { echo "[FAIL] /objects/1 request failed"; exit 1; }
# Basic validation: contains id and metadata_entries keys
if echo "$resp2" | grep -q '"id"' && echo "$resp2" | grep -q '"metadata_entries"'; then
  echo "[OK] /objects/1 returned expected fields"
else
  echo "[FAIL] /objects/1 response missing expected fields"; exit 1
fi

echo "✅ ACTION-010 completed successfully"
