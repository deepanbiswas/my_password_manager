terraform {
  required_version = ">= 1.5.0"

  # Terraform Cloud (free tier): shared state for local + GitHub Actions.
  # Create workspace "password-manager-hetzner" (CLI-driven) and set execution mode to Local.
  # Auth: terraform login and/or TF_TOKEN_app_terraform_io.
  cloud {
    organization = "TF_DEEPAN_PERSONAL_ORG"

    workspaces {
      # Must match the HCP project that contains this workspace. Workspace names are only
      # unique per project; without this, the CLI can bind to a different (empty) workspace
      # than the one you migrated — plans then try to recreate existing Hetzner objects.
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
