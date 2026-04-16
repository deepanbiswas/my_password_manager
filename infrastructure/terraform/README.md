# Terraform layouts (Azure + Hetzner)

This directory holds **two separate Terraform roots** (separate state files). Shared VM bootstrap lives under **`shared/scripts/cloud-init.sh`**.

| Directory | Cloud | When to use |
|-----------|-------|----------------|
| **`azure/`** | Microsoft Azure | Default CI path when repository variable `HOSTING_PROVIDER` is unset or `azure`. |
| **`hetzner/`** | Hetzner Cloud | Set `HOSTING_PROVIDER=hetzner` and configure `HCLOUD_TOKEN` secret. |

## Commands

```bash
# Azure
cd infrastructure/terraform/azure
cp terraform.tfvars.example terraform.tfvars   # then edit
terraform init && terraform plan

# Hetzner (token from environment only — never commit it)
export HCLOUD_TOKEN='…'
cd infrastructure/terraform/hetzner
cp terraform.tfvars.example terraform.tfvars
terraform init && terraform plan
```

## Migrating existing state (Azure)

If your state file still lives in the **parent** folder (`infrastructure/terraform/terraform.tfstate` from the old flat layout), move it into `azure/` before running `terraform plan`:

```bash
mv infrastructure/terraform/terraform.tfstate infrastructure/terraform/azure/terraform.tfstate
# optional: move backups *.tfstate.*
cd infrastructure/terraform/azure && terraform init && terraform plan
```

## TDI verification scripts

From a root directory, or from anywhere with **`TERRAFORM_DIR`** set:

```bash
export TERRAFORM_DIR="$PWD/infrastructure/terraform/azure"
cd "$TERRAFORM_DIR" && ../../../iterations/iteration-1-infrastructure/verify.sh
```

See [docs/hetzner-automated-deployment.md](../../docs/hetzner-automated-deployment.md) for prerequisites and TDI iterations 1–7 on Hetzner.

<!-- noop: touches infrastructure/** to trigger Deploy workflow on push -->
