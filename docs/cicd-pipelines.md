# CI/CD Pipelines Guide

## Overview

CI/CD pipelines automate the deployment process, enabling one-command deployment to any environment with version-controlled infrastructure and automated testing.

## GitHub Actions Workflow

### Workflow Requirements (`.github/workflows/deploy.yml`)

**Purpose**: Automated deployment workflow for infrastructure and application configuration

**Location**: `.github/workflows/deploy.yml`

**Created During**: CI/CD Pipeline Setup (see [plan.md](plan.md) Step 2)

**Workflow Structure Requirements**:

1. **Workflow Triggers**:
   - Trigger on push to `main` branch when paths change: `infrastructure/**`, `docker-compose.yml`, `.github/workflows/deploy.yml`
   - Manual trigger (`workflow_dispatch`) with environment selection (production/staging)

2. **Environment Variables**:
   - Azure credentials: `AZURE_SUBSCRIPTION_ID`, `AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`, `AZURE_TENANT_ID`
   - Loaded from GitHub Secrets

3. **Jobs**:
   - **terraform-plan**: Plan infrastructure changes
     - Checkout code
     - Setup Terraform (version 1.5.0)
     - Run `terraform init`, `terraform validate`, `terraform plan`
     - Upload plan artifact
   - **terraform-apply**: Apply infrastructure (only on main branch)
     - Checkout code
     - Setup Terraform
     - Configure Azure credentials
     - Download plan artifact
     - Run `terraform apply`
     - Get VM public IP from Terraform output
     - Setup SSH agent with private key
     - **Deploy Application Configuration** (see requirements below)
     - **Verify Deployment** (see requirements below)
     - Comment on PR if triggered from pull request

**Deploy Application Configuration Step Requirements**:

This step must SSH into the VM and execute the following operations:

1. **Repository Setup**: Clone or pull repository (contains templates from `infrastructure/templates/`)
2. **Template Verification**: Verify `infrastructure/templates/` directory exists
3. **Environment Variables Generation**:
   - Generate `.env` from template if it doesn't exist
   - Generate `ADMIN_TOKEN` using `openssl rand -base64 48`
   - Generate `BACKUP_ENCRYPTION_KEY` using `openssl rand -base64 32`
   - Replace template variables: `{{ADMIN_TOKEN}}`, `{{DOMAIN}}`, `{{BACKUP_ENCRYPTION_KEY}}`
   - Set `.env` file permissions to 600
4. **Docker Compose Generation**: Generate `docker-compose.yml` from template if it doesn't exist (replace `{{DOMAIN}}`, `{{ADMIN_TOKEN}}`)
5. **Caddyfile Generation**: Generate `caddy/Caddyfile` from template if it doesn't exist (replace `{{DOMAIN_NAME}}`)
6. **Backup Script Deployment**: Copy `backup.sh.template` to `scripts/backup.sh` and make executable
7. **Health Check Script Deployment**: Generate `scripts/health-check.sh` from template (replace `{{DOMAIN}}`) and make executable
8. **Crontab Configuration**: Add crontab entries for nightly backup (2 AM) and health checks (every 15 minutes)
9. **Service Deployment**: Run `docker-compose pull` and `docker-compose up -d`
10. **Container Verification**: Verify all containers are running

**Verify Deployment Step Requirements**:

This step must:
1. Get VM public IP from Terraform output
2. Wait 30 seconds for services to start
3. Perform health check: Test HTTPS endpoint returns HTTP 200 status code
4. Verify containers: Check all containers are running via SSH
5. Exit with error if health check or container verification fails

**Note**: This workflow file is created during execution based on these requirements, not stored in documentation.

### Required GitHub Secrets

Configure these secrets in GitHub repository settings:

