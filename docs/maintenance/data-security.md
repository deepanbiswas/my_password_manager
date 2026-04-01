# Keeping data secure (low-effort habits)

This setup is **zero-knowledge for vault contents**: the server stores encrypted blobs; your **master password** never leaves the Bitwarden clients in a recoverable form. Security on the server is about **protecting the host, secrets, and backups**.

## 1. Transport and exposure

- **HTTPS only**: Caddy terminates TLS; users should only use `https://` for your domain.
- **Firewall**: Restrict SSH (and optionally HTTP/S) to your IP or a bastion if you can. Follow whatever NSG/firewall rules you defined in Terraform or your cloud console.
- **Admin URL**: Vaultwarden admin is at `/admin`. Use a **strong `ADMIN_TOKEN`** and do not share it. Do not post screenshots of the admin panel with tokens visible.

## 2. Secrets on the server

- **`/opt/vaultwarden/.env`** holds `ADMIN_TOKEN`, `BACKUP_ENCRYPTION_KEY`, and related settings. Permissions should be tight (e.g. root-owned, `chmod 600` or equivalent).
- **Never commit `.env`** to git; use your password manager or a secure store for values needed during rebuilds.
- **SSH keys**: Use ed25519 keys, disable password SSH if policy allows, and keep your workstation secure—whoever has SSH has access to the VM and backup decryption if they also have the key material.

## 3. Backups

- Backups are **encrypted with GPG (AES-256)** using `BACKUP_ENCRYPTION_KEY` before upload to Google Drive (see `infrastructure/templates/backup.sh.template`).
- **Google Drive access**: Prefer the **least-privilege** rclone scope you configured (e.g. `drive.file` for OAuth, or a service account limited to a shared folder). See [Rclone + Google Drive](../rclone-google-drive.md).
- **Retention**: `BACKUP_RETENTION_DAYS` limits how long old copies stay in the remote—balance recovery needs vs. exposure window.

## 4. Dependencies and disclosure

- **Watchtower** (if enabled for Caddy) pulls new images automatically—acceptable for the reverse proxy if you accept automatic updates; Vaultwarden is typically **not** auto-updated in this project so you can review releases first.
- Subscribe to **Vaultwarden security advisories** on GitHub and apply image updates after taking a backup (see [Updating without data loss](updating-without-data-loss.md)).

## 5. Operational hygiene (minimal checklist)

| Frequency | Action |
|-----------|--------|
| After any staff change | Rotate `ADMIN_TOKEN` and SSH keys if someone had access (see [Key rotation](key-rotation.md)). |
| Monthly (optional) | Confirm backups exist in Drive and spot-check one decrypt on an offline machine. |
| When alerts fire | Read Caddy/Vaultwarden logs and fix TLS or disk issues before they become outages. |

## 6. What this document does not cover

- **Bitwarden account security** (2FA, device approvals) is configured in client apps and the Vaultwarden admin policies—follow Bitwarden’s documentation for organizations if you use them.
- **Physical or legal** access to the VM or Google account bypasses encryption at rest if the attacker also obtains `BACKUP_ENCRYPTION_KEY`—protect both.

For incident-style steps, see [Troubleshooting](../troubleshooting.md).
