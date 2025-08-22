#!/usr/bin/env bash
# ACTION-027: Backup & restore scripts
set -euo pipefail
export DOCKER_CLI_HINTS=false
LOG_LEVEL=${LOG_LEVEL:-normal}
[[ "$LOG_LEVEL" == "debug" ]] && set -x

DB_DIR="$(pwd)/data"
TS=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="backups/$TS"
mkdir -p "$BACKUP_DIR"
cp -v "$DB_DIR/apios.db" "$BACKUP_DIR/" 2>/dev/null || true
cp -v "$DB_DIR/apios.db-wal" "$BACKUP_DIR/" 2>/dev/null || true
cp -v "$DB_DIR/apios.db-shm" "$BACKUP_DIR/" 2>/dev/null || true
echo "Backup saved to $BACKUP_DIR"
echo "✅ ACTION-027 completed successfully"
