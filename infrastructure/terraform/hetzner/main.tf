terraform {
  required_version = ">= 1.10.0"

  # Terraform Cloud (free tier): shared state for local + GitHub Actions.
  # Create workspace "password-manager-hetzner" (CLI-driven) and set execution mode to Local.
  # Auth: terraform login and/or TF_TOKEN_app_terraform_io.
  cloud {
    organization = "TF_DEEPAN_PERSONAL_ORG"

    workspaces {
      # Requires Terraform >= 1.10 (workspaces.project). Match the HCP project for this workspace.
      project = "Default Project"
      name    = "password-manager-hetzner"
    }
  }

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45"
    }
  }
}

provider "hcloud" {}
