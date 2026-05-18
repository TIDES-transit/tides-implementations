# =============================================================================
# MACHINE USERS (OAUTH)
# Centralized definition of OAuth-based machine users
# =============================================================================
#
# This file defines machine users that authenticate via Azure AD OAuth2.
# Each machine user has a single Azure AD application and service principal,
# with access to services controlled by boolean flags.
#
# Configuration fields:
#   display_name - Azure AD application display name
#   description  - Human-readable description of the service
#   lakekeeper   - Boolean: Grant access to Lakekeeper APIs via OAuth2
#   trino        - Boolean: Grant access to Trino via OAuth2
#   storage      - Boolean: Grant access to Azure Storage (Blob Data Contributor & Delegator roles)
#   secrets      - Boolean: Grant access to Key Vault secrets (Key Vault Secrets User role)
#
# For password-based authentication (e.g., Metabase), see trino_password_users.tf
#
# =============================================================================

locals {
  # OAuth-based machine user definitions with service access flags
  machine_users = {
    # trino = {
    #   display_name = "lakekeeper-client-trino"
    #   description  = "Trino authentication to Lakekeeper"
    #   lakekeeper   = true
    #   trino        = false # Trino itself doesn't need to auth to Trino
    # }
    # python_demo = {
    #   display_name = "trino-client-python-demo"
    #   description  = "Python demo script authentication to Trino"
    #   lakekeeper   = false
    #   trino        = true
    # }
    # dagster = {
    #   display_name = "dagster"
    #   description  = "Dagster machine user"
    #   lakekeeper   = true
    #   trino        = true
    #   storage      = true
    #   secrets      = true
    # }
  }

  # Derived locals for filtering by service
  lakekeeper_machine_users = {
    for k, v in local.machine_users : k => v
    if v.lakekeeper == true
  }

  trino_machine_users = {
    for k, v in local.machine_users : k => v
    if v.trino == true
  }

  # Storage-enabled machine users
  storage_machine_users = {
    for k, v in local.machine_users : k => v
    if lookup(v, "storage", false) == true
  }

  # Secrets-enabled machine users
  secrets_machine_users = {
    for k, v in local.machine_users : k => v
    if lookup(v, "secrets", false) == true
  }
}

# =============================================================================
# MACHINE USER APP REGISTRATIONS
# Single app registration per machine user with access to multiple services
# =============================================================================

resource "azuread_application" "machine_users" {
  for_each = local.machine_users

  display_name = each.value.display_name

  # required_resource_access will be affected by azuread_application_api_access
  # resources in specific applications.
  lifecycle {
    ignore_changes = [
      required_resource_access,
    ]
  }
}

resource "azuread_service_principal" "machine_users" {
  for_each  = local.machine_users
  client_id = azuread_application.machine_users[each.key].client_id

  feature_tags {
    enterprise = true
  }
}

resource "azuread_application_password" "machine_users" {
  for_each = local.machine_users

  application_id = azuread_application.machine_users[each.key].id
  display_name   = each.value.description
}

# =============================================================================
# KEY VAULT SECRETS
# Store machine user credentials in Key Vault
# =============================================================================

resource "azurerm_key_vault_secret" "machine_user_ids" {
  for_each = local.machine_users

  name         = "[SECRET_NAME]"_", "-")}-id"
  value        = azuread_application.machine_users[each.key].client_id
  key_vault_id = var.datahub_key_vault_id
}

resource "azurerm_key_vault_secret" "machine_user_secrets" {
  for_each = local.machine_users

  name         = "[SECRET_NAME]"_", "-")}-secret"
  value        = azuread_application_password.machine_users[each.key].value
  key_vault_id = var.datahub_key_vault_id
}

# =============================================================================
# AZURE STORAGE ACCESS GRANTS
# Grant machine users access to Azure Storage when storage flag is true
# =============================================================================

resource "azurerm_role_assignment" "machine_user_storage_contributor" {
  for_each = local.storage_machine_users

  scope                = var.datahub_lake_storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azuread_service_principal.machine_users[each.key].object_id
}

resource "azurerm_role_assignment" "machine_user_storage_delegator" {
  for_each = local.storage_machine_users

  scope                = var.datahub_lake_storage_account_id
  role_definition_name = "Storage Blob Delegator"
  principal_id         = azuread_service_principal.machine_users[each.key].object_id
}

# =============================================================================
# KEY VAULT ACCESS GRANTS
# Grant machine users access to Key Vault secrets when secrets flag is true
# =============================================================================

resource "azurerm_role_assignment" "machine_user_kv_secrets_user" {
  for_each = local.secrets_machine_users

  scope                = var.datahub_key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azuread_service_principal.machine_users[each.key].object_id
}

# # =============================================================================
# # OUTPUTS
# # Dynamic outputs for OAuth machine users
# # =============================================================================

# # Dynamic output for OAuth machine user credentials
# output "machine_user_credentials" {
#   value = {
#     for k, v in local.machine_users : k => merge(
#       {
#         description   = v.description
#         tenant_id     = var.tenant_id
#         client_id     = azuread_application.machine_users[k].client_id
#         client_secret = azuread_application_password.machine_users[k].value
#       },
#       # Service URLs based on access flags
#       # TODO: Uncomment after setting up Lakekeeper app
#       # v.lakekeeper ? {
#       #   lakekeeper_url         = "https://lakekeeper.${var.cae_dns_suffix}"
#       #   lakekeeper_oauth_scope = "api://${azuread_application.lakekeeper_server.client_id}/.default"
#       # } : {},
#       v.trino ? {
#         trino_url         = "https://trino.${var.cae_dns_suffix}"
#         trino_oauth_scope = "api://${var.trino_app_registration_id}/.default"
#       } : {},
#       lookup(v, "storage", false) ? {
#         storage_account_name = azurerm_storage_account.dataingest.name
#         storage_account_id   = azurerm_storage_account.dataingest.id
#       } : {},
#       lookup(v, "secrets", false) ? {
#         key_vault_id = var.datahub_key_vault_id
#       } : {}
#     )
#   }
#   sensitive   = true
#   description = "Credentials for OAuth-based machine users with their respective service access"
# }