#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMMAND="${1:-list}"
LAB="${2:-}"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/tf-lab.sh list
  ./scripts/tf-lab.sh roots
  ./scripts/tf-lab.sh init <terraform-root-path>
  ./scripts/tf-lab.sh validate <terraform-root-path>
  ./scripts/tf-lab.sh plan <terraform-root-path>
  ./scripts/tf-lab.sh fmt <terraform-root-path>

Examples:
  make list
  make roots
  make init LAB=terraform/fa01hc/day05-storage-and-security-services/02-aws-config-compliance
  make validate LAB=terraform/fa01hc/day05-storage-and-security-services/02-aws-config-compliance
  make plan LAB=terraform/fa01hc/day05-storage-and-security-services/02-aws-config-compliance
EOF
}

require_lab() {
  if [[ -z "$LAB" ]]; then
    usage
    exit 2
  fi

  if [[ ! -d "$ROOT_DIR/$LAB" ]]; then
    echo "Lab path does not exist: $LAB" >&2
    exit 2
  fi
}

var_file_args() {
  if [[ -f "$ROOT_DIR/$LAB/terraform.tfvars" ]]; then
    printf '%s\n' "-var-file=terraform.tfvars"
  elif [[ -f "$ROOT_DIR/$LAB/terraform.tfvars.example" ]]; then
    printf '%s\n' "-var-file=terraform.tfvars.example"
  fi
}

profile_var_arg() {
  if grep -q 'variable "aws_profile"' "$ROOT_DIR/$LAB"/*.tf 2>/dev/null; then
    printf '%s\n' "-var=aws_profile=${FA01HC_AWS_PROFILE:-}"
  fi
}

case "$COMMAND" in
  list)
    if command -v jq >/dev/null 2>&1 && [[ -f "$ROOT_DIR/fa01hc-curriculum.json" ]]; then
      jq -r '.days[] as $day | $day.units[] | "\(.id)\tday\($day.day)\t\(.time)\t\(.kind)\t\(.path)\t\(.title)"' "$ROOT_DIR/fa01hc-curriculum.json"
    elif command -v jq >/dev/null 2>&1 && [[ -f "$ROOT_DIR/labs.json" ]]; then
      jq -r '.labs[] | "\(.id)\tch\(.chapter)\t\(.priority)\t\(.suggested_check)\t\(.path)\t\(.description)"' "$ROOT_DIR/labs.json"
    else
      find "$ROOT_DIR/terraform" -maxdepth 2 -type d | sort | sed "s#^$ROOT_DIR/##"
    fi
    ;;
  roots)
    if [[ -f "$ROOT_DIR/terraform-roots.txt" ]]; then
      cat "$ROOT_DIR/terraform-roots.txt"
    else
      find "$ROOT_DIR/terraform/fa01hc" -maxdepth 4 -name '*.tf' -not -path '*/modules/*' -print \
        | sed 's#/[^/]*$##' \
        | sort -u
    fi
    ;;
  init)
    require_lab
    terraform -chdir="$ROOT_DIR/$LAB" init
    ;;
  validate)
    require_lab
    terraform -chdir="$ROOT_DIR/$LAB" validate
    ;;
  plan)
    require_lab
    VAR_ARG="$(var_file_args)"
    PROFILE_ARG="$(profile_var_arg)"
    if [[ -n "$VAR_ARG" && -n "$PROFILE_ARG" ]]; then
      terraform -chdir="$ROOT_DIR/$LAB" plan "$VAR_ARG" "$PROFILE_ARG"
    elif [[ -n "$VAR_ARG" ]]; then
      terraform -chdir="$ROOT_DIR/$LAB" plan "$VAR_ARG"
    elif [[ -n "$PROFILE_ARG" ]]; then
      terraform -chdir="$ROOT_DIR/$LAB" plan "$PROFILE_ARG"
    else
      terraform -chdir="$ROOT_DIR/$LAB" plan
    fi
    ;;
  fmt)
    require_lab
    terraform -chdir="$ROOT_DIR/$LAB" fmt -recursive
    ;;
  help|-h|--help)
    usage
    ;;
  *)
    echo "Unknown command: $COMMAND" >&2
    usage
    exit 2
    ;;
esac
