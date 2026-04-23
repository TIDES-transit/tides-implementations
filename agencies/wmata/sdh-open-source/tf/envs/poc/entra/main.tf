module "common" {
  source                   = "../../../modules/entra/common"
  datahub_users_group_name = "[Project Name] Users"
}

module "lakekeeper" {
  source                     = "../../../modules/entra/lakekeeper"
  datahub_cae_dns_suffix     = var.datahub_cae_dns_suffix
  datahub_users_group_id     = module.common.datahub_users_group_id
  oauth2_permission_scope_id = var.lakekeeper_oauth2_permission_scope_id
}

module "trino" {
  source                          = "../../../modules/entra/trino"
  datahub_cae_dns_suffix          = var.datahub_cae_dns_suffix
  datahub_users_group_id          = module.common.datahub_users_group_id
  datahub_lake_storage_account_id = var.datahub_lake_storage_account_id
  lakekeeper_app_client_id        = module.lakekeeper.app_client_id
  lakekeeper_oauth2_scope_id      = module.lakekeeper.oauth2_scope_id
  workload_identity_principal_id  = var.trino_workload_identity_principal_id
  can_create_app_passwords        = false
}

module "dagster" {
  source                         = "../../../modules/entra/dagster"
  datahub_key_vault_id           = var.datahub_key_vault_id
  datahub_container_registry_id  = var.datahub_container_registry_id
  datahub_cae_dns_suffix         = var.datahub_cae_dns_suffix
  datahub_users_group_id         = module.common.datahub_users_group_id
  lakekeeper_app_client_id       = module.lakekeeper.app_client_id
  lakekeeper_oauth2_scope_id     = module.lakekeeper.oauth2_scope_id
  workload_identity_principal_id = var.dagster_workload_identity_principal_id
  can_create_app_passwords       = false
}

module "openmetadata" {
  source                         = "../../../modules/entra/openmetadata"
  datahub_cae_dns_suffix         = var.datahub_cae_dns_suffix
  datahub_key_vault_id           = var.datahub_key_vault_id
  datahub_users_group_id         = module.common.datahub_users_group_id
  workload_identity_principal_id = var.openmetadata_workload_identity_principal_id
  can_create_app_passwords       = false
}