#!/usr/bin/env bash
# TDI Iteration 5: security hardening (signups, UFW, rate limits, compose limits, .env, non-root).
# Optional: ITERATION5_NONINTERACTIVE=1 — skip the "Press Enter" prompt (requires signups already disabled).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../common/lib.sh
source "${SCRIPT_DIR}/../common/lib.sh"

ITERATION="Iteration 5: Security Hardening"
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
  print_failure "DOMAIN / DOMAIN_NAME not set"
  print_footer "$ITERATION" 1
  exit 1
fi
print_success "DOMAIN and DOMAIN_NAME loaded (${DOMAIN_NAME})"

compose_signups_line() {
  ssh_vm "grep -E '^[[:space:]]*SIGNUPS_ALLOWED:' /opt/vaultwarden/docker-compose.yml | head -1" || true
}

# Returns 0 if compose still allows open signups (SIGNUPS_ALLOWED true).
signups_true_in_compose() {
  local line
  line="$(compose_signups_line)"
  [[ -z "$line" ]] && return 1
  echo "$line" | grep -qE 'true' && ! echo "$line" | grep -qE 'false'
}

if signups_true_in_compose; then
  print_success "SIGNUPS_ALLOWED=true in docker-compose.yml (initial setup / before hardening)"
else
  print_warning "SIGNUPS_ALLOWED not true in docker-compose.yml (already hardened or edited) — skipping 'initial signups enabled' check"
fi

if signups_true_in_compose; then
  code=$(curl -sS -o /dev/null -w "%{http_code}" --connect-timeout 20 "https://${DOMAIN_NAME}/" || echo "000")
  if [[ "$code" =~ ^(200|301|302|308)$ ]]; then
    print_success "Site reachable over HTTPS (${code}) while signups enabled"
  else
    print_warning "HTTPS returned ${code} (expected live site for account creation)"
  fi
fi

if signups_true_in_compose && [[ "${ITERATION5_NONINTERACTIVE:-}" != "1" ]]; then
  echo ""
  echo "── Manual step (required while SIGNUPS_ALLOWED is true) ──"
  echo "  1. Open: ${DOMAIN}/"
  echo "  2. Create your Vaultwarden account."
  echo "  3. Edit /opt/vaultwarden/docker-compose.yml on the VM: set SIGNUPS_ALLOWED to \"false\" (both in the vaultwarden environment section)."
  echo "  4. Run: cd /opt/vaultwarden && docker compose up -d"
  echo ""
  if [[ -t 0 ]]; then
    read -r -p "Press Enter when done (signups disabled and stack restarted) ... " _
  else
    print_failure "stdin is not a TTY; set ITERATION5_NONINTERACTIVE=1 only after signups are already disabled"
    print_footer "$ITERATION" 1
    exit 1
  fi
elif signups_true_in_compose && [[ "${ITERATION5_NONINTERACTIVE:-}" == "1" ]]; then
  print_failure "SIGNUPS_ALLOWED still true; complete the manual step or run without ITERATION5_NONINTERACTIVE=1"
  print_footer "$ITERATION" 1
  exit 1
fi

if signups_true_in_compose; then
  print_failure "SIGNUPS_ALLOWED is still true in docker-compose.yml — set to false and run: cd /opt/vaultwarden && docker compose up -d"
  STATUS=1
else
  print_success "SIGNUPS_ALLOWED=false in docker-compose.yml"
fi

if ! ssh_vm "docker inspect vaultwarden --format '{{range .Config.Env}}{{println .}}{{end}}' | grep -q '^SIGNUPS_ALLOWED=false'"; then
  print_failure "vaultwarden container env must include SIGNUPS_ALLOWED=false (restart after editing compose)"
  STATUS=1
else
  print_success "vaultwarden container has SIGNUPS_ALLOWED=false"
fi

reg_code=$(curl -sS -o /dev/null -w "%{http_code}" --connect-timeout 20 -X POST "https://${DOMAIN_NAME}/api/accounts/register" \
  -H "Content-Type: application/json" -d '{}' || echo "000")
if [[ "$reg_code" == "200" || "$reg_code" == "201" ]]; then
  print_failure "Register API returned ${reg_code} (signups should be blocked)"
  STATUS=1
else
  print_success "Register API does not allow open signup (HTTP ${reg_code})"
fi

if ! ssh_vm "sudo ufw status | head -1 | grep -qi 'active'"; then
  print_failure "UFW is not active"
  STATUS=1
else
  print_success "UFW is active"
fi

ufw_txt=$(ssh_vm "sudo ufw status verbose" || true)
if ! echo "$ufw_txt" | grep -qE '22/tcp|22 .*ALLOW|OpenSSH'; then
  print_warning "UFW: no obvious SSH (22) allow rule (admin access may use another path)"
else
  print_success "UFW allows SSH (22)"
fi
if ! echo "$ufw_txt" | grep -qE '80/tcp|80 .*ALLOW'; then
  print_failure "UFW: port 80 not allowed"
  STATUS=1
else
  print_success "UFW allows HTTP (80)"
fi
if ! echo "$ufw_txt" | grep -qE '443/tcp|443 .*ALLOW'; then
  print_failure "UFW: port 443 not allowed"
  STATUS=1
else
  print_success "UFW allows HTTPS (443)"
fi

if ! ssh_vm "grep -q 'rate_limit' /opt/vaultwarden/caddy/Caddyfile"; then
  print_failure "Caddyfile missing rate_limit (deploy templates with Caddy ratelimit image)"
  STATUS=1
else
  print_success "Caddyfile configures rate_limit"
fi

if ! ssh_vm "grep -qE 'tls[[:space:]]*\\{|protocols tls1' /opt/vaultwarden/caddy/Caddyfile"; then
  print_warning "Caddyfile TLS block not detected (optional)"
else
  print_success "Caddyfile has TLS protocol settings"
fi

if ! ssh_vm "grep -q 'deploy:' /opt/vaultwarden/docker-compose.yml && grep -q 'limits:' /opt/vaultwarden/docker-compose.yml"; then
  print_failure "docker-compose.yml missing deploy.resources.limits"
  STATUS=1
else
  print_success "docker-compose.yml has resource limits"
fi

if ! ssh_vm "test -f /opt/vaultwarden/.env && stat -c '%a' /opt/vaultwarden/.env | grep -qx '600'"; then
  print_failure ".env missing or permissions not 600"
  STATUS=1
else
  print_success ".env permissions 600"
fi

if ! ssh_vm "docker inspect vaultwarden --format '{{.Config.User}}' | grep -q '1000:1000'"; then
  print_failure "vaultwarden container user is not 1000:1000"
  STATUS=1
else
  print_success "Vaultwarden runs as 1000:1000"
fi

verify_container_running vaultwarden || STATUS=1
verify_container_running caddy || STATUS=1

print_footer "$ITERATION" "$STATUS"
exit "$STATUS"
