data "azurerm_client_config" "current" {
}

locals {
  base_name = "${var.system_name}-${var.environment_name}"

  # Common tags applied to all resources
  common_tags = {
    Project     = "[Project Name]"
    Environment = var.environment_name
    SourceFile  = "tf/envs/${var.env_short}/main.tf"
    # TODO: Provide the following as variables filled in during the CD run.
    SourceBranch     = "main"
    SourceRepository = "https://github.com/[ORGANIZATION]/[project-name]"
    Release          = "<commit-hash>"
  }

  # Per-application tags for modules
  app_tags = {
    lakekeeper = merge(local.common_tags, {
      Description = "Lakekeeper service for data catalog and governance"
      Application = "lakekeeper"
    })

    trino = merge(local.common_tags, {
      Description = "Trino distributed SQL query engine"
      Application = "trino"
    })

    dagster = merge(local.common_tags, {
      Description = "Dagster data orchestration platform"
      Application = "dagster"
    })

    openmetadata = merge(local.common_tags, {
      Description = "OpenMetadata data discovery and lineage platform"
      Application = "openmetadata"
    })

    echo_http = merge(local.common_tags, {
      Description = "Echo HTTP service for debugging and testing"
      Application = "echo-http"
    })
  }
}

module "common" {
  source                        = "../../modules/common"
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  arm_subscription_id           = var.arm_subscription_id
  resource_group_name           = var.resource_group_name
  resource_group_location       = var.resource_group_location
  dns_zone_subscription_id      = var.dns_zone_subscription_id
  dns_zone_resource_group_name  = var.dns_zone_resource_group_name
  public_network_access_enabled = var.public_network_access_enabled

  # Temporarily override the database name/location until we can
  # get the quotas increased in East US.
  db_location_override = "centralus"
  resource_name_overrides = {}

  cae_dns_suffix      = module.common.container_app_environment_default_domain
  cae_subnet_id       = var.cae_subnet_id
  pe_subnet_id        = var.pe_subnet_id
  environment_name    = var.environment_name
  sys_short           = var.sys_short
  env_short           = var.env_short
  has_entra           = var.has_entra
  has_network         = var.has_network
  has_db_registration = var.has_db_registration
  psql_firewall_rules = var.psql_firewall_rules

}

module "lakekeeper" {
  source    = "../../modules/apps/lakekeeper"
  tenant_id = data.azurerm_client_config.current.tenant_id
  # subscription_environment                = var.subscription_environment
  environment_name                        = var.environment_name
  sys_short                               = var.sys_short
  env_short                               = var.env_short
  cae_dns_suffix                          = module.common.container_app_environment_default_domain
  resource_group_name                     = var.resource_group_name
  resource_group_location                 = var.resource_group_location
  app_name                                = module.common.app_names.lakekeeper
  app_registration_client_id              = var.lakekeeper_app_registration_client_id
  app_service_principal_object_id         = var.lakekeeper_app_service_principal_object_id
  datahub_users_group_id                  = var.datahub_users_group_id
  datahub_developers_group_id             = var.datahub_developers_group_id
  datahub_postgresql_flexible_server_id   = module.common.postgres_flexible_server_id
  datahub_postgresql_flexible_server_fqdn = module.common.postgresql_flexible_server_fqdn
  datahub_postgresql_admin_username       = module.common.postgresql_admin_username
  datahub_postgresql_admin_password       = module.common.postgresql_admin_password
  datahub_container_app_environment_id    = module.common.container_app_environment_id
  datahub_key_vault_id                    = module.common.key_vault_id
  datahub_key_vault_name                  = module.common.key_vault_name
  has_db_registration                     = var.has_db_registration
  can_modify_entra                        = false

  # Since can_modify_entra is false, we need to pass in the ID of an existing
  # Lakekeeper app registration and a known permission scope ID.
  oauth2_permission_scope_id = var.lakekeeper_oauth2_permission_scope_id

  # Container registry for bootstrap job image
  datahub_container_registry_id           = module.common.container_registry_id
  datahub_container_registry_login_server = module.common.container_registry_login_server

  # Bootstrap job configuration - uses Trino's SP since it has a direct app role
  # assignment on the Lakekeeper enterprise app (required for client credentials
  # flow; group membership alone is not sufficient); this should be changed to use
  # Lakekeeper's SP once the necessary permissions are granted.
  bootstrap_client_id     = var.trino_app_registration_client_id
  bootstrap_client_secret = var.trino_app_registration_client_secret

  # Use Dagster's workload identity temporarily until security team assigns
  # AcrPull to the Lakekeeper identity (module.lakekeeper.workload_identity_principal_id)
  workload_identity_id = module.dagster.dagster_workload_identity_id

