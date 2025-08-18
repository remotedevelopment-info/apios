#!/usr/bin/env bash
set -euo pipefail

export DOCKER_CLI_HINTS=false
VERBOSE=false
if [[ "${1:-}" == "--verbose" ]]; then
  VERBOSE=true
fi

function check_container() {
  local name="$1"
  if docker ps --format '{{.Names}}' | grep -q "^$name\$"; then
    echo "[OK] container $name is running"
  else
    echo "[FAIL] container $name is not running"
  fi
}

function check_sqlite() {
  # Use the same DB file initialized in steps/a001.bash
  local host_db="./data/apios_local.sqlite"
  local container_db="/data/apios_local.sqlite"
  if [ ! -f "$host_db" ]; then
    echo "[FAIL] SQLite DB not found at $host_db"
    return
  fi
  if docker exec apios sqlite3 "$container_db" ".tables" | grep -q "linguistic_objects"; then
    echo "[OK] SQLite schema present"
    if [[ "$VERBOSE" == true ]]; then
      docker exec apios sqlite3 "$container_db" ".schema"
    fi
  else
    echo "[FAIL] SQLite schema missing"
  fi
}

function check_mongo() {
  if docker exec apios-mongo mongosh --quiet --eval 'db.getMongo()' >/dev/null 2>&1; then
    echo "[OK] MongoDB reachable"
  else
    echo "[FAIL] MongoDB not reachable"
  fi
}

function check_storage() {
  local root="./data/objects"
  if [ -d "$root" ]; then
    echo "[OK] object storage directory exists"
    if [[ "$VERBOSE" == true ]]; then
      find "$root" -maxdepth 2 -type d
    fi
  else
    echo "[FAIL] object storage directory missing"
  fi
}

echo "Step 5: Verifying ApiOS environment"

check_container apios
check_container apios-mongo
check_container apios-sqlite

check_sqlite
check_mongo
check_storage

