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
- [ ] Create templates directory: `mkdir -p infrastructure/terraform/templates`
- [ ] Create `infrastructure/terraform/templates/docker-compose.yml.template` - Copy from [Manual Deployment - Docker Compose Configuration](#docker-compose-configuration-docker-composeyml) and replace:
  - `https://your-domain.com` → `{{DOMAIN}}`
  - `vaultwarden/server:latest` → `vaultwarden/server:1.30.0` (or latest stable version - check [Vaultwarden Releases](https://github.com/dani-garcia/vaultwarden/releases))
  - `com.centurylinklabs.watchtower.enable=true` → `com.centurylinklabs.watchtower.enable=false` (for Vaultwarden service)
  - Keep `${ADMIN_TOKEN}` as-is (will be replaced from .env)
- [ ] Create `infrastructure/terraform/templates/Caddyfile.template` - Copy from [Manual Deployment - Caddyfile Configuration](#caddyfile-configuration-caddycaddyfile) and replace:
  - `your-domain.com` → `{{DOMAIN_NAME}}` (domain without https://)
- [ ] Create `infrastructure/terraform/templates/backup.sh.template` - Copy from [Manual Deployment - Backup Script](#backup-script-optvaultwardenscriptsbackupsh)
- [ ] Create `infrastructure/terraform/templates/health-check.sh.template` - Copy from [Manual Deployment - Health Check Script](#health-check-script-optvaultwardenscriptshealth-checksh) and replace:
  - `https://your-domain.com` → `{{DOMAIN}}`
- [ ] Create `infrastructure/terraform/templates/.env.template` with:
  ```bash
  ADMIN_TOKEN={{ADMIN_TOKEN}}
  DOMAIN={{DOMAIN}}
  BACKUP_ENCRYPTION_KEY={{BACKUP_ENCRYPTION_KEY}}
  RCLONE_REMOTE_NAME=gdrive
  BACKUP_RETENTION_DAYS=30
  ```
- [ ] **Note**: These templates will be used by both CI/CD pipeline and manual deployment to generate deployment files with environment-specific values

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

**Note**: The CI/CD pipeline automatically handles most configuration steps. Manual steps are only required for Rclone configuration.

- [ ] Get VM public IP from Terraform output: `terraform output vm_public_ip`
- [ ] Update DNS A record to point to VM IP
- [ ] Wait for DNS propagation (check: `nslookup your-domain.com`)
- [ ] **Configure Rclone** (manual step required): SSH into VM and run `rclone config`
  - This step cannot be fully automated as it requires interactive authentication
  - After Rclone is configured, the CI/CD pipeline will handle the rest
- [ ] Push code to trigger CI/CD pipeline (or wait for automatic trigger)
- [ ] Monitor pipeline execution - it will automatically:
  - Generate `.env` file with secrets (admin token, encryption key)
  - Create `docker-compose.yml` and `caddy/Caddyfile`
  - Deploy backup and health check scripts
  - Set up crontab entries
  - Start all services

### Step 4: Verification

- [ ] Verify CI/CD pipeline completed successfully (check GitHub Actions)
- [ ] Access admin panel: `https://your-domain.com/admin`
- [ ] Verify HTTPS working (automatic via Caddy)
- [ ] Create first user account via admin panel (using `ADMIN_TOKEN` from `.env`)
- [ ] Test login from Bitwarden client
- [ ] Verify backup automation is configured (check crontab: `crontab -l`)
- [ ] Verify health monitoring is configured (check crontab: `crontab -l`)
- [ ] Test backup manually: `ssh into VM && /opt/vaultwarden/scripts/backup.sh`
- [ ] Verify backup in Google Drive: `rclone ls gdrive:vaultwarden-backups/`

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
- [ ] Create scripts directory: `mkdir -p /opt/vaultwarden/scripts`
- [ ] Create setup script: Create file `/opt/vaultwarden/scripts/setup.sh` with the content below
- [ ] Make setup script executable: `chmod +x /opt/vaultwarden/scripts/setup.sh`
- [ ] Navigate to deployment directory: `cd /opt/vaultwarden`
- [ ] Run setup script: `./scripts/setup.sh`
- [ ] Verify Docker installed: `docker --version`
- [ ] Verify Docker Compose installed: `docker-compose --version`
- [ ] Verify Rclone installed: `rclone version`
- [ ] Verify firewall is configured: `sudo ufw status verbose`

**Create Setup Script (`/opt/vaultwarden/scripts/setup.sh`):**

Create this file on the VM before running it. You can use `nano`, `vi`, or copy-paste the content:

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

- [ ] Create `docker-compose.yml` at `/opt/vaultwarden/` (see Docker Compose Configuration below)
- [ ] Create `caddy/Caddyfile` at `/opt/vaultwarden/caddy/` (see Caddyfile Configuration below)
- [ ] Update Caddyfile with your domain
- [ ] Start services: `docker-compose up -d`
- [ ] Verify containers running: `docker-compose ps`

**Docker Compose Configuration (`docker-compose.yml`):**

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
      - DOMAIN=https://your-domain.com
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

**Caddyfile Configuration (`caddy/Caddyfile`):**

```
your-domain.com {
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
http://your-domain.com {
    redir https://your-domain.com{uri} permanent
}
```

**Note**: For Nginx alternative configuration, see [Reverse Proxy Comparison](docs/reverse-proxy-comparison.md).

### 6. Post-Deployment Verification

- [ ] Access admin panel: `https://your-domain.com/admin`
- [ ] Verify HTTPS working (green lock icon)
- [ ] Create first user account via admin panel
- [ ] Test login from Bitwarden client
- [ ] Verify signups disabled (attempt public signup should fail)
- [ ] Check container logs: `docker-compose logs -f`

### 7. Backup Automation

**Option A: Using Templates (Recommended - if repository is cloned on VM):**
- [ ] Create scripts directory: `mkdir -p /opt/vaultwarden/scripts`
- [ ] Copy backup script from template: `cp infrastructure/terraform/templates/backup.sh.template /opt/vaultwarden/scripts/backup.sh`
- [ ] Make executable: `chmod +x /opt/vaultwarden/scripts/backup.sh`
- [ ] Test backup manually: `cd /opt/vaultwarden && ./scripts/backup.sh`
- [ ] Verify backup in Google Drive: `rclone ls gdrive:vaultwarden-backups/`
- [ ] Add to crontab: `crontab -e`
  ```bash
  0 2 * * * /opt/vaultwarden/scripts/backup.sh >> /var/log/vaultwarden-backup.log 2>&1
  ```

**Option B: Manual Creation (Alternative - if templates not available):**
- [ ] Create scripts directory (if not exists): `mkdir -p /opt/vaultwarden/scripts`
- [ ] Create backup script: Create file `/opt/vaultwarden/scripts/backup.sh` with the content below
- [ ] Make executable: `chmod +x /opt/vaultwarden/scripts/backup.sh`
- [ ] Test backup manually: `cd /opt/vaultwarden && ./scripts/backup.sh`
- [ ] Verify backup in Google Drive: `rclone ls gdrive:vaultwarden-backups/`
- [ ] Add to crontab: `crontab -e`
  ```bash
  0 2 * * * /opt/vaultwarden/scripts/backup.sh >> /var/log/vaultwarden-backup.log 2>&1
  ```

**Backup Script (`/opt/vaultwarden/scripts/backup.sh`):**

Create this file on the VM if not using templates. Copy the content below:

```bash
#!/bin/bash
set -e

# Configuration
BACKUP_DIR="/opt/vaultwarden/backups"
VAULTWARDEN_DATA="/opt/vaultwarden/vaultwarden/data"
RCLONE_REMOTE="${RCLONE_REMOTE_NAME:-gdrive}"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"
ENCRYPTION_KEY="${BACKUP_ENCRYPTION_KEY}"

# Timestamp for backup filename
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="vaultwarden_backup_${TIMESTAMP}"
BACKUP_PATH="${BACKUP_DIR}/${BACKUP_NAME}"

# Create backup directory
mkdir -p "${BACKUP_PATH}"

# Backup SQLite database
echo "[$(date)] Starting database backup..."
sqlite3 "${VAULTWARDEN_DATA}/db.sqlite3" ".backup '${BACKUP_PATH}/db.sqlite3'"

# Backup attachments
echo "[$(date)] Starting attachments backup..."
if [ -d "${VAULTWARDEN_DATA}/attachments" ]; then
    tar -czf "${BACKUP_PATH}/attachments.tar.gz" -C "${VAULTWARDEN_DATA}" attachments
fi

# Create backup manifest
cat > "${BACKUP_PATH}/manifest.json" <<EOF
{
    "timestamp": "${TIMESTAMP}",
    "date": "$(date -Iseconds)",
    "database": "db.sqlite3",
    "attachments": "attachments.tar.gz",
    "version": "1.0"
}
EOF

# Create archive
echo "[$(date)] Creating backup archive..."
cd "${BACKUP_DIR}"
tar -czf "${BACKUP_NAME}.tar.gz" "${BACKUP_NAME}"

# Encrypt backup
echo "[$(date)] Encrypting backup..."
if [ -n "${ENCRYPTION_KEY}" ]; then
    # Using GPG with passphrase
    gpg --batch --yes --passphrase "${ENCRYPTION_KEY}" \
        --symmetric --cipher-algo AES256 \
        "${BACKUP_NAME}.tar.gz"
    ENCRYPTED_FILE="${BACKUP_NAME}.tar.gz.gpg"
else
    # Using GPG with key ID
    gpg --encrypt --recipient "${ENCRYPTION_KEY}" \
        --output "${BACKUP_NAME}.tar.gz.gpg" \
        "${BACKUP_NAME}.tar.gz"
fi

# Upload to Google Drive
echo "[$(date)] Uploading to Google Drive..."
rclone copy "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz.gpg" \
    "${RCLONE_REMOTE}:vaultwarden-backups/" \
    --log-file="${BACKUP_DIR}/rclone.log"

# Clean up local files
echo "[$(date)] Cleaning up local files..."
rm -rf "${BACKUP_PATH}"
rm -f "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
rm -f "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz.gpg"

# Clean up old backups from Google Drive (retention policy)
echo "[$(date)] Applying retention policy (${RETENTION_DAYS} days)..."
rclone delete "${RCLONE_REMOTE}:vaultwarden-backups/" \
    --min-age "${RETENTION_DAYS}d" \
    --log-file="${BACKUP_DIR}/rclone.log"

echo "[$(date)] Backup completed successfully"
```

**Backup Encryption Key Setup:**

**Method 1: GPG with Passphrase**

```bash
# Generate encryption passphrase
BACKUP_ENCRYPTION_KEY=$(openssl rand -base64 32)
echo "BACKUP_ENCRYPTION_KEY=${BACKUP_ENCRYPTION_KEY}" >> .env
```

**Method 2: GPG with Key Pair**

```bash
# Generate GPG key pair
gpg --full-generate-key
# Export public key for backup
gpg --export --armor your-email@example.com > backup-public-key.asc
# Use key ID in .env
BACKUP_ENCRYPTION_KEY=<key-id-from-gpg-list-keys>
```

### 8. Health Monitoring (Optional)

**Option A: Using Templates (Recommended - if repository is cloned on VM):**
- [ ] Generate health check script from template:
  ```bash
  cd /opt/vaultwarden
  source .env  # Load DOMAIN variable
  sed "s|{{DOMAIN}}|${DOMAIN}|g" \
      infrastructure/terraform/templates/health-check.sh.template > scripts/health-check.sh
  chmod +x scripts/health-check.sh
  ```
- [ ] Test health check: `./scripts/health-check.sh`
- [ ] Add to crontab (every 15 minutes):
  ```bash
  */15 * * * * /opt/vaultwarden/scripts/health-check.sh >> /var/log/vaultwarden-health.log 2>&1
  ```

**Option B: Manual Creation (Alternative - if templates not available):**
- [ ] Create health check script: Create file `/opt/vaultwarden/scripts/health-check.sh` with the content below
- [ ] Make executable: `chmod +x /opt/vaultwarden/scripts/health-check.sh`
- [ ] Test health check: `./scripts/health-check.sh`
- [ ] Add to crontab (every 15 minutes):
  ```bash
  */15 * * * * /opt/vaultwarden/scripts/health-check.sh >> /var/log/vaultwarden-health.log 2>&1
  ```

**Health Check Script (`/opt/vaultwarden/scripts/health-check.sh`):**

Create this file on the VM if not using templates. Copy the content below:

```bash
#!/bin/bash

DOMAIN="${DOMAIN:-https://your-domain.com}"
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

## Cost Monitoring Setup

After deployment, set up cost monitoring to track resource usage:

### Azure Cost Alerts

- [ ] Navigate to Azure Portal → Cost Management + Billing
- [ ] Create budget alert at ₹4,000 (89% of monthly credits) - early warning
- [ ] Create critical alert at ₹4,400 (98% of monthly credits) - immediate action needed
- [ ] Set up email notifications
- [ ] Configure daily cost reports

### Tag-based Cost Analysis

Use Azure CLI to query costs by tag:

```bash
# Query costs by tag using Azure CLI
az consumption usage list \
  --start-date 2024-01-01 \
  --end-date 2024-01-31 \
  --query "[?tags.Project=='password-manager']"
```

For detailed cost analysis and optimization strategies, see [Cost Analysis](docs/cost-analysis.md).

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
```

## Disaster Recovery

### Restore Procedure

**Step 1: Prepare New Environment**

- [ ] On new VM, create setup script: Create file `/opt/vaultwarden/scripts/setup.sh` (see Setup Script in Section 1 above)
- [ ] Make executable: `chmod +x /opt/vaultwarden/scripts/setup.sh`
- [ ] Run setup script: `cd /opt/vaultwarden && ./scripts/setup.sh`
- [ ] Configure Rclone: `rclone config`
- [ ] Set encryption key in `.env`: `echo "BACKUP_ENCRYPTION_KEY=<your-key>" >> /opt/vaultwarden/.env`

**Step 2: List Available Backups**

- [ ] Navigate to deployment directory: `cd /opt/vaultwarden`
- [ ] Run restore script without arguments to list backups: `./scripts/restore.sh`
- [ ] Note the backup filename you want to restore

**Step 3: Execute Restore**

- [ ] Create scripts directory (if not exists): `mkdir -p /opt/vaultwarden/scripts`
- [ ] Create restore script: Create file `/opt/vaultwarden/scripts/restore.sh` with the content below
- [ ] Make executable: `chmod +x /opt/vaultwarden/scripts/restore.sh`
- [ ] Navigate to deployment directory: `cd /opt/vaultwarden`
- [ ] Execute restore: `./scripts/restore.sh vaultwarden_backup_YYYYMMDD_HHMMSS.tar.gz.gpg`

**Step 4: Verify Restore**

- [ ] Access `https://your-domain.com`
- [ ] Verify user accounts are present
- [ ] Verify password entries are accessible
- [ ] Check attachment storage

**Restore Script (`/opt/vaultwarden/scripts/restore.sh`):**

Create this file on the VM. Copy the content below:

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

### Backup Verification

**Monthly Verification Procedure:**

- [ ] Download latest backup from Google Drive: `rclone copy gdrive:vaultwarden-backups/latest-backup.tar.gz.gpg ./`
- [ ] Decrypt backup: `gpg --decrypt latest-backup.tar.gz.gpg > latest-backup.tar.gz`
- [ ] Extract backup: `tar -xzf latest-backup.tar.gz`
- [ ] Verify database integrity: `sqlite3 db.sqlite3 "PRAGMA integrity_check;"`
- [ ] Verify attachment files are present: `ls -la attachments/`
- [ ] (Optional) Test restore on isolated test environment

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