- `AZURE_SUBSCRIPTION_ID`: Azure subscription ID
- `AZURE_CLIENT_ID`: Service principal client ID
- `AZURE_CLIENT_SECRET`: Service principal client secret
- `AZURE_TENANT_ID`: Azure tenant ID
- `AZURE_CREDENTIALS`: JSON credentials for Azure login
- `DOMAIN`: Your domain name (e.g., `https://your-domain.com`)
- `SSH_PRIVATE_KEY`: Private SSH key for VM access
- `VM_USERNAME`: VM admin username (e.g., `azureuser`)
- `ALERT_EMAIL`: (Optional) Email for health check alerts

### Setting Up GitHub Secrets

1. Navigate to repository → Settings → Secrets and variables → Actions
2. Click "New repository secret"
3. Add each secret with its corresponding value

## Azure DevOps Pipeline

### Pipeline Requirements (`azure-pipelines.yml`)

**Purpose**: Alternative CI/CD pipeline using Azure DevOps

**Location**: `azure-pipelines.yml`

**Created During**: CI/CD Pipeline Setup (see [plan.md](plan.md) Step 2)

**Pipeline Structure Requirements**:

1. **Triggers**: Trigger on push to `main` branch
2. **Pool**: Use `ubuntu-latest` VM image
3. **Variables**: Load from variable group `password-manager-variables`

4. **Stages**:
   - **Infrastructure Stage**: Deploy infrastructure with Terraform
     - Install Terraform (version 1.5.0)
     - Run Terraform Init & Apply
     - Configure backend: Azure Storage for remote state
     - Working directory: `infrastructure/terraform`
   - **Application Stage**: Deploy application (depends on Infrastructure stage)
     - **Deploy via SSH**: Connect to VM and execute deployment commands
       - Navigate to `/opt/vaultwarden`
       - Pull latest code from repository
       - Pull latest Docker images
       - Start services with `docker-compose up -d`
     - **Health Check**: Verify deployment
       - Test HTTPS endpoint returns HTTP 200 status code
       - Exit with error if health check fails

**Note**: This pipeline file is created during execution based on these requirements, not stored in documentation.

## Deployment Automation Benefits

### Advantages of IaC + CI/CD Approach

1. **Reproducibility**: Same infrastructure can be deployed to any environment
2. **Version Control**: Infrastructure changes tracked in Git
3. **Rollback Capability**: Revert to previous infrastructure state
4. **Multi-Cloud Support**: Same Terraform code works for Azure, AWS, GCP
5. **Cost Optimization**: Infrastructure costs visible in code
6. **Security**: Infrastructure changes reviewed via pull requests
7. **Disaster Recovery**: Complete environment recreation in minutes
8. **Compliance**: Infrastructure as code meets audit requirements

## Pipeline Configuration Examples

### Environment-Specific Deployments

**Instructions**: Configure Terraform variables for different environments:
- Staging: Use `terraform apply -var="environment=staging"`
- Production: Use `terraform apply -var="environment=production"`

### Multi-Cloud Deployment

**Instructions**: Use Terraform with different providers:
- Azure: Use `terraform apply -var="provider=azure"` (default)
- AWS: Use `terraform apply -var="provider=aws"` (requires AWS provider configuration)
- Local: Use `docker-compose up -d` for local testing (no Terraform needed)

## Pipeline Best Practices

1. **Separate Plan and Apply**: Always run plan before apply
2. **Manual Approval**: Require approval for production deployments
3. **Health Checks**: Verify deployment after each step
4. **Rollback Strategy**: Have a plan to rollback if deployment fails
5. **Secret Management**: Use secure secret storage (GitHub Secrets, Azure Key Vault)
6. **Logging**: Enable detailed logging for troubleshooting

## Troubleshooting

### Common Pipeline Issues

**Issue: Terraform authentication fails**
- Verify service principal has correct permissions
- Check Azure credentials in secrets

**Issue: SSH connection fails**
- Verify SSH key is correct
- Check VM network security group allows SSH

**Issue: Health check fails**
- Wait longer for services to start
- Check container logs on VM

## Summary

CI/CD pipelines automate the entire deployment process, from infrastructure provisioning to application deployment and health verification. This enables reliable, repeatable deployments with minimal manual intervention.
