#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMMAND="${1:-plan}"
LAB="${2:-}"
ROOTS_FILE="${ROOTS_FILE:-$ROOT_DIR/terraform-roots.txt}"
PLUGIN_CACHE_DIR="${TF_PLUGIN_CACHE_DIR:-$ROOT_DIR/.terraform-plugin-cache}"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/fa01hc-lifecycle.sh plan <terraform-root-path>
  CONFIRM_APPLY_DESTROY=YES ./scripts/fa01hc-lifecycle.sh apply-destroy <terraform-root-path>

The apply-destroy command always attempts terraform destroy after terraform apply.
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

  if [[ ! -f "$ROOTS_FILE" ]] || ! grep -Fxq "$LAB" "$ROOTS_FILE"; then
    echo "Lab is not listed in terraform-roots.txt: $LAB" >&2
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

run_terraform_destroy() {
  local var_arg
  local profile_arg
  var_arg="$(var_file_args)"
  profile_arg="$(profile_var_arg)"

  echo "Running terraform destroy for cleanup: $LAB"
  if [[ -n "$var_arg" && -n "$profile_arg" ]]; then
    terraform -chdir="$ROOT_DIR/$LAB" destroy -input=false -auto-approve "$var_arg" "$profile_arg"
  elif [[ -n "$var_arg" ]]; then
    terraform -chdir="$ROOT_DIR/$LAB" destroy -input=false -auto-approve "$var_arg"
  elif [[ -n "$profile_arg" ]]; then
    terraform -chdir="$ROOT_DIR/$LAB" destroy -input=false -auto-approve "$profile_arg"
  else
    terraform -chdir="$ROOT_DIR/$LAB" destroy -input=false -auto-approve
  fi
}

verify_destroy() {
  local remaining

  remaining="$(
    terraform -chdir="$ROOT_DIR/$LAB" state list 2>/dev/null \
      | grep -v '^data\.' \
      || true
  )"

  if [[ -n "$remaining" ]]; then
    echo "Managed resources remain in Terraform state after destroy:" >&2
    printf '%s\n' "$remaining" >&2
    exit 1
  fi

  echo "Cleanup verified: no managed resources remain in Terraform state for $LAB"
}

require_lab
mkdir -p "$PLUGIN_CACHE_DIR"
export TF_PLUGIN_CACHE_DIR="$PLUGIN_CACHE_DIR"

case "$COMMAND" in
  plan)
    terraform -chdir="$ROOT_DIR/$LAB" init -input=false
    VAR_ARG="$(var_file_args)"
    PROFILE_ARG="$(profile_var_arg)"
    if [[ -n "$VAR_ARG" && -n "$PROFILE_ARG" ]]; then
      terraform -chdir="$ROOT_DIR/$LAB" plan -input=false "$VAR_ARG" "$PROFILE_ARG"
    elif [[ -n "$VAR_ARG" ]]; then
      terraform -chdir="$ROOT_DIR/$LAB" plan -input=false "$VAR_ARG"
    elif [[ -n "$PROFILE_ARG" ]]; then
      terraform -chdir="$ROOT_DIR/$LAB" plan -input=false "$PROFILE_ARG"
    else
      terraform -chdir="$ROOT_DIR/$LAB" plan -input=false
    fi
    ;;
  apply-destroy)
    if [[ "${CONFIRM_APPLY_DESTROY:-}" != "YES" ]]; then
      echo "Refusing to create AWS resources without CONFIRM_APPLY_DESTROY=YES." >&2
      echo "This command will apply and then always attempt destroy for: $LAB" >&2
      exit 2
    fi

    terraform -chdir="$ROOT_DIR/$LAB" init -input=false

    applied=0
    cleanup() {
      if [[ "$applied" -eq 1 ]]; then
        run_terraform_destroy
        verify_destroy
      fi
    }
    trap cleanup EXIT

    VAR_ARG="$(var_file_args)"
    PROFILE_ARG="$(profile_var_arg)"
    applied=1
    if [[ -n "$VAR_ARG" && -n "$PROFILE_ARG" ]]; then
      terraform -chdir="$ROOT_DIR/$LAB" apply -input=false -auto-approve "$VAR_ARG" "$PROFILE_ARG"
    elif [[ -n "$VAR_ARG" ]]; then
      terraform -chdir="$ROOT_DIR/$LAB" apply -input=false -auto-approve "$VAR_ARG"
    elif [[ -n "$PROFILE_ARG" ]]; then
      terraform -chdir="$ROOT_DIR/$LAB" apply -input=false -auto-approve "$PROFILE_ARG"
    else
      terraform -chdir="$ROOT_DIR/$LAB" apply -input=false -auto-approve
    fi

    run_terraform_destroy
    verify_destroy
    applied=0
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
