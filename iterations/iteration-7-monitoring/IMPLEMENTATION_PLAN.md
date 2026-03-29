# Iteration 7: Monitoring & Automation — Implementation Plan

**Branch:** `feature/tdi-iteration-7-monitoring`  
**Reference:** [auto_deploy_iterations.md](../../auto_deploy_iterations.md#iteration-7-monitoring--automation), [plan.md — Step 4](../../plan.md#step-4-verification--cost-monitoring)

---

## Objective

Deploy **`health-check.sh`** from [`health-check.sh.template`](../../infrastructure/templates/health-check.sh.template), **`*/15`** cron + [`logrotate-vaultwarden.conf`](../../infrastructure/templates/logrotate-vaultwarden.conf) via [`deploy-to-vm.sh`](../../infrastructure/scripts/deploy-to-vm.sh), and ship **`verify.sh`** / **`rollback.sh`** per TDI.

---

## Automation vs manual

| Aspect | Automated | Manual |
|--------|-----------|--------|
| **health-check.sh + cron + logrotate** | [`deploy-to-vm.sh`](../../infrastructure/scripts/deploy-to-vm.sh) | Re-run deploy after merge if **`infrastructure/**`** changed (Deploy workflow path filter). |
| **Azure cost budgets / alerts** | Not in repo | [plan.md](../../plan.md) Step 4 — Portal; `verify.sh` may warn if CLI cannot list budgets. |
| **`verify.sh`** | Not in CI (SSH / optional `az`) | From `infrastructure/terraform`: `../../iterations/iteration-7-monitoring/verify.sh` |

---

## Deliverables

1. **`deploy-to-vm.sh`** — `sed` health-check template, idempotent `*/15` crontab, `sudo` install logrotate drop-in.
2. **`verify.sh`** — Checks per [auto_deploy_iterations.md](../../auto_deploy_iterations.md#iteration-7-monitoring--automation).
3. **`rollback.sh`** — Confirm `yes`, remove health cron + script, stop/remove Watchtower container.

---

## Status

- [x] `deploy-to-vm.sh` installs health-check + cron + logrotate
- [x] `verify.sh` / `rollback.sh`
- [x] Merge PR #6; `verify.sh` exit 0 on VM after deploy
- [ ] Azure cost budgets/alerts in Portal per [plan.md](../../plan.md) Step 4 (manual)
