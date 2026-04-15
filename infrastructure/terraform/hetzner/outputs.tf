output "vm_public_ip" {
  description = "Public IPv4 address of the password manager VM"
  value       = hcloud_server.main.ipv4_address
}

output "vm_fqdn" {
  description = "Not used on Hetzner (no Azure-style FQDN); IPv4 for reference"
  value       = hcloud_server.main.ipv4_address
}

output "vm_ssh_command" {
  description = "Example SSH command to connect to the VM"
  value       = "ssh ${var.admin_username}@${hcloud_server.main.ipv4_address}"
}

output "vm_admin_username" {
  description = "VM admin username (same as var.admin_username)"
  value       = var.admin_username
}

output "domain" {
  description = "Effective domain for Vaultwarden (custom domain if set, otherwise https://<ipv4>)"
  value       = local.effective_domain
}

output "resource_group_name" {
  description = "Unused on Hetzner (empty string for TDI script compatibility)"
  value       = ""
}

output "vm_name" {
  description = "Hetzner server name (for hcloud CLI checks in iteration-1)"
  value       = hcloud_server.main.name
}

output "cloud_provider" {
  description = "IaC target for TDI verify scripts"
  value       = "hetzner"
}
