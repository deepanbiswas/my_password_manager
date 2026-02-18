# CI/CD Pipelines Guide

## Overview

CI/CD pipelines automate the deployment process, enabling one-command deployment to any environment with version-controlled infrastructure and automated testing.

## GitHub Actions Workflow

### Complete Workflow (`.github/workflows/deploy.yml`)

```yaml
name: Deploy Password Manager

on:
  push:
    branches:
      - main
    paths:
      - 'infrastructure/**'
      - 'docker-compose.yml'
      - '.github/workflows/deploy.yml'
  workflow_dispatch:
    inputs:
      environment:
        description: 'Deployment environment'
        required: true
        default: 'production'
        type: choice
        options:
          - production
          - staging

env:
  AZURE_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
  AZURE_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
  AZURE_CLIENT_SECRET: ${{ secrets.AZURE_CLIENT_SECRET }}
  AZURE_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}

jobs:
  terraform-plan:
    name: Terraform Plan
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: ./infrastructure/terraform
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.5.0
      
      - name: Terraform Init
        run: terraform init
      
      - name: Terraform Validate
        run: terraform validate
      
      - name: Terraform Plan
        run: terraform plan -out=tfplan
        env:
          TF_VAR_domain: ${{ secrets.DOMAIN }}
      
      - name: Upload Terraform Plan
        uses: actions/upload-artifact@v3
        with:
          name: terraform-plan
          path: infrastructure/terraform/tfplan

  terraform-apply:
    name: Terraform Apply
    needs: terraform-plan
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    defaults:
      run:
        working-directory: ./infrastructure/terraform
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.5.0
      
      - name: Configure Azure credentials
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      
      - name: Terraform Init
        run: terraform init
      
      - name: Download Terraform Plan
        uses: actions/download-artifact@v3
        with:
          name: terraform-plan
      
      - name: Terraform Apply
        run: terraform apply -auto-approve tfplan
        env:
          TF_VAR_domain: ${{ secrets.DOMAIN }}
      
      - name: Get VM Public IP
        id: vm-ip
        run: |
          VM_IP=$(terraform output -raw vm_public_ip)
          echo "vm_ip=$VM_IP" >> $GITHUB_OUTPUT
      
      - name: Setup SSH
        uses: webfactory/ssh-agent@v0.7.0
        with:
          ssh-private-key: ${{ secrets.SSH_PRIVATE_KEY }}
      
      - name: Deploy Application Configuration
        run: |
          ssh -o StrictHostKeyChecking=no ${{ secrets.VM_USERNAME }}@${{ steps.vm-ip.outputs.vm_ip }} << 'EOF'
            set -e
            cd /opt/vaultwarden
            
            # Clone or pull repository (contains templates)
            if [ -d .git ]; then
              git pull origin main
            else
              git clone https://github.com/${{ github.repository }}.git .
            fi
            
            # Verify templates directory exists
            if [ ! -d "infrastructure/templates" ]; then
              echo "Error: Templates directory not found. Ensure templates are committed to repository."
              exit 1
            fi
            
            # Generate secrets if .env doesn't exist
            if [ ! -f .env ]; then
              ADMIN_TOKEN=$(openssl rand -base64 48)
              BACKUP_ENCRYPTION_KEY=$(openssl rand -base64 32)
              
              # Generate .env from template
              sed -e "s|{{ADMIN_TOKEN}}|${ADMIN_TOKEN}|g" \
                  -e "s|{{DOMAIN}}|${{ secrets.DOMAIN }}|g" \
                  -e "s|{{BACKUP_ENCRYPTION_KEY}}|${BACKUP_ENCRYPTION_KEY}|g" \
                  infrastructure/templates/.env.template > .env
              chmod 600 .env
            fi
            
            # Source .env for variable substitution
            set -a
            source .env
            set +a
            
            # Generate docker-compose.yml from template if it doesn't exist
            if [ ! -f docker-compose.yml ]; then
              sed -e "s|{{DOMAIN}}|${DOMAIN}|g" \
                  -e "s|{{ADMIN_TOKEN}}|${ADMIN_TOKEN}|g" \
                  infrastructure/templates/docker-compose.yml.template > docker-compose.yml
            fi
            
            # Generate Caddyfile from template if it doesn't exist
            mkdir -p caddy
            DOMAIN_NAME=$(echo ${DOMAIN} | sed 's|https\?://||')
            if [ ! -f caddy/Caddyfile ]; then
              sed "s|{{DOMAIN_NAME}}|${DOMAIN_NAME}|g" \
                  infrastructure/templates/Caddyfile.template > caddy/Caddyfile
            fi
            
            # Deploy backup script from template if it doesn't exist
            if [ ! -f scripts/backup.sh ]; then
              mkdir -p scripts
              cp infrastructure/templates/backup.sh.template scripts/backup.sh
              chmod +x scripts/backup.sh
            fi
            
            # Deploy health check script from template if it doesn't exist
            if [ ! -f scripts/health-check.sh ]; then
              sed "s|{{DOMAIN}}|${DOMAIN}|g" \
                  infrastructure/templates/health-check.sh.template > scripts/health-check.sh
              chmod +x scripts/health-check.sh
            fi
            
            # Setup crontab entries if not already present
            (crontab -l 2>/dev/null | grep -v "backup.sh" | grep -v "health-check.sh"; \
             echo "0 2 * * * /opt/vaultwarden/scripts/backup.sh >> /var/log/vaultwarden-backup.log 2>&1"; \
             echo "*/15 * * * * /opt/vaultwarden/scripts/health-check.sh >> /var/log/vaultwarden-health.log 2>&1") | crontab -
            
            # Pull latest images and start services
            docker-compose pull
            docker-compose up -d
            
            # Verify containers are running
            sleep 5
            docker-compose ps
          EOF
      
      - name: Verify Deployment
        run: |
          VM_IP=$(terraform output -raw vm_public_ip)
          sleep 30  # Wait for services to start
          
          # Health check
          HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" https://${{ secrets.DOMAIN }})
          if [ "$HTTP_CODE" != "200" ]; then
            echo "Health check failed: HTTP $HTTP_CODE"
            exit 1
          fi
          
          # Verify containers are running
          ssh -o StrictHostKeyChecking=no ${{ secrets.VM_USERNAME }}@$VM_IP "docker-compose -f /opt/vaultwarden/docker-compose.yml ps | grep -q 'Up' || exit 1"
          
          echo "✅ Deployment verified successfully"
      
      - name: Comment PR
        if: github.event_name == 'pull_request'
        uses: actions/github-script@v6
        with:
          script: |
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: '✅ Deployment completed successfully!'
            })
```

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

