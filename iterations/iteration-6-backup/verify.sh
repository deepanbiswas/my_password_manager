#!/usr/bin/env bash
# TDI Iteration 6: backup automation (backup.sh, rclone, GPG, cron, manifest).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../common/lib.sh
source "${SCRIPT_DIR}/../common/lib.sh"

ITERATION="Iteration 6: Backup System"
STATUS=0

print_header "$ITERATION"

if ! verify_terraform_state_or_vm_env; then
  print_warning "Apply Terraform first or set VM_PUBLIC_IP, VM_USERNAME, DOMAIN"
  print_footer "$ITERATION" 1
  exit 1
fi

# shellcheck source=../common/config.sh
source "${SCRIPT_DIR}/../common/config.sh"

BACKUP_SCRIPT="/opt/vaultwarden/scripts/backup.sh"
ENV_FILE="/opt/vaultwarden/.env"

if ! ssh_vm "test -x ${BACKUP_SCRIPT}"; then
  print_failure "backup.sh missing or not executable at ${BACKUP_SCRIPT}"
  STATUS=1
else
  print_success "backup.sh exists and is executable"
fi

if ! ssh_vm "command -v rclone >/dev/null 2>&1"; then
  print_failure "rclone not installed on VM"
  STATUS=1
else
  print_success "rclone installed"
fi

if ! ssh_vm "rclone config show 2>/dev/null | grep -qF '[gdrive]'"; then
  print_warning "Rclone remote 'gdrive' not found in config (rclone config show). Configure per plan.md before backups can upload."
  STATUS=1
else
  print_success "Rclone remote 'gdrive' present in config"
fi

if ! ssh_vm "grep -qE 'docker exec|docker cp' ${BACKUP_SCRIPT}"; then
  print_failure "backup.sh should use docker exec / docker cp for container-based backup"
  STATUS=1
else
  print_success "backup.sh uses docker exec / docker cp"
fi

if ! ssh_vm "grep -qE '^BACKUP_ENCRYPTION_KEY=' ${ENV_FILE} 2>/dev/null"; then
  print_failure "BACKUP_ENCRYPTION_KEY not set in .env"
  STATUS=1
else
  print_success "BACKUP_ENCRYPTION_KEY present in .env"
fi

if ! ssh_vm "grep -q MANIFEST ${BACKUP_SCRIPT}"; then
  print_failure "backup.sh should create a manifest (MANIFEST)"
  STATUS=1
else
  print_success "backup.sh includes manifest logic"
fi

if ! ssh_vm "crontab -l 2>/dev/null | grep -qF '/opt/vaultwarden/scripts/backup.sh'"; then
  print_failure "crontab missing entry for backup.sh (expected nightly 0 2 * * * per plan.md)"
  STATUS=1
elif ! ssh_vm "crontab -l 2>/dev/null | grep -F '/opt/vaultwarden/scripts/backup.sh' | grep -qF '0 2 * * *'"; then
  print_warning "backup crontab line may not use 0 2 * * * (check schedule)"
  STATUS=1
else
  print_success "crontab: nightly backup at 0 2 * * *"
fi

if [[ "$STATUS" -eq 0 ]]; then
  print_header "Test backup run"
  if ssh_vm "cd /opt/vaultwarden && set -a && source .env && set +a && ./scripts/backup.sh"; then
    print_success "backup.sh completed successfully"
  else
    print_failure "backup.sh execution failed (check rclone gdrive, gpg, docker)"
    STATUS=1
  fi
fi

if [[ "$STATUS" -eq 0 ]]; then
  if ! ssh_vm "rclone lsf 'gdrive:vaultwarden-backups/' 2>/dev/null | head -1 | grep -q ."; then
    print_warning "No files listed under gdrive:vaultwarden-backups/ (upload may have failed)"
    STATUS=1
  else
    print_success "Remote path gdrive:vaultwarden-backups/ contains at least one object"
  fi
fi

print_footer "$ITERATION" "$STATUS"
exit "$STATUS"
