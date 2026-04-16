# Hetzner automated deployment (TDI)

This guide is the **operator playbook** for deploying the password manager stack on **Hetzner Cloud** using **Terraform**, **GitHub Actions**, and the repo’s **Test-Driven Infrastructure** scripts (`iterations/…/verify.sh`). If you are **moving from Azure**, treat the optional closing section as your cutover checklist; the numbered iterations are the same for a **new** Hetzner-only install.

**Terraform creates the VM.** The files under `infrastructure/terraform/hetzner/` define the **Hetzner Cloud server**, firewall, and project SSH key; `terraform apply` (locally or via CI) **provisions** those resources. **cloud-init** runs on first boot and installs Docker, UFW, directories under `/opt/vaultwarden`, etc.

**“Iteration 1” does not create infrastructure** — it is the name of the **first verification script** (`iteration-1-infrastructure/verify.sh`). That script **checks** that Terraform’s resources exist, that the server is running, that SSH works, and that cloud-init finished its job. Same pattern for Iterations 2–7: each is a **test pass**, not the tool that creates the server or containers (except where steps say to run `deploy-to-vm.sh` or push to CI).

**Related:** [Prerequisites checklist](prerequisites-checklist.md) (common + Hetzner), [CI/CD pipelines](cicd-pipelines.md), [Terraform layout](../infrastructure/terraform/README.md), [TDI reference](../auto_deploy_iterations.md), [AGENTS.md](../AGENTS.md).

---

## Prerequisites (before Iteration 1)

Complete this block **once** before you rely on Iteration 1’s checks. (You can treat it as “Iteration 0” if you prefer a fully numbered path.)

1. **Repository and tools**
   - Clone this repo; install **Terraform** (≥ 1.5.0).
   - Install **Hetzner CLI** `hcloud` (required for Iteration 1 on Hetzner).

