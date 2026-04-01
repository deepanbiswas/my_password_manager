# Key and secret rotation

Rotate secrets **when someone with access leaves**, after a suspected leak, or on a **calendar schedule** you are comfortable with (e.g. admin token yearly). This project uses a few rotating or replaceable values—not every item has a fixed “expiry.”

## 1. `ADMIN_TOKEN` (Vaultwarden `/admin`)

**When:** Compromise suspicion, staff change, or periodic policy.

**Steps:**

1. Generate a new token:
   ```bash
   openssl rand -base64 48
   ```
2. On the VM, edit `/opt/vaultwarden/.env` and set `ADMIN_TOKEN=<new value>`.
3. Recreate Vaultwarden so it picks up the env:
   ```bash
   cd /opt/vaultwarden
   docker compose up -d vaultwarden
   ```
4. Test `https://your-domain/admin` with the new token.

**Note:** This does not reset user vaults; it only changes access to the admin UI.

## 2. `BACKUP_ENCRYPTION_KEY` (GPG symmetric passphrase or key ID)

**When:** You must assume the passphrase was exposed, or policy requires periodic rotation.

**Important:** Backups already in Google Drive were encrypted with the **old** key. After you change `BACKUP_ENCRYPTION_KEY`:

- **New** backups use the new key.
- **Old** `.tar.gz.gpg` files still need the **old** passphrase (or old GPG key) to decrypt.

**Safe rotation:**

1. Run a **fresh backup** with the current key so you have a current restore point:
   ```bash
   cd /opt/vaultwarden && ./scripts/backup.sh
   ```
2. Store the **old** key in your password manager labeled with the date range it applies to (for example, “Vaultwarden backups until 2026-06-01”).
3. Generate a new key (if using passphrase style):
   ```bash
   openssl rand -base64 32
   ```
4. Update `BACKUP_ENCRYPTION_KEY` in `/opt/vaultwarden/.env`.
5. Run another backup and verify decrypt locally:
   ```bash
   gpg --decrypt vaultwarden-xxxxx.tar.gz.gpg > /tmp/test.tar.gz
   ```

Keep the old key until you have **no** backups left that require it (after retention prunes them), or re-archive old backups re-encrypted with the new key (advanced; usually unnecessary if retention is short).

## 3. TLS certificates (Caddy / Let’s Encrypt)

**When:** Normally **automatic**. Caddy renews certificates; you do not rotate them manually unless you change DNS or domain.

**If you change the public hostname:** Update `DOMAIN` and DNS, redeploy Caddy config, and let Caddy obtain new certs.

## 4. Rclone / Google Drive

**OAuth refresh tokens** are managed by rclone; you rarely “rotate” them manually.

**When:** Revoke or re-run `rclone config` if:

- A laptop with the rclone config was lost, or
- You switch from OAuth to a service account (see [Rclone + Google Drive](../rclone-google-drive.md) and related docs).

After reconfiguration, confirm uploads still work:

```bash
cd /opt/vaultwarden && ./scripts/backup.sh
```

## 5. SSH host keys and VM access

**When:** VM recreated or you see SSH host key warnings after a documented rebuild.

Update your `known_hosts` or verify out-of-band that the new fingerprint is expected.

## 6. GitHub / CI secrets (if deploy uses them)

Rotate **Azure service principal**, **SSH private key**, or **VM host** secrets in GitHub Actions if a secret was exposed or an employee with access leaves. Update the secret in the repository settings and run a small test deploy if needed.

---

**Summary:** The two values you touch most often on the VM itself are **`ADMIN_TOKEN`** and **`BACKUP_ENCRYPTION_KEY`**. Plan backup key rotation so you never lose the ability to decrypt historical archives.
