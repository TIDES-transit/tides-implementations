terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    postgresql = {
      source  = "cyrilgdn/postgresql"
      version = "~> 1.22"
    }
  }
}

provider "postgresql" {
  host      = var.datahub_postgresql_flexible_server_fqdn
  port      = 5432
  database  = "postgres"
  username  = var.datahub_postgresql_admin_username
  password  = var.datahub_postgresql_admin_password
  sslmode   = "require"
  superuser = false
}
