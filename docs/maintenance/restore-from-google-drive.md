# Recovery from Google Drive backups

This guide restores Vaultwarden **data** from an encrypted backup produced by `/opt/vaultwarden/scripts/backup.sh` (see `infrastructure/templates/backup.sh.template`). Filenames look like `vaultwarden-YYYYMMDD-HHMMSS.tar.gz.gpg` under the remote folder `vaultwarden-backups/`.

You need:

- SSH access to the VM (or a new Linux host with Docker and the same layout)
- **`BACKUP_ENCRYPTION_KEY`** from your secure store (same value as in `/opt/vaultwarden/.env`)
- **`RCLONE_REMOTE_NAME`** configured (e.g. `gdrive`) and working `rclone`—see [Rclone + Google Drive](../rclone-google-drive.md)

## 1. List backups in Drive

```bash
export RCLONE_REMOTE_NAME="${RCLONE_REMOTE_NAME:-gdrive}"
rclone ls "${RCLONE_REMOTE_NAME}:vaultwarden-backups/"
```

Pick the file you want (usually the latest timestamp).

## 2. Download the encrypted backup

```bash
mkdir -p /opt/vaultwarden/backups/recovery
cd /opt/vaultwarden/backups/recovery
rclone copy "${RCLONE_REMOTE_NAME}:vaultwarden-backups/vaultwarden-20260115-020001.tar.gz.gpg" .
```

Replace the filename with yours.

## 3. Decrypt

Passphrase-style key (value in `BACKUP_ENCRYPTION_KEY`):

```bash
export BACKUP_ENCRYPTION_KEY='your-passphrase-here'
echo -n "$BACKUP_ENCRYPTION_KEY" | gpg --batch --yes --passphrase-fd 0 --decrypt \
  -o vaultwarden-restored.tar.gz \
  vaultwarden-20260115-020001.tar.gz.gpg
```

If you use a GPG **key ID** instead of a passphrase, use your usual `gpg --decrypt` workflow with that key.

## 4. Inspect the archive

```bash
tar -tzf vaultwarden-restored.tar.gz | head
```

You should see entries such as `db_backup.sqlite3`, `attachments.tar.gz`, and `MANIFEST.txt`.

## 5. Stop Vaultwarden and back up current data (if any)

```bash
cd /opt/vaultwarden
docker compose stop vaultwarden
sudo cp -a vaultwarden/data "vaultwarden/data.bak.$(date +%Y%m%d%H%M%S)"
```

## 6. Extract and place files

```bash
cd /opt/vaultwarden/backups/recovery
mkdir -p stage
tar -xzf vaultwarden-restored.tar.gz -C stage
sudo install -o 1000 -g 1000 -m 0644 stage/db_backup.sqlite3 /opt/vaultwarden/vaultwarden/data/db.sqlite3
```

If `attachments.tar.gz` exists in `stage`:

```bash
sudo rm -rf /opt/vaultwarden/vaultwarden/data/attachments
sudo tar -xzf stage/attachments.tar.gz -C /opt/vaultwarden/vaultwarden/data
sudo chown -R 1000:1000 /opt/vaultwarden/vaultwarden/data
```

## 7. Verify SQLite (optional but recommended)

```bash
sqlite3 /opt/vaultwarden/vaultwarden/data/db.sqlite3 "PRAGMA integrity_check;"
```

Expect a single line: `ok`.

## 8. Start Vaultwarden

```bash
cd /opt/vaultwarden
docker compose up -d vaultwarden
docker compose logs -f --tail=50 vaultwarden
```

## 9. Smoke test

- Open `https://your-domain` (or IP if DNS not ready).
- Log in with a Bitwarden client using an account that existed at backup time.
- Open a few items and attachments.

## 10. Clean up sensitive scratch files

```bash
rm -f /opt/vaultwarden/backups/recovery/vaultwarden-restored.tar.gz
rm -rf /opt/vaultwarden/backups/recovery/stage
```

Keep `.gpg` files only if you still need them; otherwise remove to save space.

---

## New VM / full disaster

If the machine is fresh:

1. Install Docker, Docker Compose, `sqlite3`, `gpg`, `rclone`, and restore `/opt/vaultwarden` layout from [plan.md](../../plan.md) (compose, `.env`, Caddy).
2. Configure `rclone` and copy `.env` (or set `BACKUP_ENCRYPTION_KEY` and `RCLONE_REMOTE_NAME` again).
3. Follow **sections 2–9** above.

## Optional: `restore.sh` on the server

[plan.md](../../plan.md) describes a `restore.sh` helper under `/opt/vaultwarden/scripts/` that can list remote backups and automate download/decrypt/extract. If you already created it, you can use:

```bash
cd /opt/vaultwarden
./scripts/restore.sh
./scripts/restore.sh vaultwarden-YYYYMMDD-HHMMSS.tar.gz.gpg
```

If the script is not present, the manual steps in this document are enough.

## Troubleshooting

- **`gpg: decryption failed`:** Wrong `BACKUP_ENCRYPTION_KEY` or you are decrypting a backup from **before** a key rotation (use the key that was active when that backup was made).
- **`rclone` errors:** Re-run `rclone config` or refresh the remote; confirm the shared folder still contains `vaultwarden-backups/`.

See also [Troubleshooting](../troubleshooting.md) for service-level issues after restore.
