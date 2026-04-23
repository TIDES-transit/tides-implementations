# =============================================================================
# THE FOLLOWING ALL DEPEND ON THE can_modify_entra VARIABLE BEING TRUE
# =============================================================================

# =============================================================================
# Azure AD Application Registration

resource "azuread_application" "openmetadata" {
  count = var.can_modify_entra ? 1 : 0

  display_name = "OpenMetadata - [Project Name]"

  web {
    redirect_uris = [
      "https://${var.app_name}.${var.cae_dns_suffix}/callback",
    ]

    logout_url = "https://${var.app_name}.${var.cae_dns_suffix}/ui/logout/logout.html"

    implicit_grant {
      access_token_issuance_enabled = true
      id_token_issuance_enabled     = true
    }
  }

  required_resource_access {
    resource_app_id = "[REDACTED_ID]" # Microsoft Graph

    resource_access {
      id   = "[REDACTED_ID]" # email
      type = "Scope"
    }

    resource_access {
      id   = "[REDACTED_ID]" # offline_access
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

    resource_access {
      id   = "[REDACTED_ID]" # User.Read
      type = "Scope"
    }
  }
}

# Create a client secret for the OpenMetadata application
resource "azuread_application_password" "openmetadata" {
  count = var.can_modify_entra ? 1 : 0

  application_id = azuread_application.openmetadata[0].id
  display_name   = "OpenMetadata Client Secret"
}

resource "azuread_service_principal" "openmetadata" {
  count = var.can_modify_entra ? 1 : 0

  client_id = azuread_application.openmetadata[0].client_id

  app_role_assignment_required = true

  feature_tags {
    enterprise = true
    hide       = true
  }
}

# =============================================================================
# User Access & Role Assignments

# Grant datahub_users group access to OpenMetadata
resource "azuread_app_role_assignment" "datahub_users_openmetadata_access" {
  count = var.can_modify_entra ? 1 : 0

  app_role_id         = "[REDACTED_ID]" # Default access role
  principal_object_id = var.datahub_users_group_id
  resource_object_id  = azuread_service_principal.openmetadata[0].object_id
}

# RBAC assignment for Key Vault access
resource "azurerm_role_assignment" "openmetadata_key_vault_secrets_user" {
  count = var.can_modify_entra ? 1 : 0

  scope                = var.datahub_key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.openmetadata.principal_id
}