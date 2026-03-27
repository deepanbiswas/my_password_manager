#!/usr/bin/env bash
# Source after lib.sh. Loads Terraform outputs into the current shell.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

if ! load_vm_config; then
  echo "Failed to load VM config from Terraform outputs. Set TERRAFORM_DIR or run from infrastructure/terraform after apply." >&2
  exit 1
fi
