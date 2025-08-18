#!/usr/bin/env bash
set -euo pipefail

# Directory containing step scripts
STEP_DIR="steps"

# Optional: run specific step(s) if passed as args
if [ $# -gt 0 ]; then
  steps=("$@")
else
  steps=("$STEP_DIR"/a*.bash)
fi

echo "=== Running ApiOS setup steps ==="
echo "Steps to run: ${steps[*]}"
echo

for step in "${steps[@]}"; do
  echo ">>> Running $step..."
  if bash "$step"; then
    echo "✅ $step completed successfully"
  else
    echo "❌ ERROR in $step"
    echo "Stopping execution."
    exit 1
  fi
  echo
done

echo "=== All steps completed successfully ==="

