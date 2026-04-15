# Deployment prerequisites checklist

This document lists what you need **before** [plan.md](../plan.md) automated deployment and before running TDI `verify.sh` scripts against a VM. Work through **Common** first, then **only the provider you use** (Azure *or* Hetzner).

**Related:** [Terraform guide](terraform-guide.md), [CI/CD pipelines](cicd-pipelines.md), [Hetzner automated deployment (TDI)](hetzner-automated-deployment.md), [cost-analysis.md](cost-analysis.md) (Azure ₹4,200/month assumption).

---

## How to use this checklist

1. Complete every item in **Common prerequisites** (tools, keys, repo).
2. Complete **either** **Azure-only** *or* **Hetzner-only** — not both unless you operate two stacks.
3. Use the **Suggested order** at the end as a single pass through the lists.

Estimated one-time setup: **about 30–60 minutes** for accounts and tools (DNS and full deploy add more later).

---

## Common prerequisites

These apply to Vaultwarden on **any** cloud VM managed from this repo.

### 1. Git repository and GitHub Actions

**Comply:** You can push this repo and run workflows under [.github/workflows/](../.github/workflows/).

- [ ] **Git**: Remote configured (`git remote -v` shows `origin`).
- [ ] **GitHub (or compatible host)**: Repository exists; **Actions** enabled: **Settings → Actions → General**.
- [ ] **CI/CD secrets/variables** (when you use automated deploy): see [cicd-pipelines.md](cicd-pipelines.md) — plan `SSH_PRIVATE_KEY`, `DOMAIN`, `VM_USERNAME`, etc.; provider-specific items are in Azure-only / Hetzner-only below.

**Verify:**

```bash
git remote -v
```

### 2. Terraform (local)

**Comply:** Terraform **≥ 1.5.0** (matches `required_version` in `infrastructure/terraform/azure/main.tf` and `infrastructure/terraform/hetzner/main.tf`).

