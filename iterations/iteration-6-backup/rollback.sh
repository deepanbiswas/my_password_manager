#!/usr/bin/env bash
# TDI Iteration 6: remove backup cron and backup.sh from VM.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../common/lib.sh
source "${SCRIPT_DIR}/../common/lib.sh"

print_header "Iteration 6 rollback: remove backup automation"

if ! verify_terraform_state_or_vm_env; then
  exit_with_error "Run from repo with Terraform state or set VM_PUBLIC_IP, VM_USERNAME, DOMAIN"
fi

# shellcheck source=../common/config.sh
source "${SCRIPT_DIR}/../common/config.sh"

echo "This removes the nightly backup crontab line and deletes /opt/vaultwarden/scripts/backup.sh on ${ADMIN_USER}@${PUBLIC_IP}."
echo "Re-run deploy-to-vm.sh or CI deploy to restore."
echo ""
read -r -p "Type yes to confirm: " ans
if [[ "${ans}" != "yes" ]]; then
  echo "Cancelled."
  exit 0
fi

if ssh_vm "crontab -l 2>/dev/null | grep -qF '/opt/vaultwarden/scripts/backup.sh'"; then
  if ssh_vm "crontab -l 2>/dev/null | grep -vF '/opt/vaultwarden/scripts/backup.sh' | crontab -"; then
    print_success "Removed backup.sh entry from crontab"
  else
    print_failure "Failed to update crontab"
    exit 1
  fi
else
  print_warning "No backup.sh crontab line found"
fi

if ssh_vm "test -f /opt/vaultwarden/scripts/backup.sh"; then
  if ssh_vm "rm -f /opt/vaultwarden/scripts/backup.sh"; then
    print_success "Removed /opt/vaultwarden/scripts/backup.sh"
  else
    print_failure "Failed to remove backup.sh"
    exit 1
  fi
else
  print_warning "backup.sh already absent"
fi

print_success "Rollback complete. Restore: run infrastructure/scripts/deploy-to-vm.sh from the repo."
exit 0