  # Warehouse configuration - uses Lakekeeper's SP for storage access
  # Note: Lakekeeper's SP needs Storage Blob Data Contributor role on the storage account
  datahub_lake_storage_account_id   = module.common.lake_storage_account_id
  datahub_lake_storage_account_name = module.common.lake_storage_account_name
  storage_client_id                 = var.lakekeeper_app_registration_client_id
  storage_client_secret             = var.lakekeeper_app_registration_client_secret

  # Image tag
  lakekeeper_image_tag = "v0.9.1"

  # Authorization - OpenFGA
  openfga_endpoint = module.openfga.openfga_grpc_endpoint
  openfga_api_key  = module.openfga.openfga_preshared_key

  # App SP grants
  app_sp_grants = {
    (var.dagster_app_service_principal_object_id) = "data_admin"
    (var.trino_app_service_principal_object_id)   = "data_admin"
  }
}

module "trino" {
  source                                = "../../modules/apps/trino"
  tenant_id                             = data.azurerm_client_config.current.tenant_id
  system_name                           = var.system_name
  environment_name                      = var.environment_name
  cae_dns_suffix                        = module.common.container_app_environment_default_domain
  resource_group_name                   = var.resource_group_name
  resource_group_location               = var.resource_group_location
  datahub_users_group_id                = var.datahub_users_group_id
  datahub_container_app_environment_id  = module.common.container_app_environment_id
  datahub_key_vault_id                  = module.common.key_vault_id
  datahub_lake_storage_account_id       = module.common.lake_storage_account_id
  lakekeeper_app_registration_client_id = module.lakekeeper.app_registration_client_id
  lakekeeper_oauth2_permission_scope_id = module.lakekeeper.oauth2_permission_scope_id
  lakekeeper_catalog_url                = module.lakekeeper.lakekeeper_catalog_url
  can_modify_entra                      = false
  has_entra                             = var.has_entra

  # Since can_modify_entra is false, we need to pass in the client secret for the
  # existing Trino app registration
  app_registration_client_id     = var.trino_app_registration_client_id
  app_registration_client_secret = var.trino_app_registration_client_secret
  app_name                       = module.common.app_names.trino
  workload_profile_name          = "datahub-profile"
  worker_memory                  = "16Gi"

  # Authorization - OPA, with Lakekeeper's OPA bridge to OpenFGA
  opa_policy_uri       = module.opa.opa_policy_uri
  opa_batch_policy_uri = module.opa.opa_batch_policy_uri
}

module "dagster" {
  source = "../../modules/apps/dagster"

  # Core infrastructure
  tenant_id                            = data.azurerm_client_config.current.tenant_id
  arm_subscription_id                  = var.arm_subscription_id
  system_name                          = var.system_name
  environment_name                     = var.environment_name
  env_short                            = var.env_short
  resource_group_name                  = var.resource_group_name
  resource_group_location              = var.resource_group_location
  datahub_container_app_environment_id = module.common.container_app_environment_id
  cae_dns_suffix                       = module.common.container_app_environment_default_domain
  app_name                             = module.common.app_names.dagster

  # Machine users
  dagster_machine_user_client_id     = var.dagster_app_registration_client_id
  dagster_machine_user_client_secret = var.dagster_app_registration_client_secret
  dagster_machine_user_object_id     = var.dagster_app_registration_object_id
  datahub_users_group_id             = var.datahub_users_group_id

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
  has_db_registration                     = var.has_db_registration
  datahub_postgresql_flexible_server_id   = module.common.postgres_flexible_server_id
  datahub_postgresql_flexible_server_fqdn = module.common.postgresql_flexible_server_fqdn
  datahub_postgresql_admin_username       = module.common.postgresql_admin_username
  datahub_postgresql_admin_password       = module.common.postgresql_admin_password

  # App registration for OpenMetadata
  app_registration_client_id     = var.dagster_app_registration_client_id
  app_registration_client_secret = var.dagster_app_registration_client_secret

  # App registrations for related apps
  lakekeeper_app_registration_client_id      = module.lakekeeper.app_registration_client_id
  lakekeeper_oauth2_permission_scope_id      = module.lakekeeper.oauth2_permission_scope_id
  lakekeeper_app_service_principal_object_id = module.lakekeeper.app_service_principal_object_id
  lakekeeper_url                             = module.lakekeeper.lakekeeper_url
  trino_host                                 = module.trino.trino_host
  trino_app_registration_client_id           = module.trino.app_registration_client_id
  openmetadata_api_url                       = module.openmetadata.openmetadata_api_url

