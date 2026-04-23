terraform {
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.4.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.0"
    }
    htpasswd = {
      source  = "loafoe/htpasswd"
      version = "~>1.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = var.resource_group_name
    storage_account_name = "[STORAGE_ACCOUNT]"
    container_name       = "tfstate"
    key                  = "${var.system_name}-${var.environment_name}.tfstate"
    use_azuread_auth     = true
  }
}

provider "azurerm" {
  subscription_id                 = var.arm_subscription_id
  resource_provider_registrations = "none"
  storage_use_azuread             = true
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
}