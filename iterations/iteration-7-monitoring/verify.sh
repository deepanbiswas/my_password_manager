#!/usr/bin/env bash
# TDI Iteration 7: monitoring (health-check, cron, Watchtower labels, logrotate, optional Azure).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../common/lib.sh
source "${SCRIPT_DIR}/../common/lib.sh"

ITERATION="Iteration 7: Monitoring & Automation"
STATUS=0

print_header "$ITERATION"

if ! verify_terraform_state_or_vm_env; then
  print_warning "Apply Terraform first or set VM_PUBLIC_IP, VM_USERNAME, DOMAIN"
  print_footer "$ITERATION" 1
  exit 1
fi

# shellcheck source=../common/config.sh
source "${SCRIPT_DIR}/../common/config.sh"

HEALTH_SCRIPT="/opt/vaultwarden/scripts/health-check.sh"
HEALTH_LOG="/var/log/vaultwarden-health.log"

if ! ssh_vm "test -x ${HEALTH_SCRIPT}"; then
  print_failure "health-check.sh missing or not executable at ${HEALTH_SCRIPT}"
  STATUS=1
else
  print_success "health-check.sh exists and is executable"
fi

if ! ssh_vm "crontab -l 2>/dev/null | grep -qF /opt/vaultwarden/scripts/health-check.sh"; then
  print_failure "crontab missing entry for health-check.sh"
  STATUS=1
elif ! ssh_vm "crontab -l 2>/dev/null | grep -F /opt/vaultwarden/scripts/health-check.sh | grep -qF '*/15'"; then
  print_failure "health crontab should run every 15 minutes (*/15)"
  STATUS=1
else
  print_success "crontab: health check every */15"
fi

if [[ "$STATUS" -eq 0 ]]; then
  if ssh_vm "cd /opt/vaultwarden && ./scripts/health-check.sh"; then
    print_success "health-check.sh executed successfully"
  else
    print_failure "health-check.sh execution failed (DOMAIN, curl, docker?)"
    STATUS=1
  fi
fi

labels_vw=$(ssh_vm "docker inspect vaultwarden --format '{{json .Config.Labels}}' 2>/dev/null" || echo "{}")
if echo "$labels_vw" | grep -qF '"com.centurylinklabs.watchtower.enable":"false"'; then
  print_success "vaultwarden has com.centurylinklabs.watchtower.enable=false"
else
  print_failure "vaultwarden label com.centurylinklabs.watchtower.enable not false (got: ${labels_vw})"
  STATUS=1
fi

labels_caddy=$(ssh_vm "docker inspect caddy --format '{{json .Config.Labels}}' 2>/dev/null" || echo "{}")
if echo "$labels_caddy" | grep -qF '"com.centurylinklabs.watchtower.enable":"true"'; then
  print_success "caddy has com.centurylinklabs.watchtower.enable=true"
else
  print_failure "caddy label com.centurylinklabs.watchtower.enable not true (got: ${labels_caddy})"
  STATUS=1
fi

if ssh_vm "docker inspect watchtower --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null | grep -q '^WATCHTOWER_LABEL_ENABLE=true'"; then
  print_success "Watchtower has WATCHTOWER_LABEL_ENABLE=true"
else
  # Some images expose env without strict ordering
  if ssh_vm "docker inspect watchtower --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null | grep -q 'WATCHTOWER_LABEL_ENABLE=true'"; then
    print_success "Watchtower has WATCHTOWER_LABEL_ENABLE=true"
  else
    print_failure "Watchtower missing WATCHTOWER_LABEL_ENABLE=true"
    STATUS=1
  fi
fi

if ssh_vm "docker logs watchtower 2>&1 | tail -20 | grep -q ."; then
  print_success "Watchtower container has log output"
else
  print_warning "Watchtower logs empty or very short (optional)"
fi

if command -v az >/dev/null 2>&1 && az account show &>/dev/null; then
  if az consumption budget list 2>/dev/null | grep -qE 'name|Budget'; then
    print_success "Azure budget(s) visible via CLI"
  else
    print_warning "Azure budgets not listed via CLI — configure in Portal per plan.md Step 4"
  fi
else
  print_warning "Skipping Azure budget CLI check (install az and az login, or set budgets in Portal)"
fi

if [[ -n "${RESOURCE_GROUP:-}" ]] && command -v az >/dev/null 2>&1 && az account show &>/dev/null; then
  if [[ "$(az group show -n "$RESOURCE_GROUP" --query tags.Project -o tsv 2>/dev/null)" == "password-manager" ]]; then
    print_success "Resource group ${RESOURCE_GROUP} has Project=password-manager tag"
  else
    print_failure "Resource group ${RESOURCE_GROUP} missing Project=password-manager tag"
    STATUS=1
  fi
else
  print_warning "Skipping resource group tag check (RESOURCE_GROUP empty or az not logged in)"
fi

if ssh_vm "sudo test -f /etc/logrotate.d/vaultwarden && grep -qE 'rotate[[:space:]]+30' /etc/logrotate.d/vaultwarden"; then
  print_success "logrotate config present with rotate 30 (30-day retention policy)"
else
  print_failure "logrotate /etc/logrotate.d/vaultwarden missing or rotate 30 not found"
  STATUS=1
fi

for c in vaultwarden caddy watchtower; do
  pol=$(ssh_vm "docker inspect \"${c}\" --format '{{.HostConfig.RestartPolicy.Name}}' 2>/dev/null" || echo "")
  if [[ "$pol" == "unless-stopped" ]]; then
    print_success "container ${c} restart policy: unless-stopped"
  else
    print_failure "container ${c} restart policy expected unless-stopped, got '${pol}'"
    STATUS=1
  fi
done

if ssh_vm "test -f ${HEALTH_LOG}"; then
  print_success "health check log exists (${HEALTH_LOG})"
else
  print_warning "health log not found yet (expected after deploy touch)"
  STATUS=1
fi

print_footer "$ITERATION" "$STATUS"
exit "$STATUS"
