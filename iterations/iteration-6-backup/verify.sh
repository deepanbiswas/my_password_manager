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

# Remote name must match rclone config and RCLONE_REMOTE_NAME in .env (default gdrive)
RCLONE_REMOTE_NAME_VM="$(ssh_vm "grep -E '^RCLONE_REMOTE_NAME=' ${ENV_FILE} 2>/dev/null | head -1 | cut -d= -f2- | tr -d '[:space:]'" 2>/dev/null | tr -d '\r' || true)"
if [[ -z "${RCLONE_REMOTE_NAME_VM}" ]]; then
  RCLONE_REMOTE_NAME_VM="gdrive"
fi

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

if ! ssh_vm "rclone config show 2>/dev/null | grep -qF '[${RCLONE_REMOTE_NAME_VM}]'"; then
  print_warning "Rclone remote '${RCLONE_REMOTE_NAME_VM}' not found in config (rclone config show). Configure per plan.md / docs/rclone-google-drive-service-account.md"
  STATUS=1
else
  print_success "Rclone remote '${RCLONE_REMOTE_NAME_VM}' present in config"
  if ssh_vm "rclone config show \"${RCLONE_REMOTE_NAME_VM}\" 2>/dev/null | grep -q '^service_account_file'"; then
    print_success "rclone remote uses service_account_file (Drive access scoped to shared folder)"
  fi
fi

if ! ssh_vm "grep -qE 'sqlite3.*\\.backup|docker exec.*sqlite3|docker cp' ${BACKUP_SCRIPT}"; then
  print_failure "backup.sh should back up the DB with sqlite3 .backup (host bind mount or container)"
  STATUS=1
else
  print_success "backup.sh uses sqlite3 .backup or docker-based DB copy"
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
    print_failure "backup.sh execution failed (check rclone remote ${RCLONE_REMOTE_NAME_VM}, gpg, docker)"
    STATUS=1
  fi
fi

if [[ "$STATUS" -eq 0 ]]; then
  if ! ssh_vm "rclone lsf \"${RCLONE_REMOTE_NAME_VM}:vaultwarden-backups/\" 2>/dev/null | head -1 | grep -q ."; then
    print_warning "No files listed under ${RCLONE_REMOTE_NAME_VM}:vaultwarden-backups/ (upload may have failed)"
    STATUS=1
  else
    print_success "Remote path ${RCLONE_REMOTE_NAME_VM}:vaultwarden-backups/ contains at least one object"
  fi
fi

print_footer "$ITERATION" "$STATUS"
exit "$STATUS"
