# Terraform Infrastructure as Code Guide

## Overview

Terraform enables automated infrastructure provisioning for the password manager setup. This guide provides complete Terraform configurations for deploying the infrastructure on Azure.

## Terraform Configuration Structure

```
infrastructure/
├── terraform/
│   ├── main.tf                 # Provider configuration & backend only
│   ├── azure.tf                # Azure-specific resources (vendor-specific)
│   ├── variables.tf            # Input variables
│   ├── outputs.tf              # Output values
│   └── scripts/
│       └── cloud-init.sh       # Cloud-init script for VM bootstrap
├── templates/                  # Deployment templates (shared by CI/CD and manual deployment)
│   ├── docker-compose.yml.template
│   ├── Caddyfile.template
│   ├── backup.sh.template
│   ├── health-check.sh.template
│   └── .env.template
├── terraform.tfvars            # Variable values (create from example)
├── terraform.tfvars.example    # Example variable values
└── terraform.tfstate           # State file (gitignored, auto-generated)
```

## Terraform Configuration Requirements

### Main Configuration (`infrastructure/terraform/main.tf`)

**Purpose**: Provider configuration and backend setup only

**Location**: `infrastructure/terraform/main.tf`

**Created During**: Step 1: Terraform Setup (see [plan.md](plan.md))

**Requirements**:
- **Terraform Version**: Require version >= 1.5.0
- **Required Providers**: 
  - `azurerm` provider (source: `hashicorp/azurerm`, version: `~> 3.0`)
- **Backend Configuration** (Optional): Azure Storage backend for remote state
  - Resource group: `terraform-state-rg`
  - Storage account: `tfstate<unique-id>`
  - Container: `tfstate`
  - Key: `password-manager.terraform.tfstate`
- **Provider Configuration**: Azure provider with default features

**Note**: This file contains only provider and backend configuration. All Azure-specific resources are in `azure.tf`.

### Azure Resources (`infrastructure/terraform/azure.tf`)

**Purpose**: All Azure-specific infrastructure resources

**Location**: `infrastructure/terraform/azure.tf`

**Created During**: Step 1: Terraform Setup (see [plan.md](plan.md))

**Requirements**:

1. **Resource Group**:
   - Name: `rg-password-manager-${var.environment}`
   - Location: From `var.location`
   - Tags: Project=password-manager, Environment=${var.environment}, Component=infrastructure, ManagedBy=terraform, CostCenter=personal

2. **Virtual Network**:
   - Name: `vnet-password-manager`
   - Address space: `10.0.0.0/16`
   - Tags: Same as resource group

3. **Subnet**:
   - Name: `subnet-password-manager`
   - Address prefixes: `10.0.1.0/24`

4. **Network Security Group**:
   - Name: `nsg-password-manager`
   - Security rules:
     - Allow HTTP (port 80, priority 1000)
     - Allow HTTPS (port 443, priority 1001)
     - Deny all other inbound (priority 4000)
   - Tags: Same as resource group

5. **Public IP Address**:
   - Name: `pip-password-manager`
   - Allocation: Static
   - SKU: Basic
   - Tags: Same as resource group

6. **Network Interface**:
   - Name: `nic-password-manager`
   - IP configuration: Dynamic private IP, associated with public IP
   - Tags: Same as resource group

7. **NSG Association**: Associate NSG with network interface

8. **Virtual Machine**:
   - Name: `vm-password-manager`
   - Size: From `var.vm_size`
   - Admin username: From `var.admin_username`
   - SSH key: From `var.ssh_public_key_path`
   - OS disk: Premium_LRS, 64 GB, ReadWrite caching
   - Source image: Ubuntu 22.04 LTS (Canonical, `0001-com-ubuntu-server-jammy`, `22_04-lts-gen2`)
   - Custom data: Base64-encoded cloud-init script (see Cloud-Init Script requirements)
   - Tags: Merge resource group tags with Component=vaultwarden, Backup=enabled

**Note**: The `custom_data` field references the cloud-init script. Ensure `scripts/cloud-init.sh` exists before running `terraform plan`. Separating vendor-specific resources makes it easier to add support for other cloud providers (AWS, GCP) in the future.

### Outputs File (`infrastructure/terraform/outputs.tf`)

**Purpose**: Output values for deployment automation

**Location**: `infrastructure/terraform/outputs.tf`

**Created During**: Step 1: Terraform Setup (see [plan.md](plan.md))

**Requirements**:
- **vm_public_ip**: Output the public IP address of the VM
- **vm_ssh_command**: Output SSH command to connect to the VM (format: `ssh ${var.admin_username}@${public_ip}`)

### Variables File (`infrastructure/terraform/variables.tf`)

**Purpose**: Input variables for Terraform configuration

**Location**: `infrastructure/terraform/variables.tf`

**Created During**: Step 1: Terraform Setup (see [plan.md](plan.md))

**Requirements**:
- **location** (string, default: "Central India"): Azure region for resources
- **environment** (string, default: "production"): Environment name (production, staging, development)
- **vm_size** (string, default: "Standard_B2s"): VM size SKU
- **admin_username** (string, default: "azureuser"): Admin username for VM
- **ssh_public_key_path** (string, default: "~/.ssh/id_rsa.pub"): Path to SSH public key file
- **domain** (string, required): Domain name for Vaultwarden

**Note**: These Terraform files are created during execution based on these requirements, not stored in documentation.

## Cloud-Init Script

### Purpose

