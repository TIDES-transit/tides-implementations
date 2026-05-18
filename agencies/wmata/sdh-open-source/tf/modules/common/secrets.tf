# =======================================================================
# Secrets Resources
#
# - Key Vault
# - Key Vault Secrets

resource "azurerm_key_vault" "kv" {
  access_policy                   = []
  rbac_authorization_enabled      = true
  enabled_for_deployment          = false
  enabled_for_disk_encryption     = false
  enabled_for_template_deployment = false
  location                        = var.resource_group_location
  name                            = local.resource_names.kv
  public_network_access_enabled   = true
  purge_protection_enabled        = false
  resource_group_name             = var.resource_group_name
  sku_name                        = "standard"
  soft_delete_retention_days      = 90
  tags                            = local.kv_tags
  tenant_id                       = var.tenant_id
  network_acls {
    bypass                     = "AzureServices"
    default_action             = "Allow"
    ip_rules                   = []
    virtual_network_subnet_ids = []
  }

  # We don't want to delete the secrets in this Key Vault accidentally,
  # so we prevent destroy operations.
  lifecycle {
    prevent_destroy = true
  }
}

resource "random_string" "psql_admin_username_suffix" {
  length  = 12
  upper   = true
  lower   = false
  numeric = true
  special = false
}

resource "random_password" "psql_admin_password" {
  length  = 16
  special = true
  upper   = true
  lower   = true
  numeric = true
}

resource "azurerm_key_vault_secret" "psql_admin_username" {
  name         = "[SECRET_NAME]"
  value        = "u${random_string.psql_admin_username_suffix.result}" # username must start with a letter
  key_vault_id = azurerm_key_vault.kv.id
}

resource "azurerm_key_vault_secret" "psql_admin_password" {
  name         = "[SECRET_NAME]"
  value        = random_password.psql_admin_password.result
  key_vault_id = azurerm_key_vault.kv.id
}