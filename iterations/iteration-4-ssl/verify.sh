#!/usr/bin/env bash
# TDI Iteration 4: reverse proxy, DNS, TLS, HTTPS, security headers.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../common/lib.sh
source "${SCRIPT_DIR}/../common/lib.sh"

ITERATION="Iteration 4: Reverse Proxy & SSL Configuration"
STATUS=0

print_header "$ITERATION"

if ! verify_terraform_state; then
  print_warning "Apply Terraform first (terraform init && terraform apply) in infrastructure/terraform"
  print_footer "$ITERATION" 1
  exit 1
fi

# shellcheck source=../common/config.sh
source "${SCRIPT_DIR}/../common/config.sh"

if [[ -z "${DOMAIN:-}" || -z "${DOMAIN_NAME:-}" ]]; then
  print_failure "DOMAIN / DOMAIN_NAME not set (check Terraform output domain)"
  print_footer "$ITERATION" 1
  exit 1
fi
print_success "DOMAIN and DOMAIN_NAME loaded (${DOMAIN_NAME})"

# --- DNS: hostname must resolve to VM public IP ---
DNS_IPS=()
if command -v dig >/dev/null 2>&1; then
  while IFS= read -r line; do
    [[ -n "$line" ]] && DNS_IPS+=("$line")
  done < <(dig +short A "$DOMAIN_NAME" 2>/dev/null | grep -E '^[0-9.]+$' || true)
elif command -v host >/dev/null 2>&1; then
  while IFS= read -r line; do
    [[ -n "$line" ]] && DNS_IPS+=("$line")
  done < <(host -t A "$DOMAIN_NAME" 2>/dev/null | awk '/has address/ {print $NF}' || true)
else
  print_failure "Need dig(1) or host(1) for DNS checks"
  STATUS=1
fi

if [[ "${STATUS:-0}" -eq 0 ]]; then
  if [[ ${#DNS_IPS[@]} -eq 0 ]]; then
    print_failure "No A record for ${DOMAIN_NAME}"
    STATUS=1
  else
    found=0
    for a in "${DNS_IPS[@]}"; do
      if [[ "$a" == "$PUBLIC_IP" ]]; then
        found=1
        break
      fi
    done
    if [[ "$found" -eq 1 ]]; then
      print_success "DNS A record for ${DOMAIN_NAME} points to VM (${PUBLIC_IP})"
    else
      print_failure "DNS for ${DOMAIN_NAME} does not include VM IP ${PUBLIC_IP} (got: ${DNS_IPS[*]})"
      STATUS=1
    fi
  fi
fi

verify_file_on_vm "/opt/vaultwarden/caddy/Caddyfile" "caddy/Caddyfile" || STATUS=1

if ! ssh_vm "grep -qF $(printf '%q' "$DOMAIN_NAME") /opt/vaultwarden/caddy/Caddyfile"; then
  print_failure "Caddyfile does not reference domain ${DOMAIN_NAME}"
  STATUS=1
else
  print_success "Caddyfile contains domain ${DOMAIN_NAME}"
fi

verify_container_running caddy || STATUS=1

# Optional: ACME / certificate lines in recent Caddy logs
logs_out=$(ssh_vm "docker logs caddy 2>&1 | tail -n 120" || true)
if [[ -n "$logs_out" ]]; then
  if echo "$logs_out" | grep -qiE 'certificate obtained|certificate acquired|tls obtain|renewed'; then
    print_success "Caddy logs mention certificate issuance/renewal"
  elif echo "$logs_out" | grep -qiE 'error|failed'; then
    print_warning "Caddy logs contain errors (check if HTTPS still works): see docker logs caddy"
  else
    print_warning "Could not confirm ACME messages in Caddy logs (non-fatal if HTTPS OK)"
  fi
fi

# --- HTTPS response ---
https_code=$(curl -sS -o /dev/null -w "%{http_code}" --connect-timeout 25 "https://${DOMAIN_NAME}/" || echo "000")
if [[ "$https_code" =~ ^(200|301|302|308)$ ]]; then
  print_success "HTTPS GET / returned ${https_code}"
else
  print_failure "HTTPS GET / unexpected code: ${https_code}"
  STATUS=1
fi

# --- HTTP -> HTTPS redirect ---
http_code=$(curl -sS -o /dev/null -w "%{http_code}" --connect-timeout 25 --max-redirs 0 "http://${DOMAIN_NAME}/" || echo "000")
if [[ "$http_code" =~ ^(301|302|307|308)$ ]]; then
  print_success "HTTP GET / redirects (${http_code})"
else
  print_failure "HTTP GET / expected redirect to HTTPS, got ${http_code}"
  STATUS=1
fi

# --- TLS 1.2+ (openssl) ---
if ! command -v openssl >/dev/null 2>&1; then
  print_warning "openssl not found; skipping TLS version check"
else
  tls_out=$(echo | openssl s_client -connect "${DOMAIN_NAME}:443" -servername "${DOMAIN_NAME}" 2>/dev/null || true)
  if echo "$tls_out" | grep -qE 'Protocol[[:space:]]*:[[:space:]]*TLSv1\.[23]|New[,:]? TLSv1\.[23]|TLSv1\.[23]'; then
    print_success "TLS 1.2 or 1.3 negotiated (openssl)"
  else
    print_failure "Could not confirm TLS 1.2+ (openssl s_client)"
    STATUS=1
  fi
fi

# --- Security headers ---
hdrs=$(curl -sSI --connect-timeout 25 "https://${DOMAIN_NAME}/" || true)
if echo "$hdrs" | grep -qi 'strict-transport-security'; then
  print_success "HSTS header present"
else
  print_failure "Strict-Transport-Security header missing"
  STATUS=1
fi

if echo "$hdrs" | grep -qi 'x-frame-options'; then
  print_success "X-Frame-Options header present"
else
  print_failure "X-Frame-Options header missing"
  STATUS=1
fi

if echo "$hdrs" | grep -qi 'content-security-policy'; then
  print_success "Content-Security-Policy header present"
else
  print_warning "Content-Security-Policy header not detected (optional)"
fi

print_footer "$ITERATION" "$STATUS"
exit "$STATUS"
