#!/usr/bin/env bash
# Tear down Hetzner Cloud resources created by infrastructure/terraform/hetzner.
#
# Prerequisites:
#   - Terraform >= 1.10 (matches hetzner/main.tf), initialized in the Hetzner root
#   - HCLOUD_TOKEN set (or hcloud context with write access) for the Hetzner provider
#   - Same remote state auth you used for apply (e.g. terraform login for Terraform Cloud)
#
# Usage (from repo root or any directory):
#   ./scripts/undeploy-hetzner.sh              # terraform plan -destroy only
#   ./scripts/undeploy-hetzner.sh --destroy    # terraform destroy (interactive confirm)
#   ./scripts/undeploy-hetzner.sh --destroy --yes   # destroy without Terraform confirmation
#
# This script does NOT change DuckDNS, GitHub secrets, or revoke Let's Encrypt certs
# (see docs/hetzner-undeploy.md).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TERRAFORM_DIR="${TERRAFORM_DIR:-${REPO_ROOT}/infrastructure/terraform/hetzner}"

DO_DESTROY=0
AUTO_APPROVE=0

usage() {
  sed -n '1,20p' "$0" | tail -n +2
  echo "Options:"
  echo "  (default)       Run terraform plan -destroy (no changes)."
  echo "  --destroy       Run terraform destroy."
  echo "  --yes           With --destroy: pass -auto-approve (non-interactive destroy)."
  echo "  -h, --help      Show this help."
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --destroy) DO_DESTROY=1; shift ;;
    --yes) AUTO_APPROVE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ ! -d "$TERRAFORM_DIR" ]]; then
  echo "Terraform directory not found: $TERRAFORM_DIR" >&2
  echo "Set TERRAFORM_DIR to your hetzner root, or run from a full clone of the repo." >&2
  exit 1
fi

if ! command -v terraform >/dev/null 2>&1; then
  echo "terraform not found in PATH." >&2
  exit 1
fi

cd "$TERRAFORM_DIR"

if [[ ! -f main.tf ]]; then
  echo "Refusing to run: missing main.tf in $TERRAFORM_DIR (wrong directory?)" >&2
  exit 1
fi

if [[ -z "${HCLOUD_TOKEN:-}" ]]; then
  echo "HCLOUD_TOKEN is not set. Export your Hetzner API token (read & write) before running." >&2
  echo "Example: export HCLOUD_TOKEN='…'" >&2
  exit 1
fi

if [[ "$DO_DESTROY" -eq 1 ]] && [[ ! -t 0 ]] && [[ "$AUTO_APPROVE" -ne 1 ]]; then
  echo "Refusing terraform destroy on a non-interactive terminal without --yes." >&2
  echo "Use: $0 --destroy --yes" >&2
  exit 1
fi

echo "==> Using Terraform directory: $TERRAFORM_DIR"
terraform init -input=false

if [[ "$DO_DESTROY" -eq 0 ]]; then
  echo "==> Planning destroy (no resources will be changed yet)."
  terraform plan -destroy -input=false
  echo ""
  echo "Next: review the plan above. To remove resources, run:"
  echo "  $0 --destroy"
  echo "Non-interactive CI/automation:"
  echo "  $0 --destroy --yes"
  exit 0
fi

echo "WARNING: This will destroy Hetzner resources tracked in Terraform state for this workspace:"
echo "  - hcloud_server (VM and all data under /opt/vaultwarden on that disk)"
echo "  - hcloud_firewall"
echo "  - hcloud_ssh_key (Terraform-managed key resource only — not your local key files)"
echo ""
if [[ "$AUTO_APPROVE" -eq 1 ]]; then
  terraform destroy -input=false -auto-approve
else
  terraform destroy -input=false
fi

echo ""
echo "==> Terraform finished. Complete manual cleanup per docs/hetzner-undeploy.md"
echo "    (DuckDNS, GitHub Actions secrets/variables, optional Terraform Cloud workspace cleanup)."
