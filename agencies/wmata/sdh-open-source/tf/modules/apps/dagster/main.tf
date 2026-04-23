# =============================================================================
# Database

resource "azurerm_postgresql_flexible_server_database" "dagster" {
  count = var.has_db_registration ? 1 : 0

  name      = "dagster"
  server_id = var.datahub_postgresql_flexible_server_id

  lifecycle {
    prevent_destroy = true
  }
}

# =============================================================================
# Common resources used by Dagster deployments

locals {
  # Generate consistent names for Dagster components
  base_name = trimsuffix(var.app_name, "-ca") # Remove -ca suffix to get base
  dagster_names = {
    webserver = var.app_name                # Main app: [Project Name]-[env3]-dagster-ca
    user_code = "${local.base_name}-uc-ca"  # User code: [Project Name]-[env3]-dagster-uc-ca
    daemon    = "${local.base_name}-dmn-ca" # Daemon: [Project Name]-[env3]-dagster-dmn-ca
  }

  # Read YAML configuration files
  dagster_config_yaml = file("${path.module}/config/dagster.yaml")
  workspace_yaml = templatefile("${path.module}/config/workspace.yaml", {
    user_code_host = local.dagster_names.user_code
  })

  app_registration_client_id     = var.app_registration_client_id != null ? var.app_registration_client_id : (var.can_modify_entra ? azuread_application.dagster[0].client_id : null)
  app_registration_client_secret = var.app_registration_client_secret != null ? var.app_registration_client_secret : (var.can_modify_entra ? azuread_application_password.dagster[0].value : null)

  machine_user_client_id     = var.dagster_machine_user_client_id != null ? var.dagster_machine_user_client_id : (var.can_modify_entra ? azuread_application.dagster[0].client_id : null)
  machine_user_client_secret = var.dagster_machine_user_client_secret != null ? var.dagster_machine_user_client_secret : (var.can_modify_entra ? azuread_application_password.dagster[0].value : null)
}

# ============================================================================
# Secrets

resource "azurerm_key_vault_secret" "dagster_oauth_client_secret" {
  name         = "[SECRET_NAME]"
  value        = local.app_registration_client_secret
  key_vault_id = var.datahub_key_vault_id
}

# Build environment variables for pipeline developers
# This secret contains all environment variables needed to build Dagster images
# in .env file format, allowing pipeline developers to easily configure their
# build process without needing access to the full infrastructure.
resource "azurerm_key_vault_secret" "dagster_build_env" {
  count = var.has_entra ? 1 : 0

  name         = "dagster-build-env-${var.system_name}-${var.env_short}"
  key_vault_id = var.datahub_key_vault_id
  value        = <<-EOT
    # Environment-specific config
    [Project Name]_ENVIRONMENT=${var.environment_name}
    SUBSCRIPTION_ID=${var.arm_subscription_id}
    RESOURCE_GROUP=${var.resource_group_name}
    CONTAINERS=(
      "${local.dagster_names.user_code}"
      "${local.dagster_names.daemon}"
      "${local.dagster_names.webserver}"
    )

    # Key vault for secrets
    KEY_VAULT_NAME=${var.datahub_key_vault_name}

    # Storage accounts for storing data for pipelines
    AZURE_GTFS_STORAGE_ACCOUNT=${var.datahub_lake_storage_account_name}
    AZURE_FARE_STORAGE_ACCOUNT=${var.datahub_lake_storage_account_name}

    # Azure AD authentication settings
    AZURE_TENANT_ID=${var.tenant_id}
    AZURE_CLIENT_ID=${local.machine_user_client_id}
    AZURE_CLIENT_SECRET=${local.machine_user_client_secret}

    # Trino connection settings
    TRINO_HOST=${var.trino_host}
    TRINO_PORT=443
    TRINO_USER=${local.machine_user_client_id}
    TRINO_CATALOG=datahub
    TRINO_SCHEMA=public
    TRINO_USE_HTTPS=true
    TRINO_OAUTH_SCOPE=api://${var.trino_app_registration_client_id}/.default

    # Lakekeeper connection settings
    LAKEKEEPER_URL=${var.lakekeeper_url}
    LAKEKEEPER_OAUTH_SCOPE=api://${var.lakekeeper_app_registration_client_id}/.default

    # Container registry for pushing built images
    CONTAINER_REGISTRY=${var.datahub_container_registry_login_server}

    # Image tag currently deployed in this environment
    DAGSTER_IMAGE_TAG=${var.dagster_image_tag}
  EOT
}

# =============================================================================
# Managed Identities

# Managed identity for Dagster workload identity
resource "azurerm_user_assigned_identity" "dagster" {
  name                = "${var.system_name}-${var.environment_name}-workload-dagster-mi"
  location            = var.resource_group_location
  resource_group_name = var.resource_group_name

  tags = {
    Department  = "[DEPARTMENT]"
    Environment = var.environment_name
    Owner       = "[TEAM]"
    Purpose     = "Dagster workload identity for container apps"
  }
}