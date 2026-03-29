#!/usr/bin/env bash
# Post-deploy checks: containers up, HTTP response (runner or VM perspective).
# Required env: VM_PUBLIC_IP, VM_USERNAME, DOMAIN
set -euo pipefail

: "${VM_PUBLIC_IP:?Set VM_PUBLIC_IP}"
: "${VM_USERNAME:?Set VM_USERNAME}"
: "${DOMAIN:?Set DOMAIN}"

SSH_BASE=(ssh -o BatchMode=yes -o ConnectTimeout=30 -o StrictHostKeyChecking=accept-new)
TARGET="${VM_USERNAME}@${VM_PUBLIC_IP}"
DOMAIN_NAME="${DOMAIN#https://}"
DOMAIN_NAME="${DOMAIN_NAME#http://}"

echo "Waiting 30s for services..."
sleep 30

echo "Checking containers on VM..."
"${SSH_BASE[@]}" "$TARGET" bash -s -- <<'REMOTE'
set -euo pipefail
cd /opt/vaultwarden
if command -v docker-compose >/dev/null 2>&1; then
  docker-compose ps
elif [[ -x /usr/local/bin/docker-compose ]]; then
  /usr/local/bin/docker-compose ps
else
  docker compose ps
fi
for c in vaultwarden caddy watchtower; do
  if ! docker ps --format '{{.Names}}' | grep -qx "$c"; then
    echo "Missing container: $c" >&2
    exit 1
  fi
done
REMOTE

echo "HTTP check (Host header to VM:80)..."
code=$(curl -sS -o /dev/null -w "%{http_code}" --connect-timeout 20 \
  "http://${VM_PUBLIC_IP}/" -H "Host: ${DOMAIN_NAME}" || echo "000")
if [[ "$code" == "000" ]]; then
  code=$("${SSH_BASE[@]}" "$TARGET" bash -s -- "$DOMAIN_NAME" <<'REMOTE' || true
curl -sS -o /dev/null -w "%{http_code}" --connect-timeout 10 "http://127.0.0.1/" -H "Host: $1" || printf '000'
REMOTE
  )
  [[ -z "$code" ]] && code="000"
fi
if [[ "$code" != "200" && "$code" != "301" && "$code" != "302" && "$code" != "308" ]]; then
  echo "Unexpected HTTP code from :80 (got ${code})." >&2
  exit 1
fi
echo "HTTP check OK (code ${code})"
