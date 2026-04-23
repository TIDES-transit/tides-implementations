# =============================================================================
# THE FOLLOWING ALL DEPEND ON THE can_modify_entra VARIABLE BEING TRUE
# =============================================================================

# ============================================================================
# App Registration

resource "azuread_application" "dagster" {
  count = var.can_modify_entra ? 1 : 0

  display_name = "Dagster - [Project Name]"

  web {
    homepage_url = "https://${var.app_name}.${var.cae_dns_suffix}"
    logout_url   = "https://${var.app_name}.${var.cae_dns_suffix}/ui/logout/logout.html"

    redirect_uris = [
      "https://${var.app_name}.${var.cae_dns_suffix}/.auth/login/aad/callback",
    ]

    implicit_grant {
      id_token_issuance_enabled = true
    }
  }

  required_resource_access {
    resource_app_id = "[REDACTED_ID]" # Microsoft Graph

    resource_access {
      id   = "[REDACTED_ID]" # email
      type = "Scope"
    }

    resource_access {
      id   = "[REDACTED_ID]" # openid
      type = "Scope"
    }

    resource_access {
      id   = "[REDACTED_ID]" # profile
      type = "Scope"
    }
  }

  lifecycle {
    ignore_changes = [
      # Ignore changes to required_resource_access managed by azuread_application_api_access
      required_resource_access,
    ]
  }
}

resource "azuread_service_principal" "dagster" {
  count = var.can_modify_entra ? 1 : 0

  client_id = azuread_application.dagster[0].client_id

  app_role_assignment_required = true

  feature_tags {
    enterprise = true
    hide       = true
  }
}

resource "azuread_app_role_assignment" "datahub_users_dagster_access" {
  count = var.can_modify_entra ? 1 : 0

  app_role_id         = "[REDACTED_ID]" # Default access role
  principal_object_id = var.datahub_users_group_id
  resource_object_id  = azuread_service_principal.dagster[0].object_id
}

resource "azuread_application_password" "dagster" {
  count = var.can_modify_entra ? 1 : 0

  application_id = azuread_application.dagster[0].id
  display_name   = "Dagster Client Secret"
}

# ================================================================
# Role Assignments

# RBAC assignment for Storage Blob Data Contributor
resource "azurerm_role_assignment" "dagster_storage_blob_data_contributor" {
  count = var.can_modify_entra ? 1 : 0

  scope                = var.datahub_lake_storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.dagster.principal_id
}

# RBAC assignment for Storage Blob Delegator
resource "azurerm_role_assignment" "dagster_storage_blob_delegator" {
  count = var.can_modify_entra ? 1 : 0

  scope                = var.datahub_lake_storage_account_id
  role_definition_name = "Storage Blob Delegator"
  principal_id         = azurerm_user_assigned_identity.dagster.principal_id
}

# RBAC assignment for Key Vault access
resource "azurerm_role_assignment" "dagster_key_vault_secrets_user" {
  count = var.can_modify_entra ? 1 : 0

  scope                = var.datahub_key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.dagster.principal_id
}

# RBAC assignment for Container Registry access
resource "azurerm_role_assignment" "dagster_acr_pull" {
  count = var.can_modify_entra ? 1 : 0

  scope                = var.datahub_container_registry_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.dagster.principal_id
}

# ============================================================================
# App/API Grants

# Trino default access
resource "azuread_app_role_assignment" "dagster_trino_access" {
  count = var.can_modify_entra ? 1 : 0

  app_role_id         = "[REDACTED_ID]" # Default access role
  principal_object_id = azuread_service_principal.dagster[0].object_id
  resource_object_id  = var.trino_app_service_principal_object_id
}

# Lakekeeper default access
resource "azuread_app_role_assignment" "dagster_lakekeeper_access" {
  count = var.can_modify_entra ? 1 : 0

  app_role_id         = "[REDACTED_ID]" # Default access role
  principal_object_id = azuread_service_principal.dagster[0].object_id
  resource_object_id  = var.lakekeeper_app_service_principal_object_id
}

# Lakekeeper API access scope
resource "azuread_application_api_access" "dagster_lakekeeper_api_access" {
  count = var.can_modify_entra ? 1 : 0

  api_client_id  = var.lakekeeper_app_registration_client_id
  application_id = azuread_application.dagster[0].id
  scope_ids      = [var.lakekeeper_oauth2_permission_scope_id]
}