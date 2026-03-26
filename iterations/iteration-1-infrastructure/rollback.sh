#!/usr/bin/env bash
# Destroy Azure resources for Iteration 1 (terraform destroy).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../common/lib.sh
source "${SCRIPT_DIR}/../common/lib.sh"

TF_DIR="$(resolve_terraform_dir)" || {
  echo "Could not find infrastructure/terraform. Set TERRAFORM_DIR." >&2
  exit 1
}

if [[ ! -f "${TF_DIR}/main.tf" ]]; then
  echo "Run this script when infrastructure/terraform/main.tf exists (cwd context)." >&2
  exit 1
fi

echo "This will destroy: VM, NSG, Public IP, NIC, VNet, Resource Group resources managed by Terraform in:"
echo "  ${TF_DIR}"
echo ""
read -r -p "Type 'yes' to destroy: " ans
if [[ "$ans" != "yes" ]]; then
  echo "Cancelled."
  exit 0
fi

cd "$TF_DIR"
terraform destroy
