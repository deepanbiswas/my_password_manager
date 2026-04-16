#!/bin/bash
# Cloud-init bootstrap for Vaultwarden host (expanded by Terraform templatefile).
# Shared by Azure custom_data and Hetzner user_data.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# Terraform templatefile injects admin_username at apply time.
# shellcheck disable=SC2154
ADMIN="${admin_username}"

apt-get update
apt-get upgrade -y

curl -fsSL https://get.docker.com | sh
usermod -aG docker "$ADMIN"

# shellcheck disable=SC2034
COMPOSE_VER="v2.24.7"
case "$(uname -m)" in
  aarch64 | arm64) COMPOSE_ARCH=aarch64 ;;
  x86_64) COMPOSE_ARCH=x86_64 ;;
  *)
    echo "Unsupported machine architecture for docker-compose: $(uname -m)" >&2
    exit 1
    ;;
esac
curl -fsSL "https://github.com/docker/compose/releases/download/$${COMPOSE_VER}/docker-compose-linux-$${COMPOSE_ARCH}" \
  -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

curl -fsSL https://rclone.org/install.sh | bash

apt-get install -y gnupg2 sqlite3 ufw

install -d -m 0755 -o "$ADMIN" -g "$ADMIN" /opt/vaultwarden
install -d -m 0755 -o "$ADMIN" -g "$ADMIN" /opt/vaultwarden/caddy/data
install -d -m 0755 -o "$ADMIN" -g "$ADMIN" /opt/vaultwarden/caddy/config
install -d -m 0755 -o "$ADMIN" -g "$ADMIN" /opt/vaultwarden/vaultwarden/data
install -d -m 0755 -o "$ADMIN" -g "$ADMIN" /opt/vaultwarden/scripts
install -d -m 0755 -o "$ADMIN" -g "$ADMIN" /opt/vaultwarden/backups

chown -R 1000:1000 /opt/vaultwarden/vaultwarden/data

ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

{
  echo "cloud-init completed at $(date -Iseconds)"
} >> /var/log/cloud-init.log