- [ ] Install from [HashiCorp: Install Terraform](https://developer.hashicorp.com/terraform/install).

**macOS (Homebrew) example:**

```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
```

**Verify:**

```bash
terraform version
```

### 3. SSH key pair (for VM access)

**Comply:** A key pair exists; the **public** key is passed into Terraform via `ssh_public_key_path` in **`terraform.tfvars`** under the root you use — `infrastructure/terraform/azure/` or `infrastructure/terraform/hetzner/` (see [terraform-guide.md](terraform-guide.md)).

- [ ] Generate a key (example RSA):

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa_vaultwarden -C "vaultwarden-vm"
```

- [ ] Copy the correct **`terraform.tfvars.example`** → **`terraform.tfvars`** (gitignored) under **`azure/`** or **`hetzner/`** and set:

```hcl
ssh_public_key_path = "~/.ssh/id_rsa_vaultwarden.pub"
```

- [ ] **Never** commit private keys, `terraform.tfvars`, or cloud API tokens (see [.gitignore](../.gitignore)).

**Verify:**

```bash
ssh-keygen -lf ~/.ssh/id_rsa_vaultwarden.pub
```

### 4. Domain name and DNS (production HTTPS)

**Comply:** You can point a hostname at the VM’s public IP **after** `terraform apply`, or you accept a **temporary** URL (Azure can expose an `*.cloudapp.azure.com` FQDN via `dns_label`; Hetzner often uses a custom domain or `https://<ipv4>` from Terraform outputs until DNS exists — see [plan.md](../plan.md) DNS steps).

- [ ] Either a domain you control **or** a documented decision to use the provider’s temporary hostname / IP-only URL for testing.
- [ ] Access to your DNS provider to create **A** (and optionally **AAAA**) records when you cut over.
- [ ] After you have `vm_public_ip`, set DNS per **[plan.md](../plan.md) → Common Configuration Steps → DNS Configuration**.

**Verify (after DNS is set):**

```bash
dig +short vault.example.com
# or
nslookup vault.example.com
```

### 5. Google Drive and backups (application default)

**Comply:** Encrypted backups use **Rclone** + Google Drive per [spec.md](../spec.md); configure Rclone **on the VM** before backup automation is relied on (not required for the very first `terraform apply`).

- [ ] Google account with Drive access; **2FA** enabled on that account (recommended).
- [ ] Later on the VM: [plan.md](../plan.md) → Rclone Configuration and [rclone-google-drive.md](rclone-google-drive.md).

**Later on the VM:**

```bash
rclone version
rclone config   # see docs/rclone-google-drive.md
```

---

## Azure-only prerequisites

Complete this section if your infrastructure is **Microsoft Azure** (`infrastructure/terraform/azure/`).

### A1. Azure subscription and permissions

**Comply:** You can create resource groups, VMs, and networking in a subscription you use for this project. The **₹4,200/month** figure in [cost-analysis.md](cost-analysis.md) is a **budget assumption**, not a portal toggle.

- [ ] Sign in to [Azure Portal](https://portal.azure.com) and confirm at least one **Subscription**.
- [ ] Your account can deploy infra (e.g. **Owner** or **Contributor** on the subscription or target resource group).
- [ ] Optional: set a **budget / cost alert** in Azure Cost Management (see [cost-analysis.md](cost-analysis.md)).

### A2. Azure CLI and login

**Comply:** `az` targets that subscription for **local** `terraform plan/apply`. CI/CD uses a **service principal** via `AZURE_CREDENTIALS` (see [cicd-pipelines.md](cicd-pipelines.md)), not necessarily your personal login.

- [ ] Install [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli).

```bash
# macOS (Homebrew) example
brew install azure-cli
```

- [ ] `az login`
- [ ] `az account set --subscription "<id-or-name>"`

**Verify:**

```bash
az account show
az group list -o table
```

### A3. Terraform root and variables (Azure)

**Comply:** State and variables live under the Azure root only.

- [ ] `cd infrastructure/terraform/azure`
- [ ] `cp terraform.tfvars.example terraform.tfvars` and edit: `location`, `vm_size`, `admin_username`, `dns_label` and/or `domain`, `ssh_public_key_path`.
- [ ] `terraform init && terraform plan` (read-only check before apply).

### A4. GitHub deploy (Azure path)

**Comply:** Repository variable **`HOSTING_PROVIDER`** unset or **`azure`** so [.github/workflows/deploy.yml](../.github/workflows/deploy.yml) runs **terraform-plan-azure** / **terraform-apply-azure** when `AZURE_CREDENTIALS` is set.

- [ ] Secrets per [cicd-pipelines.md](cicd-pipelines.md): `AZURE_CREDENTIALS`, `DOMAIN`, `SSH_PRIVATE_KEY`, `VM_USERNAME`, etc.

---

## Hetzner-only prerequisites

Complete this section if your infrastructure is **Hetzner Cloud** (`infrastructure/terraform/hetzner/`).

### H1. Hetzner Cloud account and project

**Comply:** You have access to [Hetzner Cloud Console](https://console.hetzner.com/) and a **project** where servers will be created.

- [ ] Account active and billing/payment method acceptable to you.
- [ ] Know which **location** you will use (e.g. `nbg1`, `fsn1`) — set in `terraform.tfvars` as `location`.

### H2. Hetzner API token (secret)

**Comply:** Terraform’s `hcloud` provider reads **`HCLOUD_TOKEN`** from the environment — **never** commit it.

- [ ] In the console: **Security → API tokens** → create token with **Read & Write** for the target project.
- [ ] **Local:** `export HCLOUD_TOKEN='…'` in the shell where you run Terraform / `hcloud`.
- [ ] **GitHub Actions:** repository secret **`HCLOUD_TOKEN`** (exact name; see [cicd-pipelines.md](cicd-pipelines.md)).
- [ ] Optional: store a copy in your password manager for rotation.

**Rotate:** Revoke the old token in Hetzner, create a new one, update `export` / GitHub secret.

### H3. Hetzner CLI (`hcloud`) for local checks

**Comply:** [iterations/iteration-1-infrastructure/verify.sh](../iterations/iteration-1-infrastructure/verify.sh) uses **`hcloud server describe`** when `cloud_provider` is Hetzner.

- [ ] Install [Hetzner CLI](https://github.com/hetznercloud/cli) (`hcloud`).
- [ ] With `HCLOUD_TOKEN` set: `hcloud server list` (or `hcloud context` if you use contexts).

### H4. Terraform root and variables (Hetzner)

**Comply:** State and variables live under the Hetzner root only.

- [ ] `cd infrastructure/terraform/hetzner`
- [ ] `cp terraform.tfvars.example terraform.tfvars` and edit: `location`, `server_type`, `admin_username` (often **`root`** for Ubuntu cloud images), `domain`, `ssh_public_key_path`, optionally **`ssh_allowed_cidr`** to restrict SSH.
- [ ] `export HCLOUD_TOKEN='…'` then `terraform init && terraform plan`.

### H5. GitHub deploy (Hetzner path)

**Comply:** **`HOSTING_PROVIDER=hetzner`** selects **terraform-plan-hetzner** / **terraform-apply-hetzner** in deploy.yml.

- [ ] Repository **variable** **`HOSTING_PROVIDER`** = `hetzner` (**Settings → Secrets and variables → Actions → Variables**).
- [ ] Repository **secret** **`HCLOUD_TOKEN`** set.
- [ ] **`VM_USERNAME`** secret matches the Linux user Terraform uses (often `root` on Hetzner Ubuntu — must match SSH and container deploy expectations).

---

## Suggested order

**Everyone (common):**  
1. Git remote + Actions enabled → 2. `terraform version` → 3. SSH key + `terraform.tfvars` in **your** root (`azure/` or `hetzner/`) → 4. Plan domain/DNS strategy → 5. (Later) Google 2FA + Rclone on VM.

**If Azure:**  
A1 subscription → A2 `az login` → A3 `terraform init` in `azure/` → A4 GitHub secrets + `HOSTING_PROVIDER` default/azure.

**If Hetzner:**  
H1 account → H2 `HCLOUD_TOKEN` → H3 `hcloud` → H4 `terraform init` in `hetzner/` → H5 `HOSTING_PROVIDER` + `HCLOUD_TOKEN` + `VM_USERNAME` in GitHub.

---

## Local verification log (optional)

| Area | Check | Command / note | Date / result |
|------|--------|----------------|----------------|
| Common | Terraform | `terraform version` | |
| Common | SSH pubkey | `ssh-keygen -lf …pub` | |
| Common | Git | `git remote -v` | |
| Common | DNS | `dig` / `nslookup` after A record | |
| Azure | Subscription | `az account show` | |
| Azure | Terraform | `cd infrastructure/terraform/azure && terraform validate` | |
| Hetzner | Token (not pasted in log) | `HCLOUD_TOKEN` set / GitHub secret | |
| Hetzner | CLI | `hcloud server list` | |
| Hetzner | Terraform | `cd infrastructure/terraform/hetzner && terraform validate` | |
| Common (later) | Rclone | On VM: `rclone config` | |