2. **Hetzner Cloud**
   - Project in [Hetzner Cloud Console](https://console.hetzner.com/).
   - API token (**Read & Write**). Locally: `export HCLOUD_TOKEN='…'` or `hcloud context create …` — never commit the token.

3. **SSH key**
   - Key pair whose **public** key path is set in `infrastructure/terraform/hetzner/terraform.tfvars` as `ssh_public_key_path`.
   - **Private** key available for GitHub secret `SSH_PRIVATE_KEY` and for local `deploy-to-vm.sh` / `verify.sh` (default file name used by scripts is often `~/.ssh/id_rsa_vaultwarden` — align with your setup).

4. **`terraform.tfvars` (Hetzner root, gitignored)**
   - Path: `infrastructure/terraform/hetzner/terraform.tfvars` (copy from `terraform.tfvars.example`).
   - Set at least: `location`, `server_type`, `admin_username` (often `root`), `ssh_public_key_path`, `domain` as the **full Vaultwarden URL** (e.g. `https://your-host.duckdns.org`).

5. **GitHub Actions (for CI-driven Terraform + deploy)**
   - **Secret** `HCLOUD_TOKEN`.
   - **Variable** `HOSTING_PROVIDER` = `hetzner` when you want workflows to run the Hetzner Terraform path.
   - **Secrets** `SSH_PRIVATE_KEY`, `DOMAIN` (same value as Terraform `domain`), `VM_USERNAME` (must match `admin_username` on the VM).

6. **DNS (plan before Iteration 4)**
   - You will point your hostname **A record** at `terraform output -raw vm_public_ip` **after** the server exists (e.g. DuckDNS).

7. **Optional — migrating from Azure**
   - Take a **fresh backup** of the old vault before cutover; see [plan.md](../plan.md) backup / DR sections. Do not commit vault data or keys.

---

## Iterations to follow (order)

1. **Apply Terraform** so the VM and related resources exist (see [Iteration 1 — Steps](#iteration-1-infrastructure-foundation)).
2. **Run** `iteration-1-infrastructure/verify.sh` to **confirm** that foundation (that is “Iteration 1” in TDI terms — verification, not provisioning).

Complete each iteration’s **steps**, then run its **`verify.sh`** until exit code **0** before moving on.

| Order | Iteration | Verify script |
|-------|-----------|----------------|
| 1 | [Iteration 1 — Infrastructure](#iteration-1-infrastructure-foundation) | `iterations/iteration-1-infrastructure/verify.sh` |
| 2 | [Iteration 2 — CI/CD](#iteration-2-cicd-pipeline-setup) | `iterations/iteration-2-cicd/verify.sh` |
| 3 | [Iteration 3 — Core services](#iteration-3-core-services-deployment) | `iterations/iteration-3-services/verify.sh` |
| 4 | [Iteration 4 — SSL](#iteration-4-reverse-proxy--ssl) | `iterations/iteration-4-ssl/verify.sh` |
| 5 | [Iteration 5 — Security](#iteration-5-security-hardening) | `iterations/iteration-5-security/verify.sh` |
| 6 | [Iteration 6 — Backups](#iteration-6-backup-system) | `iterations/iteration-6-backup/verify.sh` |
| 7 | [Iteration 7 — Monitoring](#iteration-7-monitoring--automation) | `iterations/iteration-7-monitoring/verify.sh` |

**How to run verifies from the repo root**

```bash
export TERRAFORM_DIR="$PWD/infrastructure/terraform/hetzner"
cd "$TERRAFORM_DIR"
../../../iterations/<folder>/verify.sh
```

**What CI automates today**

- On push to `main` (paths: `infrastructure/**`, `infrastructure/templates/**`, `.github/workflows/deploy.yml`, `docker-compose.yml`) with `HOSTING_PROVIDER=hetzner` and `HCLOUD_TOKEN`: **terraform plan/apply** for `infrastructure/terraform/hetzner`, then **light gate** (`verify-vm-deployment.sh` + **Iteration 3** `verify.sh`), then optionally **Deploy Application Configuration** (`deploy-to-vm.sh`). See [cicd-pipelines.md](cicd-pipelines.md).
- **Iterations 4–7** are **not** used as the CI skip gate; run them **locally** when you want full SSL, hardening, backup, and monitoring sign-off.

---

## Iteration 1: Infrastructure foundation

**Provisioning (creates the VM):** `terraform apply` in `infrastructure/terraform/hetzner/` (see step 1 below). That creates the **server**, **firewall**, and **hcloud_ssh_key** resource; **cloud-init** runs on first boot.

**Verification (Iteration 1):** The **`verify.sh`** script only **checks** that the above succeeded — it does not call Terraform or the Hetzner API to create servers.

### Steps

1. **Provision with Terraform (pick one path)** — this step **creates** the infrastructure.  
   - **Local**
     ```bash
     cd infrastructure/terraform/hetzner
     export HCLOUD_TOKEN='…'
     terraform init && terraform plan && terraform apply
     ```
   - **CI** — set `HOSTING_PROVIDER=hetzner`, `HCLOUD_TOKEN`, and deploy secrets; push a change under `infrastructure/**` to `main` (or use **workflow_dispatch** on the Deploy workflow if you use it). Wait for **terraform-apply-hetzner** to finish.

2. **Wait for cloud-init** — first boot can take several minutes before SSH and packages stabilize.

3. **Confirm outputs**
   ```bash
   cd infrastructure/terraform/hetzner
   terraform output vm_public_ip
   terraform output domain
   ```

### Verify

```bash
export TERRAFORM_DIR="$PWD/infrastructure/terraform/hetzner"
cd "$TERRAFORM_DIR"
../../../iterations/iteration-1-infrastructure/verify.sh
```

**Checks include:** Terraform state/outputs; `hcloud server describe` for server name from outputs; server **running**; SSH; `/opt/vaultwarden` layout; **UFW** active with 80/443; **Docker** / **Compose**; **rclone**, **sqlite3**, **gpg**; data dir ownership **1000:1000**.

**Requirement:** `hcloud` installed; for local describe, **`HCLOUD_TOKEN`** (or active context) set.

---

## Iteration 2: CI/CD pipeline setup

**Goal:** The **Deploy** workflow and docs expected by the repo are present and structurally valid (no live cloud call).

### Steps

1. Ensure you are on a revision of the repo that includes `.github/workflows/deploy.yml` and [docs/cicd-pipelines.md](cicd-pipelines.md).
2. Optionally install **yamllint** for stricter YAML checks (the verify script skips if missing).

### Verify

From **repository root** (script resolves paths from `iterations/`):

```bash
./iterations/iteration-2-cicd/verify.sh
```

**Checks include:** `deploy.yml` exists; YAML parse; expected job names / strings (e.g. deploy-config, Hetzner jobs when applicable).

---

## Iteration 3: Core services deployment

**Goal:** **Vaultwarden**, **Caddy**, and **Watchtower** run under `/opt/vaultwarden` with expected compose and `.env` layout.

### Steps

1. **Iteration 1 must pass** (SSH and directories OK).

2. **Deploy application files to the VM** (pick one):
   - **GitHub Actions** — after a successful Hetzner apply, the workflow runs **`infrastructure/scripts/deploy-to-vm.sh`** unless the **light gate** skips it (both `verify-vm-deployment.sh` and Iteration 3 verify already pass).
   - **Local**
     ```bash
     cd infrastructure/terraform/hetzner
     export VM_PUBLIC_IP="$(terraform output -raw vm_public_ip)"
     export VM_USERNAME="$(terraform output -raw vm_admin_username)"
     export DOMAIN="$(terraform output -raw domain)"
     export REPO_ROOT="$(cd ../../.. && pwd)"
     "${REPO_ROOT}/infrastructure/scripts/deploy-to-vm.sh"
     ```
     Use `SSH_IDENTITY_FILE` if your private key is not the default the script looks for.

3. If containers fail to start, inspect on the VM: `docker compose -f /opt/vaultwarden/docker-compose.yml ps` and logs.

### Verify

```bash
export TERRAFORM_DIR="$PWD/infrastructure/terraform/hetzner"
cd "$TERRAFORM_DIR"
../../../iterations/iteration-3-services/verify.sh
```

**Checks include:** `docker-compose.yml` and `.env` (mode **600**); containers **vaultwarden**, **caddy**, **watchtower** running; compose expectations such as **SIGNUPS_ALLOWED=true** for initial setup (see script and [cicd-pipelines.md](cicd-pipelines.md#light-gate-option-b-and-what-ci-does-not-check)).

---

## Iteration 4: Reverse proxy & SSL

**Goal:** DNS for your public hostname resolves to the VM’s public IP; **HTTPS** and reverse-proxy behaviour match the script’s checks.

### Steps

1. **Iteration 3 must pass** (services up).

2. **DNS** — set **A** (and **AAAA** if you use IPv6) for the hostname embedded in `DOMAIN` / Terraform `domain` to **`terraform output -raw vm_public_ip`**. Wait for propagation.

3. Ensure **Caddy** can obtain certificates (ports **80**/**443** reachable from the internet; hostname correct).

### Verify

```bash
export TERRAFORM_DIR="$PWD/infrastructure/terraform/hetzner"
cd "$TERRAFORM_DIR"
../../../iterations/iteration-4-ssl/verify.sh
```

**Checks include:** `dig`/`host` for **A** record vs VM IP; HTTPS / TLS / header checks as implemented in the script.

---

## Iteration 5: Security hardening

**Goal:** Post-setup hardening: signups policy, UFW rules, compose limits, `.env` hygiene, non-root where required by the script.

### Steps

1. **Iteration 4 must pass**.

2. Follow [plan.md](../plan.md) / project guidance to disable open signups and tighten security **as the script expects**.

3. If you need a non-interactive run, see the header of `iteration-5-security/verify.sh` (**`ITERATION5_NONINTERACTIVE=1`**) and ensure signups are already disabled per script logic.

### Verify

```bash
export TERRAFORM_DIR="$PWD/infrastructure/terraform/hetzner"
cd "$TERRAFORM_DIR"
../../../iterations/iteration-5-security/verify.sh
```

---

## Iteration 6: Backup system

**Goal:** **GPG**-encrypted backup script, **rclone** remote toward Google Drive (or configured remote), cron, and related files on the VM.

### Steps

1. **Iterations 1–3** should be green; Iteration 4–5 strongly recommended before relying on backups in production.

2. On the VM, configure **rclone** per [rclone-google-drive.md](rclone-google-drive.md) and [plan.md](../plan.md).

3. Confirm **`backup.sh`** exists under `/opt/vaultwarden/scripts` (deploy script lays down templates); run a manual backup test if [plan.md](../plan.md) describes one.

### Verify

```bash
export TERRAFORM_DIR="$PWD/infrastructure/terraform/hetzner"
cd "$TERRAFORM_DIR"
../../../iterations/iteration-6-backup/verify.sh
```

---

## Iteration 7: Monitoring & automation

**Goal:** Health check script, cron (every **15** minutes), Watchtower labels, container restart policies, logrotate; on Hetzner, **Azure-specific** budget/tag checks in the script are **skipped** with a warning.

### Steps

1. Ensure **deploy** has installed **health-check** cron and **logrotate** config (see `deploy-to-vm.sh` comments).

2. After first runs, confirm `/var/log/vaultwarden-health.log` exists if the verify script expects it.

### Verify

```bash
export TERRAFORM_DIR="$PWD/infrastructure/terraform/hetzner"
cd "$TERRAFORM_DIR"
../../../iterations/iteration-7-monitoring/verify.sh
```

---

## Terraform roots and state

| Directory | Use |
|-----------|-----|
| `infrastructure/terraform/hetzner/` | **This guide** — Hetzner server, firewall, SSH key resource. |
| `infrastructure/terraform/azure/` | Legacy / alternate path — **separate state**; do not mix commands. |

If you previously kept **Azure** state in a **flat** `infrastructure/terraform/terraform.tfstate`, move it into `azure/` before planning:

```bash
mv infrastructure/terraform/terraform.tfstate infrastructure/terraform/azure/terraform.tfstate
cd infrastructure/terraform/azure && terraform init -upgrade && terraform plan
```

---

## Optional: leaving Azure entirely

When Hetzner is stable and iterations **1–7** pass:

1. **Data** — confirm backups on the new host and a tested restore procedure.
2. **DNS** — production hostname should already target Hetzner (Iteration 4).
3. **Destroy Azure infra** — from `infrastructure/terraform/azure`: `terraform destroy` (or use the Portal).
4. **GitHub** — remove or rotate **Azure-only** secrets if unused; keep `HOSTING_PROVIDER=hetzner` if Hetzner is the only IaC target.

---

## Risks (short)

- **`HCLOUD_TOKEN`** and **`SSH_PRIVATE_KEY`** are high-impact — store only in GitHub **Secrets** / local secure storage; rotate if leaked.
- **Wrong Terraform directory** → wrong **state** or accidental **destroy** of the wrong cloud.
- **CI** does not replace **Iterations 4–7**; treat local verify as part of “done” for production.
