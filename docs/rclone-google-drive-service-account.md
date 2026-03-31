# Rclone: Google Drive with a service account (recommended)

This guide configures backups to **Google Drive** using a **Google Cloud service account** and a **single shared folder** from your personal Drive. The VM never holds an OAuth token for your user account; the service account can only access folders you explicitly share with it.

**Related:** [`backup.sh.template`](../infrastructure/templates/backup.sh.template) uses `RCLONE_REMOTE_NAME` (default `gdrive`) and path `vaultwarden-backups/` under that remote’s root.

**Do not** commit the JSON key or add it to the repo. Store it on the VM with restrictive permissions (`chmod 600`).

---

## Why use a service account

| Approach | Exposure if `rclone.conf` is stolen |
|----------|-------------------------------------|
| OAuth (user token) | Token may allow broad Drive access for that user (until revoked) |
| Service account + shared folder | Access is limited to what you shared with the SA email (sandbox) |

Backups remain **GPG-encrypted** by `BACKUP_ENCRYPTION_KEY` before upload; this guide reduces **Drive API scope**, not vault encryption.

---

## Layout (recommended)

1. In **personal Google Drive**, create a folder (e.g. `Vaultwarden_Backups`).
2. Share that folder with the **service account email** as **Editor** (or **Content manager** on a Shared Drive).
3. Copy the folder ID from the URL: `https://drive.google.com/drive/folders/<FOLDER_ID>`.
4. In rclone, set **`root_folder_id`** to that ID. The remote’s root is that folder only.
5. Create the **`vaultwarden-backups`** subfolder once:  
   `rclone mkdir <remote>:vaultwarden-backups`  
   so existing [`backup.sh`](../infrastructure/templates/backup.sh.template) paths keep working.

---

## Phase B — Google Cloud and Drive (browser)

