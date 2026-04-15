variable "environment" {
  type        = string
  description = "Environment name (production, staging, development)"
  default     = "production"
}

variable "server_type" {
  type        = string
  description = "Hetzner Cloud server type (e.g. cx22 — 2 vCPU, 4 GB RAM)"
  default     = "cx22"
}

variable "location" {
  type        = string
  description = "Hetzner Cloud location (nbg1, fsn1, hel1, ash, hil, …)"
  default     = "nbg1"
}

variable "admin_username" {
  type        = string
  description = "Primary Linux user for SSH and cloud-init (Hetzner Ubuntu images typically use root)"
  default     = "root"
}

variable "ssh_public_key_path" {
  type        = string
  description = "Path to SSH public key file for VM access"
  default     = "~/.ssh/id_rsa.pub"
}

variable "domain" {
  type        = string
  description = "Full HTTPS URL for Vaultwarden (e.g. https://vault.example.com). Leave empty to use https://<server_ipv4> after apply."
  default     = ""
}

variable "ssh_allowed_cidr" {
  type        = string
  description = "CIDR allowed to reach SSH (port 22). Use your public IP/32 when possible; 0.0.0.0/0 matches any IPv4."
  default     = "0.0.0.0/0"
}
