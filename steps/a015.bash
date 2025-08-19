#!/usr/bin/env bash
# ACTION-015: Docs & ERD validation
set -euo pipefail
export DOCKER_CLI_HINTS=false

LOG_LEVEL=${LOG_LEVEL:-normal}
[[ "$LOG_LEVEL" == "debug" ]] && set -x

API_DOC="docs/api/README.md"
SCH_DOC="docs/schema/README.md"
FAIL=0

say() { echo "$@"; }

say "ACTION-015: Validate docs"

# Basic checks for API doc
[[ -f "$API_DOC" ]] || { say "[FAIL] $API_DOC missing"; exit 1; }
grep -q "/users/register" "$API_DOC" || { say "[FAIL] register endpoint missing"; FAIL=1; }
grep -q "/users/login" "$API_DOC" || { say "[FAIL] login endpoint missing"; FAIL=1; }
grep -q "/objects" "$API_DOC" || { say "[FAIL] objects endpoints missing"; FAIL=1; }
grep -q "/metadata" "$API_DOC" || { say "[FAIL] metadata endpoint missing"; FAIL=1; }
grep -q "/relations" "$API_DOC" || { say "[FAIL] relations endpoint missing"; FAIL=1; }
grep -q "/projects/" "$API_DOC" || { say "[FAIL] project-scoped endpoint missing"; FAIL=1; }

# Basic checks for schema doc
[[ -f "$SCH_DOC" ]] || { say "[FAIL] $SCH_DOC missing"; exit 1; }
grep -q "password_hash" "$SCH_DOC" || { say "[FAIL] schema missing password_hash"; FAIL=1; }
grep -q "project_id" "$SCH_DOC" || { say "[FAIL] schema missing project_id"; FAIL=1; }

if [[ "$LOG_LEVEL" == "debug" ]]; then
  echo "--- $API_DOC (first 100 lines) ---"; sed -n '1,100p' "$API_DOC" || true
  echo "--- $SCH_DOC (first 100 lines) ---"; sed -n '1,100p' "$SCH_DOC" || true
fi

if [[ $FAIL -ne 0 ]]; then
  say "❌ ACTION-015 failed"; exit 1
else
  say "✅ ACTION-015 completed successfully"; exit 0
fi
