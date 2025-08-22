#!/usr/bin/env bash
# ACTION-012: Auth scaffold (register & login with JWT)
set -euo pipefail
export DOCKER_CLI_HINTS=false

LOG_LEVEL=${LOG_LEVEL:-normal}
[[ "$LOG_LEVEL" == "debug" ]] && set -x

DB="/data/apios.db"
IMAGE="apios-api:latest"
NAME="apios-api"
PORT=8080
JWT_SECRET=${JWT_SECRET:-dev-secret-change-me}
FAIL=0

say() { echo "$@"; }
log_debug() { [[ "$LOG_LEVEL" == "debug" ]] && echo "$@" || true; }

say "ACTION-012: Auth scaffold"

# Ensure users.password_hash column exists
has_col=$(docker exec apios sqlite3 "$DB" "SELECT 1 FROM pragma_table_info('users') WHERE name='password_hash' LIMIT 1;") || has_col=""
if [[ -z "$has_col" ]]; then
  if docker exec apios sqlite3 "$DB" "ALTER TABLE users ADD COLUMN password_hash TEXT"; then
    say "[OK] Added users.password_hash"
  else
    say "[FAIL] Could not add users.password_hash"; FAIL=1
  fi
else
  say "[OK] users.password_hash present"
fi

# Rebuild API to ensure deps present
say "Building API image"
docker build -t "$IMAGE" -f api/Dockerfile . >/dev/null

# Restart API with JWT_SECRET
docker rm -f "$NAME" >/dev/null 2>&1 || true
if ! docker network inspect apios-net >/dev/null 2>&1; then docker network create apios-net >/dev/null; fi

docker run -d --name "$NAME" --network apios-net -e JWT_SECRET="$JWT_SECRET" -p ${PORT}:8000 -v "$(pwd)/data:/data" "$IMAGE" >/dev/null

# Wait for readiness
for i in {1..30}; do
  if curl -fsS "http://localhost:${PORT}/objects" >/dev/null 2>&1; then break; fi
  sleep 0.5
done

# Credentials
USER="u012"
NEW_PW="password012"
OLD_PW="p012"

# Register user (idempotent)
reg_payload=$(printf '{"username":"%s","password":"%s","email":"%s@example.com"}' "$USER" "$NEW_PW" "$USER")
log_debug "Register payload: $reg_payload"
reg_resp=$(curl -sS -H 'Content-Type: application/json' -d "$reg_payload" "http://localhost:${PORT}/users/register") || reg_resp=""
log_debug "Register response: $reg_resp"
if echo "$reg_resp" | grep -q '"id"' && echo "$reg_resp" | grep -q '"username"'; then
  say "[OK] register succeeded"
elif echo "$reg_resp" | grep -qi 'already exists'; then
  say "[OK] user already exists"
else
  say "[FAIL] register failed"; FAIL=1
fi

# Login (try new password, then fallback to old for idempotency)
login_payload=$(printf '{"username":"%s","password":"%s"}' "$USER" "$NEW_PW")
log_debug "Login payload: $login_payload"
login_resp=$(curl -sS -H 'Content-Type: application/json' -d "$login_payload" "http://localhost:${PORT}/users/login") || login_resp=""
log_debug "Login response: $login_resp"
# Robust token extract (BSD/macOS compatible, non-failing)
token=$(printf '%s' "$login_resp" | sed -nE 's/.*"access_token"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/p' | head -n1)
if [[ -z "$token" ]]; then
  # Try old password
  login_payload=$(printf '{"username":"%s","password":"%s"}' "$USER" "$OLD_PW")
  log_debug "Login fallback payload: $login_payload"
  login_resp=$(curl -sS -H 'Content-Type: application/json' -d "$login_payload" "http://localhost:${PORT}/users/login") || login_resp=""
  log_debug "Login fallback response: $login_resp"
  token=$(printf '%s' "$login_resp" | sed -nE 's/.*"access_token"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/p' | head -n1)
fi
if [[ -n "$token" ]]; then
  say "[OK] login succeeded"
else
  say "[FAIL] login failed"; FAIL=1
fi

# Unauthorized POST /objects should 401/403
code_noauth=$(curl -s -o /dev/null -w "%{http_code}" -H 'Content-Type: application/json' -d '{"name":"x"}' "http://localhost:${PORT}/objects")
if [[ "$code_noauth" == "401" || "$code_noauth" == "403" ]]; then
  say "[OK] unauthorized blocked"
else
  say "[FAIL] unauthorized not blocked (code=$code_noauth)"; FAIL=1
fi

# Authorized POST /objects
body='{"name":"delta","content":"z","metadata":{"m":"1"}}'
log_debug "Authorized payload: $body"
auth_resp=$(curl -sS -H "Authorization: Bearer $token" -H 'Content-Type: application/json' -d "$body" "http://localhost:${PORT}/objects") || auth_resp=""
log_debug "Authorized response: $auth_resp"
if echo "$auth_resp" | grep -q '"id"' && echo "$auth_resp" | grep -q '"name"'; then
  say "[OK] authorized create succeeded"
else
  say "[FAIL] authorized create failed"; FAIL=1
fi

if [[ $FAIL -ne 0 ]]; then
  say "❌ ACTION-012 failed"; exit 1
else
  say "✅ ACTION-012 completed successfully"; exit 0
fi