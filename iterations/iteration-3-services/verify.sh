#!/usr/bin/env bash
# TDI Iteration 3: core services (Vaultwarden, Caddy, Watchtower) on VM.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../common/lib.sh
source "${SCRIPT_DIR}/../common/lib.sh"

ITERATION="Iteration 3: Core Services Deployment"
STATUS=0

print_header "$ITERATION"

if ! verify_terraform_state_or_vm_env; then
  print_warning "Apply Terraform first in infrastructure/terraform/azure or hetzner (or set TERRAFORM_DIR), or set VM_PUBLIC_IP, VM_USERNAME, and DOMAIN"
  print_footer "$ITERATION" 1
  exit 1
fi

# shellcheck source=../common/config.sh
source "${SCRIPT_DIR}/../common/config.sh"

verify_file_on_vm "/opt/vaultwarden/docker-compose.yml" "docker-compose.yml" || STATUS=1

if ! ssh_vm "test -f /opt/vaultwarden/.env && stat -c '%a' /opt/vaultwarden/.env | grep -qx '600'"; then
  print_failure ".env missing or permissions not 600"
  STATUS=1
else
  print_success ".env permissions 600"
fi

verify_container_running vaultwarden || STATUS=1
verify_container_running caddy || STATUS=1
verify_container_running watchtower || STATUS=1

if ! ssh_vm "docker inspect vaultwarden --format '{{.Config.User}}' | grep -q '1000:1000'"; then
  print_failure "vaultwarden container user is not 1000:1000"
  STATUS=1
else
  print_success "Vaultwarden runs as 1000:1000"
fi

if ! ssh_vm "grep -qE 'SIGNUPS_ALLOWED.*true' /opt/vaultwarden/docker-compose.yml"; then
  print_failure "docker-compose.yml should set SIGNUPS_ALLOWED=true for initial setup"
  STATUS=1
else
  print_success "SIGNUPS_ALLOWED=true in compose"
fi

if ! ssh_vm "grep -q 'WATCHTOWER_LABEL_ENABLE' /opt/vaultwarden/docker-compose.yml"; then
  print_failure "WATCHTOWER_LABEL_ENABLE missing in docker-compose.yml"
  STATUS=1
else
  print_success "WATCHTOWER_LABEL_ENABLE present"
fi

if ! ssh_vm "docker inspect vaultwarden --format '{{json .Config.Labels}}' | grep -q 'com.centurylinklabs.watchtower.enable'"; then
  print_failure "Vaultwarden com.centurylinklabs.watchtower.enable label missing"
  STATUS=1
else
  print_success "Vaultwarden watchtower label present"
fi

if ! ssh_vm "docker network inspect vaultwarden-network >/dev/null 2>&1"; then
  print_failure "Docker network vaultwarden-network missing"
  STATUS=1
else
  print_success "vaultwarden-network exists"
fi

if ! ssh_vm "docker inspect vaultwarden --format '{{range .Mounts}}{{.Destination}} {{end}}' | grep -q '/data'"; then
  print_failure "Vaultwarden /data volume not mounted"
  STATUS=1
else
  print_success "Vaultwarden data volume mounted"
fi

if ! ssh_vm "docker exec vaultwarden test -f /data/db.sqlite3" 2>/dev/null; then
  print_warning "SQLite DB not present yet (expected on brand-new deploy until first use)"
else
  print_success "Vaultwarden database file present"
fi

print_footer "$ITERATION" "$STATUS"
exit "$STATUS"
