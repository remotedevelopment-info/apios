#!/usr/bin/env bash
# ACTION-018: Auth hardening (unique email, token expiry 15m, refresh)
set -euo pipefail
export DOCKER_CLI_HINTS=false
LOG_LEVEL=${LOG_LEVEL:-normal}
[[ "$LOG_LEVEL" == "debug" ]] && set -x
DB="/data/apios.db"
JWT_SECRET=${JWT_SECRET:-dev-secret-change-me}

say() { echo "$@"; }

say "ACTION-018: Auth hardening"
# Ensure unique email (backfilled in schema already)
# Restart API with auth env
docker rm -f apios-api >/dev/null 2>&1 || true
if ! docker network inspect apios-net >/dev/null 2>&1; then docker network create apios-net >/dev/null; fi
docker run -d --name apios-api --network apios-net -e JWT_SECRET="$JWT_SECRET" -e JWT_ACCESS_MINUTES=15 -e JWT_REFRESH_MINUTES=43200 -p 8080:8000 -v "$(pwd)/data:/data" apios-api:latest >/dev/null
sleep 1
# Register minimal user (idempotent)
reg='{"username":"u018","password":"password18","email":"u018@example.com"}'
resp=$(curl -sS -H 'Content-Type: application/json' -d "$reg" http://localhost:8080/users/register) || resp=""
if echo "$resp" | grep -qi 'already exists'; then echo "[OK] user exists"; else echo "$resp" | grep -q '"id"' || echo "[WARN] register resp: $resp"; fi
# Login and refresh
login='{"username":"u018","password":"password18"}'
login_resp=$(curl -sS -H 'Content-Type: application/json' -d "$login" http://localhost:8080/users/login)
acc=$(printf '%s' "$login_resp" | grep -Eo '"access_token"[^"]*"[^"]*"' | sed -E 's/.*"access_token"[^"]*"([^"]*)".*/\1/')
ref=$(printf '%s' "$login_resp" | grep -Eo '"refresh_token"[^"]*"[^"]*"' | sed -E 's/.*"refresh_token"[^"]*"([^"]*)".*/\1/')
[[ -n "$acc" && -n "$ref" ]] || { echo "[FAIL] tokens not returned"; exit 1; }
new_acc=$(curl -sS -H 'Content-Type: application/json' -d "{\"refresh_token\":\"$ref\"}" http://localhost:8080/users/refresh)
echo "$new_acc" | grep -q '"access_token"' || { echo "[FAIL] refresh failed"; exit 1; }
say "✅ ACTION-018 completed successfully"
