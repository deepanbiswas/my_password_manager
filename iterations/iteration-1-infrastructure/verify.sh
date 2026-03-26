#!/usr/bin/env bash
# Iteration 1: verify Azure VM, cloud-init, directories, UFW, tools.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../common/lib.sh
source "${SCRIPT_DIR}/../common/lib.sh"

ITERATION="Iteration 1: Infrastructure Foundation"
STATUS=0

print_header "$ITERATION"

echo "Using Terraform directory: $(resolve_terraform_dir || echo '?')"

if ! verify_terraform_state; then
  print_warning "Apply Terraform first (terraform init && terraform apply) in infrastructure/terraform"
  print_footer "$ITERATION" 1
  exit 1
fi
print_success "Terraform state / outputs OK"

# shellcheck source=../common/config.sh
source "${SCRIPT_DIR}/../common/config.sh"

if ! command -v az >/dev/null 2>&1; then
  exit_with_error "Azure CLI (az) not found; install it to verify VM in Azure"
fi

if ! az vm show -g "$RESOURCE_GROUP" -n "$VM_NAME" &>/dev/null; then
  print_failure "VM $VM_NAME not found in resource group $RESOURCE_GROUP"
  exit 1
fi
print_success "VM exists in Azure"

PS=$(az vm list -g "$RESOURCE_GROUP" -d --query "[?name=='$VM_NAME'].powerState" -o tsv 2>/dev/null || true)
if [[ "$PS" != *"running"* ]]; then
  print_failure "VM power state: ${PS:-unknown} (expected running; wait if the VM was just created)"
  exit 1
fi
print_success "VM is running"

if [[ -z "$PUBLIC_IP" ]] || [[ "$PUBLIC_IP" == "null" ]]; then
  exit_with_error "vm_public_ip output empty"
fi
print_success "Public IP from Terraform: $PUBLIC_IP"

if ! verify_ssh_connectivity; then
  print_failure "SSH connectivity failed (wait for cloud-init if the VM was just created; retry in 5–10 minutes)"
  exit 1
fi
print_success "SSH connectivity OK"

verify_directory_on_vm "/opt/vaultwarden" "/opt/vaultwarden" || STATUS=1
verify_directory_on_vm "/opt/vaultwarden/caddy" "/opt/vaultwarden/caddy" || STATUS=1
verify_directory_on_vm "/opt/vaultwarden/vaultwarden" "/opt/vaultwarden/vaultwarden" || STATUS=1
verify_directory_on_vm "/opt/vaultwarden/scripts" "/opt/vaultwarden/scripts" || STATUS=1
verify_directory_on_vm "/opt/vaultwarden/backups" "/opt/vaultwarden/backups" || STATUS=1

if ! ssh_vm "sudo ufw status | grep -q 'Status: active'"; then
  print_failure "UFW not active"
  STATUS=1
else
  print_success "UFW active"
fi
if ! ssh_vm "sudo ufw status | grep -qE '80/tcp|80.*ALLOW'"; then
  print_failure "UFW port 80 not allowed"
  STATUS=1
else
  print_success "UFW allows HTTP"
fi
if ! ssh_vm "sudo ufw status | grep -qE '443/tcp|443.*ALLOW'"; then
  print_failure "UFW port 443 not allowed"
  STATUS=1
else
  print_success "UFW allows HTTPS"
fi

verify_command_on_vm docker "Docker" || STATUS=1
if ssh_vm "command -v docker-compose >/dev/null 2>&1"; then
  print_success "docker-compose"
elif ssh_vm "docker compose version >/dev/null 2>&1"; then
  print_success "docker compose plugin"
else
  print_failure "Docker Compose not found"
  STATUS=1
fi
verify_command_on_vm rclone "Rclone" || STATUS=1
verify_command_on_vm sqlite3 "sqlite3" || STATUS=1
if ssh_vm "command -v gpg >/dev/null 2>&1 || command -v gpg2 >/dev/null 2>&1"; then
  print_success "gpg"
else
  print_failure "gpg not found"
  STATUS=1
fi

OWN=$(ssh_vm "stat -c '%u:%g' /opt/vaultwarden/vaultwarden/data" || echo "")
if [[ "$OWN" != "1000:1000" ]]; then
  print_failure "/opt/vaultwarden/vaultwarden/data ownership is ${OWN:-?}, expected 1000:1000"
  STATUS=1
else
  print_success "vaultwarden/data owned by 1000:1000"
fi

print_footer "$ITERATION" "$STATUS"
exit "$STATUS"
