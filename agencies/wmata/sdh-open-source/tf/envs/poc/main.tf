data "azurerm_client_config" "current" {
}

locals {
  base_name = "${var.system_name}-${var.environment_name}"

  # Common tags applied to all resources
  common_tags = {
    Project     = "[Project Name]"
    Environment = var.environment_name
    SourceFile  = "tf/envs/[env3]/main.tf"
    # TODO: Provide the following as variables filled in during the CD run.
    SourceBranch     = "main"
    SourceRepository = "https://github.com/[ORGANIZATION]/[project-name]"
    Release          = "<commit-hash>"
  }

  # Per-application tags for modules
  app_tags = {
    lakekeeper = merge(local.common_tags, {
      SourceFile  = "tf/envs/[env3]/main.tf"
      Description = "Lakekeeper service for data catalog and governance"
      Application = "lakekeeper"
    })

    trino = merge(local.common_tags, {
      SourceFile  = "tf/envs/[env3]/main.tf"
      Description = "Trino distributed SQL query engine"
      Application = "trino"
    })

    dagster = merge(local.common_tags, {
      SourceFile  = "tf/envs/[env3]/main.tf"
      Description = "Dagster data orchestration platform"
      Application = "dagster"
    })

    openmetadata = merge(local.common_tags, {
      SourceFile  = "tf/envs/[env3]/main.tf"
      Description = "OpenMetadata data discovery and lineage platform"
      Application = "openmetadata"
    })

    echo_http = merge(local.common_tags, {
      SourceFile  = "tf/envs/[env3]/main.tf"
      Description = "Echo HTTP service for debugging and testing"
      Application = "echo-http"
    })
  }
}

module "common" {
  source                       = "../../modules/common"
  tenant_id                    = data.azurerm_client_config.current.tenant_id
  arm_subscription_id          = var.arm_subscription_id
  environment_name             = var.environment_name
  sys_short                    = var.sys_short
  env_short                    = var.env_short
  resource_group_name          = var.resource_group_name
  resource_group_location      = var.resource_group_location
  dns_zone_subscription_id     = var.dns_zone_subscription_id
  dns_zone_resource_group_name = var.dns_zone_resource_group_name
  cae_dns_suffix               = var.cae_dns_suffix
  cae_subnet_id                = var.cae_subnet_id
  pe_subnet_id                 = var.pe_subnet_id
  has_entra                    = true
  has_network                  = true

  resource_name_overrides = {}
}


module "lakekeeper" {
  source                                  = "../../modules/apps/lakekeeper"
  tenant_id                               = data.azurerm_client_config.current.tenant_id
  environment_name                        = var.environment_name
  cae_dns_suffix                          = var.cae_dns_suffix
  resource_group_name                     = var.resource_group_name
  resource_group_location                 = var.resource_group_location
  app_name                                = "lakekeeper"
  app_registration_client_id              = var.lakekeeper_app_registration_client_id
  datahub_users_group_id                  = var.datahub_users_group_id
  datahub_postgresql_flexible_server_id   = module.common.postgres_flexible_server_id
  datahub_postgresql_flexible_server_fqdn = module.common.postgresql_flexible_server_fqdn
  datahub_postgresql_admin_username       = module.common.postgresql_admin_username
  datahub_postgresql_admin_password       = module.common.postgresql_admin_password
  datahub_container_app_environment_id    = module.common.container_app_environment_id
  datahub_key_vault_id                    = module.common.key_vault_id
  can_modify_entra                        = false

  # Since can_modify_entra is false, we need to pass in the ID of an existing
  # Lakekeeper app registration and a known permission scope ID.
  oauth2_permission_scope_id = var.lakekeeper_oauth2_permission_scope_id
}

module "trino" {
  source                                = "../../modules/apps/trino"
  tenant_id                             = data.azurerm_client_config.current.tenant_id
  environment_name                      = var.environment_name
  cae_dns_suffix                        = var.cae_dns_suffix
  resource_group_name                   = var.resource_group_name
  resource_group_location               = var.resource_group_location
  datahub_users_group_id                = var.datahub_users_group_id
  datahub_container_app_environment_id  = module.common.container_app_environment_id
  datahub_key_vault_id                  = module.common.key_vault_id
  datahub_lake_storage_account_id       = module.common.lake_storage_account_id
  lakekeeper_app_registration_client_id = var.lakekeeper_app_registration_client_id
  lakekeeper_oauth2_permission_scope_id = module.lakekeeper.oauth2_permission_scope_id
  can_modify_entra                      = false

  # Since can_modify_entra is false, we need to pass in the client secret for the
  # existing Trino app registration
  app_registration_client_id     = var.trino_app_registration_client_id
  app_registration_client_secret = var.trino_app_registration_client_secret
  app_name                       = "trino"
}

module "dagster_workload_id" {
  source = "../../modules/workload-ids/dagster"

  environment_name        = var.environment_name
  resource_group_name     = var.resource_group_name
  resource_group_location = var.resource_group_location
}

