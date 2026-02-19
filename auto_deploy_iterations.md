# Test-Driven Infrastructure Deployment: Automated Deployment Iterations

## Introduction

### Scope

**This guide is exclusively for Automated Deployment** using Terraform and CI/CD pipelines. Manual deployment steps are not covered in this iterative plan.

### Purpose

This document provides a Test-Driven Infrastructure (TDI) approach for deploying the self-hosted password manager using automated deployment methods. Each iteration is self-contained, testable, and includes verification scripts to ensure deployment correctness.

### How to Use This Guide

1. **Create folder structure first** - Before running any iteration, create the required folder structure:
   ```bash
   mkdir -p iterations/common \
            iterations/iteration-1-infrastructure \
            iterations/iteration-2-cicd \
            iterations/iteration-3-services \
            iterations/iteration-4-ssl \
            iterations/iteration-5-security \
            iterations/iteration-6-backup \
            iterations/iteration-7-monitoring
   ```
2. **Create scripts during execution** - Scripts are created during execution based on requirements specified in each iteration section. Scripts are not stored in this documentation to allow independent refactoring.
3. **Execute iterations sequentially** - Each iteration builds upon the previous one
4. **Create iteration scripts as needed** - For each iteration, create the `verify.sh` and `rollback.sh` scripts based on the requirements listed in that iteration's section
5. **Run `verify.sh` after each step** - The test script validates that the iteration completed successfully
   - Scripts are located in `iterations/iteration-X-*/verify.sh`
   - Run from the terraform directory: `cd infrastructure/terraform && ../../iterations/iteration-1-infrastructure/verify.sh`
6. **Do not proceed to next iteration** until the current iteration's verification passes
7. **Reference plan.md** - All execution steps reference the "Automated Deployment (Recommended)" section in [plan.md](plan.md)
8. **Use rollback scripts if needed** - Each iteration has a `rollback.sh` script to revert changes if verification fails

### Script Organization

All verification and rollback scripts are organized in a hybrid folder structure that will be created during execution:

```
iterations/
├── common/
│   ├── lib.sh                    # Shared functions (colors, VM connection, SSH helpers)
│   └── config.sh                 # Common configuration (loads terraform outputs)
├── iteration-1-infrastructure/
│   ├── verify.sh                 # Iteration-specific verification
│   └── rollback.sh               # Iteration-specific rollback
├── iteration-2-cicd/
│   ├── verify.sh
│   └── rollback.sh
├── iteration-3-services/
│   ├── verify.sh
│   └── rollback.sh
├── iteration-4-ssl/
│   ├── verify.sh
│   └── rollback.sh
├── iteration-5-security/
│   ├── verify.sh
│   └── rollback.sh
├── iteration-6-backup/
│   ├── verify.sh
│   └── rollback.sh
└── iteration-7-monitoring/
    ├── verify.sh
    └── rollback.sh
```

**Setup Instructions:**

Before running any iteration, you must:

1. **Create the folder structure:**
   ```bash
   mkdir -p iterations/common \
            iterations/iteration-1-infrastructure \
            iterations/iteration-2-cicd \
            iterations/iteration-3-services \
            iterations/iteration-4-ssl \
            iterations/iteration-5-security \
            iterations/iteration-6-backup \
            iterations/iteration-7-monitoring
   ```

2. **Create common library files** - The common library (`lib.sh` and `config.sh`) should be created before running Iteration 1. See Iteration 1 section for requirements.

3. **Create iteration scripts** - Each iteration section contains requirements for what the scripts should do. Create the `verify.sh` and `rollback.sh` files for each iteration based on these requirements as you proceed.

**Note**: Scripts are created during execution based on requirements specified in each iteration section. Scripts are not embedded in this documentation to allow independent refactoring without updating documentation.

