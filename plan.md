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
| Storage: 20 GB min, 50 GB recommended | **Automated**: [Step 1: Terraform Setup](#step-1-terraform-setup) - `terraform.tfvars` (os_disk size)<br>**Manual**: [Pre-Deployment Checklist](#pre-deployment-checklist) | Disk size configured in Terraform or pre-provisioned VM |
| Ports 80/443 only (inbound) | **Automated**: [Step 1: Terraform Setup](#step-1-terraform-setup) (cloud-init.sh via Terraform)<br>**Manual**: [Step 1: Initial Server Setup](#step-1-initial-server-setup) (setup.sh) | Firewall configured automatically |
| Port 443 outbound (Let's Encrypt, Google Drive) | **Inherent**: Default outbound traffic allowed | Firewall allows all outbound traffic by default |
| SQLite accessible for backup | **Automated**: [Step 1: Terraform Setup](#step-1-terraform-setup) (cloud-init.sh installs sqlite3)<br>**Manual**: [Step 1: Initial Server Setup](#step-1-initial-server-setup) (setup.sh installs sqlite3) | sqlite3 CLI installed on host |
| **Section 3.2: Directory Structure Requirements** |
| `/opt/vaultwarden/` structure | **Automated**: [Step 1: Terraform Setup](#step-1-terraform-setup) (cloud-init.sh creates structure)<br>**Manual**: [Step 1: Initial Server Setup](#step-1-initial-server-setup) (setup.sh creates structure) | Directory structure created |
| `.env` file 600 permissions | **Automated**: [Step 3: Post-Infrastructure Configuration](#step-3-post-infrastructure-configuration) (CI/CD sets permissions)<br>**Manual**: [Step 2: Configuration](#step-2-configuration) | Permissions set in both methods |
| **Section 3.3: Service Requirements** |
| Vaultwarden with version pinning | **Automated**: [Step 1: Terraform Setup](#step-1-terraform-setup) (docker-compose.yml.template)<br>**Manual**: [Step 5: Deploy Services](#step-5-deploy-services) (docker-compose.yml) | Configured in docker-compose.yml |
| Vaultwarden WebSocket support | **Automated**: [Step 1: Terraform Setup](#step-1-terraform-setup) (docker-compose.yml.template: WEBSOCKET_ENABLED=true, Caddyfile.template)<br>**Manual**: [Step 5: Deploy Services](#step-5-deploy-services) | WebSocket configured in docker-compose.yml and Caddyfile |
| Caddy with SSL automation | **Automated**: [Step 1: Terraform Setup](#step-1-terraform-setup) (Caddyfile.template)<br>**Manual**: [Step 5: Deploy Services](#step-5-deploy-services) (Caddyfile) | Configured in Caddyfile |
| Watchtower (Caddy only) | **Automated**: [Step 1: Terraform Setup](#step-1-terraform-setup) (docker-compose.yml.template)<br>**Manual**: [Step 5: Deploy Services](#step-5-deploy-services) (docker-compose.yml) | Watchtower configured with Vaultwarden exclusion |
| Watchtower update schedule (daily at 2 AM) | **Automated**: [Step 1: Terraform Setup](#step-1-terraform-setup) (docker-compose.yml.template: --interval 86400)<br>**Manual**: [Step 5: Deploy Services](#step-5-deploy-services) | Watchtower checks daily (86400 seconds) |
| Environment variables | **Automated**: [Step 3: Post-Infrastructure Configuration](#step-3-post-infrastructure-configuration) (CI/CD generates .env)<br>**Manual**: [Step 2: Configuration](#step-2-configuration) | Environment variables configured |
| **Section 3.4: Security Requirements** |
| Firewall (UFW) | **Automated**: [Step 1: Terraform Setup](#step-1-terraform-setup) (cloud-init.sh)<br>**Manual**: [Step 1: Initial Server Setup](#step-1-initial-server-setup) (setup.sh) | Network security |
| SSL/TLS automatic | **Automated**: [Step 1: Terraform Setup](#step-1-terraform-setup) (Caddyfile.template)<br>**Manual**: [Step 5: Deploy Services](#step-5-deploy-services) (Caddyfile) | Let's Encrypt |
| TLS 1.2 minimum, TLS 1.3 preferred | **Automated**: [Step 1: Terraform Setup](#step-1-terraform-setup) (Caddyfile.template: tls protocols)<br>**Manual**: [Step 5: Deploy Services](#step-5-deploy-services) (Caddyfile) | TLS version configured in Caddyfile |
| Strong cipher suites (ECDHE, AES-GCM) | **Automated**: [Step 1: Terraform Setup](#step-1-terraform-setup) (Caddyfile.template: tls ciphers)<br>**Manual**: [Step 5: Deploy Services](#step-5-deploy-services) (Caddyfile) | Cipher suites configured in Caddyfile |
| Security headers | **Automated**: [Step 1: Terraform Setup](#step-1-terraform-setup) (Caddyfile.template)<br>**Manual**: [Step 5: Deploy Services](#step-5-deploy-services) (Caddyfile) | HTTP headers (HSTS, X-Frame-Options, etc.) |
| Content-Security-Policy header | **Automated**: [Step 1: Terraform Setup](#step-1-terraform-setup) (Caddyfile.template)<br>**Manual**: [Step 5: Deploy Services](#step-5-deploy-services) (Caddyfile) | CSP header configured in Caddyfile |
| Rate limiting (50 requests/minute per IP) | **Automated**: [Step 1: Terraform Setup](#step-1-terraform-setup) (Caddyfile.template: rate_limit events 50)<br>**Manual**: [Step 5: Deploy Services](#step-5-deploy-services) (Caddyfile) | Rate limiting configured in Caddyfile |
| Container resource limits | **Automated**: [Step 1: Terraform Setup](#step-1-terraform-setup) (docker-compose.yml.template: deploy.resources.limits)<br>**Manual**: [Step 5: Deploy Services](#step-5-deploy-services) (docker-compose.yml) | CPU and memory limits configured |
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
| Signup restrictions | **Automated**: [Step 1: Terraform Setup](#step-1-terraform-setup) (docker-compose.yml.template: SIGNUPS_ALLOWED=true initially)<br>**Manual**: [Step 5: Deploy Services](#step-5-deploy-services) (docker-compose.yml: SIGNUPS_ALLOWED=true initially)<br>**Both**: [Post-Deployment Verification](#post-deployment-verification) - Disable signups after initial account creation | Two-phase: Enable for initial setup, then disable for security |
| Two-Factor Authentication (TOTP) | **Inherent**: Supported by Vaultwarden | Configured via Bitwarden client apps |
| Admin token rotation | **Both**: [Environment Variables Setup](#environment-variables-setup) | Regenerate ADMIN_TOKEN in .env and restart services |
| Log retention (30 days) | **Both**: [Log Retention Configuration](#log-retention-configuration) | Configured via logrotate |
| **Section 5: Data Protection (Backup & Disaster Recovery)** |
| Backup process | **Automated**: [Step 3: Post-Infrastructure Configuration](#step-3-post-infrastructure-configuration) (backup.sh.template deployed)<br>**Manual**: [Step 7: Backup Automation](#step-7-backup-automation) (backup.sh) | Backup script implements requirements |
| Backup manifest creation | **Automated**: [Step 3: Post-Infrastructure Configuration](#step-3-post-infrastructure-configuration) (backup.sh.template)<br>**Manual**: [Step 7: Backup Automation](#step-7-backup-automation) (backup.sh) | Backup script creates manifest with metadata |
| Backup encryption | **Automated**: [Step 3: Post-Infrastructure Configuration](#step-3-post-infrastructure-configuration) (backup.sh.template)<br>**Manual**: [Step 7: Backup Automation](#step-7-backup-automation) (backup.sh) | GPG encryption |
| Google Drive 2FA requirement | **Both**: [Rclone Configuration](#rclone-configuration) | Google Drive account must have 2FA enabled |
| Disaster recovery | **Both**: [Disaster Recovery](#disaster-recovery) section | restore.sh script |
| Backup verification | **Both**: [Disaster Recovery → Backup Verification](#backup-verification) | Verification procedure |
| **Section 6: Maintenance & Automation Strategy** |
| Watchtower configuration | **Automated**: [Step 1: Terraform Setup](#step-1-terraform-setup) (docker-compose.yml.template)<br>**Manual**: [Step 5: Deploy Services](#step-5-deploy-services) (docker-compose.yml) | Container updates |
| Vaultwarden updates | **Both**: [Vaultwarden Update Procedure](#vaultwarden-update-procedure) | Manual update process |
| Health checks | **Automated**: [Step 3: Post-Infrastructure Configuration](#step-3-post-infrastructure-configuration) (health-check.sh.template deployed)<br>**Manual**: [Step 8: Health Monitoring](#step-8-health-monitoring-optional) | health-check.sh script |
| OS updates (automated/unattended-upgrades) | **Both**: [OS Updates Configuration](#os-updates-configuration-optional) (Optional) | Optional automated OS security updates |
| Disk space management | **Both**: See [spec.md](spec.md) Section 6.3.2 | Monitor via `df -h` and `docker system df` |
| Database maintenance (VACUUM, ANALYZE) | **Both**: [Database Maintenance](#database-maintenance) | Monthly SQLite optimization |
| Documentation maintenance (CONFIG.md, CHANGELOG.md) | **Both**: [Documentation Maintenance](#documentation-maintenance) | Ongoing documentation tracking |

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

**Note**: For a Test-Driven Infrastructure (TDI) approach with iterative verification, see [auto_deploy_iterations.md](auto_deploy_iterations.md). This guide provides step-by-step iterations with verification scripts for each deployment phase.

### Step 1: Terraform Setup

**Estimated Time**: 30-45 minutes

**Create Directory Structure:**
- [ ] Create base directories: `mkdir -p infrastructure/terraform/scripts infrastructure/templates`
- [ ] Verify directory structure:
  ```
  infrastructure/
  ├── terraform/
  │   ├── scripts/
  │   │   └── cloud-init.sh
  │   └── (Terraform files will be created here)
  └── templates/
      ├── docker-compose.yml.template
      ├── Caddyfile.template
      ├── backup.sh.template
      ├── health-check.sh.template
      └── .env.template
  ```

**Create Terraform Configuration Files:**
- [ ] Create `infrastructure/terraform/main.tf` - Follow instructions in [Terraform Guide - Main Configuration](docs/terraform-guide.md#main-configuration-infrastructureterraformmaintf)
- [ ] Create `infrastructure/terraform/azure.tf` - Follow instructions in [Terraform Guide - Azure Resources](docs/terraform-guide.md#azure-resources-infrastructureterraformazuretf)
  - **Note**: This file contains all Azure vendor-specific resources (resource group, network, VM, etc.)
  - Separating vendor-specific code makes it easier to add support for other cloud providers (AWS, GCP) in the future
- [ ] Create `infrastructure/terraform/variables.tf` - Follow instructions in [Terraform Guide - Variables File](docs/terraform-guide.md#variables-file-infrastructureterraformvariablestf)
- [ ] Create `infrastructure/terraform/outputs.tf` - Follow instructions in [Terraform Guide - Outputs File](docs/terraform-guide.md#outputs-file-infrastructureterraformoutputstf)

**Create Cloud-Init Script:**
- [ ] Create `infrastructure/terraform/scripts/cloud-init.sh` - Follow instructions in [Terraform Guide - Cloud-Init Script](docs/terraform-guide.md#cloud-init-script-infrastructureterraformscriptscloud-initsh)
- [ ] Make script executable: `chmod +x infrastructure/terraform/scripts/cloud-init.sh`
- [ ] **Important**: The `azure.tf` file references this script via `templatefile("${path.module}/scripts/cloud-init.sh", {...})`, so it must exist before running `terraform plan`

**Create Deployment Templates:**
- [ ] Create templates directory: `mkdir -p infrastructure/templates`
- [ ] Create `infrastructure/templates/docker-compose.yml.template` - Follow instructions in [Templates Reference - Docker Compose Template](#docker-compose-template-docker-composeymltemplate)
- [ ] Create `infrastructure/templates/Caddyfile.template` - Follow instructions in [Templates Reference - Caddyfile Template](#caddyfile-template-caddyfiletemplate)
- [ ] Create `infrastructure/templates/backup.sh.template` - Follow instructions in [Templates Reference - Backup Script Template](#backup-script-template-backupshtemplate)
- [ ] Create `infrastructure/templates/health-check.sh.template` - Follow instructions in [Templates Reference - Health Check Script Template](#health-check-script-template-health-checkshtemplate)
- [ ] Create `infrastructure/templates/.env.template` - Follow instructions in [Templates Reference - Environment Variables Template](#environment-variables-template-envtemplate)
- [ ] **Note**: The `tag-resources.sh.template` file will be created in `infrastructure/templates/` when needed. Follow instructions in [Resource Tagging Script](#resource-tagging-script-tag-resourcessh) in Templates Reference section.
- [ ] **Note**: These templates will be used by both CI/CD pipeline and manual deployment to generate deployment files with environment-specific values. See [Templates Reference](#templates-reference) section for template instructions.

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

**Note**: If following the iterative deployment approach, this step corresponds to [Iteration 2: CI/CD Pipeline Setup](auto_deploy_iterations.md#iteration-2-cicd-pipeline-setup) in the Test-Driven Infrastructure guide.

- [ ] Choose CI/CD platform (GitHub Actions recommended)
- [ ] Create pipeline configuration - Follow instructions in [CI/CD Pipelines Guide](docs/cicd-pipelines.md)
  - Create `.github/workflows/deploy.yml` for GitHub Actions (or `azure-pipelines.yml` for Azure DevOps)
  - Follow workflow structure and step instructions from the guide
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
- [ ] Create setup script: Create file `/opt/vaultwarden/scripts/setup.sh` with the following requirements:

**Setup Script Requirements** (`/opt/vaultwarden/scripts/setup.sh`):

The script must perform the following tasks:

1. **System Updates**: Update package lists and upgrade system packages
2. **Install Docker**: Install Docker if not present (using official Docker installation script)
3. **Install Docker Compose**: Install Docker Compose if not present (latest version from GitHub)
4. **Install Rclone**: Install Rclone if not present (using official installation script)
5. **Install GPG**: Install gnupg2 package
6. **Install sqlite3**: Install sqlite3 CLI for backups
7. **Create Directory Structure**: Create `/opt/vaultwarden/` with subdirectories:
   - `caddy/{data,config}`
   - `vaultwarden/data`
   - `scripts`
   - `backups`
8. **Set Directory Permissions**: Set ownership to deployment user for `/opt/vaultwarden/`
9. **Set Vaultwarden Data Permissions**: Set ownership to `1000:1000` for `/opt/vaultwarden/vaultwarden/data` (for non-root container execution)
10. **Generate Initial .env File**: Create `.env` file with:
    - Generated `ADMIN_TOKEN` (using `openssl rand -base64 48`)
    - Placeholder `DOMAIN=https://your-domain.com` (to be edited)
    - `BACKUP_RETENTION_DAYS=30`
11. **Configure Firewall (UFW)**:
    - Default deny incoming traffic
    - Default allow outgoing traffic
    - Allow port 80/tcp (HTTP for Let's Encrypt)
    - Allow port 443/tcp (HTTPS)
    - Enable UFW
12. **Display Completion Message**: Show instructions for next steps (edit .env, configure Rclone, set up GPG, deploy services)

**Note**: This script is created during execution based on these requirements, not stored in documentation.

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
- [ ] Create tagging script: Create file `scripts/tag-resources.sh` following instructions in [Resource Tagging Script](#resource-tagging-script-tag-resourcessh) in Templates Reference section
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

**Manual Tagging Instructions**:
- **Tag VM**: Use `az vm update` command with VM-specific tags: Project=password-manager, Environment=production, Component=vaultwarden, ManagedBy=manual, CostCenter=personal, Backup=enabled, Owner=<email>
- **Tag Other Resources**: Use Azure CLI update commands (`az disk update`, `az network nic update`, `az network public-ip update`, `az network nsg update`, `az network vnet update`, `az group update`) with base tags: Project=password-manager, Environment=production, Component=infrastructure, ManagedBy=manual, CostCenter=personal
- **Resource Discovery**: Use `az vm list`, `az disk list`, `az network nic list`, etc. to discover resource names before tagging
- **Tag Format**: Use `--set tags.Key=Value` format for each tag, or combine multiple tags in a single `--set` command

**Note**: See [Resource Tagging Script](#resource-tagging-script-tag-resourcessh) in Templates Reference section for the automated script that handles all resources with proper discovery and error handling.

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

- [ ] On new VM, create setup script: Create file `/opt/vaultwarden/scripts/setup.sh` following instructions in [Manual Deployment - Step 1: Initial Server Setup](#step-1-initial-server-setup) (Setup Script Requirements section)
- [ ] Make executable: `chmod +x /opt/vaultwarden/scripts/setup.sh`
- [ ] Run setup script: `cd /opt/vaultwarden && ./scripts/setup.sh`
- [ ] Configure Rclone: `rclone config`
- [ ] Set encryption key in `.env`: `echo "BACKUP_ENCRYPTION_KEY=<your-key>" >> /opt/vaultwarden/.env`

**Step 2: Create Restore Script**

- [ ] Create scripts directory (if not exists): `mkdir -p /opt/vaultwarden/scripts`
- [ ] Create restore script: Create file `/opt/vaultwarden/scripts/restore.sh` following instructions in [Restore Script](#restore-script-restoresh) in Templates Reference section
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

**Full update procedure** (after reviewing release notes):
1. Navigate to deployment directory: `cd /opt/vaultwarden`
2. Run backup: `./scripts/backup.sh` (always backup first!)
3. Update version in `docker-compose.yml`: Edit file and update Vaultwarden image version
4. Pull new image: `docker-compose pull vaultwarden`
5. Stop Vaultwarden: `docker-compose stop vaultwarden`
6. Start with new image: `docker-compose up -d vaultwarden`
7. Monitor logs: `docker-compose logs -f vaultwarden`

### Current Version Tracking

**Note**: Update the version in `docker-compose.yml` when deploying. To check current running version:
- Command: `docker inspect vaultwarden | grep -i image`

**Version History** (update this section when you update):
- Initial deployment: `1.30.0` (example - check actual latest version)
- Last updated: [Date of last update]
- Next check: [Schedule monthly review]

---

## Rollback Procedures

If deployment fails at any stage, use these rollback procedures to restore the system to a previous working state.

### Phase 1: Infrastructure Rollback (Terraform)

**If Terraform apply fails or creates incorrect resources:**

**Rollback Steps**:
1. Navigate to Terraform directory: `cd infrastructure/terraform`
2. Review what will be destroyed: `terraform plan -destroy`
3. Destroy all resources (if needed): `terraform destroy`
4. Or rollback to previous state (if using remote state):
   - List all resources: `terraform state list`
   - Remove specific resource: `terraform state rm <resource-name>`
   - Re-apply with corrected configuration: `terraform apply`

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

This section contains requirements for all template files and scripts referenced in both automated and manual deployment procedures. These templates are created during execution based on these requirements, not stored in documentation.

## Docker Compose Template (`docker-compose.yml.template`)

**Purpose**: Docker Compose configuration template for Vaultwarden, Caddy, and Watchtower services

**Location**: `infrastructure/templates/docker-compose.yml.template`

**Created During**: Step 1: Terraform Setup (for automated) or Step 5: Deploy Services (for manual)

**Requirements**:
- **Version**: Docker Compose file format version 3.8
- **Vaultwarden Service**:
  - Image: `vaultwarden/server:1.30.0` (pinned version - check latest at https://github.com/dani-garcia/vaultwarden/releases)
  - Container name: `vaultwarden`
  - Restart policy: `unless-stopped`
  - User: `1000:1000` (non-root execution)
  - Environment variables:
    - `WEBSOCKET_ENABLED=true`
    - `SIGNUPS_ALLOWED=true` (initially true for first account creation, then disable after setup)
    - `DOMAIN={{DOMAIN}}` (template variable)
    - `ADMIN_TOKEN=${ADMIN_TOKEN}` (from .env)
    - `DATABASE_URL=/data/db.sqlite3`
  - Volumes: `./vaultwarden/data:/data`
  - Network: `vaultwarden-network`
  - Label: `com.centurylinklabs.watchtower.enable=false` (Vaultwarden uses version pinning)
  - Resource limits: 1.5 CPU cores, 2GB RAM
- **Caddy Service**:
  - Image: `caddy:latest`
  - Container name: `caddy`
  - Restart policy: `unless-stopped`
  - Ports: 80, 443 (TCP and UDP)
  - Volumes: Caddyfile, data, config directories
  - Network: `vaultwarden-network`
  - Depends on: `vaultwarden`
  - Label: `com.centurylinklabs.watchtower.enable=true`
  - Resource limits: 0.5 CPU cores, 512MB RAM
- **Watchtower Service**:
  - Image: `containrrr/watchtower:latest`
  - Container name: `watchtower`
  - Restart policy: `unless-stopped`
  - Volumes: Docker socket
  - Environment variables:
    - `WATCHTOWER_CLEANUP=true`
    - `WATCHTOWER_POLL_INTERVAL=86400`
    - `WATCHTOWER_INCLUDE_STOPPED=false`
    - `WATCHTOWER_REVIVE_STOPPED=false`
    - `WATCHTOWER_LABEL_ENABLE=true` (enable label-based filtering)
  - Command: `--interval 86400`
  - Resource limits: 0.25 CPU cores, 256MB RAM
- **Network**: `vaultwarden-network` with bridge driver

**Template Variables**:
- `{{DOMAIN}}`: Full domain URL with https:// (e.g., `https://your-domain.com`)

**Usage**: Template is processed with `sed` to replace `{{DOMAIN}}` with actual domain value during deployment.

**Note**: This template is created during execution based on these requirements, not stored in documentation.

## Caddyfile Template (`Caddyfile.template`)

**Template Variables**:
- `{{DOMAIN_NAME}}`: Domain name without https:// (e.g., `your-domain.com`)

## Backup Script Template (`backup.sh.template`)

**Purpose**: Automated backup script for Vaultwarden database and attachments

**Location**: `infrastructure/templates/backup.sh.template`

**Created During**: Step 1: Terraform Setup (for automated) or Step 7: Backup Automation (for manual)

**Requirements** (per spec.md Section 5.1.2):
- **SQLite Database Backup**:
  - **Critical**: Must execute `.backup` command inside the Vaultwarden container via `docker exec` to avoid permission clashes and database locks
  - Command pattern: `docker exec vaultwarden sqlite3 /data/db.sqlite3 ".backup /data/db_backup.sqlite3"`
  - Backup file created inside container at `/data/db_backup.sqlite3`, then copied to host for archiving
  - Ensures backup runs with correct user permissions (UID 1000) and avoids database locking issues
- **Attachments Archive**: Archive attachments directory to tar.gz
- **Backup Manifest**: Create manifest file with metadata (backup timestamp, file sizes, checksums, etc.)
- **Encryption**: Encrypt backup using GPG (AES-256) with passphrase or key-based encryption
- **Upload**: Upload encrypted backup to Google Drive via Rclone
- **Cleanup**: Remove local temporary files after successful upload (including temporary backup file inside container)
- **Retention Policy**: Remove old backups older than retention period (30 days default)

**Usage**: Script is copied from template and executed via crontab for nightly backups.

**Note**: This template is created during execution based on these requirements, not stored in documentation.

## Restore Script (`restore.sh`)

**Purpose**: Restore Vaultwarden data from encrypted backups stored in Google Drive

**Location**: `/opt/vaultwarden/scripts/restore.sh`

**Created During**: Disaster Recovery - Step 2: Create Restore Script

**Requirements**:
- **Usage**: 
  - List backups: `./scripts/restore.sh` (no arguments)
  - Restore backup: `./scripts/restore.sh <backup-filename> [restore-path]`
- **Features**:
  - Downloads encrypted backup from Google Drive using Rclone
  - Decrypts backup using GPG (supports both passphrase and key-based encryption)
  - Extracts and restores database and attachments
  - Automatically stops and starts Vaultwarden container during restore
  - Sets correct file permissions (1000:1000) for restored files
  - Cleans up temporary files after restore
- **Configuration**:
  - `BACKUP_DIR`: `/opt/vaultwarden/backups`
  - `VAULTWARDEN_DATA`: `/opt/vaultwarden/vaultwarden/data`
  - `RCLONE_REMOTE`: From `RCLONE_REMOTE_NAME` environment variable (defaults to `gdrive`)
  - `ENCRYPTION_KEY`: From `BACKUP_ENCRYPTION_KEY` environment variable
- **Error Handling**: Validates backup file exists, checks backup content structure, handles GPG decryption errors

**Environment Variables**:
- `RCLONE_REMOTE_NAME` (defaults to `gdrive`) - Rclone remote name for Google Drive
- `BACKUP_ENCRYPTION_KEY` - GPG passphrase or key ID for decrypting backups

**Note**: This script is created manually during disaster recovery. See [Disaster Recovery - Step 2: Create Restore Script](#step-2-create-restore-script) for creation instructions. The script is created during execution based on these requirements, not stored in documentation.

## Health Check Script Template (`health-check.sh.template`)

**Purpose**: Health monitoring script to verify Vaultwarden service availability

**Location**: `infrastructure/templates/health-check.sh.template`

**Created During**: Step 1: Terraform Setup (for automated) or Step 8: Health Monitoring (for manual)

**Requirements**:
- **Template Variables**:
  - `{{DOMAIN}}`: Full domain URL with https:// (e.g., `https://your-domain.com`)
- **Health Checks**:
  - Check service HTTP response: Verify domain returns HTTP 200 status code
  - Check container status: Verify Vaultwarden container is running
- **Alerting**:
  - Log health check failures with timestamp
  - Send email alert if `ALERT_EMAIL` environment variable is set (optional)
- **Exit Codes**:
  - Exit 0 on success
  - Exit 1 on failure

**Usage**: Script is generated from template and executed via crontab every 15 minutes.

**Note**: This template is created during execution based on these requirements, not stored in documentation.

## Environment Variables Template (`.env.template`)

**Purpose**: Environment variables configuration template for Vaultwarden deployment

**Location**: `infrastructure/templates/.env.template`

**Created During**: Step 1: Terraform Setup (for automated) or Step 2: Configuration (for manual)

**Requirements**:
- **Required Variables**:
  - `ADMIN_TOKEN={{ADMIN_TOKEN}}`: Strong random token (generate with `openssl rand -base64 48`)
  - `DOMAIN={{DOMAIN}}`: Full domain URL with https:// (e.g., `https://your-domain.com`)
  - `BACKUP_ENCRYPTION_KEY={{BACKUP_ENCRYPTION_KEY}}`: GPG passphrase or key ID (generate with `openssl rand -base64 32`)
- **Optional Variables**:
  - `RCLONE_REMOTE_NAME=gdrive`: Rclone remote name (defaults to `gdrive`)
  - `BACKUP_RETENTION_DAYS=30`: Backup retention period in days (defaults to 30)

**Template Variables**:
- `{{ADMIN_TOKEN}}`: Strong random token (generate with `openssl rand -base64 48`)
- `{{DOMAIN}}`: Full domain URL with https:// (e.g., `https://your-domain.com`)
- `{{BACKUP_ENCRYPTION_KEY}}`: GPG passphrase or key ID (generate with `openssl rand -base64 32`)

**Usage**: Template is processed with `sed` to replace template variables with actual values during deployment. Generated `.env` file must have 600 permissions.

**Note**: This template is created during execution based on these requirements, not stored in documentation.

## Resource Tagging Script (`tag-resources.sh`)

**Purpose**: Automate tagging of all Azure resources in a resource group, reusing the same tag structure as Terraform

**Location**: `/opt/vaultwarden/scripts/tag-resources.sh`

**Created During**: Step 1: Terraform Setup (for automated) or Step 9: Resource Tagging & Cost Monitoring (for manual)

**Requirements**:
- **Usage**:
  - Basic: `./scripts/tag-resources.sh <resource-group-name> <owner-email>`
  - With environment: `./scripts/tag-resources.sh <resource-group-name> <owner-email> <environment>` (defaults to "production")
- **Validation**:
  - Verify Azure CLI is installed
  - Verify user is logged in to Azure (`az login`)
  - Verify resource group exists
  - Validate required parameters (resource group name, owner email)
- **Tag Structure** (matches Terraform):
  - **Base tags**: `Project=password-manager`, `Environment=<env>`, `Component=infrastructure`, `ManagedBy=manual`, `CostCenter=personal`
  - **VM-specific tags**: `Component=vaultwarden`, `Backup=enabled`, `Owner=<email>` (overrides base Component)
- **Resource Discovery and Tagging**:
  - Tag Resource Group
  - Discover and tag: Virtual Machine, OS Disk, Network Interface, Public IP Address, Network Security Group, Virtual Network
  - Use Azure CLI to discover resources dynamically
  - Handle missing resources gracefully (warnings, not errors)
- **Error Handling**:
  - Validate Azure CLI availability
  - Validate Azure login status
  - Validate resource group existence
  - Handle resource discovery failures gracefully
- **Progress Reporting**:
  - Display tagging progress for each resource
  - Show success/failure counts
  - Display tagging summary
  - Optionally verify tags by showing VM tags as example

**Features**:
- Automatically discovers and tags all resources: Resource Group, VM, Disk, NIC, Public IP, NSG, VNet
- Uses same tag structure as Terraform (see [Terraform Guide](docs/terraform-guide.md))
- Base tags: `Project=password-manager`, `Environment=<env>`, `Component=infrastructure`, `ManagedBy=manual`, `CostCenter=personal`
- VM-specific tags: `Component=vaultwarden`, `Backup=enabled`, `Owner=<email>`
- Includes error handling, validation, and progress reporting

**Note**: This script is created during execution based on these requirements, not stored in documentation. The script ensures consistency between automated (Terraform) and manual deployments by using the same tag structure.

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
- Generate encryption key: `openssl rand -base64 32`
- Add to `.env`: `BACKUP_ENCRYPTION_KEY=<generated-key>`

**Method 2: GPG with Key Pair** (Recommended for enhanced security)
- Generate GPG key pair: `gpg --full-generate-key`
- Export public key for backup: `gpg --export --armor your-email@example.com > backup-public-key.asc`
- Use key ID in `.env`: `BACKUP_ENCRYPTION_KEY=<key-id-from-gpg-list-keys>`

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
- [ ] **Create first user account via web UI** (signups are enabled by default):
  - Navigate to `https://your-domain.com`
  - Click "Create Account" and register your master account
  - Verify account creation successful
- [ ] **Disable public signups** (security hardening):
  - Edit `.env` file: `nano /opt/vaultwarden/.env` or `vi /opt/vaultwarden/.env`
  - Change `SIGNUPS_ALLOWED=true` to `SIGNUPS_ALLOWED=false`
  - Save and exit
  - Restart Vaultwarden container: `cd /opt/vaultwarden && docker-compose restart vaultwarden`
  - Verify signups disabled: Attempt to access signup page - should be blocked or show error
- [ ] Test login from Bitwarden client with your newly created account
- [ ] Verify WebSocket connection (check real-time sync in Bitwarden client)
- [ ] Check container logs: `docker-compose logs -f`
- [ ] Verify all containers running: `docker-compose ps` (all should show "Up")

**Backup Verification:**
- [ ] Verify backup automation is configured (check crontab: `crontab -l`)
- [ ] Verify health monitoring is configured (check crontab: `crontab -l`)
- [ ] Test backup manually: `cd /opt/vaultwarden && ./scripts/backup.sh`
- [ ] Verify backup in Google Drive: `rclone ls gdrive:vaultwarden-backups/`

### OS Updates Configuration (Optional)

**Estimated Time**: 10-15 minutes

**⚠️ Optional**: This step configures automated OS security updates. Manual updates are also acceptable.

**Automated OS Updates (Recommended for Security):**
- [ ] Install unattended-upgrades: `sudo apt-get install -y unattended-upgrades`
- [ ] Configure unattended-upgrades: `sudo dpkg-reconfigure -plow unattended-upgrades`
- [ ] Verify configuration: `cat /etc/apt/apt.conf.d/50unattended-upgrades | grep -i security`
- [ ] Test update process: `sudo unattended-upgrade --dry-run --debug`

**Manual OS Updates (Alternative):**
- [ ] Update package lists: `sudo apt-get update`
- [ ] Upgrade packages: `sudo apt-get upgrade -y`
- [ ] Reboot if kernel updated: `sudo reboot`

**Note**: Automated updates are recommended to ensure security patches are applied promptly. See [spec.md](spec.md) Section 6.3.1 for details.

### Database Maintenance

**Estimated Time**: 5-10 minutes (monthly task)

**⚠️ Monthly Task**: Perform SQLite maintenance to optimize database performance and reclaim space.

**SQLite Maintenance Operations:**
- [ ] Navigate to deployment directory: `cd /opt/vaultwarden`
- [ ] Vacuum database (reclaim space): `docker exec vaultwarden sqlite3 /data/db.sqlite3 "VACUUM;"`
- [ ] Analyze database (update statistics): `docker exec vaultwarden sqlite3 /data/db.sqlite3 "ANALYZE;"`
- [ ] Integrity check: `docker exec vaultwarden sqlite3 /data/db.sqlite3 "PRAGMA integrity_check;"`
  - Should return "ok" if database is healthy

**Automated Monthly Maintenance (Optional):**
- [ ] Add to crontab (first day of month at 3 AM): `crontab -e`
  ```bash
  0 3 1 * * docker exec vaultwarden sqlite3 /data/db.sqlite3 "VACUUM; ANALYZE;"
  ```

**Note**: See [spec.md](spec.md) Section 6.3.3 for database maintenance requirements.

### Log Retention Configuration

**Estimated Time**: 5-10 minutes

**⚠️ Requirement**: Logs must be retained for 30 days locally and archived in backups (per spec.md Section 4.5.1).

**Configure Log Rotation:**
- [ ] Create log rotation configuration: `sudo nano /etc/logrotate.d/vaultwarden`
- [ ] Add configuration:
  ```bash
  /var/log/vaultwarden-*.log {
      daily
      rotate 30
      compress
      delaycompress
      missingok
      notifempty
      create 0640 root root
  }
  ```
- [ ] Test log rotation: `sudo logrotate -d /etc/logrotate.d/vaultwarden`
- [ ] Verify log files exist: `ls -la /var/log/vaultwarden-*.log`

**Note**: Logs are automatically included in nightly backups. See [spec.md](spec.md) Section 4.5.1 for log retention requirements.

### Documentation Maintenance

**Estimated Time**: Ongoing (as needed)

**⚠️ Best Practice**: Maintain local documentation for configuration tracking and troubleshooting.

**Create CONFIG.md (Initial Setup):**
- [ ] Navigate to deployment directory: `cd /opt/vaultwarden`
- [ ] Create CONFIG.md file: `nano CONFIG.md`
- [ ] Document the following (store securely):
  - Domain name
  - Admin token (store securely, not in plain text)
  - Backup encryption key (store securely, not in plain text)
  - Rclone remote name
  - Custom configurations
  - Important dates (deployment, updates, etc.)

**Create CHANGELOG.md (Ongoing):**
- [ ] Create CHANGELOG.md file: `nano CHANGELOG.md`
- [ ] Track the following:
  - Configuration changes
  - Manual interventions
  - Update dates and versions
  - Known issues
  - Troubleshooting steps taken

**Example CHANGELOG.md format:**
```markdown
# Changelog

## [Date] - Update Description
- Changed: Description of change
- Fixed: Description of fix
- Known Issues: Any ongoing issues
```

**Note**: See [spec.md](spec.md) Section 6.6 for documentation maintenance requirements. Keep CONFIG.md secure (restrict permissions: `chmod 600 CONFIG.md`).
