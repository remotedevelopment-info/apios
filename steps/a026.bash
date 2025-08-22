#!/usr/bin/env bash
# ACTION-026: Secrets management (.env example)
set -euo pipefail
export DOCKER_CLI_HINTS=false
LOG_LEVEL=${LOG_LEVEL:-normal}
[[ "$LOG_LEVEL" == "debug" ]] && set -x

echo "ACTION-026: Ensure .env.example exists"
[[ -f .env.example ]] && echo "[OK] .env.example present" || { echo "[FAIL] missing .env.example"; exit 1; }
echo "✅ ACTION-026 completed successfully"
