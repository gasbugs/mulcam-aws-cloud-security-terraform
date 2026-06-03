#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOTS_FILE="${ROOTS_FILE:-$ROOT_DIR/terraform-roots.txt}"
REPORT_DIR="${REPORT_DIR:-$ROOT_DIR/reports}"
REPORT_FILE="${REPORT_FILE:-$REPORT_DIR/fa01hc-plan-$(date +%Y%m%d-%H%M%S).log}"
PLUGIN_CACHE_DIR="${TF_PLUGIN_CACHE_DIR:-$ROOT_DIR/.terraform-plugin-cache}"

if [[ ! -f "$ROOTS_FILE" ]]; then
  echo "Terraform roots file does not exist: $ROOTS_FILE" >&2
  exit 2
fi

mkdir -p "$REPORT_DIR" "$PLUGIN_CACHE_DIR"
export TF_PLUGIN_CACHE_DIR="$PLUGIN_CACHE_DIR"

var_file_args() {
  local lab="$1"

  if [[ -f "$ROOT_DIR/$lab/terraform.tfvars" ]]; then
    printf '%s\n' "-var-file=terraform.tfvars"
  elif [[ -f "$ROOT_DIR/$lab/terraform.tfvars.example" ]]; then
    printf '%s\n' "-var-file=terraform.tfvars.example"
  fi
}

profile_var_arg() {
  local lab="$1"

  if grep -q 'variable "aws_profile"' "$ROOT_DIR/$lab"/*.tf 2>/dev/null; then
    printf '%s\n' "-var=aws_profile=${FA01HC_AWS_PROFILE:-}"
  fi
}

total=0
planable=0
failed=0
failures=()

{
  echo "FA01HC Terraform plan report"
  echo "Started: $(date -Iseconds)"
  echo "Roots file: $ROOTS_FILE"
  echo "Mode: terraform plan -refresh=false -detailed-exitcode"
  echo
} | tee "$REPORT_FILE"

while IFS= read -r lab || [[ -n "$lab" ]]; do
  [[ -z "$lab" ]] && continue

  total=$((total + 1))
  echo "== [$total] $lab ==" | tee -a "$REPORT_FILE"

  set +e
  (
    cd "$ROOT_DIR/$lab"
    terraform init -input=false
    var_arg="$(var_file_args "$lab")"
    profile_arg="$(profile_var_arg "$lab")"
    if [[ -n "$var_arg" && -n "$profile_arg" ]]; then
      terraform plan -input=false -lock=false -refresh=false -detailed-exitcode "$var_arg" "$profile_arg"
    elif [[ -n "$var_arg" ]]; then
      terraform plan -input=false -lock=false -refresh=false -detailed-exitcode "$var_arg"
    elif [[ -n "$profile_arg" ]]; then
      terraform plan -input=false -lock=false -refresh=false -detailed-exitcode "$profile_arg"
    else
      terraform plan -input=false -lock=false -refresh=false -detailed-exitcode
    fi
  ) >>"$REPORT_FILE" 2>&1
  exit_code=$?
  set -e

  case "$exit_code" in
    0|2)
      planable=$((planable + 1))
      echo "PLANABLE $lab" | tee -a "$REPORT_FILE"
      ;;
    *)
      failed=$((failed + 1))
      failures+=("$lab")
      echo "FAIL $lab" | tee -a "$REPORT_FILE"
      ;;
  esac

  echo | tee -a "$REPORT_FILE" >/dev/null
done < "$ROOTS_FILE"

{
  echo "Summary: total=$total planable=$planable failed=$failed"
  if (( failed > 0 )); then
    echo "Failures:"
    printf '  %s\n' "${failures[@]}"
  fi
  echo "Finished: $(date -Iseconds)"
} | tee -a "$REPORT_FILE"

if (( failed > 0 )); then
  exit 1
fi