module "dagster" {
  source = "../../modules/apps/dagster"

  # Core infrastructure
  tenant_id                            = data.azurerm_client_config.current.tenant_id
  arm_subscription_id                  = var.arm_subscription_id
  environment_name                     = var.environment_name
  resource_group_name                  = var.resource_group_name
  resource_group_location              = var.resource_group_location
  datahub_container_app_environment_id = module.common.container_app_environment_id
  cae_dns_suffix                       = var.cae_dns_suffix
  app_name                             = "dagster"

  # Machine users
  dagster_machine_user_client_id = var.dagster_app_registration_client_id
  dagster_machine_user_object_id = var.dagster_app_registration_object_id
  datahub_users_group_id         = var.datahub_users_group_id

  # Key Vault and secrets
  datahub_key_vault_id   = module.common.key_vault_id
  datahub_key_vault_name = module.common.key_vault_name

  # Storage
  datahub_lake_storage_account_id   = module.common.lake_storage_account_id
  datahub_lake_storage_account_name = module.common.lake_storage_account_name

  # Container Registry
  datahub_container_registry_login_server = module.common.container_registry_login_server
  datahub_container_registry_id           = module.common.container_registry_id

  # PostgreSQL
  datahub_postgresql_flexible_server_fqdn = module.common.postgresql_flexible_server_fqdn
  datahub_postgresql_admin_username       = module.common.postgresql_admin_username
  datahub_postgresql_admin_password       = module.common.postgresql_admin_password

  # App registration for OpenMetadata
  app_registration_client_id     = var.dagster_app_registration_client_id
  app_registration_client_secret = var.dagster_app_registration_client_secret

  # App registrations for related apps
  lakekeeper_app_registration_client_id = var.lakekeeper_app_registration_client_id
  lakekeeper_oauth2_permission_scope_id = var.lakekeeper_oauth2_permission_scope_id
  trino_app_registration_client_id      = var.trino_app_registration_client_id

  # Dagster-specific configuration
  dagster_image_tag        = var.dagster_image_tag
  [Project Name]_environment = var.[Project Name]_environment

  # Environment controls
  has_entra             = var.has_entra
  workload_profile_name = "Consumption"
  workload_id           = module.dagster_workload_id.workload_id
}

module "openmetadata" {
  source = "../../modules/apps/openmetadata"

  # Core infrastructure
  tenant_id                            = data.azurerm_client_config.current.tenant_id
  system_name                          = var.system_name
  environment_name                     = var.environment_name
  sys_short                            = var.sys_short
  env_short                            = var.env_short
  resource_group_name                  = var.resource_group_name
  resource_group_location              = var.resource_group_location
  datahub_container_app_environment_id = module.common.container_app_environment_id
  container_apps_subnet_id             = var.cae_subnet_id
  cae_dns_suffix                       = var.cae_dns_suffix
  can_modify_entra                     = false
  has_entra                            = var.has_entra

  # User access
  datahub_users_group_id = var.datahub_users_group_id

  # Key Vault
  datahub_key_vault_id   = module.common.key_vault_id
  datahub_key_vault_name = module.common.key_vault_name

  # Database
  datahub_postgresql_flexible_server_fqdn = module.common.postgresql_flexible_server_fqdn
  postgresql_username                     = "openmetadata_user"
  postgresql_password_secret_name         = "[SECRET_NAME]"

  # OpenMetadata configuration
  openmetadata_initial_admin    = var.openmetadata_initial_admin
  openmetadata_principal_domain = var.openmetadata_principal_domain

  # Image versions
  openmetadata_image_tag = "1.9.2"
  opensearch_image_tag   = "2.7.0"

  # Container configuration
  workload_profile_name = "Consumption"

  # Since can_modify_entra is false, we need to pass in the ID of an existing
  # OpenMetadata app registration and a known client secret.
  app_registration_client_id     = var.openmetadata_app_registration_client_id
  app_registration_client_secret = var.openmetadata_app_registration_client_secret
  app_name                       = "openmetadata"
  workload_id                    = module.openmetadata_workload_id.workload_id
}

# Testing/troubleshooting apps
# =======================================

# Echo HTTP Container App -- a simple app that echoes HTTP requests. Useful for
# testing ingress and networking.
module "echo_http" {
  source                               = "../../modules/apps/echo_http"
  resource_group_name                  = var.resource_group_name
  datahub_container_app_environment_id = module.common.container_app_environment_id
}

# Hello World Container App -- a simple web app that displays "Hello, World!"
# and some environment information. Useful for testing container builds and
# deployments.
module "hello_world" {
  source                                  = "../../modules/apps/hello_world"
  arm_subscription_id                     = var.arm_subscription_id
  resource_group_name                     = var.resource_group_name
  resource_group_location                 = var.resource_group_location
  datahub_container_app_environment_id    = module.common.container_app_environment_id
  datahub_container_registry_id           = module.common.container_registry_id
  datahub_container_registry_login_server = module.common.container_registry_login_server
  workload_identity_resource_id           = module.dagster_workload_id.workload_id
}