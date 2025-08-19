#!/usr/bin/env bash
set -euo pipefail

# Directory containing step scripts
STEP_DIR="steps"

# Defaults
LOG_LEVEL="normal"   # quiet | normal | debug

# Parse optional flags: --from NNN --to NNN --log LEVEL
FROM_NUM=""
TO_NUM=""
positional=()
while [[ $# -gt 0 ]]; do
  case "${1}" in
    --from)
      FROM_NUM="${2:-}"; shift 2 ;;
    --to)
      TO_NUM="${2:-}"; shift 2 ;;
    --log)
      LOG_LEVEL="${2:-normal}"; shift 2 ;;
    -h|--help)
      cat <<'USAGE'
Usage: ./run-steps.bash [--from NNN] [--to NNN] [--log quiet|normal|debug] [files...]
  --from NNN   Run steps with numeric id >= NNN (e.g., 006)
  --to NNN     Run steps with numeric id <= NNN (e.g., 010)
  --log L      Logging: quiet (only summary), normal (default), debug (trace)
  files...     Explicit list of step files to run (overrides --from/--to)
Examples:
  ./run-steps.bash --from 006            # run a006+ only
  ./run-steps.bash --from 006 --to 010   # run a006..a010
  ./run-steps.bash --log quiet           # minimal output
  ./run-steps.bash --log debug           # verbose with bash tracing
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

# Filter by --from/--to if provided (use base-10 arithmetic to avoid octal issues)
if [[ -n "$FROM_NUM" || -n "$TO_NUM" ]]; then
  if [[ -n "$FROM_NUM" ]]; then FROM_DEC=$((10#$FROM_NUM)); fi
  if [[ -n "$TO_NUM" ]]; then TO_DEC=$((10#$TO_NUM)); fi
  filtered=()
  for step in "${steps[@]}"; do
    base=$(basename "$step")
    num=$(echo "$base" | sed -E 's/[^0-9]//g')
    [[ -n "$num" ]] || continue
    num_dec=$((10#$num))
    if [[ -n "$FROM_NUM" ]] && (( num_dec < FROM_DEC )); then continue; fi
    if [[ -n "$TO_NUM" ]] && (( num_dec > TO_DEC )); then continue; fi
    filtered+=("$step")
  done
  steps=("${filtered[@]}")
fi

if [[ ${#steps[@]} -eq 0 ]]; then
  echo "No steps matched the criteria."; exit 1
fi

# Summary counters
ok_count=0
fail_count=0

echo "=== Running ApiOS setup steps ==="
echo "Steps to run: ${steps[*]}"
echo "Log level: ${LOG_LEVEL}"
echo

for step in "${steps[@]}"; do
  start_ts=$(date +%s)
  case "$LOG_LEVEL" in
    quiet)
      echo ">>> Running $step..."  # brief header
      tmp_log=$(mktemp)
      if LOG_LEVEL=$LOG_LEVEL bash "$step" >"$tmp_log" 2>&1; then
        echo "✅ $step completed successfully"
        ((ok_count++))
      else
        echo "❌ ERROR in $step"
        echo "--- Last 50 lines of log ---"
        tail -n 50 "$tmp_log" || true
        rm -f "$tmp_log"
        echo "Stopping execution."
        ((fail_count++))
        exit 1
      fi
      rm -f "$tmp_log"
      ;;
    debug)
      echo ">>> Running $step (debug)..."
      # Pass LOG_LEVEL and enable bash tracing for the step
      if LOG_LEVEL=$LOG_LEVEL bash -x "$step"; then
        echo "✅ $step completed successfully"
        ((ok_count++))
      else
        echo "❌ ERROR in $step"
        echo "Stopping execution."
        ((fail_count++))
        exit 1
      fi
      ;;
    *) # normal
      echo ">>> Running $step..."
      if LOG_LEVEL=$LOG_LEVEL bash "$step"; then
        echo "✅ $step completed successfully"
        ((ok_count++))
      else
        echo "❌ ERROR in $step"
        echo "Stopping execution."
        ((fail_count++))
        exit 1
      fi
      ;;
  esac
  end_ts=$(date +%s)
  duration=$(( end_ts - start_ts ))
  [[ "$LOG_LEVEL" != "quiet" ]] && echo
  echo "(duration: ${duration}s)"
  echo

done

echo "=== All steps completed successfully ==="
echo "Summary: OK=${ok_count} FAIL=${fail_count}"

