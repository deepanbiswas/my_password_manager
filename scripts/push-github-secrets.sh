#!/usr/bin/env bash
# Push GitHub Actions secrets from a local file (never commit that file).
# Usage: ./scripts/push-github-secrets.sh [path/to/github-secrets.env]
# Copy scripts/github-secrets.env.example to scripts/github-secrets.env, fill values, then run.
set -euo pipefail

ENV_FILE=${1:-scripts/github-secrets.env}
if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE — copy from scripts/github-secrets.env.example" >&2
  exit 1
fi

while IFS= read -r line || [[ -n "$line" ]]; do
  [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
  key="${line%%=*}"
  val="${line#*=}"
  key="${key//[[:space:]]/}"
  [[ -z "$key" ]] && continue

  case "$key" in
    AZURE_CREDENTIALS_FILE)
      [[ -z "$val" ]] && continue
      gh secret set AZURE_CREDENTIALS < "$val"
      echo "Set AZURE_CREDENTIALS from $val"
      ;;
    SSH_PRIVATE_KEY_FILE)
      [[ -z "$val" ]] && continue
      gh secret set SSH_PRIVATE_KEY < "$val"
      echo "Set SSH_PRIVATE_KEY from $val"
      ;;
    *)
      [[ -z "$val" ]] && continue
      gh secret set "$key" --body "$val"
      echo "Set $key"
      ;;
  esac
done < "$ENV_FILE"

echo "Done. Run: ./scripts/verify-github-actions-secrets.sh"
