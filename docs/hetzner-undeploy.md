# Hetzner: undeploy and teardown

This guide describes how to **remove** the password manager stack from **Hetzner Cloud** and what you must do **outside** Terraform (DNS, CI secrets, certificates).

**What Terraform manages:** a single VM (`hcloud_server`), an `hcloud_firewall`, and an `hcloud_ssh_key` resource in your Hetzner project. See `infrastructure/terraform/hetzner/main-stack.tf`.

**What Terraform does *not* manage:** DuckDNS (or any DNS) records, GitHub Actions secrets, Let’s Encrypt **account** lifecycle on third-party systems, or backups in Google Drive. Those need separate steps below.

---

## Recommended order (full teardown)

1. **Commit the paused Deploy workflow** (or disable the workflow in GitHub) so pushes do not run Terraform while you tear down — see `.github/workflows/deploy.yml` header comments.
2. **Export the vault** if you still need the data (Bitwarden client export / backup).
3. **`terraform destroy`** — `./scripts/undeploy-hetzner.sh --destroy` (or `--destroy --yes`). This needs **`HCLOUD_TOKEN`** and Terraform Cloud auth (`terraform login` or `TF_TOKEN_app_terraform_io`) while state still exists.
4. **Delete the Terraform Cloud workspace** (optional but frees the workspace name) — **only after** destroy succeeds: `./scripts/delete-terraform-cloud-workspace-hetzner.sh` (see script header for `TF_TOKEN_app_terraform_io`). Deleting the workspace first makes later `terraform destroy` much harder because remote state is gone.
5. **DuckDNS / DNS** — clear or repoint **A** / **AAAA** as in [DNS](#1-dns-eg-duckdns) below.
6. **GitHub** — clear `HOSTING_PROVIDER`, remove or rotate `HCLOUD_TOKEN`, `SSH_PRIVATE_KEY`, `DOMAIN`, `VM_USERNAME`, and `TF_TOKEN_APP_TERRAFORM_IO` if you no longer use Terraform Cloud from Actions.

---

## Before you destroy anything

1. **Export or backup the vault** using a Bitwarden client (recommended) so you do not rely on server disk or SQLite files after the VM is gone.
2. **Confirm Terraform directory and state** — destroying the wrong root can delete the wrong cloud. The Hetzner root is **`infrastructure/terraform/hetzner/`** (not `azure/`).
3. **Decide whether to keep remote state** — after destroy, Terraform Cloud (or your backend) still holds **state** for an empty stack unless you remove the workspace or reconfigure. That is optional cleanup (see below).

---

## Automated teardown (script)

From the repository root (or anywhere, if `TERRAFORM_DIR` points at the Hetzner root):

```bash
export HCLOUD_TOKEN='your-hetzner-read-write-token'
./scripts/undeploy-hetzner.sh              # preview: terraform plan -destroy
./scripts/undeploy-hetzner.sh --destroy    # interactive destroy (you confirm at Terraform prompt)
./scripts/undeploy-hetzner.sh --destroy --yes   # non-interactive destroy (CI / automation)
```

Requirements:

- **`HCLOUD_TOKEN`** — same class of token you used for `terraform apply` (Hetzner API read/write).
- **Terraform** installed and **same backend auth** as for apply (e.g. `terraform login` if you use Terraform Cloud, as in `infrastructure/terraform/hetzner/main.tf`).
- Run **`terraform init`** is performed automatically by the script.

If `terraform destroy` fails (wrong state, token, or network), fix the error and retry, or use [Manual Hetzner cleanup](#manual-hetzner-cleanup-if-terraform-fails) for orphaned resources.

### Delete Terraform Cloud workspace (after destroy)

When the Hetzner root uses the `cloud {}` backend in `main.tf`, the workspace **`password-manager-hetzner`** in org **`TF_DEEPAN_PERSONAL_ORG`** holds remote state. After a successful destroy, you can remove that workspace with API access:

```bash
export TF_TOKEN_app_terraform_io='…'   # Terraform Cloud user token with workspace delete
./scripts/delete-terraform-cloud-workspace-hetzner.sh
# Non-interactive:
./scripts/delete-terraform-cloud-workspace-hetzner.sh --yes
```

Override defaults with `TFC_ORG`, `TFC_WORKSPACE`, or `TFC_ADDRESS` if your backend differs.

---

## Manual steps after (or alongside) destroy

### 1. DNS (e.g. DuckDNS)

Terraform never set your DuckDNS hostname; you pointed an **A** record at the VM’s public IP during deployment.

- Log in to [DuckDNS](https://www.duckdns.org/) (or your DNS provider).
- **Remove** the **A** record, set the IP to a placeholder, or **delete** the subdomain if you no longer need the name.
- If you use **AAAA** to the VM’s IPv6 address, remove that record too.

Until DNS is updated, the hostname may still resolve to an old IP (or nothing useful); that does not keep the server running after destroy.

### 2. Let’s Encrypt certificates

**Caddy** on the VM obtained certificates for your hostname. When the **VM is destroyed**, that disk and those certificate files are **gone**. You do not need a separate “delete certificate” step for a full teardown.

Optional notes:

- **Revocation** is usually unnecessary for short-lived DV certs when the private key is destroyed with the VM. If you ever had a **key compromise**, use your CA’s revocation process; that is outside this repo.
- If you **redeploy later** on a new IP with the same hostname, Caddy will **issue new** certificates after DNS points at the new server.

### 3. GitHub Actions and repository configuration

So CI does not try to plan/apply against a removed server (or with stale expectations):

- **Repository variable** `HOSTING_PROVIDER` — clear it, set to another provider, or leave as `hetzner` only if you still use the Hetzner workflow intentionally.
- **Secrets** such as `HCLOUD_TOKEN`, `SSH_PRIVATE_KEY`, `DOMAIN`, `VM_USERNAME` — remove or rotate if you are done with this deployment. Treat them as sensitive even after destroy.
- Optional: disable or adjust **Deploy** workflows if you no longer want pushes to touch Hetzner.

### 4. Terraform Cloud (if you use it)

The Hetzner root is configured with a `cloud { ... }` block in `main.tf`. After destroy:

- The **workspace** still exists with **empty or updated state**. Delete it with **`scripts/delete-terraform-cloud-workspace-hetzner.sh`** or in the Terraform Cloud UI if you want a clean slate (**after** `terraform destroy`, not before).
- This does **not** delete Hetzner resources by itself; `terraform destroy` (or the script) does.

### 5. Local and operational artifacts

- **`terraform.tfvars`** in `infrastructure/terraform/hetzner/` — may contain your domain and paths; keep or delete locally as you prefer (it should remain gitignored).
- **SSH keys** — destroying `hcloud_ssh_key` in Hetzner does not delete files on your laptop; rotate or archive keys if policy requires.
- **Backups** in **Google Drive** (or another rclone remote) — not deleted by Terraform; delete or retain per your retention policy.

---

## Manual Hetzner cleanup if Terraform fails

If state is lost or Terraform cannot run:

1. Open [Hetzner Cloud Console](https://console.hetzner.com/) → your project.
2. Delete the **server** named like `vm-password-manager` (or the name you used if customized).
3. Remove the **firewall** and **SSH key** entries that match your deployment labels/names if they were left behind.

Use the same names/labels as in `main-stack.tf` (`fw-password-manager-*`, `vaultwarden-*`) to avoid deleting unrelated resources.

---

## Quick checklist

| Step | Action |
|------|--------|
| Backup | Export vault; confirm backups if you need historical archives |
| Terraform | `./scripts/undeploy-hetzner.sh` then `./scripts/undeploy-hetzner.sh --destroy` |
| DNS | DuckDNS / DNS: remove or repoint **A** (and **AAAA** if used) |
| TLS | No extra step for full VM delete; optional revocation only for compromise |
| GitHub | Adjust `HOSTING_PROVIDER`, secrets; Deploy workflow paused or manual-only |
| Terraform Cloud | After destroy: `delete-terraform-cloud-workspace-hetzner.sh` or UI |
| Remotes | Retain or delete cloud backup objects separately |

---

## Related docs

- [Hetzner automated deployment (TDI)](hetzner-automated-deployment.md) — how the stack was deployed
- [Prerequisites checklist](prerequisites-checklist.md) — secrets and tools referenced during deploy
- [CI/CD pipelines](cicd-pipelines.md) — what GitHub Actions does for Hetzner
