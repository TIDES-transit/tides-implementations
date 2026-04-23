# =============================================================================
# Common resources used by OpenMetadata deployments

locals {
  # Naming configuration for multi-container OpenMetadata deployment
  base_name              = trimsuffix(var.app_name, "-ca")
  env_base_name          = trimsuffix(local.base_name, "-openmetadata")
  env_base_name_alphanum = "${var.sys_short}${var.env_short}"

  resource_names = {
    storage_account = "${local.env_base_name_alphanum}omdstrg01"
  }

  app_registration_client_id     = var.app_registration_client_id != null ? var.app_registration_client_id : (var.can_modify_entra ? azuread_application.openmetadata[0].client_id : null)
  app_registration_client_secret = var.app_registration_client_secret != null ? var.app_registration_client_secret : (var.can_modify_entra ? azuread_application_password.openmetadata[0].value : null)
}

# =============================================================================
# Azure AD Application Registration

# Store the OAuth client secret in Key Vault
resource "azurerm_key_vault_secret" "openmetadata_oauth_client_secret" {
  name         = "[SECRET_NAME]"
  value        = local.app_registration_client_secret
  key_vault_id = var.datahub_key_vault_id
}

# =============================================================================
# Managed Identities

# Managed identity for OpenMetadata workload identity
resource "azurerm_user_assigned_identity" "openmetadata" {
  name                = "${var.system_name}-${var.environment_name}-workload-openmetadata-mi"
  location            = var.resource_group_location
  resource_group_name = var.resource_group_name

  tags = {
    Department  = "[DEPARTMENT]"
    Environment = var.environment_name
    Owner       = "[TEAM]"
    Purpose     = "OpenMetadata workload identity for container apps"
  }
}

# =============================================================================
# Azure Files Share for OpenSearch Persistence

# Storage account for OpenSearch data (if not using existing one)
resource "azurerm_storage_account" "openmetadata_storage" {
  name                     = local.resource_names.storage_account
  resource_group_name      = var.resource_group_name
  location                 = var.resource_group_location
  account_tier             = "Standard"
  account_replication_type = "LRS"


  tags = {
    Department  = "[DEPARTMENT]"
    Environment = var.environment_name
    Owner       = "[TEAM]"
    Purpose     = "OpenMetadata OpenSearch persistent storage"
  }
}

# Azure Files share for OpenSearch data
resource "azurerm_storage_share" "opensearch_data" {
  name               = "opensearch-data"
  storage_account_id = azurerm_storage_account.openmetadata_storage.id
  quota              = 10
}

# Container App Environment Storage for mounting the Azure Files share
resource "azurerm_container_app_environment_storage" "opensearch_storage" {
  name                         = "opensearch-storage"
  container_app_environment_id = var.datahub_container_app_environment_id
  account_name                 = azurerm_storage_account.openmetadata_storage.name
  access_key                   = azurerm_storage_account.openmetadata_storage.primary_access_key
  share_name                   = azurerm_storage_share.opensearch_data.name
  access_mode                  = "ReadWrite"
}

# =============================================================================
# JWT key ID

# Generate random UUID for OpenMetadata JWT keyId
resource "random_uuid" "openmetadata_jwt_keyid" {}

# Store JWT keyId in Key Vault
resource "azurerm_key_vault_secret" "openmetadata_jwt_keyid" {
  name         = "[SECRET_NAME]"
  value        = random_uuid.openmetadata_jwt_keyid.result
  key_vault_id = var.datahub_key_vault_id
}

# =============================================================================
# Database

resource "azurerm_postgresql_flexible_server_database" "openmetadata" {
  count = var.has_db_registration ? 1 : 0

  name      = "openmetadata"
  server_id = var.datahub_postgresql_flexible_server_id

  # Under normal circumstances, you wouldn't want to destroy this database on
  # accident, so protect it from happening with this TF lifecycle rule. We can
  # comment out the rule if we actually intend to replace or destroy the
  # database.
  lifecycle {
    prevent_destroy = true
  }
}

# Generate random password for OpenMetadata PostgreSQL user
resource "random_password" "openmetadata_postgres_password" {
  length  = 32
  special = true
}

# Store OpenMetadata PostgreSQL user password in Key Vault
resource "azurerm_key_vault_secret" "openmetadata_postgres_password" {
  name         = "[SECRET_NAME]"
  value        = random_password.openmetadata_postgres_password.result
  key_vault_id = var.datahub_key_vault_id
}

# Create PostgreSQL role/user for OpenMetadata
resource "postgresql_role" "openmetadata_user" {
  count = var.has_db_registration ? 1 : 0

  name     = var.postgresql_username
  login    = true
  password = random_password.openmetadata_postgres_password.result

  depends_on = [
    azurerm_postgresql_flexible_server_database.openmetadata
  ]
}

# Grant database-level permissions to OpenMetadata user
resource "postgresql_grant" "openmetadata_database" {
  count = var.has_db_registration ? 1 : 0

  database    = azurerm_postgresql_flexible_server_database.openmetadata[0].name
  role        = postgresql_role.openmetadata_user[0].name
  object_type = "database"
  privileges  = ["CONNECT", "CREATE"]

  depends_on = [
    postgresql_role.openmetadata_user
  ]
}

# Grant schema-level permissions to OpenMetadata user
resource "postgresql_grant" "openmetadata_schema" {
  count = var.has_db_registration ? 1 : 0

  database    = azurerm_postgresql_flexible_server_database.openmetadata[0].name
  role        = postgresql_role.openmetadata_user[0].name
  schema      = "public"
  object_type = "schema"
  privileges  = ["USAGE", "CREATE"]

  depends_on = [
    postgresql_role.openmetadata_user
  ]
}