# Rclone: Google Drive for Vaultwarden backups

[`backup.sh.template`](../infrastructure/templates/backup.sh.template) uploads to **`${RCLONE_REMOTE_NAME}:vaultwarden-backups/`** (default remote name **`gdrive`**). Set **`RCLONE_REMOTE_NAME`** in `/opt/vaultwarden/.env` to match the remote name in `rclone config`.

**Do not** commit OAuth tokens or `rclone.conf`. Restrict permissions on the VM (`chmod 600` for `~/.config/rclone/` and `.env`).

---

## Google Cloud and OAuth

1. In [Google Cloud Console](https://console.cloud.google.com/), select your project → **APIs & Services** → **Library** → enable **Google Drive API**.
2. **APIs & Services** → **OAuth consent screen** — configure (External + test users is fine for personal use).
3. **Credentials** → **Create credentials** → **OAuth client ID** → type **Desktop** (or per [rclone Drive docs](https://rclone.org/drive/) if you use another client type).
4. On the **VM**, run `rclone config`:
   - New remote, name e.g. **`gdrive`** (must match **`RCLONE_REMOTE_NAME`** in `.env`).
   - Storage: **drive**.
   - Enter your **OAuth client ID** and **client secret** when prompted (or use rclone’s default app if acceptable).
   - **Scope**: e.g. **`drive.file`** or full **`drive`** — pick the minimal scope that works for your backups.
   - Complete **browser** authorization when rclone gives a URL (headless VM: run `rclone authorize "drive"` on a machine with a browser and paste the result).
5. Set **`RCLONE_REMOTE_NAME=gdrive`** (or your remote name) in `/opt/vaultwarden/.env`.
6. One-time folder for [`backup.sh`](../infrastructure/templates/backup.sh.template):
   ```bash
   rclone mkdir "gdrive:vaultwarden-backups" 2>/dev/null || true
   rclone lsd "gdrive:vaultwarden-backups"
   ```
7. Test:
   ```bash
   cd /opt/vaultwarden && set -a && source .env && set +a && ./scripts/backup.sh
   ```
8. Confirm a **`.gpg`** file appears under **`vaultwarden-backups`** in Google Drive.

**Rotate / remove access:** **Google Account** → **Security** → **Third-party access** — revoke **Rclone** if you remove the remote; delete or disable the OAuth client in GCP if you decommission it.

---

## Troubleshooting

| Symptom | What to check |
|---------|---------------|
| `403` / API not enabled | **Google Drive API** enabled on the GCP project used by your OAuth client |
| Consent / “access blocked” | OAuth app in **Testing**: add your Google account as a **test user** on the consent screen |
| Remote name mismatch | **`RCLONE_REMOTE_NAME`** in `.env` equals the name in `rclone config show` |
| `vaultwarden-backups` missing | Run `rclone mkdir "<remote>:vaultwarden-backups"` once |

See also [Troubleshooting — Backup fails](troubleshooting.md#backup-fails).

---

## Verification

From `infrastructure/terraform/azure` or `hetzner` (Terraform state or `VM_*` env set; or `export TERRAFORM_DIR=...`):

```bash
../../iterations/iteration-6-backup/verify.sh
```

---

## Operator checklist (VM)

1. **Rclone** — OAuth remote configured; name = **`RCLONE_REMOTE_NAME`**; **`vaultwarden-backups/`** exists.
2. **`.env`** — **`BACKUP_ENCRYPTION_KEY`** set.
3. **Test** — `./scripts/backup.sh` completes; **`.gpg`** visible in Drive.
4. **Exit criteria** — `../../iterations/iteration-6-backup/verify.sh` exits **0**.