1. Open [Google Cloud Console](https://console.cloud.google.com/), select or create a **project**.
2. **APIs & Services** → **Library** → enable **Google Drive API**.
3. **IAM & Admin** → **Service Accounts** → **Create service account** (e.g. display name `vaultwarden-backup`). Project IAM roles are not required for Drive access via shared folder.
4. Open the service account → **Keys** → **Add key** → **JSON** → download. Keep this file private.
5. Note the **service account email** (ends with `@...iam.gserviceaccount.com`).
6. In **Google Drive** (your user), create or pick a folder → **Share** → add the service account email with **Editor**.
7. Open the folder in the browser and copy **`root_folder_id`** from the URL.

---

## Phase C — VM: JSON path and `rclone config`

### Option: migrate from your laptop (script)

If you have the JSON on your Mac/Linux machine and SSH to the VM works (same as [`deploy-to-vm.sh`](../infrastructure/scripts/deploy-to-vm.sh)):

```bash
cd infrastructure/terraform
export VM_PUBLIC_IP="$(terraform output -raw vm_public_ip)"
export VM_USERNAME="$(terraform output -raw vm_admin_username)"
# optional: export SSH_IDENTITY_FILE=~/.ssh/id_rsa_vaultwarden
../scripts/migrate-rclone-service-account-on-vm.sh \
  --json-file /path/to/your-service-account.json \
  --root-folder-id YOUR_FOLDER_ID_FROM_DRIVE_URL
```

This backs up `rclone.conf`, removes the existing remote name (default `gdrive`), creates a new `drive` remote with `service_account_file` + `root_folder_id`, and runs `mkdir` for `vaultwarden-backups`. Then run a manual backup and `../../iterations/iteration-6-backup/verify.sh`.

### Manual steps on the VM

1. Copy the JSON to the VM, e.g. `/opt/vaultwarden/secrets/rclone-sa.json`:
   ```bash
   sudo mkdir -p /opt/vaultwarden/secrets
   sudo mv /path/to/downloaded.json /opt/vaultwarden/secrets/rclone-sa.json
   sudo chown "$(whoami):$(whoami)" /opt/vaultwarden/secrets/rclone-sa.json
   chmod 600 /opt/vaultwarden/secrets/rclone-sa.json
   ```
2. Run `rclone config`:
   - `n` — New remote.
   - Name: e.g. `gdrive` (must match `RCLONE_REMOTE_NAME` in `/opt/vaultwarden/.env`).
   - Storage: `drive` (Google Drive).
   - **service_account_file:** `/opt/vaultwarden/secrets/rclone-sa.json`
   - **root_folder_id:** paste the folder ID from the Drive URL.
   - **team_drive** / Shared Drive: leave blank unless you use a Shared Drive.
   - Scope: default is fine.
3. Ensure `/opt/vaultwarden/.env` contains:
   ```bash
   RCLONE_REMOTE_NAME=gdrive
   ```
   (or the same name you chose in `rclone config`).
4. One-time subfolder for the template:
   ```bash
   rclone mkdir "gdrive:vaultwarden-backups"
   rclone lsd "gdrive:vaultwarden-backups"
   ```
5. Test backup:
   ```bash
   cd /opt/vaultwarden && set -a && source .env && set +a && ./scripts/backup.sh
   ```
6. Confirm the encrypted file appears under the shared folder in the Drive UI (inside `vaultwarden-backups/`).

---

## Phase A — Undo previous OAuth-based rclone

Use when switching **from** a user-OAuth remote **to** a service account, or to rotate credentials.

1. **Inspect** current remotes (note the name, often `gdrive`):
   ```bash
   rclone config show
   ```
2. **Backup** the config file:
   ```bash
   cp ~/.config/rclone/rclone.conf ~/.config/rclone/rclone.conf.bak."$(date +%Y%m%d)"
   ```
3. **Delete** the old remote (replace `gdrive` if yours differs):
   ```bash
   rclone config delete gdrive
   ```
4. **Optional:** Remove leftover token/cache files under `~/.config/rclone/` only if nothing else uses them.
5. **Google Account** (browser): **Google Account** → **Security** → **Third-party access** / **Manage third-party access** → revoke the old **Rclone** OAuth app if listed.
6. **Drive:** After the new remote works, move or delete old backup objects if they lived under paths you no longer use.

Then complete **Phase C** above.

---

## Troubleshooting

| Symptom | What to check |
|---------|----------------|
| `403` / `accessNotConfigured` | Drive API enabled on the GCP project that owns the service account. |
| `404` / file not found | Wrong `root_folder_id`; folder not shared with the **exact** SA email. |
| Empty listing | Run `rclone mkdir <remote>:vaultwarden-backups` once. |
| Permission denied on JSON | Path in `service_account_file` correct; `chmod 600`; user running `rclone` can read the file. |

See also [Troubleshooting — Backup Fails](troubleshooting.md#backup-fails).

---

## Verification

From `infrastructure/terraform` (Terraform state or `VM_*` env set):

```bash
../../iterations/iteration-6-backup/verify.sh
```

---

## Operator migration checklist (Phases A–C on the VM)

Complete these on the VM (or from your workstation with SSH). The repository cannot apply your GCP JSON or Google sharing for you.

1. **Phase A** — If replacing OAuth: backup `rclone.conf`, `rclone config delete <old-remote>`, revoke third-party Rclone access in Google Account if applicable.
2. **Phase B** — GCP: Drive API, service account, JSON key; Drive: share folder with SA email; note `root_folder_id`.
3. **Phase C** — Install JSON with `chmod 600`, run `rclone config` (`service_account_file`, `root_folder_id`), align `RCLONE_REMOTE_NAME` in `.env`, `rclone mkdir <remote>:vaultwarden-backups`, run `./scripts/backup.sh` once, confirm file in Drive.
4. **Exit criteria:** `../../iterations/iteration-6-backup/verify.sh` exits **0** (from `infrastructure/terraform`, with SSH access to the VM).

---

## Legacy: OAuth user remote

You can still use `rclone config` with **OAuth** and a remote named `gdrive`; it is **less isolated** than the service-account pattern above. Prefer this document for new setups.
