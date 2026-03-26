#!/usr/bin/env bash
# Shared helpers for TDI iteration scripts.
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_header() {
  local name="$1"
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  ${name}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

print_success() {
  echo -e "${GREEN}✓${NC} ${1:-OK}"
}

print_failure() {
  echo -e "${RED}✗${NC} ${1:-FAILED}" >&2
}

print_warning() {
  echo -e "${YELLOW}⚠${NC} ${1:-}"
}

print_result() {
  local status="$1"
  local msg="${2:-}"
  if [[ "$status" -eq 0 ]]; then
    print_success "$msg"
  else
    print_failure "$msg"
  fi
}

print_footer() {
  local name="$1"
  local status="$2"
  echo ""
  if [[ "$status" -eq 0 ]]; then
    echo -e "${GREEN}PASSED${NC} — ${name}"
  else
    echo -e "${RED}FAILED${NC} — ${name}" >&2
  fi
  echo ""
}

exit_with_error() {
  print_failure "${1:-Error}"
  exit 1
}

resolve_terraform_dir() {
  if [[ -n "${TERRAFORM_DIR:-}" ]] && [[ -d "$TERRAFORM_DIR" ]]; then
    echo "$TERRAFORM_DIR"
    return 0
  fi
  if [[ -f "$(pwd)/main.tf" ]] || [[ -f "$(pwd)/terraform.tfstate" ]]; then
    pwd
    return 0
  fi
  local script_dir repo_root
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  repo_root="$(cd "$script_dir/../.." && pwd)"
  local candidate="${repo_root}/infrastructure/terraform"
  if [[ -d "$candidate" ]] && [[ -f "$candidate/main.tf" ]]; then
    echo "$candidate"
    return 0
  fi
  return 1
}

verify_terraform_state() {
  local tf_dir
  if ! tf_dir="$(resolve_terraform_dir)"; then
    print_warning "Could not resolve Terraform directory; set TERRAFORM_DIR or run from infrastructure/terraform"
    return 1
  fi
  if [[ ! -d "$tf_dir/.terraform" ]] && [[ ! -f "$tf_dir/terraform.tfstate" ]]; then
    print_warning "No local Terraform state found in ${tf_dir} (run terraform init && terraform apply first)"
    return 2
  fi
  if ! (cd "$tf_dir" && terraform output -json >/dev/null 2>&1); then
    print_failure "Terraform outputs not readable; check state in ${tf_dir}"
    return 1
  fi
  return 0
}

load_vm_config() {
  local tf_dir
  if ! tf_dir="$(resolve_terraform_dir)"; then
    return 1
  fi
  pushd "$tf_dir" >/dev/null || return 1
  PUBLIC_IP=$(terraform output -raw vm_public_ip)
  ADMIN_USER=$(terraform output -raw vm_admin_username)
  DOMAIN=$(terraform output -raw domain)
  RESOURCE_GROUP=$(terraform output -raw resource_group_name)
  VM_NAME=$(terraform output -raw vm_name)
  popd >/dev/null || true
  export PUBLIC_IP ADMIN_USER DOMAIN RESOURCE_GROUP VM_NAME
  DOMAIN_NAME="${DOMAIN#https://}"
  DOMAIN_NAME="${DOMAIN_NAME#http://}"
  export DOMAIN_NAME
}

ssh_vm() {
  local cmd="$1"
  ssh -i ~/.ssh/id_rsa_vaultwarden \
    -o BatchMode=yes -o ConnectTimeout=15 -o StrictHostKeyChecking=accept-new \
    "${ADMIN_USER}@${PUBLIC_IP}" "bash -lc $(printf '%q' "$cmd")"
}

verify_ssh_connectivity() {
  ssh_vm "echo ok" >/dev/null
}

verify_file_on_vm() {
  local path="$1"
  local desc="${2:-$path}"
  if ssh_vm "test -f $(printf '%q' "$path")"; then
    print_success "$desc"
    return 0
  fi
  print_failure "Missing file on VM: $desc"
  return 1
}

verify_directory_on_vm() {
  local path="$1"
  local desc="${2:-$path}"
  if ssh_vm "test -d $(printf '%q' "$path")"; then
    print_success "$desc"
    return 0
  fi
  print_failure "Missing directory on VM: $desc"
  return 1
}

verify_command_on_vm() {
  local cmd="$1"
  local desc="${2:-$cmd}"
  if ssh_vm "command -v $(printf '%q' "$cmd") >/dev/null 2>&1"; then
    print_success "$desc"
    return 0
  fi
  print_failure "Missing command on VM: $desc"
  return 1
}

verify_container_running() {
  local name="$1"
  if ssh_vm "docker ps --format '{{.Names}}' | grep -qx \"$name\""; then
    print_success "container $name running"
    return 0
  fi
  print_failure "container $name not running"
  return 1
}
