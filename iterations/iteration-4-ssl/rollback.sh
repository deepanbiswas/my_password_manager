#!/usr/bin/env bash
# TDI Iteration 4: attempt to restore caddy/Caddyfile and restart Caddy (non-destructive).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../common/lib.sh
source "${SCRIPT_DIR}/../common/lib.sh"

print_header "Iteration 4 rollback: Caddyfile + Caddy restart"

if ! verify_terraform_state; then
  exit_with_error "Run from repo with Terraform state (infrastructure/terraform/azure or hetzner, or set TERRAFORM_DIR)"
fi

# shellcheck source=../common/config.sh
source "${SCRIPT_DIR}/../common/config.sh"

echo "Target VM: ${ADMIN_USER}@${PUBLIC_IP} (${VM_NAME})"
echo "This will try to:"
echo "  - Restore /opt/vaultwarden/caddy/Caddyfile from git (only if /opt/vaultwarden is a git clone)"
echo "  - Otherwise print manual recovery steps"
echo "  - Restart the caddy container"
echo ""
read -r -p "Type yes to confirm: " ans
if [[ "${ans}" != "yes" ]]; then
  echo "Cancelled."
  exit 0
fi

revert=$(ssh_vm "cd /opt/vaultwarden && if [[ -d .git ]] && git rev-parse --git-dir >/dev/null 2>&1; then if git checkout HEAD -- caddy/Caddyfile 2>/dev/null; then echo OK; else echo GITFAIL; fi; else echo NOGIT; fi" || echo SSHFAIL)

case "$revert" in
  OK)
    print_success "Restored caddy/Caddyfile from last git revision"
    ;;
  NOGIT|GITFAIL|SSHFAIL)
    print_warning "Could not revert Caddyfile from git (no repo or checkout failed)."
    echo "Manual fix: run infrastructure/scripts/deploy-to-vm.sh from the repo with VM_PUBLIC_IP, VM_USERNAME, DOMAIN set,"
    echo "or on the VM regenerate caddy/Caddyfile from infrastructure/templates/Caddyfile.template and restart Caddy."
    ;;
esac

if ssh_vm "cd /opt/vaultwarden && if command -v docker-compose >/dev/null 2>&1; then docker-compose restart caddy; elif [[ -x /usr/local/bin/docker-compose ]]; then /usr/local/bin/docker-compose restart caddy; else docker compose restart caddy; fi"; then
  print_success "Caddy container restarted"
else
  print_failure "Could not restart Caddy"
  exit 1
fi

print_footer "Iteration 4 rollback" 0
