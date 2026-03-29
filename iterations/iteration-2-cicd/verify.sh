#!/usr/bin/env bash
# TDI Iteration 2: verify deploy workflow structure (local; does not run the pipeline).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../common/lib.sh
source "${SCRIPT_DIR}/../common/lib.sh"

REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DEPLOY_YML="${REPO_ROOT}/.github/workflows/deploy.yml"
GUIDE="${REPO_ROOT}/docs/cicd-pipelines.md"

fail() {
  print_failure "$1"
  exit 1
}

print_header "Iteration 2: CI/CD Pipeline Setup"

if [[ ! -f "$DEPLOY_YML" ]]; then
  fail ".github/workflows/deploy.yml not found"
fi
print_success ".github/workflows/deploy.yml exists"

if ! ruby -ryaml -e "YAML.load_file('$DEPLOY_YML')" 2>/dev/null; then
  fail "deploy.yml is not valid YAML"
fi
print_success "deploy.yml is valid YAML"

if command -v yamllint >/dev/null 2>&1; then
  if yamllint "$DEPLOY_YML"; then
    print_success "yamllint OK"
  else
    fail "yamllint failed"
  fi
else
  print_warning "yamllint not installed; skipping (optional)"
fi

wf="$(cat "$DEPLOY_YML")"

check_contains() {
  local needle="$1"
  local msg="${2:-$needle}"
  if [[ "$wf" != *"$needle"* ]]; then
    fail "deploy.yml missing required content: $msg"
  fi
}

check_contains "deploy-config" "job deploy-config"
check_contains "terraform-plan" "job terraform-plan"
check_contains "terraform-apply" "job terraform-apply"
check_contains "vm-deploy" "job vm-deploy"
check_contains "deploy-notice" "job deploy-notice"

# Required step names (auto_deploy_iterations.md); terraform-apply includes light gate before deploy
for step in "Checkout code" "Setup Terraform" "Configure Azure credentials" "Terraform Init" "Terraform Apply" "Get VM Public IP" "Setup SSH" "Light gate (verify-vm + iteration 3)" "Deploy Application Configuration" "Verify Deployment"; do
  check_contains "$step" "step: $step"
done

check_contains "workflow_dispatch" "workflow_dispatch trigger"
check_contains "push:" "on.push"
check_contains "infrastructure/**" "paths: infrastructure/**"
check_contains ".github/workflows/deploy.yml" "paths: deploy workflow"
check_contains "docker-compose.yml" "paths: docker-compose.yml"

for sec in AZURE_SUBSCRIPTION_ID AZURE_CLIENT_ID AZURE_CLIENT_SECRET AZURE_TENANT_ID AZURE_CREDENTIALS DOMAIN SSH_PRIVATE_KEY VM_USERNAME VM_PUBLIC_IP; do
  check_contains "secrets.${sec}" "secret ${sec}"
done

if [[ ! -f "$GUIDE" ]]; then
  fail "docs/cicd-pipelines.md not found"
fi
if ! grep -q "deploy.yml" "$GUIDE"; then
  fail "docs/cicd-pipelines.md should reference deploy.yml"
fi
print_success "CI/CD Pipelines Guide references deploy workflow"

print_footer "Iteration 2: CI/CD Pipeline Setup" 0
exit 0
