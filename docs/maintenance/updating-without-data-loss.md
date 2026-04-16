# Updating the setup without losing data

This guide covers **safe updates** for the Vaultwarden stack on the VM (default path: `/opt/vaultwarden`). Your passwords and vault data live on disk under `vaultwarden/data/` (SQLite + attachments). Updates that replace container images or redeploy Compose **do not** remove that directory if you follow the steps below.

## Principles

1. **Data lives on the host**, not inside disposable container layers. The bind mount `./vaultwarden/data:/data` keeps the database across image pulls.
2. **Always take a backup before** changing images or major config (same backup script as nightly jobs).
3. **Pull then recreate** containers; avoid `docker compose down -v` (the `-v` flag removes named volumes—this project uses bind mounts, but avoid `-v` out of habit).

## Before any update

1. SSH to the server and go to the deployment directory:
   ```bash
   cd /opt/vaultwarden
   ```
2. Run a **manual backup** (uses the same script as cron):
   ```bash
   ./scripts/backup.sh
   ```
3. Confirm the encrypted file appears in Google Drive (adjust remote name if yours is not `gdrive`):
   ```bash
   rclone ls "${RCLONE_REMOTE_NAME:-gdrive}:${RCLONE_BACKUP_FOLDER:-vaultwarden-backups-hetzner}/" | tail -5
   ```
4. Optionally note the current image tags:
   ```bash
   docker compose images
   ```

## Update via CI/CD (if you use the deploy workflow)

When you merge changes that update `docker-compose.yml`, templates, or scripts, the pipeline can redeploy to the VM. That process should **not** delete `./vaultwarden/data` on the host. Still run **`./scripts/backup.sh` once before** you trigger a deploy that changes production images, so you have a fresh restore point.

## Update Vaultwarden (image bump)

1. Complete [Before any update](#before-any-update).
2. Edit `docker-compose.yml` and set the Vaultwarden image tag (e.g. `vaultwarden/server:1.xx.x` or `vaultwarden/server:latest`—pinning a version is easier to roll back).
3. Pull and restart **only** Vaultwarden:
   ```bash
   docker compose pull vaultwarden
   docker compose up -d vaultwarden
   ```
4. Check logs and the web UI:
   ```bash
   docker compose logs -f --tail=100 vaultwarden
   ```
5. Test login and sync from a Bitwarden client.

## Update Caddy or other services

Same pattern: backup first, then:

```bash
docker compose pull <service>
docker compose up -d <service>
```

Caddy certificates and config live under `./caddy/` on the host; normal `up -d` keeps those directories.

## Update host packages (optional, low frequency)

```bash
sudo apt update && sudo apt upgrade -y
```

Reboot only if the kernel or libc update recommends it; after reboot, confirm containers are up:

```bash
cd /opt/vaultwarden && docker compose ps
```

## If something goes wrong

- **Roll back the image tag** in `docker-compose.yml` to the previous version, then `docker compose pull vaultwarden && docker compose up -d vaultwarden`.
- **Restore from backup** only if data is corrupted or missing—see [Restore from Google Drive](restore-from-google-drive.md).

## What not to do

- Do not delete or move `/opt/vaultwarden/vaultwarden/data` unless you are intentionally migrating or restoring.
- Do not commit `.env` or encryption keys to git.

For a longer checklist (release notes, monitoring after update), see **Vaultwarden Update Procedure** in [plan.md](../../plan.md#vaultwarden-update-procedure).