### Complete Pipeline (`azure-pipelines.yml`)

```yaml
trigger:
  branches:
    include:
      - main

pool:
  vmImage: 'ubuntu-latest'

variables:
  - group: password-manager-variables

stages:
  - stage: Infrastructure
    displayName: 'Deploy Infrastructure'
    jobs:
      - job: Terraform
        displayName: 'Terraform Apply'
        steps:
          - task: TerraformInstaller@0
            displayName: 'Install Terraform'
            inputs:
              terraformVersion: '1.5.0'
          
          - task: TerraformTaskV3@3
            displayName: 'Terraform Init & Apply'
            inputs:
              provider: 'azurerm'
              command: 'apply'
              workingDirectory: '$(System.DefaultWorkingDirectory)/infrastructure/terraform'
              backendServiceArm: 'Azure-Service-Connection'
              backendAzureRmResourceGroupName: 'terraform-state-rg'
              backendAzureRmStorageAccountName: 'tfstate$(unique-id)'
              backendAzureRmContainerName: 'tfstate'
              backendAzureRmKey: 'password-manager.terraform.tfstate'
  
  - stage: Application
    displayName: 'Deploy Application'
    dependsOn: Infrastructure
    jobs:
      - job: Deploy
        displayName: 'Deploy Vaultwarden'
        steps:
          - task: SSH@0
            displayName: 'Deploy via SSH'
            inputs:
              sshEndpoint: 'VM-SSH-Connection'
              runOptions: 'commands'
              commands: |
                cd /opt/vaultwarden
                git pull origin main
                docker-compose pull
                docker-compose up -d
          
          - task: PowerShell@2
            displayName: 'Health Check'
            inputs:
              targetType: 'inline'
              script: |
                $response = Invoke-WebRequest -Uri "https://$(domain)" -UseBasicParsing
                if ($response.StatusCode -ne 200) { exit 1 }
```

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

```yaml
# Deploy to staging
terraform apply -var="environment=staging"

# Deploy to production
terraform apply -var="environment=production"
```

### Multi-Cloud Deployment

```bash
# Deploy to Azure
terraform apply -var="provider=azure"

# Deploy to AWS (same code, different provider)
terraform apply -var="provider=aws"

# Deploy to local machine (Docker only)
docker-compose up -d
```

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
