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
  local azure_root="${repo_root}/infrastructure/terraform/azure"
  if [[ -d "$azure_root" ]] && [[ -f "$azure_root/main.tf" ]]; then
    echo "$azure_root"
    return 0
  fi
  local legacy="${repo_root}/infrastructure/terraform"
  if [[ -d "$legacy" ]] && [[ -f "$legacy/main.tf" ]]; then
    echo "$legacy"
    return 0
  fi
  return 1
}

verify_terraform_state() {
  local tf_dir
  if ! tf_dir="$(resolve_terraform_dir)"; then
    print_warning "Could not resolve Terraform directory; set TERRAFORM_DIR or run from infrastructure/terraform/azure (or hetzner)"
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

# True when VM_PUBLIC_IP, VM_USERNAME, and DOMAIN are set (e.g. GitHub Actions without Terraform state).
vm_env_config_complete() {
  [[ -n "${VM_PUBLIC_IP:-}" && -n "${VM_USERNAME:-}" && -n "${DOMAIN:-}" ]]
}

# Iteration 3 CI / VM-only path: allow verify when Terraform state is missing but VM env is wired.
verify_terraform_state_or_vm_env() {
  if verify_terraform_state; then
    return 0
  fi
  if vm_env_config_complete; then
    print_warning "No usable Terraform state in workspace; using VM_PUBLIC_IP/VM_USERNAME/DOMAIN"
    return 0
  fi
  return 1
}

load_vm_config_from_env() {
  if ! vm_env_config_complete; then
    return 1
  fi
  PUBLIC_IP="${VM_PUBLIC_IP}"
  ADMIN_USER="${VM_USERNAME}"
  # DOMAIN is already set in the environment (full URL); same contract as Terraform output domain.
  RESOURCE_GROUP="${RESOURCE_GROUP:-}"
  VM_NAME="${VM_NAME:-}"
  export PUBLIC_IP ADMIN_USER DOMAIN RESOURCE_GROUP VM_NAME
  DOMAIN_NAME="${DOMAIN#https://}"
  DOMAIN_NAME="${DOMAIN_NAME#http://}"
  export DOMAIN_NAME
  return 0
}

load_vm_config() {
  local tf_dir
  if ! tf_dir="$(resolve_terraform_dir)"; then
    return 1
  fi
  pushd "$tf_dir" >/dev/null || return 1
  if ! PUBLIC_IP=$(terraform output -raw vm_public_ip 2>/dev/null); then
    popd >/dev/null || true
    return 1
  fi
  if ! ADMIN_USER=$(terraform output -raw vm_admin_username 2>/dev/null); then
    popd >/dev/null || true
    return 1
  fi
  if ! DOMAIN=$(terraform output -raw domain 2>/dev/null); then
    popd >/dev/null || true
    return 1
  fi
  RESOURCE_GROUP=$(terraform output -raw resource_group_name 2>/dev/null || echo "")
  VM_NAME=$(terraform output -raw vm_name 2>/dev/null || echo "")
  popd >/dev/null || true
  export PUBLIC_IP ADMIN_USER DOMAIN RESOURCE_GROUP VM_NAME
  DOMAIN_NAME="${DOMAIN#https://}"
  DOMAIN_NAME="${DOMAIN_NAME#http://}"
  export DOMAIN_NAME
  return 0
}

# After load_vm_config / load_vm_config_from_env (RESOURCE_GROUP, VM_NAME set when applicable).
resolve_cloud_provider() {
  local tf_dir raw=""
  if tf_dir="$(resolve_terraform_dir 2>/dev/null)"; then
    raw="$(cd "$tf_dir" && terraform output -raw cloud_provider 2>/dev/null)" || true
    if [[ -n "$raw" ]]; then
      echo "$raw"
      return 0
    fi
  fi
  if [[ -n "${RESOURCE_GROUP:-}" ]]; then
    echo "azure"
  else
    echo "hetzner"
  fi
}

ssh_vm() {
  local cmd="$1"
  local ssh_opts=(-o BatchMode=yes -o ConnectTimeout=15 -o StrictHostKeyChecking=accept-new)
  if [[ -n "${SSH_IDENTITY_FILE:-}" ]]; then
    local id="${SSH_IDENTITY_FILE/#\~/${HOME}}"
    if [[ ! -f "$id" ]]; then
      print_failure "SSH_IDENTITY_FILE not found: $id" >&2
      return 1
    fi
    ssh_opts=(-i "$id" "${ssh_opts[@]}")
  elif [[ -f "${HOME}/.ssh/id_rsa_vaultwarden" ]]; then
    ssh_opts=(-i "${HOME}/.ssh/id_rsa_vaultwarden" "${ssh_opts[@]}")
  elif [[ -n "${GITHUB_ACTIONS:-}" ]]; then
    :
  else
    print_failure "No SSH private key: set SSH_IDENTITY_FILE or ~/.ssh/id_rsa_vaultwarden (or run in GitHub Actions with ssh-agent)" >&2
    return 1
  fi
  # shellcheck disable=SC2029
  # Remote runs quoted command built with local printf.
  ssh "${ssh_opts[@]}" "${ADMIN_USER}@${PUBLIC_IP}" "bash -lc $(printf '%q' "$cmd")"
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
