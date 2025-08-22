#!/usr/bin/env bash
# ACTION-022: API ergonomics (pagination/filtering/error schema)
set -euo pipefail
export DOCKER_CLI_HINTS=false
LOG_LEVEL=${LOG_LEVEL:-normal}
[[ "$LOG_LEVEL" == "debug" ]] && set -x

say() { echo "$@"; }

say "ACTION-022: Validate pagination and filtering"
# Basic calls
curl -fsS "http://localhost:8080/objects?limit=2&offset=0" | grep -q '"items"' || { echo "[FAIL] pagination missing"; exit 1; }
curl -fsS "http://localhost:8080/objects?meta_key=stage" >/dev/null || { echo "[FAIL] meta filter failed"; exit 1; }
say "✅ ACTION-022 completed successfully"
