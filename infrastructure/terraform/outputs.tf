output "vm_public_ip" {
  description = "Public IPv4 address of the password manager VM"
  value       = azurerm_public_ip.main.ip_address
}

output "vm_fqdn" {
  description = "Azure-generated FQDN for the public IP (<dns_label>.<region>.cloudapp.azure.com)"
  value       = azurerm_public_ip.main.fqdn
}

output "vm_ssh_command" {
  description = "Example SSH command to connect to the VM"
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.main.ip_address}"
}

output "vm_admin_username" {
  description = "VM admin username (same as var.admin_username)"
  value       = var.admin_username
}

output "domain" {
  description = "Effective domain for Vaultwarden (custom domain if set, otherwise Azure FQDN)"
  value       = local.effective_domain
}

output "resource_group_name" {
  description = "Azure resource group containing the VM and networking"
  value       = azurerm_resource_group.main.name
}

output "vm_name" {
  description = "Azure VM resource name"
  value       = azurerm_linux_virtual_machine.main.name
}
