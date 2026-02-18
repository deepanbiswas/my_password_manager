# Deployment Execution Checklist

Quick reference checklist for deploying the self-hosted password manager. For detailed steps and explanations, refer to [spec.md](spec.md).

## Deployment Methods

This checklist supports two deployment approaches:

1. **Automated Deployment (Recommended)**: Using Infrastructure as Code (Terraform) and CI/CD pipelines
2. **Manual Deployment**: Step-by-step manual setup on a pre-provisioned VM

---

## Automated Deployment (Recommended)

### Prerequisites

- [ ] Azure account with subscription and ₹4,500/month credits
- [ ] Domain name registered and DNS access available
- [ ] GitHub account (for CI/CD) or Azure DevOps account
- [ ] Terraform installed locally (>= 1.5.0)
- [ ] Azure CLI installed and configured
- [ ] SSH key pair generated
- [ ] Google Drive account ready for backup storage

### Step 1: Terraform Setup

- [ ] Create `infrastructure/terraform/` directory structure
- [ ] Copy Terraform configuration from [Terraform Guide](docs/terraform-guide.md)
- [ ] Create `terraform.tfvars` with your configuration:
  ```hcl
  location         = "Central India"
  environment      = "production"
  vm_size          = "Standard_B2s"
  admin_username   = "azureuser"
  domain           = "https://your-domain.com"
  ```
- [ ] Configure Azure provider credentials
- [ ] Initialize Terraform: `terraform init`
- [ ] Review plan: `terraform plan`
- [ ] Apply infrastructure: `terraform apply`

### Step 2: CI/CD Pipeline Setup

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

- [ ] Get VM public IP from Terraform output
- [ ] Update DNS A record to point to VM IP
- [ ] Wait for DNS propagation
- [ ] SSH into VM (cloud-init should have completed setup)
- [ ] Verify Docker and dependencies installed: `docker --version`
- [ ] Configure Rclone: `rclone config`
- [ ] Set up `.env` file with secrets (see Manual Deployment Step 2)
- [ ] Deploy application: `docker-compose up -d`

### Step 4: Verification

- [ ] Access admin panel: `https://your-domain.com/admin`
- [ ] Verify HTTPS working (automatic via Caddy)
- [ ] Create first user account via admin panel
- [ ] Test login from Bitwarden client
- [ ] Configure backup automation (see Manual Deployment Step 7)
- [ ] Verify CI/CD pipeline can deploy updates

### Step 5: Ongoing Operations

- [ ] Monitor CI/CD pipeline for automated deployments
- [ ] Infrastructure changes via Terraform (version controlled)
- [ ] Application updates via CI/CD pipeline
- [ ] Review [spec.md](spec.md) Section 6 for maintenance procedures

---

## Manual Deployment (Alternative)

### Pre-Deployment Checklist

- [ ] Azure VM provisioned (Standard_B2s or higher recommended)
- [ ] Domain name registered and DNS access available
- [ ] SSH key pair generated
- [ ] Google Drive account ready for backup storage
- [ ] Review [spec.md](spec.md) Section 3.1 for infrastructure requirements

### Deployment Steps

### 1. Initial Server Setup

- [ ] SSH into VM: `ssh username@vm-ip-address`
- [ ] Run setup script: `./scripts/setup.sh`
- [ ] Verify Docker installed: `docker --version`
- [ ] Verify Docker Compose installed: `docker-compose --version`
- [ ] Verify Rclone installed: `rclone version`

### 2. Configuration

- [ ] Copy `.env.example` to `.env`: `cp .env.example .env`
- [ ] Generate admin token: `openssl rand -base64 48`
- [ ] Update `.env` with domain: `DOMAIN=https://your-domain.com`
- [ ] Update `.env` with admin token: `ADMIN_TOKEN=<generated-token>`
- [ ] Generate backup encryption key: `openssl rand -base64 32`
- [ ] Update `.env` with encryption key: `BACKUP_ENCRYPTION_KEY=<generated-key>`
- [ ] Set file permissions: `chmod 600 .env`

### 3. Rclone Configuration

- [ ] Configure Rclone: `rclone config`
- [ ] Create remote named `gdrive` (or update `RCLONE_REMOTE_NAME` in `.env`)
- [ ] Test connection: `rclone lsd gdrive:`
- [ ] Create backup directory: `rclone mkdir gdrive:vaultwarden-backups`

### 4. DNS Configuration

- [ ] Get VM public IP address
- [ ] Create/update DNS A record pointing to VM IP
- [ ] Wait for DNS propagation (check: `nslookup your-domain.com`)
- [ ] Verify DNS: `dig your-domain.com`

### 5. Deploy Services

- [ ] Copy `docker-compose.yml` to `/opt/vaultwarden/`
- [ ] Copy `caddy/Caddyfile` to `/opt/vaultwarden/caddy/`
- [ ] Update Caddyfile with your domain
- [ ] Start services: `docker-compose up -d`
- [ ] Verify containers running: `docker-compose ps`

### 6. Post-Deployment Verification

- [ ] Access admin panel: `https://your-domain.com/admin`
- [ ] Verify HTTPS working (green lock icon)
- [ ] Create first user account via admin panel
- [ ] Test login from Bitwarden client
- [ ] Verify signups disabled (attempt public signup should fail)
- [ ] Check container logs: `docker-compose logs -f`

### 7. Backup Automation

- [ ] Copy backup script to `/opt/vaultwarden/scripts/backup.sh`
- [ ] Make executable: `chmod +x scripts/backup.sh`
- [ ] Test backup manually: `./scripts/backup.sh`
- [ ] Verify backup in Google Drive: `rclone ls gdrive:vaultwarden-backups/`
- [ ] Add to crontab: `crontab -e`
  ```bash
  0 2 * * * /opt/vaultwarden/scripts/backup.sh >> /var/log/vaultwarden-backup.log 2>&1
  ```

### 8. Health Monitoring (Optional)

- [ ] Copy health check script to `/opt/vaultwarden/scripts/health-check.sh`
- [ ] Make executable: `chmod +x scripts/health-check.sh`
- [ ] Test health check: `./scripts/health-check.sh`
- [ ] Add to crontab (every 15 minutes):
  ```bash
  */15 * * * * /opt/vaultwarden/scripts/health-check.sh >> /var/log/vaultwarden-health.log 2>&1
  ```

## Quick Reference Commands

```bash
# Start services
cd /opt/vaultwarden && docker-compose up -d

# Stop services
docker-compose stop

# View logs
docker-compose logs -f

# Manual backup
./scripts/backup.sh

# Restore backup
./scripts/restore.sh <backup-filename>

# Check health
./scripts/health-check.sh

# Update containers
docker-compose pull && docker-compose up -d
```

## Troubleshooting

If you encounter issues during deployment:

1. Check container logs: `docker-compose logs -f`
2. Verify configuration: `docker-compose config`
3. Check disk space: `df -h`
4. Verify DNS: `nslookup your-domain.com`
5. See [Troubleshooting Guide](docs/troubleshooting.md) for detailed solutions

## Next Steps

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
