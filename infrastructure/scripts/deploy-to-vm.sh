#!/usr/bin/env bash
# Deploy templates and start Vaultwarden stack on the VM (CI or local with SSH).
# Required env: VM_PUBLIC_IP, VM_USERNAME, DOMAIN (full URL, e.g. https://host/)
# Optional: REPO_ROOT (defaults from script location). Installs backup.sh + nightly crontab (Iteration 6),
#            health-check.sh + */15 crontab + logrotate (Iteration 7).
# Optional: SSH_IDENTITY_FILE — private key path (default: ~/.ssh/id_rsa_vaultwarden if present, same as iterations/common/lib.sh / terraform.tfvars).
#          On GitHub Actions, ssh-agent usually has the key; no file needed.
set -euo pipefail

: "${VM_PUBLIC_IP:?Set VM_PUBLIC_IP}"
: "${VM_USERNAME:?Set VM_USERNAME}"
: "${DOMAIN:?Set DOMAIN (e.g. https://example.com)}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"
TEMPLATES="${REPO_ROOT}/infrastructure/templates"
DOCKER_CADDY="${REPO_ROOT}/infrastructure/docker/caddy"

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
  echo "No SSH private key: set SSH_IDENTITY_FILE or place key at ~/.ssh/id_rsa_vaultwarden (see terraform.tfvars ssh_public_key_path)." >&2
  exit 1
fi

SSH_BASE=(ssh "${SSH_IDENTITY[@]}" -o BatchMode=yes -o ConnectTimeout=30 -o StrictHostKeyChecking=accept-new)
if [[ ${#SSH_IDENTITY[@]} -gt 0 ]]; then
  RSYNC_E="ssh -i $(printf '%q' "${SSH_IDENTITY[1]}") -o BatchMode=yes -o ConnectTimeout=30 -o StrictHostKeyChecking=accept-new"
else
  RSYNC_E="ssh -o BatchMode=yes -o ConnectTimeout=30 -o StrictHostKeyChecking=accept-new"
fi
TARGET="${VM_USERNAME}@${VM_PUBLIC_IP}"

DOMAIN_NAME="${DOMAIN#https://}"
DOMAIN_NAME="${DOMAIN_NAME#http://}"

if [[ ! -d "$TEMPLATES" ]]; then
  echo "Missing templates directory: $TEMPLATES" >&2
  exit 1
fi
if [[ ! -d "$DOCKER_CADDY" ]]; then
  echo "Missing Caddy Dockerfile directory: $DOCKER_CADDY" >&2
  exit 1
fi

echo "Syncing templates to ${TARGET}:/opt/vaultwarden/infrastructure/templates/"
"${SSH_BASE[@]}" "$TARGET" "mkdir -p /opt/vaultwarden/infrastructure/templates"
rsync -avz --delete \
  -e "$RSYNC_E" \
  "${TEMPLATES}/" "${TARGET}:/opt/vaultwarden/infrastructure/templates/"

echo "Syncing Caddy Docker build context to ${TARGET}:/opt/vaultwarden/docker/caddy/"
"${SSH_BASE[@]}" "$TARGET" "mkdir -p /opt/vaultwarden/docker/caddy"
rsync -avz --delete \
  -e "$RSYNC_E" \
  "${DOCKER_CADDY}/" "${TARGET}:/opt/vaultwarden/docker/caddy/"

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
# caddy/ may be root-owned from a prior Docker run; ensure it is writable for this user
sudo mkdir -p caddy
sudo chown "$(id -un):$(id -gn)" caddy
sed "s|{{DOMAIN_NAME}}|${DOMAIN_NAME}|g" infrastructure/templates/Caddyfile.template > caddy/Caddyfile

if command -v docker-compose >/dev/null 2>&1; then
  docker-compose pull vaultwarden watchtower 2>/dev/null || docker-compose pull || true
  docker-compose build caddy
  docker-compose up -d
  docker-compose ps
elif [[ -x /usr/local/bin/docker-compose ]]; then
  /usr/local/bin/docker-compose pull vaultwarden watchtower 2>/dev/null || /usr/local/bin/docker-compose pull || true
  /usr/local/bin/docker-compose build caddy
  /usr/local/bin/docker-compose up -d
  /usr/local/bin/docker-compose ps
elif docker compose version >/dev/null 2>&1; then
  docker compose pull vaultwarden watchtower 2>/dev/null || true
  docker compose build caddy
  docker compose up -d
  docker compose ps
else
  echo "docker-compose not found" >&2
  exit 1
fi

# Backup script + nightly cron (TDI iteration 6; templates already under infrastructure/templates/)
mkdir -p scripts backups
cp -f infrastructure/templates/backup.sh.template scripts/backup.sh
chmod +x scripts/backup.sh
# crontab -l fails with no user crontab; avoid set -e killing the subshell before echo
if ! { crontab -l 2>/dev/null || true; } | grep -qF '/opt/vaultwarden/scripts/backup.sh'; then
  ({ crontab -l 2>/dev/null || true; echo '0 2 * * * cd /opt/vaultwarden && set -a && . ./.env && set +a && /opt/vaultwarden/scripts/backup.sh >> /var/log/vaultwarden-backup.log 2>&1'; }) | crontab -
fi
# Cron runs as the deploy user; /var/log/ is root-owned — create log file so redirection succeeds (same pattern as health log).
sudo touch /var/log/vaultwarden-backup.log
sudo chown "$(id -un):$(id -gn)" /var/log/vaultwarden-backup.log

# Health check + logrotate (TDI iteration 7; templates under infrastructure/templates/)
sed "s|{{DOMAIN}}|${DOMAIN}|g" infrastructure/templates/health-check.sh.template > scripts/health-check.sh
chmod +x scripts/health-check.sh
if ! { crontab -l 2>/dev/null || true; } | grep -qF '/opt/vaultwarden/scripts/health-check.sh'; then
  ({ crontab -l 2>/dev/null || true; echo '*/15 * * * * /opt/vaultwarden/scripts/health-check.sh >> /var/log/vaultwarden-health.log 2>&1'; }) | crontab -
fi
sudo touch /var/log/vaultwarden-health.log
sudo chown "$(id -un):$(id -gn)" /var/log/vaultwarden-health.log
sudo cp -f infrastructure/templates/logrotate-vaultwarden.conf /etc/logrotate.d/vaultwarden
sudo chmod 644 /etc/logrotate.d/vaultwarden
REMOTE

echo "Deploy-to-vm finished."
