#!/usr/bin/env bash
# From your laptop: upload a GCP service account JSON to the VM, replace OAuth
# "gdrive" remote with drive + service_account_file + root_folder_id.
#
# Prerequisites (Phase B — browser): GCP project, Drive API enabled, service account,
# JSON key downloaded, personal Drive folder shared with the SA email (Editor),
# folder ID from https://drive.google.com/drive/folders/<ID>
#
# Usage:
#   cd infrastructure/terraform
#   export VM_PUBLIC_IP="$(terraform output -raw vm_public_ip)"
#   export VM_USERNAME="$(terraform output -raw vm_admin_username)"
#   # optional: export SSH_IDENTITY_FILE=~/.ssh/id_rsa_vaultwarden
#   ../scripts/migrate-rclone-service-account-on-vm.sh \
#     --json-file /path/to/service-account.json \
#     --root-folder-id YOUR_FOLDER_ID
#
set -euo pipefail

JSON_FILE=""
ROOT_FOLDER_ID=""
REMOTE_NAME="gdrive"

usage() {
  echo "Usage: $0 --json-file PATH --root-folder-id FOLDER_ID [--remote NAME]" >&2
  echo "Requires: VM_PUBLIC_IP, VM_USERNAME (and optional SSH_IDENTITY_FILE like deploy-to-vm.sh)" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json-file) JSON_FILE="${2:?}"; shift 2 ;;
    --root-folder-id) ROOT_FOLDER_ID="${2:?}"; shift 2 ;;
    --remote) REMOTE_NAME="${2:?}"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1" >&2; usage ;;
  esac
done

if [[ -z "$JSON_FILE" || -z "$ROOT_FOLDER_ID" ]]; then
  usage
fi
if [[ ! -f "$JSON_FILE" ]]; then
  echo "JSON file not found: $JSON_FILE" >&2
  exit 1
fi

: "${VM_PUBLIC_IP:?Set VM_PUBLIC_IP}"
: "${VM_USERNAME:?Set VM_USERNAME}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=deploy-to-vm.sh pattern - duplicate identity resolution
resolve_identity() {
  local f="${SSH_IDENTITY_FILE:-}"
  if [[ -n "$f" ]]; then
    f="${f/#\~/${HOME}}"
    if [[ -f "$f" ]]; then echo "$f"; return 0; fi
    echo "SSH_IDENTITY_FILE not found: $f" >&2; exit 1
  fi
  local def="${HOME}/.ssh/id_rsa_vaultwarden"
  if [[ -f "$def" ]]; then echo "$def"; return 0; fi
  return 1
}

SSH_IDENTITY=()
if id_path="$(resolve_identity)"; then
  SSH_IDENTITY=(-i "$id_path")
elif [[ -z "${GITHUB_ACTIONS:-}" ]]; then
  echo "No SSH private key: set SSH_IDENTITY_FILE or place key at ~/.ssh/id_rsa_vaultwarden" >&2
  exit 1
fi

SSH_BASE=(ssh "${SSH_IDENTITY[@]}" -o BatchMode=yes -o ConnectTimeout=30 -o StrictHostKeyChecking=accept-new)
if [[ ${#SSH_IDENTITY[@]} -gt 0 ]]; then
  RSYNC_E="ssh -i $(printf '%q' "${SSH_IDENTITY[1]}") -o BatchMode=yes -o ConnectTimeout=30 -o StrictHostKeyChecking=accept-new"
else
  RSYNC_E="ssh -o BatchMode=yes -o ConnectTimeout=30 -o StrictHostKeyChecking=accept-new"
fi
TARGET="${VM_USERNAME}@${VM_PUBLIC_IP}"
REMOTE_JSON="/opt/vaultwarden/secrets/rclone-sa.json"

echo "Uploading JSON to ${TARGET}:${REMOTE_JSON} (tmp)..."
"${SSH_BASE[@]}" "$TARGET" "mkdir -p /opt/vaultwarden/secrets"
scp "${SSH_IDENTITY[@]}" -o BatchMode=yes -o StrictHostKeyChecking=accept-new \
  "$JSON_FILE" "${TARGET}:/tmp/rclone-sa-upload.json"

echo "Applying rclone service account remote on VM..."
"${SSH_BASE[@]}" "$TARGET" bash -s -- "$REMOTE_NAME" "$ROOT_FOLDER_ID" "$REMOTE_JSON" <<'REMOTE'
set -euo pipefail
REMOTE_NAME="$1"
ROOT_FOLDER_ID="$2"
REMOTE_JSON="$3"
mv /tmp/rclone-sa-upload.json "$REMOTE_JSON"
chmod 600 "$REMOTE_JSON"

mkdir -p ~/.config/rclone
if [[ -f ~/.config/rclone/rclone.conf ]]; then
  cp ~/.config/rclone/rclone.conf ~/.config/rclone/rclone.conf.bak."$(date +%Y%m%d%H%M%S)"
fi

if rclone config show "$REMOTE_NAME" &>/dev/null; then
  echo "Removing existing remote: $REMOTE_NAME"
  rclone config delete "$REMOTE_NAME"
fi

rclone config create "$REMOTE_NAME" drive \
  service_account_file="$REMOTE_JSON" \
  root_folder_id="$ROOT_FOLDER_ID"

rclone mkdir "${REMOTE_NAME}:vaultwarden-backups" 2>/dev/null || true
rclone lsd "${REMOTE_NAME}:vaultwarden-backups"
echo "OK: remote ${REMOTE_NAME} uses service_account_file + root_folder_id"
REMOTE

echo ""
echo "Next: cd /opt/vaultwarden && set -a && source .env && set +a && ./scripts/backup.sh"
echo "Then: cd infrastructure/terraform && ../../iterations/iteration-6-backup/verify.sh"
echo "Optional: Google Account → Security → revoke old Rclone OAuth third-party access."
