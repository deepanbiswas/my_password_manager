# Iteration 6: Backup System — Implementation Plan

**Branch:** `feature/tdi-iteration-6-backup`  
**Reference:** [auto_deploy_iterations.md](../../auto_deploy_iterations.md#iteration-6-backup-system), [plan.md — Step 7 / Rclone](../../plan.md)

---

## Objective

Deploy **`backup.sh`** from [`backup.sh.template`](../../infrastructure/templates/backup.sh.template) via [`deploy-to-vm.sh`](../../infrastructure/scripts/deploy-to-vm.sh), add **nightly crontab (0 2 \* \* \*)**, and ship **`verify.sh`** / **`rollback.sh`** per TDI.

---

## Automation vs manual

| Aspect | Automated | Manual |
|--------|-----------|--------|
| **backup.sh + crontab on VM** | [`deploy-to-vm.sh`](../../infrastructure/scripts/deploy-to-vm.sh) copies template → `scripts/backup.sh`, idempotent crontab. | Re-run deploy after merging to `main` if **`infrastructure/**`** changed (Deploy workflow path filter). |
| **Rclone `gdrive`** | Not in repo | Configure on VM per [plan.md](../../plan.md) before `verify.sh` upload checks pass — [docs](../../docs/rclone-google-drive.md). |
| **`verify.sh`** | Not in CI (SSH) | From `infrastructure/terraform`: `../../iterations/iteration-6-backup/verify.sh` |

---

## Deliverables

1. **[`deploy-to-vm.sh`](../../infrastructure/scripts/deploy-to-vm.sh)** — `mkdir` `scripts` / `backups`, `cp` template, `chmod +x`, crontab line sourcing `.env` before `backup.sh`.
2. **`verify.sh`** — Checks per [auto_deploy_iterations.md](../../auto_deploy_iterations.md#iteration-6-backup-system) (script, rclone, host `sqlite3` `.backup`, `.env` key, test run, `gdrive:vaultwarden-backups/`, crontab, manifest).
3. **`rollback.sh`** — Confirm `yes`, strip crontab line, remove `backup.sh`.

---

## Status

- [x] `deploy-to-vm.sh` installs backup + cron
- [x] `verify.sh` / `rollback.sh`
- [x] Merge PR; run `verify.sh` on VM after deploy (requires **rclone `gdrive`** remote — OAuth)
