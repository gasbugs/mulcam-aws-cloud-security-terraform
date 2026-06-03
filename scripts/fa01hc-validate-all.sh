#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOTS_FILE="${ROOTS_FILE:-$ROOT_DIR/terraform-roots.txt}"
REPORT_DIR="${REPORT_DIR:-$ROOT_DIR/reports}"
REPORT_FILE="${REPORT_FILE:-$REPORT_DIR/fa01hc-validate-$(date +%Y%m%d-%H%M%S).log}"
PLUGIN_CACHE_DIR="${TF_PLUGIN_CACHE_DIR:-$ROOT_DIR/.terraform-plugin-cache}"

if [[ ! -f "$ROOTS_FILE" ]]; then
  echo "Terraform roots file does not exist: $ROOTS_FILE" >&2
  exit 2
fi

mkdir -p "$REPORT_DIR" "$PLUGIN_CACHE_DIR"
export TF_PLUGIN_CACHE_DIR="$PLUGIN_CACHE_DIR"

total=0
passed=0
failed=0
failures=()

{
  echo "FA01HC Terraform validation report"
  echo "Started: $(date -Iseconds)"
  echo "Roots file: $ROOTS_FILE"
  echo
} | tee "$REPORT_FILE"

while IFS= read -r lab || [[ -n "$lab" ]]; do
  [[ -z "$lab" ]] && continue

  total=$((total + 1))
  echo "== [$total] $lab ==" | tee -a "$REPORT_FILE"

  if (
    cd "$ROOT_DIR/$lab"
    terraform init -backend=false -input=false
    terraform validate
  ) >>"$REPORT_FILE" 2>&1; then
    passed=$((passed + 1))
    echo "PASS $lab" | tee -a "$REPORT_FILE"
  else
    failed=$((failed + 1))
    failures+=("$lab")
    echo "FAIL $lab" | tee -a "$REPORT_FILE"
  fi

  echo | tee -a "$REPORT_FILE" >/dev/null
done < "$ROOTS_FILE"

{
  echo "Summary: total=$total passed=$passed failed=$failed"
  if (( failed > 0 )); then
    echo "Failures:"
    printf '  %s\n' "${failures[@]}"
  fi
  echo "Finished: $(date -Iseconds)"
} | tee -a "$REPORT_FILE"

if (( failed > 0 )); then
  exit 1
fi
