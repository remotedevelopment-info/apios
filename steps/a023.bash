#!/usr/bin/env bash
# ACTION-023: Observability endpoints and JSON logging
set -euo pipefail
export DOCKER_CLI_HINTS=false
LOG_LEVEL=${LOG_LEVEL:-normal}
[[ "$LOG_LEVEL" == "debug" ]] && set -x

say() { echo "$@"; }

say "ACTION-023: Validate /ready and /metrics"
# Ensure API up
if ! curl -fsS http://localhost:8080/health >/dev/null 2>&1; then
  docker rm -f apios-api >/dev/null 2>&1 || true
  docker run -d --name apios-api --network apios-net -p 8080:8000 -v "$(pwd)/data:/data" apios-api:latest >/dev/null
  sleep 1
fi
curl -fsS http://localhost:8080/ready | grep -q '"status"' || { echo "[FAIL] /ready"; exit 1; }
curl -fsS http://localhost:8080/metrics | grep -q '"requests"' || { echo "[FAIL] /metrics"; exit 1; }
say "✅ ACTION-023 completed successfully"