The `cloud-init.sh` script is a bootstrap automation script that runs automatically on the first boot of a newly provisioned Azure VM. It eliminates the need for manual SSH access and setup by automatically installing all required dependencies (Docker, Docker Compose, Rclone, GPG, SQLite), creating directory structures, and configuring the firewall. This enables true zero-touch infrastructure provisioning when combined with Terraform and CI/CD pipelines.

### Cloud-Init Script (`infrastructure/terraform/scripts/cloud-init.sh`)

**Purpose**: Bootstrap automation script that runs automatically on first boot of newly provisioned Azure VM

**Location**: `infrastructure/terraform/scripts/cloud-init.sh`

**Created During**: Step 1: Terraform Setup (see [plan.md](plan.md))

**Requirements**:

The script must perform the following operations in order:

1. **System Updates**: Update package lists and upgrade system packages (`apt-get update && apt-get upgrade -y`)

2. **Install Docker**: 
   - Download and run official Docker installation script
   - Add admin user to docker group

3. **Install Docker Compose**: 
   - Download latest Docker Compose binary from GitHub releases
   - Install to `/usr/local/bin/docker-compose`
   - Make executable

4. **Install Rclone**: 
   - Download and run official Rclone installation script

5. **Install GPG and SQLite CLI**: 
   - Install `gnupg2` and `sqlite3` packages

6. **Create Directory Structure**: 
   - Create `/opt/vaultwarden/` with subdirectories: `caddy/{data,config}`, `vaultwarden/data`, `scripts`, `backups`
   - Set ownership to admin user for `/opt/vaultwarden/`

7. **Set Vaultwarden Data Permissions**: 
   - Set ownership to `1000:1000` for `/opt/vaultwarden/vaultwarden/data` (for non-root container execution)

8. **Configure Firewall (UFW)**:
   - Default deny incoming traffic
   - Default allow outgoing traffic
   - Allow port 80/tcp (HTTP for Let's Encrypt)
   - Allow port 443/tcp (HTTPS)
   - Enable UFW

9. **Log Completion**: 
   - Log completion timestamp to `/var/log/cloud-init.log`

**Template Variables**:
- `${admin_username}`: Admin username passed from Terraform variable

**Note**: This script is created during execution based on these requirements, not stored in documentation. The script is base64-encoded and passed to the VM via Terraform's `custom_data` field.

## Step-by-Step Implementation

### 1. Prerequisites

- Azure account with subscription
- Terraform installed (>= 1.5.0)
- Azure CLI configured
- SSH key pair generated

### 2. Initialize Terraform

**Instructions**: Navigate to Terraform directory and run `terraform init` to initialize the backend and download providers.

### 3. Create terraform.tfvars

**Instructions**: Create `terraform.tfvars` file with your configuration values:
- `location`: Azure region (e.g., "Central India")
- `environment`: Environment name (e.g., "production")
- `vm_size`: VM SKU (e.g., "Standard_B2s")
- `admin_username`: VM admin username (e.g., "azureuser")
- `ssh_public_key_path`: Path to SSH public key (e.g., "~/.ssh/id_rsa.pub")
- `domain`: Domain name for Vaultwarden (e.g., "https://your-domain.com")

**Note**: `terraform.tfvars` should not be committed to Git (add to `.gitignore`).

### 4. Plan Infrastructure

**Instructions**: Run `terraform plan -out=tfplan` to review infrastructure changes before applying.

### 5. Apply Infrastructure

**Instructions**: Run `terraform apply tfplan` to provision infrastructure. Type `yes` when prompted.

### 6. Get Outputs

**Instructions**: Use `terraform output` commands to get VM public IP and SSH command:
- `terraform output vm_public_ip`: Get VM public IP address
- `terraform output vm_ssh_command`: Get SSH command to connect to VM

## Variable Explanations

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `location` | Azure region | "Central India" | No |
| `environment` | Environment name | "production" | No |
| `vm_size` | VM SKU | "Standard_B2s" | No |
| `admin_username` | VM admin user | "azureuser" | No |
| `ssh_public_key_path` | SSH public key path | "~/.ssh/id_rsa.pub" | No |
| `domain` | Domain name | - | Yes |

## Remote State Backend

### Setup Azure Storage for State

**Instructions**:

1. **Create Storage Account**: Use Azure CLI to create storage account for Terraform state:
   - Name: `tfstate<unique-id>` (use unique identifier)
   - Resource group: `terraform-state-rg`
   - Location: Azure region (e.g., "Central India")
   - SKU: Standard_LRS

2. **Create Container**: Create blob container named `tfstate` in the storage account

3. **Update Backend Configuration**: Update `backend "azurerm"` block in `main.tf` with storage account details

## Best Practices

1. **Use Remote State**: Store state in Azure Storage for team collaboration
2. **Version Control**: Keep Terraform code in Git
3. **Tag Resources**: All resources should be tagged for cost tracking
4. **Review Plans**: Always review `terraform plan` before applying
5. **Backup State**: Regularly backup Terraform state files

## Troubleshooting

### Common Issues

**Issue: Authentication failed**
- Verify Azure CLI is logged in: `az account show`
- Check service principal permissions

**Issue: Resource already exists**
- Import existing resource: `terraform import <resource> <id>`
- Or destroy and recreate

**Issue: Cloud-init not running**
- Check VM boot diagnostics in Azure Portal
- Verify custom_data is base64 encoded correctly

## Summary

Terraform enables automated, repeatable infrastructure deployment. The cloud-init script ensures the VM is pre-configured on first boot, eliminating manual setup steps. Combined with CI/CD pipelines, this provides true zero-touch deployment.
