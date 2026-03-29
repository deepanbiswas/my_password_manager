#!/usr/bin/env bash
# Option C(2): Copy infrastructure/templates/docker-compose.yml.template to the VM and
# regenerate /opt/vaultwarden/docker-compose.yml with the same sed as deploy-to-vm.sh,
# then pull and recreate Watchtower so compose matches the repo without a full deploy.
#
# Required env: VM_PUBLIC_IP, VM_USERNAME, DOMAIN (full URL, e.g. https://host/)
# Optional: REPO_ROOT, SSH_IDENTITY_FILE (same defaults as deploy-to-vm.sh)
#
# For a full template + Caddy sync use deploy-to-vm.sh instead.
set -euo pipefail

: "${VM_PUBLIC_IP:?Set VM_PUBLIC_IP}"
: "${VM_USERNAME:?Set VM_USERNAME}"
: "${DOMAIN:?Set DOMAIN (e.g. https://example.com)}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"
TEMPLATE="${REPO_ROOT}/infrastructure/templates/docker-compose.yml.template"

resolve_identity() {
  local f="${SSH_IDENTITY_FILE:-}"
  if [[ -n "$f" ]]; then
    f="${f/#\~/${HOME}}"
    if [[ -f "$f" ]]; then
      echo "$f"
      return 0
    fi
    echo "SSH_IDENTITY_FILE not found: $f" >&2
    exit 1
  fi
  local def="${HOME}/.ssh/id_rsa_vaultwarden"
  if [[ -f "$def" ]]; then
    echo "$def"
    return 0
  fi
  return 1
}

SSH_IDENTITY=()
if id_path="$(resolve_identity)"; then
  SSH_IDENTITY=(-i "$id_path")
elif [[ -z "${GITHUB_ACTIONS:-}" ]]; then
  echo "No SSH private key: set SSH_IDENTITY_FILE or place key at ~/.ssh/id_rsa_vaultwarden." >&2
  exit 1
fi

SSH_BASE=(ssh "${SSH_IDENTITY[@]}" -o BatchMode=yes -o ConnectTimeout=30 -o StrictHostKeyChecking=accept-new)
if [[ ${#SSH_IDENTITY[@]} -gt 0 ]]; then
  RSYNC_E="ssh -i $(printf '%q' "${SSH_IDENTITY[1]}") -o BatchMode=yes -o ConnectTimeout=30 -o StrictHostKeyChecking=accept-new"
else
  RSYNC_E="ssh -o BatchMode=yes -o ConnectTimeout=30 -o StrictHostKeyChecking=accept-new"
fi
TARGET="${VM_USERNAME}@${VM_PUBLIC_IP}"

if [[ ! -f "$TEMPLATE" ]]; then
  echo "Missing template: $TEMPLATE" >&2
  exit 1
fi

echo "Syncing docker-compose.yml.template to ${TARGET}:/opt/vaultwarden/infrastructure/templates/"
"${SSH_BASE[@]}" "$TARGET" "mkdir -p /opt/vaultwarden/infrastructure/templates"
rsync -avz \
  -e "$RSYNC_E" \
  "$TEMPLATE" "${TARGET}:/opt/vaultwarden/infrastructure/templates/docker-compose.yml.template"

echo "Regenerating docker-compose.yml and refreshing Watchtower on VM..."
"${SSH_BASE[@]}" "$TARGET" bash -s -- "$DOMAIN" <<'REMOTE'
set -euo pipefail
DOMAIN="$1"
cd /opt/vaultwarden

sed "s|{{DOMAIN}}|${DOMAIN}|g" infrastructure/templates/docker-compose.yml.template > docker-compose.yml

if command -v docker-compose >/dev/null 2>&1; then
  docker-compose pull watchtower 2>/dev/null || docker-compose pull watchtower || true
  docker-compose up -d watchtower
  docker-compose ps watchtower
elif [[ -x /usr/local/bin/docker-compose ]]; then
  /usr/local/bin/docker-compose pull watchtower 2>/dev/null || /usr/local/bin/docker-compose pull watchtower || true
  /usr/local/bin/docker-compose up -d watchtower
  /usr/local/bin/docker-compose ps watchtower
elif docker compose version >/dev/null 2>&1; then
  docker compose pull watchtower 2>/dev/null || true
  docker compose up -d watchtower
  docker compose ps watchtower
else
  echo "docker-compose not found" >&2
  exit 1
fi
REMOTE

echo "sync-docker-compose-template-to-vm.sh finished."
