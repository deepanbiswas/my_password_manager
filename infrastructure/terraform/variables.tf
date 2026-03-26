variable "location" {
  type        = string
  description = "Azure region for resources"
  default     = "Central India"
}

variable "environment" {
  type        = string
  description = "Environment name (production, staging, development)"
  default     = "production"
}

variable "vm_size" {
  type        = string
  description = "Azure VM size SKU"
  default     = "Standard_B2s"
}

variable "admin_username" {
  type        = string
  description = "Admin username for the VM"
  default     = "azureuser"
}

variable "ssh_public_key_path" {
  type        = string
  description = "Path to SSH public key file for VM access"
  default     = "~/.ssh/id_rsa.pub"
}

variable "domain" {
  type        = string
  description = "Domain for Vaultwarden (hostname or https:// URL)"
}
