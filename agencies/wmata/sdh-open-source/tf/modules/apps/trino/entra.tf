# =============================================================================
# THE FOLLOWING ALL DEPEND ON THE can_modify_entra VARIABLE BEING TRUE
# =============================================================================

# =============================================================================
# App registration (for human users accessing Trino)
#
# IMPORTANT: Admin Consent Required
# ---------------------------------
# The Trino app registration requires tenant-wide admin consent before users
# can sign in. This is because the app requests these delegated permissions:
#
# 1. Microsoft Graph "User.Read" - to read the signed-in user's profile
# 2. Microsoft Graph "offline_access" - to obtain refresh tokens for sessions
# 3. Microsoft Graph "openid", "profile", "email" - for OIDC authentication
# 4. Lakekeeper API scope - to access the Lakekeeper catalog on behalf of users
#
# When can_modify_entra = true:
#   Admin consent is granted automatically via OpenTofu using the
#   azuread_service_principal_delegated_permission_grant resource below.
#
# When can_modify_entra = false:
#   An Azure AD administrator must manually grant consent:
#   - Azure Portal → Microsoft Entra ID → Enterprise applications
#   - Find "Trino - [Project Name]" → Permissions → "Grant admin consent"
#   - Or visit: https://login.microsoftonline.com/{tenant-id}/adminconsent?client_id={trino-client-id}
#

resource "azuread_application" "trino" {
  count = var.can_modify_entra ? 1 : 0

  display_name = "Trino - [Project Name]"

  web {
    logout_url = "https://${var.app_name}.${var.cae_dns_suffix}/ui/logout/logout.html"
    redirect_uris = [
      "https://${var.app_name}.${var.cae_dns_suffix}/oauth2/callback",
    ]

    # # TODO: THE STATE THINKS THESE ARE STILL FALSE
    # implicit_grant {
    #   access_token_issuance_enabled = true
    #   id_token_issuance_enabled     = true
    # }
  }

  required_resource_access {
    resource_app_id = var.lakekeeper_app_registration_client_id

    # Request the API scope
    resource_access {
      id   = var.lakekeeper_oauth2_permission_scope_id
      type = "Scope"
    }
  }

  required_resource_access {
    resource_app_id = "[REDACTED_ID]" # Microsoft Graph

    resource_access {
      id   = "[REDACTED_ID]" # User.Read
      type = "Scope"
    }
  }

  lifecycle {
    ignore_changes = [
      identifier_uris,
    ]
  }
}

resource "azuread_application_identifier_uri" "trino" {
  count = var.can_modify_entra ? 1 : 0

  application_id = azuread_application.trino[0].id
  identifier_uri = "api://${azuread_application.trino[0].client_id}"
}

# Create a client secret for the Trino application
resource "azuread_application_password" "trino" {
  count = var.can_modify_entra ? 1 : 0

  application_id = azuread_application.trino[0].id
  display_name   = "Trino Client Secret"
}

resource "azuread_service_principal" "trino" {
  count = var.can_modify_entra ? 1 : 0

  client_id = azuread_application.trino[0].client_id

  app_role_assignment_required = true

  feature_tags {
    enterprise = true
    hide       = true
  }
}

# =============================================================================
# Workload Identity Roles

resource "azurerm_role_assignment" "trino_workload_identity_storage_contributor" {
  count = var.can_modify_entra ? 1 : 0

  scope                = var.datahub_lake_storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.trino_workload_identity.principal_id
}

resource "azurerm_role_assignment" "trino_workload_identity_storage_delegator" {
  count = var.can_modify_entra ? 1 : 0

  scope                = var.datahub_lake_storage_account_id
  role_definition_name = "Storage Blob Delegator"
  principal_id         = azurerm_user_assigned_identity.trino_workload_identity.principal_id
}

# =============================================================================
# User Access

# Grant datahub_users group access to Trino
resource "azuread_app_role_assignment" "datahub_users_trino_access" {
  count = var.can_modify_entra ? 1 : 0

  app_role_id         = "[REDACTED_ID]" # Default access role
  principal_object_id = var.datahub_users_group_id
  resource_object_id  = azuread_service_principal.trino[0].object_id
}

# # =============================================================================
# # Machine Users

# # Grant other machine users that need access to Trino
# resource "azuread_app_role_assignment" "machine_user_trino_access" {
#   for_each = var.machine_users

#   app_role_id         = "[REDACTED_ID]" # Default access role
#   principal_object_id = each.value.service_principal.object_id
#   resource_object_id  = azuread_service_principal.trino.object_id
# }

# =============================================================================
# App/API Grants

# Lakekeeper default access
resource "azuread_app_role_assignment" "trino_lakekeeper_access" {
  count = var.can_modify_entra ? 1 : 0

  app_role_id         = "[REDACTED_ID]" # Default access role
  principal_object_id = azuread_service_principal.trino[0].object_id
  resource_object_id  = data.azuread_service_principal.lakekeeper[0].object_id
}

# =============================================================================
# Admin Consent for Delegated Permissions
#
# Grant tenant-wide admin consent for the OAuth2 scopes that Trino requests.
# This eliminates the "Approval required" prompt for users in the tenant.

# Data source to get the Microsoft Graph service principal
data "azuread_service_principal" "msgraph" {
  count = var.can_modify_entra ? 1 : 0

  client_id = "[REDACTED_ID]" # Microsoft Graph
}

# Grant admin consent for Microsoft Graph delegated permissions
resource "azuread_service_principal_delegated_permission_grant" "trino_msgraph_consent" {
  count = var.can_modify_entra ? 1 : 0

  service_principal_object_id          = azuread_service_principal.trino[0].object_id
  resource_service_principal_object_id = data.azuread_service_principal.msgraph[0].object_id
  claim_values                         = ["User.Read", "offline_access", "openid", "profile", "email"]
}

# Data source to get the Lakekeeper service principal
data "azuread_service_principal" "lakekeeper" {
  count = var.can_modify_entra ? 1 : 0

  client_id = var.lakekeeper_app_registration_client_id
}

# Grant admin consent for Lakekeeper API delegated permissions
resource "azuread_service_principal_delegated_permission_grant" "trino_lakekeeper_consent" {
  count = var.can_modify_entra ? 1 : 0

  service_principal_object_id          = azuread_service_principal.trino[0].object_id
  resource_service_principal_object_id = data.azuread_service_principal.lakekeeper[0].object_id
  claim_values                         = ["user_impersonation"]
}