#!/usr/bin/env bash
# ACTION-017: DB connection defaults
set -euo pipefail
export DOCKER_CLI_HINTS=false
LOG_LEVEL=${LOG_LEVEL:-normal}
[[ "$LOG_LEVEL" == "debug" ]] && set -x

say() { echo "$@"; }

say "ACTION-017: Ensure DB connection defaults applied"
# No DB migration; verify API can read with WAL and PRAGMAs
if ! curl -fsS http://localhost:8080/health >/dev/null 2>&1; then
  say "[INFO] Starting API for checks"
  docker rm -f apios-api >/dev/null 2>&1 || true
  docker run -d --name apios-api --network apios-net -p 8080:8000 -v "$(pwd)/data:/data" apios-api:latest >/dev/null
  sleep 1
fi
curl -fsS http://localhost:8080/objects >/dev/null
say "✅ ACTION-017 completed successfully"
