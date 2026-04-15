locals {
  ssh_public_key = trimspace(file(pathexpand(var.ssh_public_key_path)))

  # Resolve the effective domain: prefer an explicit var.domain, otherwise
  # derive from the Azure-generated FQDN (requires dns_label on the public IP).
  effective_domain = var.domain != "" ? var.domain : "https://${azurerm_public_ip.main.fqdn}"

  base_tags = {
    Project     = "password-manager"
    Environment = var.environment
    Component   = "infrastructure"
    ManagedBy   = "terraform"
    CostCenter  = "personal"
  }

  vm_tags = merge(local.base_tags, {
    Component = "vaultwarden"
    Backup    = "enabled"
  })
}

resource "azurerm_resource_group" "main" {
  name     = "rg-password-manager-${var.environment}"
  location = var.location
  tags     = local.base_tags
}

# Azure ARM API can take ~30s to fully propagate a new resource group before
# child resources (VNet in particular) become queryable. This sleep prevents
# the provider's post-create polling from receiving a spurious 404.
resource "time_sleep" "wait_for_rg" {
  depends_on      = [azurerm_resource_group.main]
  create_duration = "30s"
}

resource "azurerm_virtual_network" "main" {
  name                = "vnet-password-manager"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.base_tags

  depends_on = [time_sleep.wait_for_rg]
}

resource "azurerm_subnet" "main" {
  name                 = "subnet-password-manager"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_security_group" "main" {
  name                = "nsg-password-manager"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.base_tags

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
    name                       = "AllowSSH"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "DenyOtherInbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Standard SKU is widely supported; if your subscription requires Basic, set sku = "Basic" and adjust.
resource "azurerm_public_ip" "main" {
  name                = "pip-password-manager"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = var.dns_label
  tags                = local.base_tags
}

resource "azurerm_network_interface" "main" {
  name                = "nic-password-manager"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.base_tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.main.id
  }
}

resource "azurerm_network_interface_security_group_association" "main" {
  network_interface_id      = azurerm_network_interface.main.id
  network_security_group_id = azurerm_network_security_group.main.id
}

resource "azurerm_linux_virtual_machine" "main" {
  name                = "vm-password-manager"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  size                = var.vm_size
  tags                = local.vm_tags

  network_interface_ids = [
    azurerm_network_interface.main.id,
  ]

  admin_username = var.admin_username

  admin_ssh_key {
    username   = var.admin_username
    public_key = local.ssh_public_key
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

  disable_password_authentication = true

  custom_data = base64encode(templatefile("${path.module}/../shared/scripts/cloud-init.sh", {
    admin_username = var.admin_username
  }))
}
