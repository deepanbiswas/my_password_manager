# Automated deployment prerequisites checklist

This document helps you comply with **[plan.md](../plan.md) → Automated Deployment → Prerequisites**. Estimated one-time setup: **30–60 minutes** for accounts and tools (DNS and full deploy add more later).

**Related:** [Cost analysis](cost-analysis.md) (₹4,200/month assumption), [Terraform guide](terraform-guide.md), [CI/CD pipelines](cicd-pipelines.md).

---

## 1. Azure account with subscription and ₹4,200/month credits

**Comply:** You have an active Azure subscription you can deploy to. The **₹4,200/month** figure is a **budget assumption** from cost docs—not something you enable in Azure.

- [X] Sign in to [Azure Portal](https://portal.azure.com) and confirm at least one **Subscription** (Pay-As-You-Go, credits, MSDN, etc.).
- [X] Confirm you can create resource groups and VMs (e.g. **Owner** or **Contributor** on the subscription or resource group).
- [X ] Optional: set a **budget / cost alert** in Azure Cost Management so spend stays within your target (see [cost-analysis.md](cost-analysis.md)).

**Verify (after [Azure CLI](#5-azure-cli-installed-and-configured) is installed):**

```bash
az account list -o table
az account show
```

**Notes:** Track spend against your credit limit; pick a VM SKU in `terraform.tfvars` that matches [cost-analysis.md](cost-analysis.md).

---

## 2. Domain name registered and DNS access available
*NOTE: Using Azure's FQDN for now*

**Comply:** You can edit DNS for a hostname that will point to the Vaultwarden VM.

- [ ] Domain registered **or** existing domain you control.
- [ ] Access to your DNS provider (registrar or DNS host) to create **A** (and optionally **AAAA**) records.
- [ ] After `terraform apply`, set an **A record** from your chosen hostname (e.g. `vault.example.com`) to `terraform output -raw vm_public_ip`. Follow **[plan.md](../plan.md) → Common Configuration Steps → DNS Configuration** (also referenced in Automated Deployment Step 3).

**Verify (after DNS is set):**

```bash
dig +short vault.yourdomain.com
# or
nslookup vault.yourdomain.com
```

---

## 3. GitHub account (for CI/CD) or Azure DevOps account

**Comply:** A Git host and automation for this repo (this project uses **GitHub Actions** for workflows under `.github/workflows/`).

- [X] GitHub (or Azure DevOps) account created.
- [X] Repository contains this project; remote configured (`git remote -v`).
- [X] **Actions** enabled: repo **Settings → Actions → General** (allow Actions).
- [X] For future deploy pipelines: plan **repository secrets** per [plan.md](../plan.md) Step 2 and [cicd-pipelines.md](cicd-pipelines.md) (Azure service principal, SSH private key, `DOMAIN`, etc.).

**Verify:**

```bash
git remote -v
# On GitHub: open Actions tab and confirm workflows can run on push/PR
```

---

## 4. Terraform installed locally (>= 1.5.0)

**Comply:** `terraform version` shows **v1.5.0 or newer** (matches `required_version` in `infrastructure/terraform/main.tf`).

- [X] Install from [HashiCorp Terraform install](https://developer.hashicorp.com/terraform/install).

**macOS (Homebrew) example:**

```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
```

**Verify:**

```bash
terraform version
```

---

## 5. Azure CLI installed and configured

**Comply:** `az` works and targets the subscription you use for Terraform.

- [X] Install [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli).

**macOS (Homebrew) example:**

```bash
brew install azure-cli
```

- [X] Sign in: `az login`
- [X] Select subscription: `az account set --subscription "<id-or-name>"`

**Verify:**

```bash
az account show
az group list -o table
```

**Note:** Local `terraform apply` with user credentials uses this login. CI/CD typically uses a **service principal** (secrets in GitHub), not your personal `az login`.

---

## 6. SSH key pair generated

**Comply:** A public key is referenced by `ssh_public_key_path` in `infrastructure/terraform/terraform.tfvars` (copy from [terraform.tfvars.example](../infrastructure/terraform/terraform.tfvars.example)).

- [X] Generate a key (RSA):

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa_vaultwarden -C "vaultwarden-vm"
```

- [X] Copy `terraform.tfvars.example` to `terraform.tfvars` (gitignored) and set:

```hcl
ssh_public_key_path = "~/.ssh/id_rsa_vaultwarden.pub"
```

Use `pathexpand`-friendly paths; Terraform resolves `~` via `pathexpand` in `azure.tf`.

- [ ] **Never** commit private keys or `terraform.tfvars` (see [.gitignore](../.gitignore)).

**Verify:**

```bash
ssh-keygen -lf ~/.ssh/id_rsa_vaultwarden.pub
```

---

## 7. Google Drive account ready for backup storage

**Comply:** A Google account with Drive access for **encrypted** backups via Rclone (see [spec.md](../spec.md) and [plan.md](../plan.md) mapping for 2FA).

- [ ] Google account available; enable **2FA** on the account (recommended for Rclone/Google security).
- [ ] **Rclone** on the VM is configured later: follow **[plan.md](../plan.md) → Common Configuration Steps → Rclone Configuration** before backup automation expects a remote (Automated Deployment Step 3).

**Later on the VM (after deploy):**

```bash
rclone version
rclone config   # create remote, e.g. gdrive
```

---

## Suggested order

1. Azure + GitHub accounts and repo access  
2. Install Terraform and Azure CLI; run `az login`  
3. Generate SSH key; create `terraform.tfvars` with `ssh_public_key_path` and `domain`  
4. Confirm domain/DNS control; create A record **after** you have the VM public IP  
5. Google account + 2FA; configure Rclone when the deployment guide reaches that step  

---

## Local verification log (optional)

Fill in after you run commands on **your** machine:

| Prerequisite | Command / action | Date / result |
|--------------|------------------|---------------|
| Azure subscription | `az account show` | |
| Domain / DNS | Registrar login; `dig` / `nslookup` | |
| GitHub / Actions | `git remote -v`; Actions tab | |
| Terraform | `terraform version` | |
| Azure CLI | `az account show` | |
| SSH key | `ls ~/.ssh/*.pub`; `terraform.tfvars` path | |
| Google + Rclone | 2FA on; `rclone config` on VM later | |
