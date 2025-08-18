#!/usr/bin/env bash
export DOCKER_CLI_HINTS=false
set -euo pipefail

echo "Step 4: Create object storage structure"

ROOT="./data/objects"
SUBDIRS=("linguistic_objects" "library_definitions" "user_interactions")

mkdir -p "$ROOT"

for dir in "${SUBDIRS[@]}"; do
  mkdir -p "$ROOT/$dir"
done

# optional README
README="$ROOT/README.md"
if [ ! -f "$README" ]; then
  cat > "$README" <<EOF
# ApiOS Object Storage

Objects are stored in this hierarchy:

- linguistic_objects/       # Raw and processed linguistic objects
- library_definitions/      # Definitions and supporting files
- user_interactions/        # Logs, transcripts, etc.

This structure is created by steps/a004.bash
EOF
fi

echo "Object storage directories created at $ROOT"

