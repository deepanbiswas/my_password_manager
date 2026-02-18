# Terraform Infrastructure as Code Guide

## Overview

Terraform enables automated infrastructure provisioning for the password manager setup. This guide provides complete Terraform configurations for deploying the infrastructure on Azure.

## Terraform Configuration Structure

```
infrastructure/
├── terraform/
│   ├── main.tf                 # Main infrastructure definition
│   ├── variables.tf            # Input variables
│   ├── outputs.tf              # Output values
│   ├── providers.tf            # Provider configuration
│   ├── vm.tf                   # VM resource definition
│   ├── network.tf              # Network security group
│   └── tags.tf                 # Resource tagging
├── terraform.tfvars.example    # Example variable values
└── terraform.tfstate           # State file (gitignored)
```

## Complete Terraform Configuration

### Main Configuration (`infrastructure/terraform/main.tf`)

```hcl
terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
  
  # Optional: Remote state backend (Azure Storage)
  backend "azurerm" {
    resource_group_name  = "terraform-state-rg"
    storage_account_name = "tfstate<unique-id>"
    container_name       = "tfstate"
    key                  = "password-manager.terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = "rg-password-manager-${var.environment}"
  location = var.location
  
  tags = {
    Project     = "password-manager"
    Environment = var.environment
    Component   = "infrastructure"
    ManagedBy   = "terraform"
    CostCenter  = "personal"
  }
}

# Virtual Network
resource "azurerm_virtual_network" "main" {
  name                = "vnet-password-manager"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  
  tags = azurerm_resource_group.main.tags
}

# Subnet
resource "azurerm_subnet" "main" {
  name                 = "subnet-password-manager"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Network Security Group
resource "azurerm_network_security_group" "main" {
  name                = "nsg-password-manager"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  
  security_rule {
    name                       = "AllowHTTP"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  
  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  
  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  
  tags = azurerm_resource_group.main.tags
}

# Public IP
resource "azurerm_public_ip" "main" {
  name                = "pip-password-manager"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Basic"
  
  tags = azurerm_resource_group.main.tags
}

# Network Interface
resource "azurerm_network_interface" "main" {
  name                = "nic-password-manager"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.main.id
  }
  
  tags = azurerm_resource_group.main.tags
}

# Associate NSG with NIC
resource "azurerm_network_interface_security_group_association" "main" {
  network_interface_id      = azurerm_network_interface.main.id
  network_security_group_id = azurerm_network_security_group.main.id
}

# Virtual Machine
resource "azurerm_linux_virtual_machine" "main" {
  name                = "vm-password-manager"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  size                = var.vm_size
  admin_username      = var.admin_username
  
  network_interface_ids = [
    azurerm_network_interface.main.id
  ]
  
  admin_ssh_key {
    username   = var.admin_username
    public_key = file(var.ssh_public_key_path)
  }
  
  os_disk {
    name                 = "osdisk-password-manager"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 64
  }
  
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
  
  # Custom data script for initial setup
  custom_data = base64encode(templatefile("${path.module}/scripts/cloud-init.sh", {
    domain = var.domain
  }))
  
  tags = merge(azurerm_resource_group.main.tags, {
    Component = "vaultwarden"
    Backup    = "enabled"
  })
}

# Outputs
output "vm_public_ip" {
  value       = azurerm_public_ip.main.ip_address
  description = "Public IP address of the VM"
}

output "vm_ssh_command" {
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.main.ip_address}"
  description = "SSH command to connect to the VM"
}
```

### Variables File (`infrastructure/terraform/variables.tf`)

```hcl
variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "Central India"
}

variable "environment" {
  description = "Environment name (production, staging, development)"
  type        = string
  default     = "production"
}

variable "vm_size" {
  description = "VM size SKU"
  type        = string
  default     = "Standard_B2s"
}

variable "admin_username" {
  description = "Admin username for VM"
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key file"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "domain" {
  description = "Domain name for Vaultwarden"
  type        = string
}
```

## Cloud-Init Script

### Purpose

The `cloud-init.sh` script is a bootstrap automation script that runs automatically on the first boot of a newly provisioned Azure VM. It eliminates the need for manual SSH access and setup by automatically installing all required dependencies (Docker, Docker Compose, Rclone, GPG, SQLite), creating directory structures, and configuring the firewall. This enables true zero-touch infrastructure provisioning when combined with Terraform and CI/CD pipelines.

### Cloud-Init Script (`infrastructure/terraform/scripts/cloud-init.sh`)

```bash
#!/bin/bash
# This script runs on first boot via cloud-init

# Update system
apt-get update && apt-get upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
usermod -aG docker ${admin_username}

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install Rclone
curl https://rclone.org/install.sh | bash

# Install GPG and SQLite CLI
apt-get install -y gnupg2 sqlite3

# Create directory structure
mkdir -p /opt/vaultwarden/{caddy/{data,config},vaultwarden/data,scripts,backups}
chown -R ${admin_username}:${admin_username} /opt/vaultwarden

# Configure firewall
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

# Log completion
echo "Cloud-init completed at $(date)" >> /var/log/cloud-init.log
```

## Step-by-Step Implementation

### 1. Prerequisites

- Azure account with subscription
- Terraform installed (>= 1.5.0)
- Azure CLI configured
- SSH key pair generated

### 2. Initialize Terraform

```bash
cd infrastructure/terraform
terraform init
```

### 3. Create terraform.tfvars

```hcl
location     = "Central India"
environment  = "production"
vm_size      = "Standard_B2s"
admin_username = "azureuser"
ssh_public_key_path = "~/.ssh/id_rsa.pub"
domain       = "https://your-domain.com"
```

### 4. Plan Infrastructure

```bash
terraform plan -out=tfplan
```

### 5. Apply Infrastructure

```bash
terraform apply tfplan
```

### 6. Get Outputs

```bash
terraform output vm_public_ip
terraform output vm_ssh_command
```

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

1. Create storage account:
```bash
az storage account create \
  --name tfstate<unique-id> \
  --resource-group terraform-state-rg \
  --location "Central India" \
  --sku Standard_LRS
```

2. Create container:
```bash
az storage container create \
  --name tfstate \
  --account-name tfstate<unique-id>
```

3. Update backend configuration in `main.tf`

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
