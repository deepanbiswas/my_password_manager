#!/usr/bin/env bash
# Deploy templates and start Vaultwarden stack on the VM (CI or local with SSH).
# Required env: VM_PUBLIC_IP, VM_USERNAME, DOMAIN (full URL, e.g. https://host/)
# Optional: REPO_ROOT (defaults from script location). Backup/cron deferred to Iteration 6.
set -euo pipefail

: "${VM_PUBLIC_IP:?Set VM_PUBLIC_IP}"
: "${VM_USERNAME:?Set VM_USERNAME}"
: "${DOMAIN:?Set DOMAIN (e.g. https://example.com)}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"
TEMPLATES="${REPO_ROOT}/infrastructure/templates"
SSH_BASE=(ssh -o BatchMode=yes -o ConnectTimeout=30 -o StrictHostKeyChecking=accept-new)
TARGET="${VM_USERNAME}@${VM_PUBLIC_IP}"

DOMAIN_NAME="${DOMAIN#https://}"
DOMAIN_NAME="${DOMAIN_NAME#http://}"

if [[ ! -d "$TEMPLATES" ]]; then
  echo "Missing templates directory: $TEMPLATES" >&2
  exit 1
fi

echo "Syncing templates to ${TARGET}:/opt/vaultwarden/infrastructure/templates/"
"${SSH_BASE[@]}" "$TARGET" "mkdir -p /opt/vaultwarden/infrastructure/templates"
rsync -avz --delete \
  -e "ssh -o BatchMode=yes -o ConnectTimeout=30 -o StrictHostKeyChecking=accept-new" \
  "${TEMPLATES}/" "${TARGET}:/opt/vaultwarden/infrastructure/templates/"

echo "Generating config and starting containers on VM..."
"${SSH_BASE[@]}" "$TARGET" bash -s -- "$DOMAIN" "$DOMAIN_NAME" <<'REMOTE'
set -euo pipefail
DOMAIN="$1"
DOMAIN_NAME="$2"
cd /opt/vaultwarden

if [[ ! -f .env ]]; then
  ADMIN_TOKEN="$(openssl rand -base64 48 | tr -d '\n')"
  BACKUP_KEY="$(openssl rand -base64 32 | tr -d '\n')"
  sed -e "s|{{ADMIN_TOKEN}}|${ADMIN_TOKEN}|g" \
      -e "s|{{DOMAIN}}|${DOMAIN}|g" \
      -e "s|{{BACKUP_ENCRYPTION_KEY}}|${BACKUP_KEY}|g" \
      infrastructure/templates/.env.template > .env
  chmod 600 .env
  echo "Created new .env"
else
  echo "Using existing .env (not overwriting secrets)"
fi

sed "s|{{DOMAIN}}|${DOMAIN}|g" infrastructure/templates/docker-compose.yml.template > docker-compose.yml
mkdir -p caddy
sed "s|{{DOMAIN_NAME}}|${DOMAIN_NAME}|g" infrastructure/templates/Caddyfile.template > caddy/Caddyfile

if command -v docker-compose >/dev/null 2>&1; then
  docker-compose pull
  docker-compose up -d
  docker-compose ps
elif [[ -x /usr/local/bin/docker-compose ]]; then
  /usr/local/bin/docker-compose pull
  /usr/local/bin/docker-compose up -d
  /usr/local/bin/docker-compose ps
elif docker compose version >/dev/null 2>&1; then
  docker compose pull
  docker compose up -d
  docker compose ps
else
  echo "docker-compose not found" >&2
  exit 1
fi
REMOTE

echo "Deploy-to-vm finished."
