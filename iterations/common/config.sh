#!/usr/bin/env bash
# Source after lib.sh. Loads VM connection from Terraform outputs or VM_* env (CI).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

if load_vm_config_from_env; then
  :
elif load_vm_config; then
  :
else
  echo "Failed to load VM config: set VM_PUBLIC_IP, VM_USERNAME, and DOMAIN, or run from infrastructure/terraform after terraform apply." >&2
  exit 1
fi
