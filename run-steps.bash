#!/usr/bin/env bash
set -euo pipefail

# Directory containing step scripts
STEP_DIR="steps"

# Parse optional flags: --from NNN --to NNN
FROM_NUM=""
TO_NUM=""
positional=()
while [[ $# -gt 0 ]]; do
  case "${1}" in
    --from)
      FROM_NUM="${2:-}"; shift 2 ;;
    --to)
      TO_NUM="${2:-}"; shift 2 ;;
    -h|--help)
      cat <<'USAGE'
Usage: ./run-steps.bash [--from NNN] [--to NNN] [files...]
  --from NNN   Run steps with numeric id >= NNN (e.g., 006)
  --to NNN     Run steps with numeric id <= NNN (e.g., 010)
  files...     Explicit list of step files to run (overrides --from/--to)
Examples:
  ./run-steps.bash --from 006            # run a006+ only
  ./run-steps.bash --from 006 --to 010   # run a006..a010
  ./run-steps.bash steps/a007.bash       # run a single step
USAGE
      exit 0 ;;
    *)
      positional+=("$1"); shift ;;
  esac
done

# If explicit files provided, use them; otherwise glob all steps
if [[ ${#positional[@]} -gt 0 ]]; then
  steps=("${positional[@]}")
else
  steps=("$STEP_DIR"/a*.bash)
fi

# Filter by --from/--to if provided
if [[ -n "$FROM_NUM" || -n "$TO_NUM" ]]; then
  filtered=()
  for step in "${steps[@]}"; do
    base=$(basename "$step")
    num=$(echo "$base" | sed -E 's/[^0-9]//g')
    [[ -z "$num" ]] && continue
    if [[ -n "$FROM_NUM" && "$num" -lt "$FROM_NUM" ]]; then continue; fi
    if [[ -n "$TO_NUM" && "$num" -gt "$TO_NUM" ]]; then continue; fi
    filtered+=("$step")
  done
  steps=("${filtered[@]}")
fi

if [[ ${#steps[@]} -eq 0 ]]; then
  echo "No steps matched the criteria."; exit 1
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