  # Dagster-specific configuration
  dagster_image_tag        = var.dagster_image_tag
  [Project Name]_environment = var.[Project Name]_environment

  # Environment controls
  has_entra             = var.has_entra
  workload_profile_name = "Consumption"
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
  cae_dns_suffix                       = module.common.container_app_environment_default_domain
  can_modify_entra                     = false
  has_entra                            = var.has_entra

  # User access
  datahub_users_group_id = var.datahub_users_group_id

  # Key Vault
  datahub_key_vault_id   = module.common.key_vault_id
  datahub_key_vault_name = module.common.key_vault_name

  # Database
  datahub_postgresql_flexible_server_fqdn = module.common.postgresql_flexible_server_fqdn
  datahub_postgresql_flexible_server_id   = module.common.postgres_flexible_server_id
  datahub_postgresql_admin_username       = module.common.postgresql_admin_username
  datahub_postgresql_admin_password       = module.common.postgresql_admin_password
  has_db_registration                     = var.has_db_registration

  # OpenMetadata configuration
  openmetadata_initial_admin    = var.openmetadata_initial_admin
  openmetadata_principal_domain = var.openmetadata_principal_domain

  # Image versions
  openmetadata_image_tag = "1.11.8"
  opensearch_image_tag   = "2.19.3"

  # Container configuration
  workload_profile_name = "Consumption"

  # Since can_modify_entra is false, we need to pass in the ID of an existing
  # OpenMetadata app registration and a known client secret.
  app_registration_client_id     = var.openmetadata_app_registration_client_id
  app_registration_client_secret = var.openmetadata_app_registration_client_secret
  app_name                       = module.common.app_names.openmetadata
}

module "metabase" {
  source = "../../modules/apps/metabase"

  # Core infrastructure
  system_name                          = var.system_name
  environment_name                     = var.environment_name
  sys_short                            = var.sys_short
  env_short                            = var.env_short
  resource_group_name                  = var.resource_group_name
  resource_group_location              = var.resource_group_location
  datahub_container_app_environment_id = module.common.container_app_environment_id
  cae_dns_suffix                       = module.common.container_app_environment_default_domain
  app_name                             = module.common.app_names.metabase
  has_entra                            = var.has_entra

  # Key Vault
  datahub_key_vault_id   = module.common.key_vault_id
  datahub_key_vault_name = module.common.key_vault_name

  # Database
  datahub_postgresql_flexible_server_fqdn = module.common.postgresql_flexible_server_fqdn
  datahub_postgresql_flexible_server_id   = module.common.postgres_flexible_server_id
  datahub_postgresql_admin_username       = module.common.postgresql_admin_username
  datahub_postgresql_admin_password       = module.common.postgresql_admin_password
  has_db_registration                     = var.has_db_registration

  # Image versions
  metabase_image_tag = "v0.55.6"

  # Container configuration
  workload_profile_name = "Consumption"
}

module "openfga" {
  source = "../../modules/apps/openfga"

  tenant_id                               = data.azurerm_client_config.current.tenant_id
  environment_name                        = var.environment_name
  sys_short                               = var.sys_short
  env_short                               = var.env_short
  cae_dns_suffix                          = module.common.container_app_environment_default_domain
  resource_group_name                     = var.resource_group_name
  resource_group_location                 = var.resource_group_location
  datahub_key_vault_id                    = module.common.key_vault_id
  datahub_container_app_environment_id    = module.common.container_app_environment_id
  datahub_postgresql_flexible_server_id   = module.common.postgres_flexible_server_id
  datahub_postgresql_flexible_server_fqdn = module.common.postgresql_flexible_server_fqdn
  datahub_postgresql_admin_username       = module.common.postgresql_admin_username
  datahub_postgresql_admin_password       = module.common.postgresql_admin_password
  datahub_container_registry_id           = module.common.container_registry_id
  datahub_container_registry_login_server = module.common.container_registry_login_server
  has_entra                               = var.has_entra
  has_db_registration                     = var.has_db_registration
  app_name                                = module.common.app_names.openfga
  enable_playground                       = true

  # Use Dagster's workload identity for AcrPull (same pattern as lakekeeper)
  workload_identity_id = module.dagster.dagster_workload_identity_id
}

module "opa" {
  source = "../../modules/apps/opa"

  tenant_id                            = data.azurerm_client_config.current.tenant_id
  sys_short                            = var.sys_short
  env_short                            = var.env_short
  resource_group_name                  = var.resource_group_name
  resource_group_location              = var.resource_group_location
  datahub_key_vault_id                 = module.common.key_vault_id
  datahub_container_app_environment_id = module.common.container_app_environment_id
  app_name                             = module.common.app_names.opa

