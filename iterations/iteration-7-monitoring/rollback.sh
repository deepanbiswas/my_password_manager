#!/usr/bin/env bash
# TDI Iteration 7: remove health-check cron, health-check.sh, and Watchtower container.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../common/lib.sh
source "${SCRIPT_DIR}/../common/lib.sh"

print_header "Iteration 7 rollback: remove health monitoring and Watchtower"

if ! verify_terraform_state_or_vm_env; then
  exit_with_error "Run from repo with Terraform state or set VM_PUBLIC_IP, VM_USERNAME, DOMAIN"
fi

# shellcheck source=../common/config.sh
source "${SCRIPT_DIR}/../common/config.sh"

echo "This will:"
echo "  - Remove the health-check.sh crontab line from ${ADMIN_USER}@${PUBLIC_IP}"
echo "  - Delete /opt/vaultwarden/scripts/health-check.sh"
echo "  - Stop and remove the Watchtower container (auto-updates for labeled images will not run until you redeploy)"
echo "  - Leave logrotate at /etc/logrotate.d/vaultwarden (harmless; remove manually if desired)"
echo "Re-run infrastructure/scripts/deploy-to-vm.sh or CI deploy to restore."
echo ""
read -r -p "Type yes to confirm: " ans
if [[ "${ans}" != "yes" ]]; then
  echo "Cancelled."
  exit 0
fi

if ssh_vm "crontab -l 2>/dev/null | grep -qF '/opt/vaultwarden/scripts/health-check.sh'"; then
  if ssh_vm "{ crontab -l 2>/dev/null || true; } | grep -vF '/opt/vaultwarden/scripts/health-check.sh' | crontab -"; then
    print_success "Removed health-check.sh entry from crontab"
  else
    print_failure "Failed to update crontab"
    exit 1
  fi
else
  print_warning "No health-check.sh crontab line found"
fi

if ssh_vm "test -f /opt/vaultwarden/scripts/health-check.sh"; then
  if ssh_vm "rm -f /opt/vaultwarden/scripts/health-check.sh"; then
    print_success "Removed /opt/vaultwarden/scripts/health-check.sh"
  else
    print_failure "Failed to remove health-check.sh"
    exit 1
  fi
else
  print_warning "health-check.sh already absent"
fi

if ssh_vm "docker ps -a --format '{{.Names}}' | grep -qx watchtower"; then
  if ssh_vm "cd /opt/vaultwarden && docker compose stop watchtower && docker compose rm -f watchtower"; then
    print_success "Stopped and removed Watchtower container"
  else
    print_failure "Failed to stop/remove Watchtower"
    exit 1
  fi
else
  print_warning "Watchtower container not present"
fi

print_success "Rollback complete. Restore: run infrastructure/scripts/deploy-to-vm.sh from the repo."
exit 0
