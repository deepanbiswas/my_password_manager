#!/usr/bin/env bash
# Write SSH_PRIVATE_KEY to disk and set TF_VAR_ssh_public_key_path for Terraform (GitHub Actions deploy workflow).
# OpenSSL 3 / ssh-keygen on ubuntu-latest reject PEM with CRLF — strip CR to avoid "error in libcrypto".
set -euo pipefail

: "${SSH_PRIVATE_KEY:?SSH_PRIVATE_KEY secret is empty or unset}"
: "${GITHUB_WORKSPACE:?}"

KEY_DIR="${GITHUB_WORKSPACE}/.ci-ssh"
mkdir -p "$KEY_DIR"
printf '%s\n' "$SSH_PRIVATE_KEY" | tr -d '\r' > "${KEY_DIR}/id_rsa"
chmod 600 "${KEY_DIR}/id_rsa"
ssh-keygen -y -f "${KEY_DIR}/id_rsa" > "${KEY_DIR}/id_rsa.pub"
echo "TF_VAR_ssh_public_key_path=${KEY_DIR}/id_rsa.pub" >> "${GITHUB_ENV}"
