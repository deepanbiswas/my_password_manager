#!/usr/bin/env bash
# TDI Iteration 5: re-enable signups in docker-compose.yml and restart Vaultwarden.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../common/lib.sh
source "${SCRIPT_DIR}/../common/lib.sh"

print_header "Iteration 5 rollback: re-enable signups"

if ! verify_terraform_state; then
  exit_with_error "Run from repo with Terraform state (infrastructure/terraform)"
fi

# shellcheck source=../common/config.sh
source "${SCRIPT_DIR}/../common/config.sh"

echo "Target VM: ${ADMIN_USER}@${PUBLIC_IP}"
echo "This will set SIGNUPS_ALLOWED to true in /opt/vaultwarden/docker-compose.yml and restart vaultwarden."
echo "If you added SIGNUPS_ALLOWED to .env, edit it on the VM to match."
echo ""
read -r -p "Type yes to confirm: " ans
if [[ "${ans}" != "yes" ]]; then
  echo "Cancelled."
  exit 0
fi

if ssh_vm "cd /opt/vaultwarden && cp -a docker-compose.yml docker-compose.yml.bak && sed -i 's/SIGNUPS_ALLOWED: \"false\"/SIGNUPS_ALLOWED: \"true\"/g; s/SIGNUPS_ALLOWED: false/SIGNUPS_ALLOWED: true/g' docker-compose.yml"; then
  print_success "Updated SIGNUPS_ALLOWED in docker-compose.yml (backup: docker-compose.yml.bak)"
else
  print_failure "sed docker-compose.yml failed"
  exit 1
fi

if ssh_vm "cd /opt/vaultwarden && if command -v docker-compose >/dev/null 2>&1; then docker-compose up -d vaultwarden; elif [[ -x /usr/local/bin/docker-compose ]]; then /usr/local/bin/docker-compose up -d vaultwarden; else docker compose up -d vaultwarden; fi"; then
  print_success "Vaultwarden container updated"
else
  print_failure "docker compose up vaultwarden failed"
  exit 1
fi

echo "Signups should be re-enabled. Check: docker inspect vaultwarden --format '{{range .Config.Env}}{{println .}}{{end}}' | grep SIGNUPS"
print_footer "Iteration 5 rollback" 0
