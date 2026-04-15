locals {
  ssh_public_key = trimspace(file(pathexpand(var.ssh_public_key_path)))

  effective_domain = var.domain != "" ? var.domain : "https://${hcloud_server.main.ipv4_address}"

  common_labels = {
    project     = "password-manager"
    environment = var.environment
    component   = "vaultwarden"
    managed_by  = "terraform"
    cost_center = "personal"
  }
}

data "hcloud_image" "ubuntu" {
  name = "ubuntu-22.04"
}

resource "hcloud_ssh_key" "vaultwarden" {
  name       = "vaultwarden-${var.environment}"
  public_key = local.ssh_public_key
  labels     = local.common_labels
}

resource "hcloud_firewall" "vaultwarden" {
  name = "fw-password-manager-${var.environment}"

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = [var.ssh_allowed_cidr]
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "80"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "443"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  labels = local.common_labels
}

resource "hcloud_server" "main" {
  name        = "vm-password-manager"
  server_type = var.server_type
  image       = data.hcloud_image.ubuntu.id
  location    = var.location

  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }

  ssh_keys     = [hcloud_ssh_key.vaultwarden.id]
  firewall_ids = [hcloud_firewall.vaultwarden.id]

  user_data = base64encode(templatefile("${path.module}/../shared/scripts/cloud-init.sh", {
    admin_username = var.admin_username
  }))

  labels = local.common_labels
}
