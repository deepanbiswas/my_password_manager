#!/usr/bin/env bash
# TDI Iteration 3: stop stack and remove volumes (destructive).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../common/lib.sh
source "${SCRIPT_DIR}/../common/lib.sh"

print_header "Iteration 3 rollback: docker-compose down (volumes)"

if ! verify_terraform_state; then
  exit_with_error "Run from repo with Terraform state (infrastructure/terraform)"
fi

# shellcheck source=../common/config.sh
source "${SCRIPT_DIR}/../common/config.sh"

echo "This runs on VM ${VM_NAME} (${PUBLIC_IP}) and will:"
echo "  - docker-compose down -v (removes containers and volumes; Vaultwarden data loss)"
read -r -p "Type yes to confirm: " ans
if [[ "${ans}" != "yes" ]]; then
  echo "Cancelled."
  exit 0
fi

if ssh_vm "cd /opt/vaultwarden && if command -v docker-compose >/dev/null 2>&1; then docker-compose down -v; elif [[ -x /usr/local/bin/docker-compose ]]; then /usr/local/bin/docker-compose down -v; else docker compose down -v; fi"; then
  print_success "Stack stopped and volumes removed"
else
  print_failure "docker-compose down failed"
  exit 1
fi

print_footer "Iteration 3 rollback" 0
