locals {
  # Naming configuration for multi-container Metabase deployment
  base_name = trimsuffix(var.app_name, "-ca")
}

# =============================================================================
# MANAGED IDENTITY
# =============================================================================

resource "azurerm_user_assigned_identity" "metabase" {
  name                = "${var.system_name}-${var.environment_name}-workload-metabase-mi"
  location            = var.resource_group_location
  resource_group_name = var.resource_group_name

  tags = {
    Department  = "[DEPARTMENT]"
    Environment = var.environment_name
    Owner       = "[TEAM]"
    Purpose     = "Metabase workload identity for container apps"
  }
}

# =============================================================================
# KEY VAULT ACCESS
# =============================================================================

resource "azurerm_role_assignment" "metabase_key_vault_secrets_user" {
  count = var.can_modify_entra ? 1 : 0

  scope                = var.datahub_key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.metabase.principal_id
}