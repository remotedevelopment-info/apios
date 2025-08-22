#!/usr/bin/env bash
# ACTION-024: Run pytest locally
set -euo pipefail
export DOCKER_CLI_HINTS=false
LOG_LEVEL=${LOG_LEVEL:-normal}
[[ "$LOG_LEVEL" == "debug" ]] && set -x

say() { echo "$@"; }

say "ACTION-024: Running pytest"
# Create and use a local virtual environment to avoid system Python restrictions
if [[ ! -d .venv ]]; then
  python3 -m venv .venv
fi
source .venv/bin/activate
python -m pip install --upgrade pip >/dev/null
python -m pip install -r requirements-dev.txt >/dev/null

# Use a fresh temporary SQLite DB for this test run so tables and data are isolated
TEST_DB="$(mktemp -t apios-test-XXXXXX.db)"
trap 'rm -f "$TEST_DB" || true' EXIT
export APISQLITE_DB_PATH="$TEST_DB"
export JWT_SECRET='test-secret'

python -m pytest -q
say "✅ ACTION-024 completed successfully"
