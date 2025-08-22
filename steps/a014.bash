#!/usr/bin/env bash
# ACTION-014: CI/CD skeleton validation
set -euo pipefail
export DOCKER_CLI_HINTS=false

LOG_LEVEL=${LOG_LEVEL:-normal}
[[ "$LOG_LEVEL" == "debug" ]] && set -x

FAIL=0
WF=".github/workflows/ci.yml"

say() { echo "$@"; }

say "ACTION-014: Validate CI workflow"

if [[ ! -f "$WF" ]]; then
  say "[FAIL] Workflow $WF not found"; exit 1
fi

# Rudimentary checks
grep -q "name:" "$WF" || { say "[FAIL] missing name"; FAIL=1; }
grep -q "on:" "$WF" || { say "[FAIL] missing on"; FAIL=1; }
grep -q "jobs:" "$WF" || { say "[FAIL] missing jobs"; FAIL=1; }
grep -q "run-steps.bash" "$WF" || { say "[FAIL] steps runner not invoked"; FAIL=1; }

if [[ "$LOG_LEVEL" == "debug" ]]; then
  echo "--- $WF ---"
  sed -n '1,200p' "$WF"
fi

if [[ $FAIL -ne 0 ]]; then
  say "❌ ACTION-014 failed"; exit 1
else
  say "✅ ACTION-014 completed successfully"; exit 0
fi
