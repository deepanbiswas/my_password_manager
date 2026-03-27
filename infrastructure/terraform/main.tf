terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }

  # Optional: configure remote backend (Azure Storage). Uncomment and set values after creating the storage account.
  # backend "azurerm" {
  #   resource_group_name  = "terraform-state-rg"
  #   storage_account_name = "tfstate<unique-id>"
  #   container_name       = "tfstate"
  #   key                  = "password-manager.terraform.tfstate"
  # }
}

provider "azurerm" {
  features {}
}
