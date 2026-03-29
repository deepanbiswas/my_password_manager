#!/usr/bin/env bash
# Verify required GitHub Actions repository secrets exist (names only; values never printed).
# Requires: gh CLI, auth with repo scope. Run from repository root.
set -euo pipefail

REQUIRED=(
  AZURE_CREDENTIALS
  AZURE_SUBSCRIPTION_ID
  AZURE_CLIENT_ID
  AZURE_CLIENT_SECRET
  AZURE_TENANT_ID
  DOMAIN
  SSH_PRIVATE_KEY
  VM_USERNAME
)

REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)
if [[ -z "$REPO" ]]; then
  echo "Could not resolve repo (gh repo view). Run from a clone with gh auth login." >&2
  exit 1
fi

HAVE_NAMES=$(gh api "repos/${REPO}/actions/secrets" --paginate --jq -r '.secrets[].name' 2>/dev/null || true)
missing=()
for s in "${REQUIRED[@]}"; do
  if ! printf '%s\n' "$HAVE_NAMES" | grep -qx "$s"; then
    missing+=("$s")
  fi
done

if [[ ${#missing[@]} -gt 0 ]]; then
  echo "Missing GitHub Actions secrets (${#missing[@]}): ${missing[*]}" >&2
  echo "Add them under Settings → Secrets and variables → Actions, or run scripts/push-github-secrets.sh" >&2
  exit 1
fi

echo "OK: all ${#REQUIRED[@]} required repository secrets are defined."
