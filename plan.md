# Implementation & Operations Guide

Step-by-step execution guide for deploying, operating, and maintaining the self-hosted password manager. For requirements and specifications, refer to [spec.md](spec.md).

## Table of Contents

1. [Requirements to Execution Mapping](#requirements-to-execution-mapping)
2. [Deployment Methods](#deployment-methods)
3. [Automated Deployment (Recommended)](#automated-deployment-recommended)
   - [Prerequisites](#prerequisites)
   - [Step 1: Terraform Setup](#step-1-terraform-setup)
   - [Step 2: CI/CD Pipeline Setup](#step-2-cicd-pipeline-setup)
   - [Step 3: Post-Infrastructure Configuration](#step-3-post-infrastructure-configuration)
   - [Step 4: Verification & Cost Monitoring](#step-4-verification--cost-monitoring)
   - [Step 5: Ongoing Operations](#step-5-ongoing-operations)
4. [Manual Deployment (Alternative)](#manual-deployment-alternative)
   - [Pre-Deployment Checklist](#pre-deployment-checklist)
   - [Step 1: Initial Server Setup](#step-1-initial-server-setup)
   - [Step 2: Configuration](#step-2-configuration)
   - [Step 3: Rclone Configuration](#step-3-rclone-configuration)
   - [Step 4: DNS Configuration](#step-4-dns-configuration)
   - [Step 5: Deploy Services](#step-5-deploy-services)
   - [Step 6: Post-Deployment Verification](#step-6-post-deployment-verification)
   - [Step 7: Backup Automation](#step-7-backup-automation)
   - [Step 8: Health Monitoring (Optional)](#step-8-health-monitoring-optional)
   - [Step 9: Resource Tagging & Cost Monitoring](#step-9-resource-tagging--cost-monitoring)
5. [Disaster Recovery](#disaster-recovery)
6. [Vaultwarden Update Procedure](#vaultwarden-update-procedure)
7. [Rollback Procedures](#rollback-procedures)
8. [Troubleshooting](#troubleshooting)
9. [Next Steps after Successful Deployment](#next-steps-after-successful-deployment)
10. [Quick Reference: Automated vs Manual](#quick-reference-automated-vs-manual)
11. [Templates Reference](#templates-reference)
    - [Docker Compose Template](#docker-compose-template-docker-composeymltemplate)
    - [Caddyfile Template](#caddyfile-template-caddyfiletemplate)
    - [Backup Script Template](#backup-script-template-backupshtemplate)
    - [Restore Script](#restore-script-restoresh)
    - [Health Check Script Template](#health-check-script-template-health-checkshtemplate)
    - [Environment Variables Template](#environment-variables-template-envtemplate)
    - [Resource Tagging Script](#resource-tagging-script-tag-resourcessh)
12. [Common Configuration Steps](#common-configuration-steps)

---

## Requirements to Execution Mapping

This section maps requirements from [spec.md](spec.md) to execution steps in this guide. Use this table to find where each requirement is implemented.

| spec.md Requirement | plan.md Execution Location | Notes |
|---------------------|---------------------------|-------|
| **Section 3.1: Infrastructure Requirements** |
| 2 vCPU, 4GB RAM, Ubuntu 22.04 | **Automated**: [Step 1: Terraform Setup](#step-1-terraform-setup) - `terraform.tfvars`<br>**Manual**: [Pre-Deployment Checklist](#pre-deployment-checklist) | VM specifications configured in Terraform or pre-provisioned |
| Ports 80/443 only | **Automated**: [Step 1: Terraform Setup](#step-1-terraform-setup) (cloud-init.sh via Terraform)<br>**Manual**: [Step 1: Initial Server Setup](#step-1-initial-server-setup) (setup.sh) | Firewall configured automatically |
| SQLite accessible for backup | **Automated**: [Step 1: Terraform Setup](#step-1-terraform-setup) (cloud-init.sh installs sqlite3)<br>**Manual**: [Step 1: Initial Server Setup](#step-1-initial-server-setup) (setup.sh installs sqlite3) | sqlite3 CLI installed on host |
| **Section 3.2: Directory Structure Requirements** |
| `/opt/vaultwarden/` structure | **Automated**: [Step 1: Terraform Setup](#step-1-terraform-setup) (cloud-init.sh creates structure)<br>**Manual**: [Step 1: Initial Server Setup](#step-1-initial-server-setup) (setup.sh creates structure) | Directory structure created |
| `.env` file 600 permissions | **Automated**: [Step 3: Post-Infrastructure Configuration](#step-3-post-infrastructure-configuration) (CI/CD sets permissions)<br>**Manual**: [Step 2: Configuration](#step-2-configuration) | Permissions set in both methods |
| **Section 3.3: Service Requirements** |
| Vaultwarden with version pinning | **Automated**: [Step 1: Terraform Setup](#step-1-terraform-setup) (docker-compose.yml.template)<br>**Manual**: [Step 5: Deploy Services](#step-5-deploy-services) (docker-compose.yml) | Configured in docker-compose.yml |
| Caddy with SSL automation | **Automated**: [Step 1: Terraform Setup](#step-1-terraform-setup) (Caddyfile.template)<br>**Manual**: [Step 5: Deploy Services](#step-5-deploy-services) (Caddyfile) | Configured in Caddyfile |
| Watchtower (Caddy only) | **Automated**: [Step 1: Terraform Setup](#step-1-terraform-setup) (docker-compose.yml.template)<br>**Manual**: [Step 5: Deploy Services](#step-5-deploy-services) (docker-compose.yml) | Watchtower configured with Vaultwarden exclusion |
| Environment variables | **Automated**: [Step 3: Post-Infrastructure Configuration](#step-3-post-infrastructure-configuration) (CI/CD generates .env)<br>**Manual**: [Step 2: Configuration](#step-2-configuration) | Environment variables configured |
| **Section 3.4: Security Requirements** |
| Firewall (UFW) | **Automated**: [Step 1: Terraform Setup](#step-1-terraform-setup) (cloud-init.sh)<br>**Manual**: [Step 1: Initial Server Setup](#step-1-initial-server-setup) (setup.sh) | Network security |
| SSL/TLS automatic | **Automated**: [Step 1: Terraform Setup](#step-1-terraform-setup) (Caddyfile.template)<br>**Manual**: [Step 5: Deploy Services](#step-5-deploy-services) (Caddyfile) | Let's Encrypt |
| Security headers | **Automated**: [Step 1: Terraform Setup](#step-1-terraform-setup) (Caddyfile.template)<br>**Manual**: [Step 5: Deploy Services](#step-5-deploy-services) (Caddyfile) | HTTP headers |
| **Section 3.5: Deployment Method Requirements** |
| Terraform IaC | **Automated**: [Step 1: Terraform Setup](#step-1-terraform-setup) | Infrastructure provisioning |
| CI/CD pipeline | **Automated**: [Step 2: CI/CD Pipeline Setup](#step-2-cicd-pipeline-setup) | Application deployment |
| Manual deployment | **Manual**: [Steps 1-9](#manual-deployment-alternative) | Alternative method |
| **Section 3.6: Resource Management Requirements** |
| Resource tagging | **Automated**: [Step 1: Terraform Setup](#step-1-terraform-setup) (Terraform tags resources)<br>**Manual**: [Step 9: Resource Tagging & Cost Monitoring](#step-9-resource-tagging--cost-monitoring) | Cost tracking |
| Cost monitoring | **Automated**: [Step 4: Verification & Cost Monitoring](#step-4-verification--cost-monitoring)<br>**Manual**: [Step 9: Resource Tagging & Cost Monitoring](#step-9-resource-tagging--cost-monitoring) | Budget alerts |
| **Section 3.7: Post-Deployment Requirements** |
| Admin account creation | **Both**: [Post-Deployment Verification](#post-deployment-verification) (Common Configuration Steps) | Initial setup |
| Backup automation | **Automated**: [Step 3: Post-Infrastructure Configuration](#step-3-post-infrastructure-configuration) (CI/CD deploys backup.sh)<br>**Manual**: [Step 7: Backup Automation](#step-7-backup-automation) | Crontab configuration |
| Health monitoring | **Automated**: [Step 3: Post-Infrastructure Configuration](#step-3-post-infrastructure-configuration) (CI/CD deploys health-check.sh)<br>**Manual**: [Step 8: Health Monitoring](#step-8-health-monitoring-optional) | Health check script |
| **Section 4: Security Specification** |
| Firewall configuration | **Automated**: [Step 1: Terraform Setup](#step-1-terraform-setup)<br>**Manual**: [Step 1: Initial Server Setup](#step-1-initial-server-setup) | UFW setup |
| SSL/TLS configuration | **Automated**: [Step 1: Terraform Setup](#step-1-terraform-setup)<br>**Manual**: [Step 5: Deploy Services](#step-5-deploy-services) | Caddy configuration |
| Signup restrictions | **Automated**: [Step 1: Terraform Setup](#step-1-terraform-setup) (docker-compose.yml.template)<br>**Manual**: [Step 5: Deploy Services](#step-5-deploy-services) (docker-compose.yml) | SIGNUPS_ALLOWED=false |
| **Section 5: Data Protection (Backup & Disaster Recovery)** |
| Backup process | **Automated**: [Step 3: Post-Infrastructure Configuration](#step-3-post-infrastructure-configuration) (backup.sh.template deployed)<br>**Manual**: [Step 7: Backup Automation](#step-7-backup-automation) (backup.sh) | Backup script implements requirements |
| Backup encryption | **Automated**: [Step 3: Post-Infrastructure Configuration](#step-3-post-infrastructure-configuration) (backup.sh.template)<br>**Manual**: [Step 7: Backup Automation](#step-7-backup-automation) (backup.sh) | GPG encryption |
| Disaster recovery | **Both**: [Disaster Recovery](#disaster-recovery) section | restore.sh script |
| Backup verification | **Both**: [Disaster Recovery → Backup Verification](#backup-verification) | Verification procedure |
| **Section 6: Maintenance & Automation Strategy** |
| Watchtower configuration | **Automated**: [Step 1: Terraform Setup](#step-1-terraform-setup) (docker-compose.yml.template)<br>**Manual**: [Step 5: Deploy Services](#step-5-deploy-services) (docker-compose.yml) | Container updates |
| Vaultwarden updates | **Both**: [Vaultwarden Update Procedure](#vaultwarden-update-procedure) | Manual update process |
| Health checks | **Automated**: [Step 3: Post-Infrastructure Configuration](#step-3-post-infrastructure-configuration) (health-check.sh.template deployed)<br>**Manual**: [Step 8: Health Monitoring](#step-8-health-monitoring-optional) | health-check.sh script |

---

## Deployment Methods

This checklist supports two deployment approaches:

1. **Automated Deployment (Recommended)**: Using Infrastructure as Code (Terraform) and CI/CD pipelines
2. **Manual Deployment**: Step-by-step manual setup on a pre-provisioned VM

**Note**: Both deployment methods share some common configuration steps. When you encounter a step that references "Common Configuration Steps", see the [Common Configuration Steps](#common-configuration-steps) section at the end of this document.

---

## Automated Deployment (Recommended)

### Prerequisites

**Estimated Time**: 30-60 minutes (one-time setup)

- [ ] Azure account with subscription and ₹4,500/month credits
- [ ] Domain name registered and DNS access available
- [ ] GitHub account (for CI/CD) or Azure DevOps account
- [ ] Terraform installed locally (>= 1.5.0)
- [ ] Azure CLI installed and configured
- [ ] SSH key pair generated
- [ ] Google Drive account ready for backup storage

**Total Estimated Time for Automated Deployment**: 2-3 hours (including DNS propagation and verification)

### Step 1: Terraform Setup

**Estimated Time**: 30-45 minutes

**Create Directory Structure:**
- [ ] Create base directories: `mkdir -p infrastructure/terraform/{scripts,templates}`
- [ ] Verify directory structure:
  ```
  infrastructure/
  └── terraform/
      ├── scripts/
      │   └── cloud-init.sh
      ├── templates/
      │   ├── docker-compose.yml.template
      │   ├── Caddyfile.template
      │   ├── backup.sh.template
      │   ├── health-check.sh.template
      │   └── .env.template
      └── (Terraform files will be created here)
  ```

**Create Terraform Configuration Files:**
- [ ] Create `infrastructure/terraform/main.tf` - Copy provider and backend configuration from [Terraform Guide - Main Configuration](docs/terraform-guide.md#main-configuration-infrastructureterraformmaintf)
- [ ] Create `infrastructure/terraform/azure.tf` - Copy Azure-specific resources from [Terraform Guide - Azure Resources](docs/terraform-guide.md#azure-resources-infrastructureterraformazuretf)
  - **Note**: This file contains all Azure vendor-specific resources (resource group, network, VM, etc.)
  - Separating vendor-specific code makes it easier to add support for other cloud providers (AWS, GCP) in the future
- [ ] Create `infrastructure/terraform/variables.tf` - Copy from [Terraform Guide - Variables File](docs/terraform-guide.md#variables-file-infrastructureterraformvariablestf)
- [ ] Create `infrastructure/terraform/outputs.tf` - Copy from [Terraform Guide - Outputs File](docs/terraform-guide.md#outputs-file-infrastructureterraformoutputstf)

**Create Cloud-Init Script:**
- [ ] Create `infrastructure/terraform/scripts/cloud-init.sh` - Copy complete script from [Terraform Guide - Cloud-Init Script](docs/terraform-guide.md#cloud-init-script-infrastructureterraformscriptscloud-initsh)
- [ ] Make script executable: `chmod +x infrastructure/terraform/scripts/cloud-init.sh`
- [ ] **Important**: The `azure.tf` file references this script via `templatefile("${path.module}/scripts/cloud-init.sh", {...})`, so it must exist before running `terraform plan`

**Create Deployment Templates:**
- [ ] Create templates directory: `mkdir -p infrastructure/templates`
- [ ] Create `infrastructure/templates/docker-compose.yml.template` - Copy from [Templates Reference - Docker Compose Template](#docker-compose-template-docker-composeymltemplate)
- [ ] Create `infrastructure/templates/Caddyfile.template` - Copy from [Templates Reference - Caddyfile Template](#caddyfile-template-caddyfiletemplate)
- [ ] Create `infrastructure/templates/backup.sh.template` - Copy from [Templates Reference - Backup Script Template](#backup-script-template-backupshtemplate)
- [ ] Create `infrastructure/templates/health-check.sh.template` - Copy from [Templates Reference - Health Check Script Template](#health-check-script-template-health-checkshtemplate)
- [ ] Create `infrastructure/templates/.env.template` - Copy from [Templates Reference - Environment Variables Template](#environment-variables-template-envtemplate)
- [ ] **Note**: The `tag-resources.sh.template` file will be created in `infrastructure/templates/` when the plan is executed. The script content is available in [Resource Tagging Script](#resource-tagging-script-tag-resourcessh) in Templates Reference section.
- [ ] **Note**: These templates will be used by both CI/CD pipeline and manual deployment to generate deployment files with environment-specific values. See [Templates Reference](#templates-reference) section for complete template content.

**Create Variable Values File:**
- [ ] Create `infrastructure/terraform/terraform.tfvars` with your configuration:
  ```hcl
  location         = "Central India"
  environment      = "production"
  vm_size          = "Standard_B2s"
  admin_username   = "azureuser"
  domain           = "https://your-domain.com"
  ssh_public_key_path = "~/.ssh/id_rsa.pub"
  ```
- [ ] **Note**: `terraform.tfvars` is not committed to Git (should be in `.gitignore`)

**Configure Azure Provider:**
- [ ] Install Azure CLI: `az --version` (if not installed)
- [ ] Login to Azure: `az login`
- [ ] Set subscription: `az account set --subscription <subscription-id>`
- [ ] Verify credentials: `az account show`

**Initialize and Deploy:**
- [ ] Navigate to Terraform directory: `cd infrastructure/terraform`
- [ ] Initialize Terraform: `terraform init`
- [ ] Review infrastructure plan: `terraform plan`
- [ ] Apply infrastructure: `terraform apply` (type `yes` when prompted)
- [ ] Save outputs: Note the `vm_public_ip` output for DNS configuration

### Step 2: CI/CD Pipeline Setup

**Estimated Time**: 15-20 minutes

- [ ] Choose CI/CD platform (GitHub Actions recommended)
- [ ] Copy pipeline configuration from [CI/CD Pipelines Guide](docs/cicd-pipelines.md)
- [ ] Configure GitHub Secrets (or Azure DevOps variables):
  - [ ] `AZURE_SUBSCRIPTION_ID`
  - [ ] `AZURE_CLIENT_ID`
  - [ ] `AZURE_CLIENT_SECRET`
  - [ ] `AZURE_TENANT_ID`
  - [ ] `AZURE_CREDENTIALS`
  - [ ] `DOMAIN`
  - [ ] `SSH_PRIVATE_KEY`
  - [ ] `VM_USERNAME`
- [ ] Push code to trigger pipeline
- [ ] Monitor pipeline execution

### Step 3: Post-Infrastructure Configuration

**Note**: The CI/CD pipeline automatically handles most configuration steps. Manual steps are only required for DNS and Rclone configuration.

**Estimated Time**: 15-20 minutes (DNS propagation: 5-15 minutes, Rclone config: 5 minutes)

- [ ] Get VM public IP from Terraform output: `terraform output vm_public_ip`
- [ ] **Configure DNS**: Follow [DNS Configuration](#dns-configuration) steps in Common Configuration Steps
  - **Important**: DNS must be configured **immediately after Terraform apply** and **before** CI/CD pipeline runs
  - Use the VM IP from step above
- [ ] **Configure Rclone**: Follow [Rclone Configuration](#rclone-configuration) steps in Common Configuration Steps
  - **Important**: Rclone must be configured **before** CI/CD pipeline can deploy backup automation
  - The CI/CD pipeline will fail if Rclone is not configured when it tries to deploy backup scripts
- [ ] Push code to trigger CI/CD pipeline (or wait for automatic trigger)
- [ ] Monitor pipeline execution - it will automatically:
  - Generate `.env` file with secrets (admin token, encryption key)
  - Create `docker-compose.yml` and `caddy/Caddyfile`
  - Deploy backup and health check scripts
  - Set up crontab entries
  - Start all services
- [ ] **If pipeline fails**: See [Rollback Procedures](#rollback-procedures) and [Troubleshooting Guide](docs/troubleshooting.md)

### Step 4: Verification & Cost Monitoring

**Estimated Time**: 20-30 minutes

- [ ] Verify CI/CD pipeline completed successfully (check GitHub Actions)
  - **Troubleshooting**: If pipeline failed, see [Troubleshooting Guide - CI/CD Issues](docs/troubleshooting.md#cicd-issues)
- [ ] **Post-Deployment Verification**: Follow [Post-Deployment Verification](#post-deployment-verification) steps in Common Configuration Steps
- [ ] **Cost Monitoring Setup**: Navigate to Azure Portal → Cost Management + Billing
  - [ ] Create budget alert at ₹4,000 (89% of monthly credits) - early warning
  - [ ] Create critical alert at ₹4,400 (98% of monthly credits) - immediate action needed
  - [ ] Set up email notifications
  - [ ] Configure daily cost reports
  - [ ] Verify tag-based cost tracking (use Azure CLI):
    ```bash
    az consumption usage list \
      --start-date $(date -d "1 month ago" +%Y-%m-%d) \
      --end-date $(date +%Y-%m-%d) \
      --query "[?tags.Project=='password-manager']"
    ```
  - [ ] For detailed cost analysis and optimization strategies, see [Cost Analysis](docs/cost-analysis.md)

### Step 5: Ongoing Operations

**Estimated Time**: Ongoing (monitoring and maintenance)

- [ ] Monitor CI/CD pipeline for automated deployments
- [ ] Infrastructure changes via Terraform (version controlled)
- [ ] Application updates via CI/CD pipeline
- [ ] Review [spec.md](spec.md) Section 6 for maintenance procedures
- [ ] Monitor cost alerts and adjust resources if needed

---

## Manual Deployment (Alternative)

### Pre-Deployment Checklist

**Estimated Total Time**: 2-3 hours

- [ ] Azure VM provisioned (Standard_B2s or higher recommended)
- [ ] Domain name registered and DNS access available
- [ ] SSH key pair generated
- [ ] Google Drive account ready for backup storage
- [ ] Review [spec.md](spec.md) Section 3.1 for infrastructure requirements

### Deployment Steps

### Step 1: Initial Server Setup

**Estimated Time**: 20-30 minutes

**⚠️ Troubleshooting**: If setup script fails, see [Troubleshooting Guide - Initial Setup](docs/troubleshooting.md#initial-setup-issues)

- [ ] SSH into VM: `ssh username@vm-ip-address`
- [ ] Create scripts directory: `mkdir -p /opt/vaultwarden/scripts`
- [ ] Create setup script: Create file `/opt/vaultwarden/scripts/setup.sh` with the following content (you can use `nano`, `vi`, or copy-paste):

```bash
#!/bin/bash
set -e

# Update system
sudo apt-get update && sudo apt-get upgrade -y

# Install Docker
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    rm get-docker.sh
fi

# Install Docker Compose
if ! command -v docker-compose &> /dev/null; then
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
fi

# Install Rclone
if ! command -v rclone &> /dev/null; then
    curl https://rclone.org/install.sh | sudo bash
fi

# Install GPG (if not present)
sudo apt-get install -y gnupg2

# Install sqlite3 for backups
sudo apt-get install -y sqlite3

# Create directory structure
sudo mkdir -p /opt/vaultwarden/{caddy/{data,config},vaultwarden/data,scripts,backups}
sudo chown -R $USER:$USER /opt/vaultwarden

# Generate admin token
ADMIN_TOKEN=$(openssl rand -base64 48)
echo "ADMIN_TOKEN=$ADMIN_TOKEN" > /opt/vaultwarden/.env
echo "DOMAIN=https://your-domain.com" >> /opt/vaultwarden/.env
echo "BACKUP_RETENTION_DAYS=30" >> /opt/vaultwarden/.env

# Configure firewall
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 80/tcp comment 'HTTP for Let's Encrypt'
sudo ufw allow 443/tcp comment 'HTTPS'
sudo ufw --force enable

echo "Setup complete. Please:"
echo "1. Edit /opt/vaultwarden/.env with your domain"
echo "2. Configure Rclone: rclone config"
echo "3. Set up GPG encryption key"
echo "4. Run: cd /opt/vaultwarden && docker-compose up -d"
```

- [ ] Make setup script executable: `chmod +x /opt/vaultwarden/scripts/setup.sh`
- [ ] Navigate to deployment directory: `cd /opt/vaultwarden`
- [ ] Run setup script: `./scripts/setup.sh`
- [ ] Verify Docker installed: `docker --version`
- [ ] Verify Docker Compose installed: `docker-compose --version`
- [ ] Verify Rclone installed: `rclone version`
- [ ] Verify firewall is configured: `sudo ufw status verbose`

### Step 2: Configuration

**Estimated Time**: 10-15 minutes

**⚠️ Prerequisite**: Ensure the repository is cloned on the VM (or templates are available at `infrastructure/templates/`)

- [ ] Navigate to deployment directory: `cd /opt/vaultwarden`
- [ ] Generate secrets:
  ```bash
  ADMIN_TOKEN=$(openssl rand -base64 48)
  BACKUP_ENCRYPTION_KEY=$(openssl rand -base64 32)
  ```
- [ ] Set your domain: `DOMAIN=https://your-domain.com` (replace with your actual domain)
- [ ] Generate `.env` from template:
  ```bash
  sed -e "s|{{ADMIN_TOKEN}}|${ADMIN_TOKEN}|g" \
      -e "s|{{DOMAIN}}|${DOMAIN}|g" \
      -e "s|{{BACKUP_ENCRYPTION_KEY}}|${BACKUP_ENCRYPTION_KEY}|g" \
      infrastructure/templates/.env.template > .env
  chmod 600 .env
  ```
- [ ] Verify `.env` file exists and has correct permissions: `ls -la .env`

### Step 3: Rclone Configuration

**Estimated Time**: 5-10 minutes

- [ ] **Rclone Configuration**: Follow [Rclone Configuration](#rclone-configuration) steps in Common Configuration Steps

### Step 4: DNS Configuration

**Estimated Time**: 5-15 minutes (DNS propagation time varies)

- [ ] Get VM public IP address (from Azure Portal or `az vm list-ip-addresses`)
- [ ] **DNS Configuration**: Follow [DNS Configuration](#dns-configuration) steps in Common Configuration Steps
  - Use the VM IP from step above

### Step 5: Deploy Services

**Estimated Time**: 10-15 minutes

**⚠️ Troubleshooting**: If services fail to start, see [Troubleshooting Guide - Container Issues](docs/troubleshooting.md#container-issues)

**⚠️ Prerequisite**: Ensure the repository is cloned on the VM (or templates are available at `infrastructure/templates/`)

- [ ] Navigate to deployment directory: `cd /opt/vaultwarden`
- [ ] Source environment variables: `source .env` (loads DOMAIN and ADMIN_TOKEN)
- [ ] Generate `docker-compose.yml` from template:
  ```bash
  sed -e "s|{{DOMAIN}}|${DOMAIN}|g" \
      infrastructure/templates/docker-compose.yml.template > docker-compose.yml
  ```
- [ ] Generate `Caddyfile` from template:
  ```bash
  DOMAIN_NAME=$(echo ${DOMAIN} | sed 's|https\?://||')
  mkdir -p caddy
  sed "s|{{DOMAIN_NAME}}|${DOMAIN_NAME}|g" \
      infrastructure/templates/Caddyfile.template > caddy/Caddyfile
  ```
- [ ] Start services: `docker-compose up -d`
- [ ] Verify containers running: `docker-compose ps`

**Note**: For Nginx alternative configuration, see [Reverse Proxy Comparison](docs/reverse-proxy-comparison.md).

### Step 6: Post-Deployment Verification

**Estimated Time**: 15-20 minutes

- [ ] **Post-Deployment Verification**: Follow [Post-Deployment Verification](#post-deployment-verification) steps in Common Configuration Steps

### Step 7: Backup Automation

**Estimated Time**: 10-15 minutes

**⚠️ Prerequisite**: Ensure the repository is cloned on the VM (or templates are available at `infrastructure/templates/`)

- [ ] Create scripts directory: `mkdir -p /opt/vaultwarden/scripts`
- [ ] Copy backup script from template: `cp infrastructure/templates/backup.sh.template /opt/vaultwarden/scripts/backup.sh`
- [ ] Make executable: `chmod +x /opt/vaultwarden/scripts/backup.sh`
- [ ] Test backup manually: `cd /opt/vaultwarden && ./scripts/backup.sh`
- [ ] Verify backup in Google Drive: `rclone ls gdrive:vaultwarden-backups/`
- [ ] Add to crontab: `crontab -e`
  ```bash
  0 2 * * * /opt/vaultwarden/scripts/backup.sh >> /var/log/vaultwarden-backup.log 2>&1
  ```

**Note**: The backup encryption key should already be set in `.env` from Step 2. If you need to set it up separately, see [Backup Encryption Key Setup](#backup-encryption-key-setup) in Common Configuration Steps.

### Step 8: Health Monitoring (Optional)

**Estimated Time**: 5-10 minutes

**⚠️ Prerequisite**: Ensure the repository is cloned on the VM (or templates are available at `infrastructure/templates/`)

- [ ] Navigate to deployment directory: `cd /opt/vaultwarden`
- [ ] Source environment variables: `source .env` (loads DOMAIN)
- [ ] Generate health check script from template:
  ```bash
  sed "s|{{DOMAIN}}|${DOMAIN}|g" \
      infrastructure/templates/health-check.sh.template > scripts/health-check.sh
  chmod +x scripts/health-check.sh
  ```
- [ ] Test health check: `./scripts/health-check.sh`
- [ ] Add to crontab (every 15 minutes):
  ```bash
  */15 * * * * /opt/vaultwarden/scripts/health-check.sh >> /var/log/vaultwarden-health.log 2>&1
  ```

### Step 9: Resource Tagging & Cost Monitoring

**Estimated Time**: 5-10 minutes

**⚠️ Prerequisites**: 
- Azure CLI installed and logged in (`az login`)
- Resource group name where your VM is deployed
- Owner email address for the Owner tag

**⚠️ Note**: This script reuses the same tag structure as Terraform (see [Terraform Guide](docs/terraform-guide.md)) to ensure consistency between automated and manual deployments. The only difference is `ManagedBy=manual` instead of `ManagedBy=terraform`.

**Resource Tagging (Using Script - Recommended):**

- [ ] Navigate to deployment directory: `cd /opt/vaultwarden`
- [ ] Create scripts directory (if not exists): `mkdir -p scripts`
- [ ] Create tagging script: Create file `scripts/tag-resources.sh` with the content from [Resource Tagging Script](#resource-tagging-script-tag-resourcessh) in Templates Reference section (you can use `nano`, `vi`, or copy-paste)
- [ ] Make executable: `chmod +x scripts/tag-resources.sh`
- [ ] Run the tagging script:
  ```bash
  ./scripts/tag-resources.sh <resource-group-name> <your-email>
  ```
  Example:
  ```bash
  ./scripts/tag-resources.sh rg-password-manager-production user@example.com
  ```
- [ ] Verify tags were applied successfully (script will show summary)
- [ ] (Optional) Verify tags in Azure Portal or using Azure CLI:
  ```bash
  az vm show --resource-group <resource-group-name> --name <vm-name> --query "tags" -o table
  ```

**Resource Tagging (Azure CLI - Fallback):**

If the script is not available, you can tag resources manually using Azure CLI commands. However, the script is recommended as it ensures consistency with Terraform's tag structure.

```bash
# Tag VM (with VM-specific tags)
az vm update --resource-group <resource-group-name> --name <vm-name> \
  --set tags.Project=password-manager \
       tags.Environment=production \
       tags.Component=vaultwarden \
       tags.ManagedBy=manual \
       tags.CostCenter=personal \
       tags.Backup=enabled \
       tags.Owner=<your-email>

# Tag other resources (with base tags)
az disk update --resource-group <resource-group-name> --name <disk-name> \
  --set tags.Project=password-manager tags.Environment=production tags.Component=infrastructure tags.ManagedBy=manual tags.CostCenter=personal

az network nic update --resource-group <resource-group-name> --name <nic-name> \
  --set tags.Project=password-manager tags.Environment=production tags.Component=infrastructure tags.ManagedBy=manual tags.CostCenter=personal

az network public-ip update --resource-group <resource-group-name> --name <ip-name> \
  --set tags.Project=password-manager tags.Environment=production tags.Component=infrastructure tags.ManagedBy=manual tags.CostCenter=personal

az network nsg update --resource-group <resource-group-name> --name <nsg-name> \
  --set tags.Project=password-manager tags.Environment=production tags.Component=infrastructure tags.ManagedBy=manual tags.CostCenter=personal

az network vnet update --resource-group <resource-group-name> --name <vnet-name> \
  --set tags.Project=password-manager tags.Environment=production tags.Component=infrastructure tags.ManagedBy=manual tags.CostCenter=personal

az group update --name <resource-group-name> \
  --set tags.Project=password-manager tags.Environment=production tags.Component=infrastructure tags.ManagedBy=manual tags.CostCenter=personal
```

**Cost Monitoring Setup:**
- [ ] Navigate to Azure Portal → Cost Management + Billing
- [ ] Create budget alert at ₹4,000 (89% of monthly credits) - early warning
- [ ] Create critical alert at ₹4,400 (98% of monthly credits) - immediate action needed
- [ ] Set up email notifications
- [ ] Configure daily cost reports
- [ ] Verify tag-based cost tracking (use Azure CLI):
  ```bash
  az consumption usage list \
    --start-date $(date -d "1 month ago" +%Y-%m-%d) \
    --end-date $(date +%Y-%m-%d) \
    --query "[?tags.Project=='password-manager']"
  ```
- [ ] For detailed cost analysis and optimization strategies, see [Cost Analysis](docs/cost-analysis.md)

## Disaster Recovery

### Restore Procedure

**Step 1: Prepare New Environment**

- [ ] On new VM, create setup script: Create file `/opt/vaultwarden/scripts/setup.sh` (see Setup Script in Section 1 above)
- [ ] Make executable: `chmod +x /opt/vaultwarden/scripts/setup.sh`
- [ ] Run setup script: `cd /opt/vaultwarden && ./scripts/setup.sh`
- [ ] Configure Rclone: `rclone config`
- [ ] Set encryption key in `.env`: `echo "BACKUP_ENCRYPTION_KEY=<your-key>" >> /opt/vaultwarden/.env`

**Step 2: Create Restore Script**

- [ ] Create scripts directory (if not exists): `mkdir -p /opt/vaultwarden/scripts`
- [ ] Create restore script: Create file `/opt/vaultwarden/scripts/restore.sh` with the content from [Restore Script](#restore-script-restoresh) in Templates Reference section (you can use `nano`, `vi`, or copy-paste)
- [ ] Make executable: `chmod +x /opt/vaultwarden/scripts/restore.sh`

**Step 3: List Available Backups**

- [ ] Navigate to deployment directory: `cd /opt/vaultwarden`
- [ ] Run restore script without arguments to list backups: `./scripts/restore.sh`
- [ ] Note the backup filename you want to restore

**Step 4: Execute Restore**

- [ ] Navigate to deployment directory: `cd /opt/vaultwarden`
- [ ] Execute restore: `./scripts/restore.sh vaultwarden_backup_YYYYMMDD_HHMMSS.tar.gz.gpg`

**Step 5: Verify Restore**

- [ ] Access `https://your-domain.com`
- [ ] Verify user accounts are present
- [ ] Verify password entries are accessible
- [ ] Check attachment storage

### Backup Verification

**Monthly Verification Procedure:**

- [ ] Download latest backup from Google Drive: `rclone copy gdrive:vaultwarden-backups/latest-backup.tar.gz.gpg ./`
- [ ] Decrypt backup: `gpg --decrypt latest-backup.tar.gz.gpg > latest-backup.tar.gz`
- [ ] Extract backup: `tar -xzf latest-backup.tar.gz`
- [ ] Verify database integrity: `sqlite3 db.sqlite3 "PRAGMA integrity_check;"`
- [ ] Verify attachment files are present: `ls -la attachments/`
- [ ] (Optional) Test restore on isolated test environment

---

## Vaultwarden Update Procedure

Vaultwarden uses **version pinning** instead of automatic updates via Watchtower. This provides better control over when updates are applied, allowing you to review release notes and test updates before deploying to production.

### Update Strategy

- **Current Configuration**: Vaultwarden image is pinned to a specific version (e.g., `vaultwarden/server:1.30.0`)
- **Watchtower**: Disabled for Vaultwarden (only updates Caddy and Watchtower itself)
- **Update Frequency**: Manual updates when stable releases or security patches are available
- **Update Source**: Monitor [Vaultwarden GitHub Releases](https://github.com/dani-garcia/vaultwarden/releases)

### Step-by-Step Update Process

**Step 1: Check for Updates**
- [ ] Visit [Vaultwarden Releases](https://github.com/dani-garcia/vaultwarden/releases)
- [ ] Review latest stable release notes
- [ ] Check for security advisories or critical patches
- [ ] Note the latest stable version number (e.g., `1.31.0`)

**Step 2: Review Release Notes**
- [ ] Read changelog for breaking changes
- [ ] Check for database migration requirements
- [ ] Review security fixes and improvements
- [ ] Verify compatibility with your deployment

**Step 3: Create Backup (Critical)**
- [ ] Navigate to deployment directory: `cd /opt/vaultwarden`
- [ ] Run backup script: `./scripts/backup.sh`
- [ ] Verify backup uploaded to Google Drive: `rclone ls gdrive:vaultwarden-backups/ | tail -1`
- [ ] **Important**: Always backup before updating

**Step 4: Update docker-compose.yml**
- [ ] Edit `docker-compose.yml`: `nano docker-compose.yml` or `vi docker-compose.yml`
- [ ] Update Vaultwarden image version:
  ```yaml
  vaultwarden:
    image: vaultwarden/server:1.31.0  # Update to new version
  ```
- [ ] Save and exit editor

**Step 5: Pull and Deploy Update**
- [ ] Pull new image: `docker-compose pull vaultwarden`
- [ ] Stop Vaultwarden container: `docker-compose stop vaultwarden`
- [ ] Start with new image: `docker-compose up -d vaultwarden`
- [ ] Verify container started: `docker-compose ps`

**Step 6: Verify Update**
- [ ] Check container logs: `docker-compose logs -f vaultwarden` (watch for errors)
- [ ] Wait 30 seconds for service to start
- [ ] Test web interface: `curl -I https://your-domain.com`
- [ ] Verify admin panel: `https://your-domain.com/admin`
- [ ] Test login from Bitwarden client
- [ ] Verify WebSocket connection (real-time sync)

**Step 7: Monitor Post-Update**
- [ ] Monitor logs for 15 minutes: `docker-compose logs -f vaultwarden`
- [ ] Check for error messages or warnings
- [ ] Verify all features working (login, sync, attachments)
- [ ] Monitor for 24 hours for any issues

**Step 8: Rollback (If Needed)**
If issues occur, rollback immediately:
- [ ] Stop current container: `docker-compose stop vaultwarden`
- [ ] Revert `docker-compose.yml` to previous version
- [ ] Pull previous image: `docker-compose pull vaultwarden`
- [ ] Start previous version: `docker-compose up -d vaultwarden`
- [ ] Verify service restored: `curl https://your-domain.com`

### Update Notification Setup (Optional)

**GitHub Release Notifications:**
- [ ] Subscribe to [Vaultwarden Releases RSS](https://github.com/dani-garcia/vaultwarden/releases.atom)
- [ ] Or enable GitHub release notifications for the repository
- [ ] Or check releases manually monthly

**Security Patch Priority:**
- [ ] Security patches should be applied within 7 days
- [ ] Critical security patches should be applied within 24-48 hours
- [ ] Always backup before applying security patches

### Quick Update Command Reference

```bash
# Full update procedure (after reviewing release notes)
cd /opt/vaultwarden
./scripts/backup.sh  # Always backup first!
nano docker-compose.yml  # Update version number
docker-compose pull vaultwarden
docker-compose stop vaultwarden
docker-compose up -d vaultwarden
docker-compose logs -f vaultwarden  # Monitor for errors
```

### Current Version Tracking

**Note**: Update the version in `docker-compose.yml` when deploying. To check current running version:
```bash
docker inspect vaultwarden | grep -i image
```

**Version History** (update this section when you update):
- Initial deployment: `1.30.0` (example - check actual latest version)
- Last updated: [Date of last update]
- Next check: [Schedule monthly review]

---

## Rollback Procedures

If deployment fails at any stage, use these rollback procedures to restore the system to a previous working state.

### Phase 1: Infrastructure Rollback (Terraform)

**If Terraform apply fails or creates incorrect resources:**

```bash
# Navigate to Terraform directory
cd infrastructure/terraform

# Review what will be destroyed
terraform plan -destroy

# Destroy all resources (if needed)
terraform destroy

# Or rollback to previous state (if using remote state)
terraform state list  # List all resources
terraform state rm <resource-name>  # Remove specific resource
terraform apply  # Re-apply with corrected configuration
```

**Troubleshooting**: See [Troubleshooting Guide - Terraform Issues](docs/troubleshooting.md#terraform-issues)

### Phase 2: CI/CD Pipeline Rollback

**If CI/CD pipeline fails during deployment:**

1. **Stop the pipeline** (if still running)
2. **SSH into VM** and check current state:
   ```bash
   ssh username@vm-ip-address
   cd /opt/vaultwarden
   docker-compose ps  # Check container status
   docker-compose logs  # Check for errors
   ```
3. **Revert to previous working configuration:**
   ```bash
   # If using Git, revert to previous commit
   git log  # Find last working commit
   git checkout <previous-commit-hash>
   
   # Or manually restore files from backup
   # Restore docker-compose.yml, Caddyfile, etc.
   ```
4. **Restart services:**
   ```bash
   docker-compose down
   docker-compose up -d
   ```
5. **Verify services are running:**
   ```bash
   docker-compose ps
   curl -I https://your-domain.com
   ```

**Troubleshooting**: See [Troubleshooting Guide - CI/CD Issues](docs/troubleshooting.md#cicd-issues)

### Phase 3: Application Rollback

**If application update causes issues:**

1. **Stop current containers:**
   ```bash
   cd /opt/vaultwarden
   docker-compose stop
   ```
2. **Revert docker-compose.yml to previous version:**
   ```bash
   # Edit docker-compose.yml and change image version back
   nano docker-compose.yml
   # Or restore from backup
   cp docker-compose.yml.backup docker-compose.yml
   ```
3. **Pull previous image and restart:**
   ```bash
   docker-compose pull vaultwarden
   docker-compose up -d
   ```
4. **Verify service restored:**
   ```bash
   docker-compose ps
   curl https://your-domain.com
   ```

**Troubleshooting**: See [Troubleshooting Guide - Container Issues](docs/troubleshooting.md#container-issues)

### Phase 4: Complete System Rollback

**If entire system needs to be restored from backup:**

1. **Follow [Disaster Recovery](#disaster-recovery) procedure**
2. **Restore from most recent backup**
3. **Verify all services are running**
4. **Test all functionality**

**Troubleshooting**: See [Troubleshooting Guide - Disaster Recovery](docs/troubleshooting.md#disaster-recovery)

---

## Troubleshooting

If you encounter issues during deployment:

1. Check container logs: `docker-compose logs -f`
2. Verify configuration: `docker-compose config`
3. Check disk space: `df -h`
4. Verify DNS: `nslookup your-domain.com`
5. See [Troubleshooting Guide](docs/troubleshooting.md) for detailed solutions
6. **For specific issues, see rollback procedures above**

## Next Steps after Successful Deployment

After successful deployment:

1. Bookmark admin panel URL
2. Store admin token securely
3. Store backup encryption key securely
4. Set up client apps (Bitwarden Desktop/Mobile)
5. Review [spec.md](spec.md) for maintenance procedures

## Quick Reference: Automated vs Manual

| Aspect | Automated (IaC + CI/CD) | Manual |
|--------|-------------------------|--------|
| **Initial Setup** | More complex, one-time | Simpler, immediate |
| **Infrastructure** | Terraform manages everything | Manual VM provisioning |
| **Updates** | Automated via pipeline | Manual commands |
| **Reproducibility** | High (version controlled) | Low (manual steps) |
| **Disaster Recovery** | One command | Multiple steps |
| **Best For** | Production, long-term use | Testing, quick setup |

**Recommendation**: Use automated deployment for production environments. Manual deployment is suitable for testing or when you prefer more control over each step.

---

## Templates Reference

This section contains all template files and scripts referenced in both automated and manual deployment procedures. These templates are used to generate deployment files with environment-specific values.

## Docker Compose Template (`docker-compose.yml.template`)

```yaml
version: '3.8'

services:
  vaultwarden:
    image: vaultwarden/server:1.30.0  # Pin to specific stable version (check https://github.com/dani-garcia/vaultwarden/releases for latest)
    container_name: vaultwarden
    restart: unless-stopped
    environment:
      - WEBSOCKET_ENABLED=true
      - SIGNUPS_ALLOWED=false
      - DOMAIN={{DOMAIN}}
      - ADMIN_TOKEN=${ADMIN_TOKEN}
      - DATABASE_URL=/data/db.sqlite3
    volumes:
      - ./vaultwarden/data:/data
    networks:
      - vaultwarden-network
    labels:
      - "com.centurylinklabs.watchtower.enable=false"  # Disabled: Vaultwarden uses version pinning for controlled updates

  caddy:
    image: caddy:latest
    container_name: caddy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
      - "443:443/udp"
    volumes:
      - ./caddy/Caddyfile:/etc/caddy/Caddyfile
      - ./caddy/data:/data
      - ./caddy/config:/config
    networks:
      - vaultwarden-network
    depends_on:
      - vaultwarden
    labels:
      - "com.centurylinklabs.watchtower.enable=true"

  watchtower:
    image: containrrr/watchtower:latest
    container_name: watchtower
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - WATCHTOWER_CLEANUP=true
      - WATCHTOWER_POLL_INTERVAL=86400
      - WATCHTOWER_INCLUDE_STOPPED=false
      - WATCHTOWER_REVIVE_STOPPED=false
    command: --interval 86400

networks:
  vaultwarden-network:
    driver: bridge
```

**Template Variables:**
- `{{DOMAIN}}`: Full domain URL with https:// (e.g., `https://your-domain.com`)

## Caddyfile Template (`Caddyfile.template`)

```
{{DOMAIN_NAME}} {
    # Automatic HTTPS with Let's Encrypt
    encode zstd gzip
    
    # Security headers
    header {
        # Enable HSTS
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        # Prevent clickjacking
        X-Frame-Options "DENY"
        # XSS protection
        X-Content-Type-Options "nosniff"
        # Referrer policy
        Referrer-Policy "strict-origin-when-cross-origin"
    }
    
    # Rate limiting
    rate_limit {
        zone dynamic {
            key {remote_host}
            events 50
            window 1m
        }
    }
    
    # Reverse proxy to Vaultwarden
    reverse_proxy vaultwarden:80 {
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
        header_up X-Forwarded-Proto {scheme}
    }
    
    # WebSocket support for real-time sync
    reverse_proxy /notifications/hub vaultwarden:3012 {
        transport http {
            versions h2c
        }
    }
}

# Redirect HTTP to HTTPS
http://{{DOMAIN_NAME}} {
    redir https://{{DOMAIN_NAME}}{uri} permanent
}
```

**Template Variables:**
- `{{DOMAIN_NAME}}`: Domain name without https:// (e.g., `your-domain.com`)

## Backup Script Template (`backup.sh.template`)

This template is used as-is without variable substitution. The complete content is available in the repository at `infrastructure/templates/backup.sh.template`.

## Restore Script (`restore.sh`)

This script restores Vaultwarden data from encrypted backups stored in Google Drive. The script is created manually during disaster recovery (see [Disaster Recovery - Step 2: Create Restore Script](#step-2-create-restore-script)).

**Usage:**
```bash
# List available backups
./scripts/restore.sh

# Restore a specific backup
./scripts/restore.sh vaultwarden_backup_YYYYMMDD_HHMMSS.tar.gz.gpg
```

**Features:**
- Downloads encrypted backup from Google Drive using Rclone
- Decrypts backup using GPG (supports both passphrase and key-based encryption)
- Extracts and restores database and attachments
- Automatically stops and starts Vaultwarden container during restore
- Cleans up temporary files after restore

**Script Content:**

```bash
#!/bin/bash
set -e

# Configuration
BACKUP_DIR="/opt/vaultwarden/backups"
VAULTWARDEN_DATA="/opt/vaultwarden/vaultwarden/data"
RCLONE_REMOTE="${RCLONE_REMOTE_NAME:-gdrive}"
ENCRYPTION_KEY="${BACKUP_ENCRYPTION_KEY}"

# Check if backup file is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <backup-filename> [restore-path]"
    echo ""
    echo "Available backups:"
    rclone lsf "${RCLONE_REMOTE}:vaultwarden-backups/" | grep "\.gpg$"
    exit 1
fi

BACKUP_FILE="$1"
RESTORE_PATH="${2:-${BACKUP_DIR}}"

# Download backup from Google Drive
echo "[$(date)] Downloading backup from Google Drive..."
mkdir -p "${RESTORE_PATH}"
rclone copy "${RCLONE_REMOTE}:vaultwarden-backups/${BACKUP_FILE}" \
    "${RESTORE_PATH}/" \
    --log-file="${RESTORE_PATH}/rclone-restore.log"

DOWNLOADED_FILE="${RESTORE_PATH}/${BACKUP_FILE}"

# Decrypt backup
echo "[$(date)] Decrypting backup..."
DECRYPTED_FILE="${DOWNLOADED_FILE%.gpg}"
if [ -n "${ENCRYPTION_KEY}" ]; then
    # Using GPG with passphrase
    gpg --batch --yes --passphrase "${ENCRYPTION_KEY}" \
        --decrypt "${DOWNLOADED_FILE}" > "${DECRYPTED_FILE}"
else
    # Using GPG with key
    gpg --decrypt --output "${DECRYPTED_FILE}" "${DOWNLOADED_FILE}"
fi

# Extract backup
echo "[$(date)] Extracting backup..."
EXTRACT_DIR="${RESTORE_PATH}/restore_$(date +%Y%m%d_%H%M%S)"
mkdir -p "${EXTRACT_DIR}"
tar -xzf "${DECRYPTED_FILE}" -C "${EXTRACT_DIR}"

# Find backup directory
BACKUP_CONTENT=$(find "${EXTRACT_DIR}" -type d -name "vaultwarden_backup_*" | head -1)
if [ -z "${BACKUP_CONTENT}" ]; then
    echo "Error: Could not find backup content directory"
    exit 1
fi

# Stop Vaultwarden container
echo "[$(date)] Stopping Vaultwarden container..."
cd /opt/vaultwarden
docker-compose stop vaultwarden

# Restore database
echo "[$(date)] Restoring database..."
if [ -f "${BACKUP_CONTENT}/db.sqlite3" ]; then
    cp "${BACKUP_CONTENT}/db.sqlite3" "${VAULTWARDEN_DATA}/db.sqlite3"
    chown -R $(id -u):$(id -g) "${VAULTWARDEN_DATA}/db.sqlite3"
fi

# Restore attachments
echo "[$(date)] Restoring attachments..."
if [ -f "${BACKUP_CONTENT}/attachments.tar.gz" ]; then
    rm -rf "${VAULTWARDEN_DATA}/attachments"
    tar -xzf "${BACKUP_CONTENT}/attachments.tar.gz" -C "${VAULTWARDEN_DATA}"
    chown -R $(id -u):$(id -g) "${VAULTWARDEN_DATA}/attachments"
fi

# Start Vaultwarden container
echo "[$(date)] Starting Vaultwarden container..."
docker-compose start vaultwarden

# Clean up
echo "[$(date)] Cleaning up temporary files..."
rm -rf "${EXTRACT_DIR}"
rm -f "${DOWNLOADED_FILE}" "${DECRYPTED_FILE}"

echo "[$(date)] Restore completed successfully"
echo "Vaultwarden is now running with restored data"
```

**Environment Variables:**
- `RCLONE_REMOTE_NAME` (defaults to `gdrive`) - Rclone remote name for Google Drive
- `BACKUP_ENCRYPTION_KEY` - GPG passphrase or key ID for decrypting backups

**Note**: This script is created manually during disaster recovery. See [Disaster Recovery - Step 2: Create Restore Script](#step-2-create-restore-script) for creation instructions.

## Health Check Script Template (`health-check.sh.template`)

```bash
#!/bin/bash

DOMAIN="{{DOMAIN}}"
ALERT_EMAIL="${ALERT_EMAIL}"

# Check if service is responding
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${DOMAIN}")

if [ "${HTTP_CODE}" != "200" ]; then
    echo "[$(date)] Health check failed: HTTP ${HTTP_CODE}"
    if [ -n "${ALERT_EMAIL}" ]; then
        echo "Vaultwarden health check failed" | mail -s "Alert: Vaultwarden Down" "${ALERT_EMAIL}"
    fi
    exit 1
fi

# Check container status
if ! docker ps | grep -q vaultwarden; then
    echo "[$(date)] Health check failed: Container not running"
    exit 1
fi

echo "[$(date)] Health check passed"
exit 0
```

**Template Variables:**
- `{{DOMAIN}}`: Full domain URL with https:// (e.g., `https://your-domain.com`)

## Environment Variables Template (`.env.template`)

```bash
ADMIN_TOKEN={{ADMIN_TOKEN}}
DOMAIN={{DOMAIN}}
BACKUP_ENCRYPTION_KEY={{BACKUP_ENCRYPTION_KEY}}
RCLONE_REMOTE_NAME=gdrive
BACKUP_RETENTION_DAYS=30
```

**Template Variables:**
- `{{ADMIN_TOKEN}}`: Strong random token (generate with `openssl rand -base64 48`)
- `{{DOMAIN}}`: Full domain URL with https:// (e.g., `https://your-domain.com`)
- `{{BACKUP_ENCRYPTION_KEY}}`: GPG passphrase or key ID (generate with `openssl rand -base64 32`)

## Resource Tagging Script (`tag-resources.sh`)

This script automates tagging of all Azure resources in a resource group, reusing the same tag structure as Terraform. The script is created from template during Step 1: Terraform Setup (see [Step 1: Terraform Setup](#step-1-terraform-setup)).

**Usage:**
```bash
# Basic usage (environment defaults to "production")
./scripts/tag-resources.sh <resource-group-name> <owner-email>

# With custom environment
./scripts/tag-resources.sh <resource-group-name> <owner-email> staging
```

**Features:**
- Automatically discovers and tags all resources: Resource Group, VM, Disk, NIC, Public IP, NSG, VNet
- Uses same tag structure as Terraform (see [Terraform Guide](docs/terraform-guide.md))
- Base tags: `Project=password-manager`, `Environment=<env>`, `Component=infrastructure`, `ManagedBy=manual`, `CostCenter=personal`
- VM-specific tags: `Component=vaultwarden`, `Backup=enabled`, `Owner=<email>`
- Includes error handling, validation, and progress reporting

**Script Content:**

```bash
#!/bin/bash
set -e

# Azure Resource Tagging Script
# Reuses the same tag structure as Terraform (docs/terraform-guide.md)
# Usage: ./tag-resources.sh <resource-group-name> <owner-email> [environment]

# Configuration
RESOURCE_GROUP="${1}"
OWNER_EMAIL="${2}"
ENVIRONMENT="${3:-production}"

# Validation
if [ -z "${RESOURCE_GROUP}" ] || [ -z "${OWNER_EMAIL}" ]; then
    echo "Usage: $0 <resource-group-name> <owner-email> [environment]"
    echo "  environment defaults to 'production' if not specified"
    exit 1
fi

# Verify Azure CLI is installed and logged in
if ! command -v az &> /dev/null; then
    echo "Error: Azure CLI is not installed. Please install it first."
    exit 1
fi

# Check if logged in
if ! az account show &> /dev/null; then
    echo "Error: Not logged in to Azure. Please run 'az login' first."
    exit 1
fi

# Verify resource group exists
if ! az group show --name "${RESOURCE_GROUP}" &> /dev/null; then
    echo "Error: Resource group '${RESOURCE_GROUP}' not found."
    exit 1
fi

echo "=========================================="
echo "Azure Resource Tagging Script"
echo "=========================================="
echo "Resource Group: ${RESOURCE_GROUP}"
echo "Owner Email: ${OWNER_EMAIL}"
echo "Environment: ${ENVIRONMENT}"
echo "=========================================="
echo ""

# Base tags (same as Terraform's azurerm_resource_group.main.tags)
# Only difference: ManagedBy = "manual" instead of "terraform"
BASE_TAGS="Project=password-manager Environment=${ENVIRONMENT} Component=infrastructure ManagedBy=manual CostCenter=personal"

# VM-specific tags (same as Terraform's merge logic)
# Component=vaultwarden overrides base Component, Backup=enabled added
VM_TAGS="${BASE_TAGS} Component=vaultwarden Backup=enabled Owner=${OWNER_EMAIL}"

# Function to tag a resource
tag_resource() {
    local resource_type=$1
    local resource_name=$2
    local tags=$3
    
    echo "Tagging ${resource_type}: ${resource_name}..."
    if az ${resource_type} update \
        --resource-group "${RESOURCE_GROUP}" \
        --name "${resource_name}" \
        --set ${tags} &> /dev/null; then
        echo "  ✓ Successfully tagged ${resource_name}"
        return 0
    else
        echo "  ✗ Failed to tag ${resource_name} (resource may not exist or name may differ)"
        return 1
    fi
}

# Function to tag resource group
tag_resource_group() {
    echo "Tagging Resource Group: ${RESOURCE_GROUP}..."
    if az group update \
        --name "${RESOURCE_GROUP}" \
        --set ${BASE_TAGS} &> /dev/null; then
        echo "  ✓ Successfully tagged resource group"
        return 0
    else
        echo "  ✗ Failed to tag resource group"
        return 1
    fi
}

# Start tagging
SUCCESS_COUNT=0
FAILED_COUNT=0

# Tag Resource Group
if tag_resource_group; then
    ((SUCCESS_COUNT++))
else
    ((FAILED_COUNT++))
fi

# Discover and tag Virtual Machine
echo ""
echo "Discovering Virtual Machine..."
VM_NAME=$(az vm list --resource-group "${RESOURCE_GROUP}" --query "[0].name" -o tsv 2>/dev/null || echo "")
if [ -n "${VM_NAME}" ]; then
    if tag_resource "vm" "${VM_NAME}" "${VM_TAGS}"; then
        ((SUCCESS_COUNT++))
    else
        ((FAILED_COUNT++))
    fi
else
    echo "  ⚠ No virtual machine found in resource group"
fi

# Discover and tag OS Disk
echo ""
echo "Discovering OS Disk..."
DISK_NAME=$(az disk list --resource-group "${RESOURCE_GROUP}" --query "[0].name" -o tsv 2>/dev/null || echo "")
if [ -n "${DISK_NAME}" ]; then
    if tag_resource "disk" "${DISK_NAME}" "${BASE_TAGS}"; then
        ((SUCCESS_COUNT++))
    else
        ((FAILED_COUNT++))
    fi
else
    echo "  ⚠ No disk found in resource group"
fi

# Discover and tag Network Interface
echo ""
echo "Discovering Network Interface..."
NIC_NAME=$(az network nic list --resource-group "${RESOURCE_GROUP}" --query "[0].name" -o tsv 2>/dev/null || echo "")
if [ -n "${NIC_NAME}" ]; then
    if tag_resource "network nic" "${NIC_NAME}" "${BASE_TAGS}"; then
        ((SUCCESS_COUNT++))
    else
        ((FAILED_COUNT++))
    fi
else
    echo "  ⚠ No network interface found in resource group"
fi

# Discover and tag Public IP Address
echo ""
echo "Discovering Public IP Address..."
PIP_NAME=$(az network public-ip list --resource-group "${RESOURCE_GROUP}" --query "[0].name" -o tsv 2>/dev/null || echo "")
if [ -n "${PIP_NAME}" ]; then
    if tag_resource "network public-ip" "${PIP_NAME}" "${BASE_TAGS}"; then
        ((SUCCESS_COUNT++))
    else
        ((FAILED_COUNT++))
    fi
else
    echo "  ⚠ No public IP address found in resource group"
fi

# Discover and tag Network Security Group
echo ""
echo "Discovering Network Security Group..."
NSG_NAME=$(az network nsg list --resource-group "${RESOURCE_GROUP}" --query "[0].name" -o tsv 2>/dev/null || echo "")
if [ -n "${NSG_NAME}" ]; then
    if tag_resource "network nsg" "${NSG_NAME}" "${BASE_TAGS}"; then
        ((SUCCESS_COUNT++))
    else
        ((FAILED_COUNT++))
    fi
else
    echo "  ⚠ No network security group found in resource group"
fi

# Discover and tag Virtual Network
echo ""
echo "Discovering Virtual Network..."
VNET_NAME=$(az network vnet list --resource-group "${RESOURCE_GROUP}" --query "[0].name" -o tsv 2>/dev/null || echo "")
if [ -n "${VNET_NAME}" ]; then
    if tag_resource "network vnet" "${VNET_NAME}" "${BASE_TAGS}"; then
        ((SUCCESS_COUNT++))
    else
        ((FAILED_COUNT++))
    fi
else
    echo "  ⚠ No virtual network found in resource group"
fi

# Summary
echo ""
echo "=========================================="
echo "Tagging Summary"
echo "=========================================="
echo "Successfully tagged: ${SUCCESS_COUNT} resource(s)"
if [ ${FAILED_COUNT} -gt 0 ]; then
    echo "Failed/Warning: ${FAILED_COUNT} resource(s)"
    echo ""
    echo "Note: Some resources may not exist or have different names."
    echo "      Verify tags in Azure Portal if needed."
fi
echo "=========================================="

# Verify tags (optional - show VM tags as example)
if [ -n "${VM_NAME}" ]; then
    echo ""
    echo "Verification - VM Tags:"
    az vm show --resource-group "${RESOURCE_GROUP}" --name "${VM_NAME}" --query "tags" -o table 2>/dev/null || echo "  Could not retrieve tags"
fi

echo ""
echo "Tagging complete!"
echo ""
echo "Tags applied match Terraform's tag structure:"
echo "  - Base tags: Project, Environment, Component, ManagedBy, CostCenter"
echo "  - VM-specific: Component=vaultwarden, Backup=enabled, Owner"
echo "  - Only difference: ManagedBy=manual (vs terraform in automated deployment)"
```

**Note**: This script will be created from template during Step 1: Terraform Setup. The template file `tag-resources.sh.template` will be created in `infrastructure/templates/` when the plan is executed. This script ensures consistency between automated (Terraform) and manual deployments by using the same tag structure.

---

## Common Configuration Steps

These steps are shared between both automated and manual deployment methods. Reference this section when your deployment method indicates to follow a common step.

### DNS Configuration

**Estimated Time**: 5-15 minutes (DNS propagation time varies)

**⚠️ IMPORTANT - DNS Configuration Timing:**
- DNS must be configured **immediately after** VM is provisioned and **before** services are deployed
- Caddy requires DNS to be properly configured to obtain SSL certificates from Let's Encrypt
- If DNS is not configured, SSL certificate acquisition will fail

- [ ] Get VM public IP address (you should have this from your deployment step)
- [ ] **Update DNS A record to point to VM IP** (do this immediately)
- [ ] Wait for DNS propagation (check: `nslookup your-domain.com`)
  - **Troubleshooting**: If DNS doesn't resolve, see [Troubleshooting Guide - DNS Issues](docs/troubleshooting.md#dns-issues)
- [ ] Verify DNS: `dig your-domain.com` or `nslookup your-domain.com`
- [ ] Verify DNS points to correct IP: `dig +short your-domain.com`

### Rclone Configuration

**Estimated Time**: 5-10 minutes

**⚠️ IMPORTANT**: Rclone configuration is required before backup automation can work. This step cannot be fully automated as it requires interactive authentication with Google Drive.

- [ ] SSH into VM: `ssh username@vm-ip-address`
- [ ] Configure Rclone: `rclone config`
  - **Troubleshooting**: If Rclone configuration fails, see [Troubleshooting Guide - Rclone Issues](docs/troubleshooting.md#rclone-issues)
- [ ] Create remote named `gdrive` (or update `RCLONE_REMOTE_NAME` in `.env`)
- [ ] Test connection: `rclone lsd gdrive:`
- [ ] Create backup directory: `rclone mkdir gdrive:vaultwarden-backups`
- [ ] Verify remote is accessible: `rclone ls gdrive:vaultwarden-backups/`

### Environment Variables Setup

**Estimated Time**: 10-15 minutes

- [ ] Navigate to deployment directory: `cd /opt/vaultwarden`
- [ ] Copy `.env.example` to `.env` (if available): `cp .env.example .env`
- [ ] Generate admin token: `openssl rand -base64 48`
- [ ] Update `.env` with domain: `DOMAIN=https://your-domain.com`
- [ ] Update `.env` with admin token: `ADMIN_TOKEN=<generated-token>`
- [ ] Generate backup encryption key: `openssl rand -base64 32`
- [ ] Update `.env` with encryption key: `BACKUP_ENCRYPTION_KEY=<generated-key>`
- [ ] Set file permissions: `chmod 600 .env`
- [ ] Verify `.env` file exists and has correct permissions: `ls -la .env`

**Backup Encryption Key Setup (Alternative Methods):**

**Method 1: GPG with Passphrase** (Recommended for simplicity)
```bash
BACKUP_ENCRYPTION_KEY=$(openssl rand -base64 32)
echo "BACKUP_ENCRYPTION_KEY=${BACKUP_ENCRYPTION_KEY}" >> .env
```

**Method 2: GPG with Key Pair** (Recommended for enhanced security)
```bash
# Generate GPG key pair
gpg --full-generate-key
# Export public key for backup
gpg --export --armor your-email@example.com > backup-public-key.asc
# Use key ID in .env
BACKUP_ENCRYPTION_KEY=<key-id-from-gpg-list-keys>
```

### Post-Deployment Verification

**Estimated Time**: 15-20 minutes

**Directory Structure Verification:**
- [ ] Verify directory structure exists: `ls -la /opt/vaultwarden/`
- [ ] Verify required directories: `ls -la /opt/vaultwarden/{caddy,vaultwarden,scripts,backups}`
- [ ] Verify directory ownership: `ls -ld /opt/vaultwarden` (should be owned by deployment user)
- [ ] Verify `.env` file permissions: `ls -la /opt/vaultwarden/.env` (should be 600)

**Service Verification:**
- [ ] Access admin panel: `https://your-domain.com/admin`
  - **Troubleshooting**: If admin panel is inaccessible, see [Troubleshooting Guide - Access Issues](docs/troubleshooting.md#access-issues)
- [ ] Verify HTTPS working (green lock icon in browser)
- [ ] Verify SSL certificate: `openssl s_client -connect your-domain.com:443 -servername your-domain.com | grep "Verify return code"`
  - Should show "Verify return code: 0 (ok)"
- [ ] Check certificate expiration: `echo | openssl s_client -connect your-domain.com:443 -servername your-domain.com 2>/dev/null | openssl x509 -noout -dates`
- [ ] Create first user account via admin panel (using `ADMIN_TOKEN` from `.env`)
- [ ] Test login from Bitwarden client
- [ ] Verify signups disabled (attempt public signup should fail)
- [ ] Verify WebSocket connection (check real-time sync in Bitwarden client)
- [ ] Check container logs: `docker-compose logs -f`
- [ ] Verify all containers running: `docker-compose ps` (all should show "Up")

**Backup Verification:**
- [ ] Verify backup automation is configured (check crontab: `crontab -l`)
- [ ] Verify health monitoring is configured (check crontab: `crontab -l`)
- [ ] Test backup manually: `cd /opt/vaultwarden && ./scripts/backup.sh`
- [ ] Verify backup in Google Drive: `rclone ls gdrive:vaultwarden-backups/`
