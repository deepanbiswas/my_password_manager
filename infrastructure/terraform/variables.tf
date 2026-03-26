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
  default     = "Standard_B2als_v2"
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

variable "dns_label" {
  type        = string
  description = "Azure public IP DNS label; produces <dns_label>.<region>.cloudapp.azure.com (must be lowercase letters, digits, hyphens)"
  default     = "vault-deepanb"
}

variable "domain" {
  type        = string
  description = "Custom domain for Vaultwarden (e.g. https://vault.example.com). Leave empty to use the Azure-generated FQDN from dns_label."
  default     = ""
}
