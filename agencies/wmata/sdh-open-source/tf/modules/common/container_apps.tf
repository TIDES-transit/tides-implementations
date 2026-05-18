# =======================================================================
# Container Apps Resources
#
# - Container Registry
# - Container App Environment
# - Log Analytics Workspace

resource "azurerm_container_registry" "cr" {
  admin_enabled              = false
  anonymous_pull_enabled     = false
  data_endpoint_enabled      = false
  encryption                 = []
  export_policy_enabled      = true
  location                   = var.resource_group_location
  name                       = local.resource_names.cr
  network_rule_bypass_option = "AzureServices"
  network_rule_set = [{
    default_action = var.public_network_access_enabled ? "Allow" : "Deny"
    ip_rule        = []
  }]
  public_network_access_enabled = var.public_network_access_enabled
  quarantine_policy_enabled     = false
  resource_group_name           = var.resource_group_name
  retention_policy_in_days      = 0
  sku                           = "Premium"
  tags                          = local.cr_tags
  trust_policy_enabled          = false
  zone_redundancy_enabled       = false
}

resource "azurerm_container_app_environment" "cae" {
  count = var.has_network ? 1 : 0

  name                           = local.resource_names.cae
  location                       = var.resource_group_location
  resource_group_name            = var.resource_group_name
  infrastructure_subnet_id       = var.cae_subnet_id
  internal_load_balancer_enabled = !var.external_ingress_enabled
  public_network_access          = var.external_ingress_enabled ? "Enabled" : "Disabled"
  logs_destination               = "log-analytics"
  log_analytics_workspace_id     = azurerm_log_analytics_workspace.log.id
  mutual_tls_enabled             = false
  tags                           = local.cae_tags

  workload_profile {
    maximum_count         = 0
    minimum_count         = 0
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }
  workload_profile {
    maximum_count         = 5
    minimum_count         = 3
    name                  = "datahub-profile"
    workload_profile_type = "D4"
  }

  # Due to VPC integration, only an admin has permission to create this
  # resource, so we should avoid operations that would destroy it.
  lifecycle {
    # prevent_destroy = true
  }
}

resource "azurerm_log_analytics_workspace" "log" {
  allow_resource_only_permissions         = true
  cmk_for_query_forced                    = false
  daily_quota_gb                          = -1
  immediate_data_purge_on_30_days_enabled = false
  internet_ingestion_enabled              = true
  internet_query_enabled                  = true
  local_authentication_enabled            = null
  location                                = var.resource_group_location
  name                                    = local.resource_names.log
  reservation_capacity_in_gb_per_day      = null
  resource_group_name                     = var.resource_group_name
  retention_in_days                       = 30
  sku                                     = "PerGB2018"
  tags                                    = local.log_tags
}
