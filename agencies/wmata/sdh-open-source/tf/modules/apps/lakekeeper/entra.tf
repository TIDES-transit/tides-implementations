# =============================================================================
# THE FOLLOWING ALL DEPEND ON THE can_modify_entra VARIABLE BEING TRUE
# =============================================================================

# =============================================================================
# App Registration - Lakekeeper (Combined UI and API)

resource "azuread_application" "lakekeeper" {
  count = var.can_modify_entra ? 1 : 0

  display_name = "Lakekeeper - [Project Name]"

  # Single Page Application configuration for UI
  single_page_application {
    redirect_uris = [
      "https://${var.app_name}.${var.cae_dns_suffix}/ui/callback",
    ]
  }

  # API configuration
  api {
    # # TODO: DO WE NEED TO SET THESE CONFIG OPTIONS ON THE API?
    # mapped_claims_enabled          = true
    # requested_access_token_version = 2
  }

  required_resource_access {
    resource_app_id = "[REDACTED_ID]" # Microsoft Graph

    resource_access {
      id   = "[REDACTED_ID]" # User.Read
      type = "Scope"
    }

    resource_access {
      id   = "[REDACTED_ID]" # GroupMember.Read.All
      type = "Role"
    }
  }

  lifecycle {
    ignore_changes = [
      api[0].oauth2_permission_scope,
      identifier_uris,
    ]
  }
}

resource "azuread_application_password" "lakekeeper" {
  count = var.can_modify_entra ? 1 : 0

  application_id = azuread_application.lakekeeper[0].id
  display_name   = "Lakekeeper Client Secret"
}

resource "random_uuid" "lakekeeper_scope_id" {
  count = var.can_modify_entra ? 1 : 0
}

resource "azuread_application_permission_scope" "lakekeeper" {
  count = var.can_modify_entra ? 1 : 0

  application_id = azuread_application.lakekeeper[0].id

  # Set the scope ID to a known value if we can't modify Entra settings.
  scope_id = var.oauth2_permission_scope_id != null ? var.oauth2_permission_scope_id : random_uuid.lakekeeper_scope_id[0].result
  value    = "Lakekeeper"
  type     = "User"

  admin_consent_description  = "Access Lakekeeper APIs"
  admin_consent_display_name = "Access Lakekeeper APIs"
  user_consent_description   = "Access Lakekeeper APIs"
  user_consent_display_name  = "Access Lakekeeper APIs"
}

resource "azuread_application_identifier_uri" "lakekeeper" {
  count = var.can_modify_entra ? 1 : 0

  application_id = azuread_application.lakekeeper[0].id
  identifier_uri = "api://${azuread_application.lakekeeper[0].client_id}"
}

resource "azuread_service_principal" "lakekeeper" {
  count = var.can_modify_entra ? 1 : 0

  client_id = azuread_application.lakekeeper[0].client_id

  app_role_assignment_required = true

  feature_tags {
    enterprise = true
    hide       = true
  }
}

# =============================================================================
# Role Assignments

resource "azuread_app_role_assignment" "datahub_users_lakekeeper_access" {
  count = var.can_modify_entra ? 1 : 0

  app_role_id         = "[REDACTED_ID]" # Default access role
  principal_object_id = var.datahub_users_group_id
  resource_object_id  = azuread_service_principal.lakekeeper[0].object_id
}

resource "azuread_app_role_assignment" "datahub_developers_lakekeeper_access" {
  count = var.can_modify_entra && var.datahub_developers_group_id != null ? 1 : 0

  app_role_id         = "[REDACTED_ID]" # Default access role
  principal_object_id = var.datahub_developers_group_id
  resource_object_id  = azuread_service_principal.lakekeeper[0].object_id
}

# =============================================================================
# Graph API Permission: GroupMember.Read.All
#
# Granted to the Lakekeeper workload managed identity so the grants sync job
# can read Entra group memberships via the Microsoft Graph API.

data "azuread_service_principal" "msgraph" {
  count     = var.can_modify_entra ? 1 : 0
  client_id = "[REDACTED_ID]" # Microsoft Graph
}

resource "azuread_app_role_assignment" "lakekeeper_sp_graph_group_member_read" {
  count = var.can_modify_entra ? 1 : 0

  app_role_id         = "[REDACTED_ID]" # GroupMember.Read.All
  principal_object_id = azuread_service_principal.lakekeeper[0].object_id
  resource_object_id  = data.azuread_service_principal.msgraph[0].object_id
}

# Key Vault Secrets Officer role for the Lakekeeper managed identity.
# Required for the grants sync job to write Entra group membership secrets.
resource "azurerm_role_assignment" "lakekeeper_kv_secrets_officer" {
  count = var.can_modify_entra ? 1 : 0

  scope                = var.datahub_key_vault_id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = azurerm_user_assigned_identity.lakekeeper.principal_id
}

# RBAC assignment for Container Registry access (AcrPull)
# Required for the bootstrap job to pull the lakekeeper-scripts image
resource "azurerm_role_assignment" "lakekeeper_acr_pull" {
  count = var.can_modify_entra && var.datahub_container_registry_id != null ? 1 : 0

  scope                = var.datahub_container_registry_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.lakekeeper.principal_id
}

# App role assignment for the Lakekeeper SP to access its own app.
# Required for client credentials flow — Azure does not auto-assign an SP
# to its own app's default role.
resource "azuread_app_role_assignment" "lakekeeper_sp_self_access" {
  count = var.can_modify_entra ? 1 : 0

  app_role_id         = "[REDACTED_ID]" # Default access role
  principal_object_id = azuread_service_principal.lakekeeper[0].object_id
  resource_object_id  = azuread_service_principal.lakekeeper[0].object_id
}

# App role assignment for the Lakekeeper managed identity to call the Lakekeeper API.
# Required when using managed identity auth for bootstrap/warehouse sync jobs.
resource "azuread_app_role_assignment" "lakekeeper_mi_access" {
  count = var.can_modify_entra ? 1 : 0

  app_role_id         = "[REDACTED_ID]" # Default access role
  principal_object_id = azurerm_user_assigned_identity.lakekeeper.principal_id
  resource_object_id  = azuread_service_principal.lakekeeper[0].object_id
}

# Storage Blob Data Contributor role for the Lakekeeper app registration's
# service principal. Required so Lakekeeper can access ADLS Gen2 storage
# using the auto-generated app registration credentials.
resource "azurerm_role_assignment" "lakekeeper_sp_storage_blob_contributor" {
  count = var.can_modify_entra && var.datahub_lake_storage_account_id != null ? 1 : 0

  scope                = var.datahub_lake_storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azuread_service_principal.lakekeeper[0].object_id
}

# # =============================================================================
# # Machine Users

# resource "azuread_application_api_access" "machine_user_lakekeeper_access" {
#   for_each = var.machine_users
#
#   api_client_id  = azuread_application.lakekeeper.client_id
#   application_id = each.value.application.id
#   scope_ids      = [random_uuid.lakekeeper_scope_id.result]
# }
#
# resource "azuread_app_role_assignment" "machine_user_lakekeeper_access" {
#   for_each = var.machine_users
#
#   app_role_id         = "[REDACTED_ID]" # Default access role
#   principal_object_id = each.value.service_principal.object_id
#   resource_object_id  = azuread_service_principal.lakekeeper.object_id
# }