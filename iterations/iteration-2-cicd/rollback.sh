#!/usr/bin/env bash
# TDI Iteration 2: remove deploy workflow (use only if you need to undo iteration 2 locally).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../common/lib.sh
source "${SCRIPT_DIR}/../common/lib.sh"

REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DEPLOY_YML="${REPO_ROOT}/.github/workflows/deploy.yml"

print_header "Iteration 2 rollback: remove deploy workflow"

echo "This will delete: ${DEPLOY_YML}"
echo "Restore later by following docs/cicd-pipelines.md and auto_deploy_iterations.md (Iteration 2)."
read -r -p "Type yes to confirm: " ans
if [[ "${ans}" != "yes" ]]; then
  echo "Cancelled."
  exit 0
fi

if [[ -f "$DEPLOY_YML" ]]; then
  rm -f "$DEPLOY_YML"
  print_success "Removed .github/workflows/deploy.yml"
else
  print_warning "deploy.yml was not present"
fi

print_footer "Iteration 2 rollback" 0