  # Lakekeeper connection
  lakekeeper_internal_url               = module.lakekeeper.lakekeeper_url
  lakekeeper_app_registration_client_id = module.lakekeeper.app_registration_client_id
  lakekeeper_version                    = "v0.9.1"

  opa_client_id     = var.trino_app_registration_client_id
  opa_client_secret = var.trino_app_registration_client_secret

  depends_on = [module.lakekeeper]
}

# Testing/troubleshooting jobs
# =======================================

# Shell Test Job -- a general-purpose troubleshooting job that runs an Alpine
# container with networking tools. Useful for ad-hoc debugging and testing.
# See tf/modules/debug/jobs/sh_test/README.md for usage instructions.
module "sh_test_job" {
  source                               = "../../modules/debug/jobs/sh_test"
  resource_group_name                  = var.resource_group_name
  resource_group_location              = var.resource_group_location
  datahub_container_app_environment_id = module.common.container_app_environment_id
  sys_short                            = var.sys_short
  env_short                            = var.env_short
  tags                                 = local.common_tags
}

# DNS Test Job -- tests DNS resolution for all private endpoints in the
# environment. Useful for verifying private DNS zone configuration.
module "dns_test_job" {
  source                               = "../../modules/debug/jobs/dns_test"
  resource_group_name                  = var.resource_group_name
  resource_group_location              = var.resource_group_location
  datahub_container_app_environment_id = module.common.container_app_environment_id
  sys_short                            = var.sys_short
  env_short                            = var.env_short
  tags                                 = local.common_tags

  # Private endpoint FQDNs
  postgresql_privatelink_fqdn         = module.common.postgresql_privatelink_fqdn
  container_registry_privatelink_fqdn = module.common.container_registry_privatelink_fqdn
  key_vault_privatelink_fqdn          = module.common.key_vault_privatelink_fqdn
  storage_blob_privatelink_fqdn       = module.common.storage_blob_privatelink_fqdn
  storage_dfs_privatelink_fqdn        = module.common.storage_dfs_privatelink_fqdn
  storage_file_privatelink_fqdn       = module.common.storage_file_privatelink_fqdn
}

# PostgreSQL Test Job -- a troubleshooting job that tests PostgreSQL connectivity
# from within the Container Apps environment. Useful for verifying private endpoint
# connectivity and database access.
# See tf/modules/jobs/psql_test/README.md for usage instructions.
module "psql_test_job" {
  source                               = "../../modules/debug/jobs/psql_test"
  resource_group_name                  = var.resource_group_name
  resource_group_location              = var.resource_group_location
  datahub_container_app_environment_id = module.common.container_app_environment_id
  sys_short                            = var.sys_short
  env_short                            = var.env_short
  postgresql_host                      = module.common.postgresql_flexible_server_fqdn
  tags                                 = local.common_tags
}

# Trino Test Job -- a troubleshooting job that uses the Trino CLI to test
# connectivity and catalog access from within the Container Apps environment.
# Useful for verifying Trino -> Lakekeeper connectivity.
# See tf/modules/debug/jobs/trino_test/README.md for usage instructions.
module "trino_test_job" {
  source                               = "../../modules/debug/jobs/trino_test"
  resource_group_name                  = var.resource_group_name
  resource_group_location              = var.resource_group_location
  datahub_container_app_environment_id = module.common.container_app_environment_id
  sys_short                            = var.sys_short
  env_short                            = var.env_short
  trino_url                            = module.trino.password_user_credentials["tableau"].trino_url
  trino_password                       = module.trino.password_user_credentials["tableau"].password
  tags                                 = local.common_tags
}

# PyIceberg Test Job -- a troubleshooting job that tests PyIceberg connectivity
# to Lakekeeper and attempts table creation. Useful for diagnosing 412 Precondition
# Failed errors and other PyIceberg/catalog issues.
module "pyiceberg_test_job" {
  source                               = "../../modules/debug/jobs/pyiceberg_test"
  resource_group_name                  = var.resource_group_name
  resource_group_location              = var.resource_group_location
  datahub_container_app_environment_id = module.common.container_app_environment_id
  sys_short                            = var.sys_short
  env_short                            = var.env_short
  tenant_id                            = data.azurerm_client_config.current.tenant_id
  lakekeeper_url                       = module.lakekeeper.lakekeeper_url
  lakekeeper_warehouse                 = "datahub"
  lakekeeper_client_id                 = var.lakekeeper_app_registration_client_id
  lakekeeper_client_secret             = var.lakekeeper_app_registration_client_secret
  lakekeeper_oauth_scope               = "api://${var.lakekeeper_app_registration_client_id}/.default"
  tags                                 = local.common_tags
}