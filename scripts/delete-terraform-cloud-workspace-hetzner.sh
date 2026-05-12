#!/usr/bin/env bash
# Delete the Hetzner Terraform Cloud workspace referenced in infrastructure/terraform/hetzner/main.tf.
#
# Run this ONLY after terraform destroy (or if the workspace is empty / abandoned). Deleting the
# workspace removes remote state; you cannot run terraform destroy against that state afterward.
#
# Requires:
#   - TF_TOKEN_app_terraform_io (or TFC_TOKEN): Terraform Cloud / HCP Terraform API user token
#   - curl; jq recommended (otherwise python3 is used to parse JSON)
#
# Usage:
#   export TF_TOKEN_app_terraform_io='…'
#   ./scripts/delete-terraform-cloud-workspace-hetzner.sh
#   ./scripts/delete-terraform-cloud-workspace-hetzner.sh --yes   # skip confirmation
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Defaults match infrastructure/terraform/hetzner/main.tf (override with env vars).
TFC_ORG="${TFC_ORG:-TF_DEEPAN_PERSONAL_ORG}"
TFC_WORKSPACE="${TFC_WORKSPACE:-password-manager-hetzner}"
TFC_ADDRESS="${TFC_ADDRESS:-https://app.terraform.io}"

TOKEN="${TF_TOKEN_app_terraform_io:-${TFC_TOKEN:-}}"
AUTO_YES=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes) AUTO_YES=1; shift ;;
    -h|--help)
      sed -n '1,18p' "$0" | tail -n +2
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$TOKEN" ]]; then
  echo "Set TF_TOKEN_app_terraform_io (or TFC_TOKEN) to a Terraform Cloud API token with workspace delete access." >&2
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required." >&2
  exit 1
fi

api_get() {
  curl -sS --fail-with-body \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/vnd.api+json" \
    "$@"
}

api_delete() {
  curl -sS --fail-with-body -X DELETE \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/vnd.api+json" \
    "$@"
}

workspace_url="${TFC_ADDRESS}/api/v2/organizations/${TFC_ORG}/workspaces/${TFC_WORKSPACE}"
echo "==> Looking up workspace: org=${TFC_ORG} name=${TFC_WORKSPACE}"
body=$(api_get "$workspace_url") || {
  echo "Failed to fetch workspace (wrong org/name, token, or network)." >&2
  exit 1
}

if command -v jq >/dev/null 2>&1; then
  ws_id=$(printf '%s' "$body" | jq -r '.data.id // empty')
else
  ws_id=$(python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("data",{}).get("id","") or "")' <<<"$body")
fi

if [[ -z "$ws_id" || "$ws_id" == "null" ]]; then
  echo "Could not parse workspace id from API response." >&2
  exit 1
fi

echo "==> Workspace id: $ws_id"
if [[ "$AUTO_YES" -ne 1 ]]; then
  if [[ ! -t 0 ]]; then
    echo "Refusing to delete on non-interactive stdin without --yes." >&2
    exit 1
  fi
  read -r -p "Delete this Terraform Cloud workspace permanently? [y/N] " ans
  if [[ ! "${ans:-}" =~ ^[yY]$ ]]; then
    echo "Aborted."
    exit 1
  fi
fi

delete_url="${TFC_ADDRESS}/api/v2/workspaces/${ws_id}"
echo "==> Deleting workspace…"
api_delete "$delete_url"
echo "==> Done. Remote state for ${TFC_WORKSPACE} is removed."
echo "    Hetzner root still contains main.tf cloud {} block; recreate workspace in TFC or remove/replace backend before a future terraform init."