**Benefits of this structure:**
- **DRY (Don't Repeat Yourself)**: Common functions are shared via `common/lib.sh`
- **Maintainability**: Update common logic in one place, scripts can be refactored independently
- **Testability**: Scripts are executable independently
- **Clarity**: Each iteration has its own folder
- **Reusability**: Common functions can be used elsewhere
- **Documentation Independence**: Scripts can be refactored without touching MD files

**Running Scripts:**
- All scripts must be run from a directory where Terraform outputs are accessible
- Typically run from `infrastructure/terraform/` directory
- Scripts automatically load VM configuration from Terraform outputs
- Use absolute paths or navigate to the iteration directory before running

### Prerequisites

Same as [plan.md](plan.md) Automated Deployment prerequisites:

- [ ] Azure account with subscription and ₹4,500/month credits
- [ ] Domain name registered and DNS access available
- [ ] GitHub account (for CI/CD) or Azure DevOps account
- [ ] Terraform installed locally (>= 1.5.0)
- [ ] Azure CLI installed and configured
- [ ] SSH key pair generated
- [ ] Google Drive account ready for backup storage

### Reference

All execution steps reference [plan.md](plan.md) "Automated Deployment (Recommended)" section only.

---

## Iteration 1: Infrastructure Foundation

### Objective & Scope

Provision Azure VM with Terraform, configure networking, firewall, and directory structure. This iteration establishes the foundational infrastructure required for all subsequent deployments.

### Execution Reference

[plan.md](plan.md) Automated Deployment → [Step 1: Terraform Setup](plan.md#step-1-terraform-setup)

**Note**: This iteration is part of Automated Deployment workflow only.

### Setup Instructions

**Before running this iteration:**

1. **Create folder structure:**
   ```bash
   mkdir -p iterations/common \
            iterations/iteration-1-infrastructure \
            iterations/iteration-2-cicd \
            iterations/iteration-3-services \
            iterations/iteration-4-ssl \
            iterations/iteration-5-security \
            iterations/iteration-6-backup \
            iterations/iteration-7-monitoring
   ```

2. **Create common library files:**
   - Create `iterations/common/lib.sh` with shared functions (see requirements below)
   - Create `iterations/common/config.sh` with configuration loader (see requirements below)
   - Make both executable: `chmod +x iterations/common/*.sh`

3. **Create iteration scripts:**
   - Create `iterations/iteration-1-infrastructure/verify.sh` (see requirements below)
   - Create `iterations/iteration-1-infrastructure/rollback.sh` (see requirements below)
   - Make both executable: `chmod +x iterations/iteration-1-infrastructure/*.sh`

### Common Library Requirements

**`iterations/common/lib.sh`** - Shared functions library requirements:

This script must provide the following functions and capabilities:

**Required Functions:**
- **Color definitions**: RED, GREEN, YELLOW, NC for colored output
- **`print_header(iteration_name)`**: Print iteration header with separator lines
- **`print_success([message])`**: Print success message with green checkmark
- **`print_failure([message])`**: Print failure message with red X
- **`print_warning([message])`**: Print warning message with yellow warning symbol
- **`print_result(status, [message])`**: Print result based on exit code
- **`print_footer(iteration_name, status)`**: Print iteration footer with pass/fail status
- **`load_vm_config()`**: Load VM configuration from Terraform outputs (PUBLIC_IP, ADMIN_USER, DOMAIN, RESOURCE_GROUP, VM_NAME) and validate
- **`ssh_vm(command)`**: Execute SSH command on VM using loaded configuration
- **`verify_terraform_state()`**: Verify Terraform state is accessible
- **`verify_ssh_connectivity()`**: Verify SSH connectivity to VM
- **`verify_file_on_vm(file_path, [description])`**: Verify file exists on VM
- **`verify_directory_on_vm(dir_path, [description])`**: Verify directory exists on VM
- **`verify_command_on_vm(command, [description])`**: Verify command is installed on VM
- **`verify_container_running(container_name)`**: Verify Docker container is running
- **`exit_with_error([message])`**: Exit script with error message

**Note**: This script is created during execution based on these requirements, not stored in documentation.

**`iterations/common/config.sh`** - Configuration loader requirements:

This script must:
- Source `lib.sh` from the same directory
- Call `load_vm_config()` and handle errors (exit if failed)
- Export the following variables for use in iteration scripts:
  - `PUBLIC_IP`
  - `ADMIN_USER`
  - `DOMAIN`
  - `DOMAIN_NAME`
  - `RESOURCE_GROUP`
  - `VM_NAME`

**Note**: This script is created during execution based on these requirements, not stored in documentation.

### Verification Script Requirements

**`iterations/iteration-1-infrastructure/verify.sh`** must:

1. **Source common library and config**: Load `lib.sh` and `config.sh` from `../common/`
2. **Print iteration header**: Use `print_header()` function
3. **Verify Terraform state**: Check if Terraform state is accessible (warn if not found, fail if not accessible)
4. **Verify VM exists and is running**: Use Azure CLI to check VM status
5. **Verify public IP exists**: Get and validate public IP from Terraform output
6. **Verify SSH connectivity**: Test SSH connection to VM using `verify_ssh_connectivity()`
7. **Verify directory structure**: Check that `/opt/vaultwarden/` and subdirectories exist (caddy, vaultwarden, scripts, backups)
8. **Verify firewall rules**: Check UFW is active and ports 80/443 are open
9. **Verify Docker installed**: Use `verify_command_on_vm()` to check Docker installation
10. **Verify Docker Compose installed**: Use `verify_command_on_vm()` to check Docker Compose installation
11. **Verify required tools**: Check rclone, sqlite3, and gpg are installed
12. **Verify directory permissions**: Check `/opt/vaultwarden/vaultwarden/data` has correct permissions (1000:1000 or admin user)
13. **Print footer**: Use `print_footer()` with "PASSED" status on success
14. **Exit codes**: Exit with 0 on success, 1 on failure

**Note**: This script is created during execution based on these requirements, not stored in documentation.

### Success Criteria

- [ ] VM accessible via SSH
- [ ] All required tools installed (Docker, Docker Compose, rclone, sqlite3, gpg)
- [ ] Directory structure created at `/opt/vaultwarden/`
- [ ] Firewall configured and active (ports 80/443 open)
- [ ] Directory permissions set correctly (1000:1000 for vaultwarden/data)

### Rollback Script Requirements

**`iterations/iteration-1-infrastructure/rollback.sh`** must:

1. **Source common library and config**: Load `lib.sh` and `config.sh` from `../common/`
2. **Check execution context**: Verify script is run from terraform directory (check for terraform.tfstate or main.tf)
3. **Display warning**: Show what resources will be destroyed (VM, NSG, Public IP, NIC, VNet, Resource Group)
4. **Confirmation prompt**: Ask user to confirm with "yes" before proceeding
5. **Destroy infrastructure**: Run `terraform destroy` to remove all resources
6. **Exit gracefully**: Exit with 0 if cancelled, show completion message if successful

**Usage**:
```bash
cd infrastructure/terraform
../../iterations/iteration-1-infrastructure/rollback.sh
```

**Rollback Actions**:
- Removes Virtual Machine
- Removes Network Security Group
- Removes Public IP Address
- Removes Network Interface
- Removes Virtual Network
- Removes Resource Group (if empty)

**Note**: This script is created during execution based on these requirements, not stored in documentation.

---

## Iteration 2: CI/CD Pipeline Setup

### Objective & Scope

Verify CI/CD pipeline configuration exists and is properly structured. This iteration ensures the GitHub Actions workflow file is created and contains the required structure before proceeding with application deployment.

### Execution Reference

[plan.md](plan.md) Automated Deployment → [Step 2: CI/CD Pipeline Setup](plan.md#step-2-cicd-pipeline-setup)

**Note**: This iteration verifies the CI/CD pipeline configuration locally. Infrastructure is deployed in Iteration 1; this verifies the pipeline that will deploy application configuration in Iteration 3.

### Setup Instructions

**Before running this iteration:**

1. **Create iteration scripts:**
   - Create `iterations/iteration-2-cicd/verify.sh` (see instructions below)
   - Create `iterations/iteration-2-cicd/rollback.sh` (see instructions below)
   - Make both executable: `chmod +x iterations/iteration-2-cicd/*.sh`

### Test Script

**Location**: [`iterations/iteration-2-cicd/verify.sh`](iterations/iteration-2-cicd/verify.sh)

**Usage**:
```bash
# Run from repository root
./iterations/iteration-2-cicd/verify.sh
```

**Note**: This script verifies the workflow file structure locally. It does not execute the pipeline or verify GitHub Secrets are configured (those are verified during actual pipeline execution). The script is created during execution based on these requirements, not stored in documentation.

### Verification Script Requirements

**`iterations/iteration-2-cicd/verify.sh`** must:

1. **Source common library and config**: Load `lib.sh` and `config.sh` from `../common/` (if available, or skip if not needed for local file checks)
2. **Print iteration header**: Use `print_header()` function (if available)
3. **Verify workflow file exists**: Check `.github/workflows/deploy.yml` exists in repository root
4. **Verify workflow file is valid YAML**: Validate YAML syntax (using `yamllint`, `yq`, or similar tool - optional warning if tool not available)
5. **Verify workflow structure**: Check workflow file contains required jobs:
   - `terraform-plan` job
   - `terraform-apply` job
6. **Verify workflow steps**: Check `terraform-apply` job contains required steps:
   - Checkout code
   - Setup Terraform
   - Configure Azure credentials
   - Terraform Init
   - Terraform Apply
   - Get VM Public IP
   - Setup SSH
   - Deploy Application Configuration
   - Verify Deployment
7. **Verify workflow triggers**: Check workflow triggers are configured:
   - `on.push.paths` includes `infrastructure/**`, `docker-compose.yml`, `.github/workflows/deploy.yml`
   - `on.workflow_dispatch` is present (manual trigger)
8. **Verify environment variables**: Check workflow references required GitHub Secrets:
   - `AZURE_SUBSCRIPTION_ID`
   - `AZURE_CLIENT_ID`
   - `AZURE_CLIENT_SECRET`
   - `AZURE_TENANT_ID`
   - `AZURE_CREDENTIALS`
   - `DOMAIN`
   - `SSH_PRIVATE_KEY`
   - `VM_USERNAME`
9. **Verify workflow matches requirements**: Compare workflow structure with requirements in [CI/CD Pipelines Guide](docs/cicd-pipelines.md)
10. **Print footer**: Use `print_footer()` with "PASSED" status on success
11. **Exit codes**: Exit with 0 on success, 1 on failure

### Success Criteria

- [ ] Workflow file (`.github/workflows/deploy.yml`) exists
- [ ] Workflow contains required jobs (terraform-plan, terraform-apply)
- [ ] Workflow contains required steps for deployment
- [ ] Workflow structure matches requirements in CI/CD Pipelines Guide
- [ ] Workflow references required GitHub Secrets

### Rollback Script Requirements

**`iterations/iteration-2-cicd/rollback.sh`** must:

1. **Source common library and config**: Load `lib.sh` and `config.sh` from `../common/` (if available)
2. **Display warning**: Show that workflow file will be removed
3. **Confirmation prompt**: Ask user to confirm with "yes" before proceeding
4. **Remove workflow file**: Delete `.github/workflows/deploy.yml` file
5. **Show completion message**: Display instructions to restore (re-create workflow file following instructions in CI/CD Pipelines Guide)

**Usage**:
```bash
# Run from repository root
./iterations/iteration-2-cicd/rollback.sh
```

**Rollback Actions**:
- Removes `.github/workflows/deploy.yml` file

**Note**: This script is created during execution based on these requirements, not stored in documentation.

---

## Iteration 3: Core Services Deployment

### Objective & Scope

Deploy Vaultwarden, Caddy, and Watchtower containers with correct configuration via CI/CD pipeline. This iteration validates that all containers are running with proper security configurations.

### Execution Reference

[plan.md](plan.md) Automated Deployment → [Step 3: Post-Infrastructure Configuration](plan.md#step-3-post-infrastructure-configuration) - CI/CD deployment part

**Note**: This iteration assumes CI/CD pipeline is configured ([Step 2: CI/CD Pipeline Setup](plan.md#step-2-cicd-pipeline-setup)) and handles container deployment.

### Setup Instructions

**Before running this iteration:**

1. **Create iteration scripts:**
   - Create `iterations/iteration-3-services/verify.sh` (see instructions below)
   - Create `iterations/iteration-3-services/rollback.sh` (see instructions below)
   - Make both executable: `chmod +x iterations/iteration-3-services/*.sh`

### Verification Script Requirements

**`iterations/iteration-3-services/verify.sh`** must:

1. **Source common library and config**: Load `lib.sh` and `config.sh` from `../common/`
2. **Print iteration header**: Use `print_header()` function
3. **Verify docker-compose.yml exists**: Use `verify_file_on_vm()` to check file exists
4. **Verify .env file permissions**: Check `.env` file has 600 permissions
5. **Verify all containers running**: Check vaultwarden, caddy, and watchtower containers are running
6. **Verify Vaultwarden runs as non-root**: Check container runs as UID 1000:1000
7. **Verify SIGNUPS_ALLOWED=true**: Check docker-compose.yml has SIGNUPS_ALLOWED=true (for initial setup)
8. **Verify WATCHTOWER_LABEL_ENABLE=true**: Check watchtower environment variable is set
9. **Verify Vaultwarden watchtower label**: Check Vaultwarden has `com.centurylinklabs.watchtower.enable=false` label
10. **Verify containers on same network**: Check all containers are on `vaultwarden-network`
11. **Verify data volumes mounted**: Check Vaultwarden data volume is mounted correctly
12. **Verify database access**: Check Vaultwarden can access database file (optional warning if new deployment)
13. **Print footer**: Use `print_footer()` with "PASSED" status on success
14. **Exit codes**: Exit with 0 on success, 1 on failure

**Usage**:
```bash
cd infrastructure/terraform
../../iterations/iteration-3-services/verify.sh
```

**Note**: This script is created during execution based on these requirements, not stored in documentation.

### Success Criteria

- [ ] All containers running (vaultwarden, caddy, watchtower)
- [ ] Correct user permissions (Vaultwarden runs as UID 1000:1000)
- [ ] Proper configuration (SIGNUPS_ALLOWED=true, WATCHTOWER_LABEL_ENABLE=true)
- [ ] Containers on same Docker network
- [ ] Data volumes mounted correctly

### Rollback Script Requirements

**`iterations/iteration-3-services/rollback.sh`** must:

1. **Source common library and config**: Load `lib.sh` and `config.sh` from `../common/`
2. **Display warning**: Show that containers and volumes will be removed, data will be lost
3. **Confirmation prompt**: Ask user to confirm with "yes" before proceeding
4. **Stop and remove containers**: Run `docker-compose down -v` on VM to stop containers and remove volumes
5. **Show completion message**: Display instructions to restore (re-run CI/CD or manual deployment)

**Usage**:
```bash
cd infrastructure/terraform
../../iterations/iteration-3-services/rollback.sh
```

**Rollback Actions**:
- Stops all containers
- Removes containers
- Removes volumes (data will be lost - ensure backups exist)

**Note**: This script is created during execution based on these requirements, not stored in documentation.

---

## Iteration 4: Reverse Proxy & SSL Configuration

### Objective & Scope

Configure Caddy reverse proxy, obtain SSL certificates, verify HTTPS. This iteration ensures secure external access to the application.

### Execution Reference

[plan.md](plan.md) Automated Deployment → [Step 3: Post-Infrastructure Configuration](plan.md#step-3-post-infrastructure-configuration) ([DNS Configuration](plan.md#dns-configuration) + CI/CD Caddyfile deployment)

**Note**: DNS configuration is manual but required before CI/CD pipeline runs.

### Setup Instructions

**Before running this iteration:**

1. **Create iteration scripts:**
   - Create `iterations/iteration-4-ssl/verify.sh` (see instructions below)
   - Create `iterations/iteration-4-ssl/rollback.sh` (see instructions below)
   - Make both executable: `chmod +x iterations/iteration-4-ssl/*.sh`

### Verification Script Requirements

**`iterations/iteration-4-ssl/verify.sh`** must:

1. **Source common library and config**: Load `lib.sh` and `config.sh` from `../common/`
2. **Validate domain**: Ensure DOMAIN and DOMAIN_NAME are set
3. **Print iteration header**: Use `print_header()` function
4. **Verify DNS A record**: Check DNS points to VM IP using `dig`
5. **Verify Caddyfile exists**: Use `verify_file_on_vm()` to check Caddyfile exists
6. **Verify Caddyfile contains domain**: Check domain name is in Caddyfile
7. **Verify Caddy container running**: Use `verify_container_running()` to check Caddy
8. **Verify SSL certificate obtained**: Check Caddy logs for certificate success (optional warning if provisioning)
9. **Verify HTTPS accessible**: Test HTTPS endpoint returns 200/301/302
10. **Verify HTTP redirects to HTTPS**: Test HTTP redirects to HTTPS (301/302/308)
11. **Verify TLS version**: Check TLS version is 1.2 or 1.3 using openssl
12. **Verify security headers**: Check HSTS and X-Frame-Options headers are present
13. **Verify Content-Security-Policy header**: Check CSP header (optional warning if missing)
14. **Print footer**: Use `print_footer()` with "PASSED" status on success
15. **Exit codes**: Exit with 0 on success, 1 on failure

**Usage**:
```bash
cd infrastructure/terraform
../../iterations/iteration-4-ssl/verify.sh
```

**Note**: This script is created during execution based on these requirements, not stored in documentation.

### Success Criteria

- [ ] HTTPS working and accessible
- [ ] SSL certificate valid and obtained from Let's Encrypt
- [ ] HTTP redirects to HTTPS
- [ ] TLS version 1.2 or 1.3
- [ ] Security headers present (HSTS, X-Frame-Options, CSP)

### Rollback Script Requirements

**`iterations/iteration-4-ssl/rollback.sh`** must:

1. **Source common library and config**: Load `lib.sh` and `config.sh` from `../common/`
2. **Display warning**: Show that Caddyfile will be reverted and Caddy restarted
3. **Confirmation prompt**: Ask user to confirm with "yes" before proceeding
4. **Revert Caddyfile**: Attempt to revert from git, or show manual fix instructions if not in git
5. **Restart Caddy**: Restart Caddy container via docker-compose
6. **Show completion message**: Display instructions for manual fix if git revert failed

**Usage**:
```bash
cd infrastructure/terraform
../../iterations/iteration-4-ssl/rollback.sh
```

**Rollback Actions**:
- Attempts to revert Caddyfile from git
- Restarts Caddy container
- Provides manual fix instructions if git revert fails

**Note**: This script is created during execution based on these requirements, not stored in documentation.

---

## Iteration 5: Security Hardening

### Objective & Scope

Verify security configurations, disable signups after initial account creation. This iteration ensures all security measures are properly implemented and the two-phase signup process works correctly.

### Execution Reference

[plan.md](plan.md) Automated Deployment → [Step 4: Verification & Cost Monitoring](plan.md#step-4-verification--cost-monitoring) → [Post-Deployment Verification](plan.md#post-deployment-verification) (Common Configuration Steps section)

**Note**: Part of automated deployment verification workflow.

### Setup Instructions

**Before running this iteration:**

1. **Create iteration scripts:**
   - Create `iterations/iteration-5-security/verify.sh` (see instructions below)
   - Create `iterations/iteration-5-security/rollback.sh` (see instructions below)
   - Make both executable: `chmod +x iterations/iteration-5-security/*.sh`

### Verification Script Requirements

**`iterations/iteration-5-security/verify.sh`** must:

1. **Source common library and config**: Load `lib.sh` and `config.sh` from `../common/`
2. **Validate domain**: Ensure DOMAIN and DOMAIN_NAME are set
3. **Print iteration header**: Use `print_header()` function
4. **Verify signups enabled initially**: Check SIGNUPS_ALLOWED=true in docker-compose.yml (with note to disable after account creation)
5. **Verify signup endpoint accessible**: Test signup API endpoint is accessible (if signups enabled)
6. **Manual step prompt**: Display instructions for creating initial account and disabling signups, then wait for user confirmation
7. **Verify signups disabled**: Check SIGNUPS_ALLOWED=false after manual step
8. **Verify signup page blocked**: Test signup endpoint is blocked (400/403/404)
9. **Verify firewall rules**: Check UFW is active and only ports 80/443 are open
10. **Verify rate limiting**: Check Caddyfile has rate limiting configured
11. **Verify resource limits**: Check docker-compose.yml has resource limits configured
12. **Verify .env permissions**: Check .env file has 600 permissions
13. **Verify non-root execution**: Check Vaultwarden runs as UID 1000:1000
14. **Verify TLS configuration**: Check Caddyfile has TLS protocols configured (optional warning if defaults apply)
15. **Print footer**: Use `print_footer()` with "PASSED" status on success
16. **Exit codes**: Exit with 0 on success, 1 on failure

**Usage**:
```bash
cd infrastructure/terraform
../../iterations/iteration-5-security/verify.sh
```

**Note**: This script includes a manual step for account creation. Follow the prompts. The script is created during execution based on these requirements, not stored in documentation.

### Success Criteria

- [ ] Signups disabled after initial account creation
- [ ] Firewall secure (only ports 80/443 open)
- [ ] Rate limiting configured
- [ ] Resource limits set
- [ ] .env file permissions correct (600)
- [ ] Non-root execution verified (UID 1000:1000)

### Rollback Script Requirements

**`iterations/iteration-5-security/rollback.sh`** must:

1. **Source common library and config**: Load `lib.sh` and `config.sh` from `../common/`
2. **Display warning**: Show that signups will be re-enabled and security configurations reverted
3. **Confirmation prompt**: Ask user to confirm with "yes" before proceeding
4. **Re-enable signups**: Change SIGNUPS_ALLOWED from false to true in both docker-compose.yml and .env
5. **Restart Vaultwarden**: Restart Vaultwarden container to apply changes
6. **Show completion message**: Display that signups are now re-enabled

**Usage**:
```bash
cd infrastructure/terraform
../../iterations/iteration-5-security/rollback.sh
```

**Rollback Actions**:
- Re-enables signups in docker-compose.yml and .env
- Restarts Vaultwarden container

**Note**: This script is created during execution based on these requirements, not stored in documentation.

---

## Iteration 6: Backup System

### Objective & Scope

Configure backup automation via CI/CD, verify backup script, test backup execution. This iteration ensures the backup system works correctly with container-based SQLite backups and encryption.

### Execution Reference

[plan.md](plan.md) Automated Deployment → [Step 3: Post-Infrastructure Configuration](plan.md#step-3-post-infrastructure-configuration) (CI/CD deploys backup.sh) + [Common Configuration Steps](plan.md#common-configuration-steps) → [Rclone Configuration](plan.md#rclone-configuration)

**Note**: Backup script is deployed by CI/CD pipeline; Rclone configuration is manual prerequisite.

### Setup Instructions

**Before running this iteration:**

1. **Create iteration scripts:**
   - Create `iterations/iteration-6-backup/verify.sh` (see instructions below)
   - Create `iterations/iteration-6-backup/rollback.sh` (see instructions below)
   - Make both executable: `chmod +x iterations/iteration-6-backup/*.sh`

### Test Script

**Location**: [`iterations/iteration-6-backup/verify.sh`](iterations/iteration-6-backup/verify.sh)

**Usage**:
```bash
cd infrastructure/terraform
../../iterations/iteration-6-backup/verify.sh
```

**Note**: This script will execute a test backup. Ensure Rclone is configured before running.

**Verification Script Requirements**:

The `verify.sh` script must perform the following checks:

1. **Verify backup.sh script exists and is executable**: Check file exists at `/opt/vaultwarden/scripts/backup.sh` and has execute permissions
2. **Verify Rclone configured**: Check Rclone remote 'gdrive' is configured using `rclone config show`
3. **Verify backup script uses docker exec**: Check backup script contains `docker exec` command for SQLite backup (container-based backup)
4. **Verify backup encryption key**: Check `BACKUP_ENCRYPTION_KEY` is set in `.env` file
5. **Execute test backup**: Run backup script manually and verify it completes successfully
6. **Verify backup file created**: Check encrypted backup file (`.gpg`) exists locally (may be cleaned up after upload)
7. **Verify backup uploaded to Google Drive**: Check backup file exists in `gdrive:vaultwarden-backups/` using `rclone lsf`
8. **Verify crontab entry**: Check crontab contains entry for nightly backup (runs at 2 AM)
9. **Verify backup manifest creation**: Check backup script contains manifest creation logic
10. **Verify container permissions**: Check backup script handles container-based backup correctly (uses `docker exec`)

**Exit Codes**: Script must exit with 0 on success, 1 on failure.

**Note**: This script is created during execution based on these requirements, not stored in documentation.

### Success Criteria

- [ ] Backup script works and is executable
- [ ] Backups encrypted (GPG)
- [ ] Backups uploaded to Google Drive
- [ ] Cron job configured for nightly backup
- [ ] Backup script uses docker exec for SQLite backup
- [ ] Backup manifest created

### Rollback Script Requirements

**`iterations/iteration-6-backup/rollback.sh`** must:

1. **Source common library and config**: Load `lib.sh` and `config.sh` from `../common/`
2. **Display warning**: Show that backup script and crontab entry will be removed
3. **Confirmation prompt**: Ask user to confirm with "yes" before proceeding
4. **Remove crontab entry**: Remove backup.sh entry from crontab
5. **Remove backup script**: Delete backup.sh script file
6. **Show completion message**: Display instructions to restore (re-run CI/CD or manual deployment)

**Usage**:
```bash
cd infrastructure/terraform
../../iterations/iteration-6-backup/rollback.sh
```

**Rollback Actions**:
- Removes backup script crontab entry
- Removes backup.sh script file

**Note**: This script is created during execution based on these requirements, not stored in documentation.

---

## Iteration 7: Monitoring & Automation

### Objective & Scope

Verify health monitoring (deployed via CI/CD), Watchtower configuration, cost monitoring. This iteration ensures all monitoring and automation systems are working correctly.

### Execution Reference

[plan.md](plan.md) Automated Deployment → [Step 4: Verification & Cost Monitoring](plan.md#step-4-verification--cost-monitoring)

**Note**: Health check script is deployed by CI/CD pipeline; cost monitoring is manual Azure Portal configuration.

### Setup Instructions

**Before running this iteration:**

1. **Create iteration scripts:**
   - Create `iterations/iteration-7-monitoring/verify.sh` (see instructions below)
   - Create `iterations/iteration-7-monitoring/rollback.sh` (see instructions below)
   - Make both executable: `chmod +x iterations/iteration-7-monitoring/*.sh`

### Test Script

**Location**: [`iterations/iteration-7-monitoring/verify.sh`](iterations/iteration-7-monitoring/verify.sh)

**Usage**:
```bash
cd infrastructure/terraform
../../iterations/iteration-7-monitoring/verify.sh
```

**Verification Script Requirements**:

The `verify.sh` script must perform the following checks:

1. **Verify health-check.sh script exists and is executable**: Check file exists at `/opt/vaultwarden/scripts/health-check.sh` and has execute permissions
2. **Verify crontab entry**: Check crontab contains entry for health checks (runs every 15 minutes)
3. **Test health check execution**: Run health check script and verify it returns success status
4. **Verify Watchtower label configuration**: Check Vaultwarden has `com.centurylinklabs.watchtower.enable=false` label and Watchtower has `WATCHTOWER_LABEL_ENABLE=true` environment variable
5. **Verify Watchtower activity**: Check Watchtower logs for update activity (optional warning if no recent activity)
6. **Verify cost monitoring**: Check Azure budgets are configured (requires Azure CLI, optional warning if not accessible)
7. **Verify resource tags**: Check resource group has tags applied (Project=password-manager, etc.)
8. **Verify log retention**: Check logrotate configuration exists for 30-day retention
9. **Verify container restart policies**: Check all containers have restart policy configured (unless-stopped or always)
10. **Verify health check logs**: Check health check log file exists at `/var/log/vaultwarden-health.log`

**Exit Codes**: Script must exit with 0 on success, 1 on failure.

**Note**: This script is created during execution based on these requirements, not stored in documentation.

### Success Criteria

- [ ] Health monitoring active (script exists, cron configured, test passes)
- [ ] Watchtower working correctly (respects labels, can update Caddy)
- [ ] Cost monitoring configured (budgets and alerts)
- [ ] Resource tags applied
- [ ] Log retention configured

### Rollback Script Requirements

**`iterations/iteration-7-monitoring/rollback.sh`** must:

1. **Source common library and config**: Load `lib.sh` and `config.sh` from `../common/`
2. **Display warning**: Show that health check script, crontab entry, and Watchtower will be removed/stopped
3. **Confirmation prompt**: Ask user to confirm with "yes" before proceeding
4. **Remove crontab entry**: Remove health-check.sh entry from crontab
5. **Remove health check script**: Delete health-check.sh script file
6. **Stop and remove Watchtower**: Stop and remove Watchtower container
7. **Show completion message**: Display instructions to restore (re-run CI/CD or manual deployment)

**Usage**:
```bash
cd infrastructure/terraform
../../iterations/iteration-7-monitoring/rollback.sh
```

**Rollback Actions**:
- Removes health check script crontab entry
- Removes health-check.sh script file
- Stops and removes Watchtower container

**Note**: This script is created during execution based on these requirements, not stored in documentation.

---

## Summary

This iterative deployment guide provides a test-driven approach to deploying the self-hosted password manager using automated deployment methods. Each iteration builds upon the previous one, with comprehensive verification scripts to ensure deployment correctness.

### Iteration Dependencies

The iterations follow a linear dependency chain with one parallel path:

**Linear Chain:**
- **Iteration 1** → **Iteration 2** → **Iteration 3** → **Iteration 4** → **Iteration 5**
  - Infrastructure must exist before CI/CD setup
  - CI/CD pipeline needed for application deployment
  - Services must be running before SSL configuration
  - HTTPS needed for security hardening tests

**Parallel Path:**
- **Iteration 6** (Backup System) can run after **Iteration 3** completes (containers must be running for backups)
  - Backup system does not require HTTPS, so it can proceed independently after services are deployed
  - However, it is recommended to complete Iteration 4 (SSL) first for a fully secure environment

**Final Step:**
- **Iteration 7** (Monitoring & Automation) requires all previous iterations to complete

### Key Architectural Validations

Each iteration validates critical architectural requirements:

- ✅ Non-root execution (UID 1000:1000)
- ✅ Watchtower label configuration (WATCHTOWER_LABEL_ENABLE=true)
- ✅ Container-based SQLite backups (docker exec)
- ✅ Two-phase signup process (enable initially, disable after account creation)

### Next Steps

After completing all iterations:

1. Review [plan.md](plan.md) for ongoing operations and maintenance
2. Set up client applications (Bitwarden Desktop/Mobile)
3. Monitor cost alerts and adjust resources if needed
4. Review [spec.md](spec.md) Section 6 for maintenance procedures

---

**Document Version**: 1.0  
**Last Updated**: 2024  
**Scope**: Automated Deployment Only (Terraform + CI/CD)
