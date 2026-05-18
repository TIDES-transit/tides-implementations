data "azurerm_client_config" "current" {
}

locals {
  base_name = "${var.system_name}-${var.environment_name}"

  # Common tags applied to all resources
  common_tags = {
    Project           = "[Project Name]"
    Environment       = var.environment_name
    Release           = "[env3]"
    SourceBranch      = "main"
    SourceRepository  = "https://github.com/[ORGANIZATION]/[project-name]"
    Release           = "<commit-hash>"
  }

  # Resource names following the same pattern as common module
  resource_names = {
    vnet = "${local.base_name}-${var.vnet_purpose}-vn"
    snet_aca = "${local.base_name}-aca-snet"
    snet_pe = "${local.base_name}-pe-snet"
    snet_psql = "${local.base_name}-psql-snet"
    cae = "${local.base_name}-cae"
  }

  # Per-resource tags
  vnet_tags = merge(local.common_tags, {
    SourceFile  = "tf/envs/[env3]/network/main.tf"
    Description = "Virtual network for [env3] environment with subnets for container apps, private endpoints, and PostgreSQL"
  })

  snet_tags = merge(local.common_tags, {
    SourceFile  = "tf/envs/[env3]/network/main.tf"
    Description = "Subnet for secure communication and resource isolation"
  })

  cae_tags = merge(local.common_tags, {
    SourceFile  = "tf/envs/[env3]/network/main.tf"
    Description = "Container app environment for hosting containerized applications"
  })

  vnet_address_space = "10.61.86.0/23"
  vnet_dns_servers   = ["[PRIVATE_IP]", "[PRIVATE_IP]"]

  subnet_address_spaces = {
    aca  = "10.61.87.0/24"
    pe   = "10.61.86.128/27"
    psql = "10.61.86.32/27"
  }
}

# =======================================================================
# Networking Resources


resource "azurerm_virtual_network" "vnet" {
  address_space                  = [local.vnet_address_space]
  dns_servers                    = local.vnet_dns_servers
  location                       = var.resource_group_location
  name                           = local.resource_names.vnet
  private_endpoint_vnet_policies = "Disabled"
  resource_group_name            = var.vnet_rg_name
  tags = local.vnet_tags

  # Only an admin has permission to create this resource, so we should avoid
  # operations that would destroy it.
  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_subnet" "aca" {
  address_prefixes                              = [local.subnet_address_spaces.aca]
  default_outbound_access_enabled               = true
  name                                          = local.resource_names.snet_aca
  private_endpoint_network_policies             = "Disabled"
  private_link_service_network_policies_enabled = true
  resource_group_name                           = var.vnet_rg_name
  service_endpoint_policy_ids                   = []
  service_endpoints                             = []
  virtual_network_name                          = local.resource_names.vnet
  delegation {
    name = "Microsoft.App.environments"
    service_delegation {
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      name    = "Microsoft.App/environments"
    }
  }

  # Due to VPC integration, only an admin has permission to create this
  # resource, so we should avoid operations that would destroy it.
  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_subnet" "pe" {
  address_prefixes                              = [local.subnet_address_spaces.pe]
  default_outbound_access_enabled               = true
  name                                          = local.resource_names.snet_pe
  private_endpoint_network_policies             = "Disabled"
  private_link_service_network_policies_enabled = true
  resource_group_name                           = var.vnet_rg_name
  service_endpoint_policy_ids                   = []
  service_endpoints                             = []
  virtual_network_name                          = local.resource_names.vnet

  # Due to VPC integration, only an admin has permission to create this
  # resource, so we should avoid operations that would destroy it.
  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_subnet" "psql" {
  address_prefixes                              = [local.subnet_address_spaces.psql]
  default_outbound_access_enabled               = true
  name                                          = local.resource_names.snet_psql
  private_endpoint_network_policies             = "Disabled"
  private_link_service_network_policies_enabled = true
  resource_group_name                           = var.vnet_rg_name
  service_endpoint_policy_ids                   = []
  service_endpoints                             = []
  virtual_network_name                          = local.resource_names.vnet
  delegation {
    name = "Microsoft.DBforPostgreSQL/flexibleServers"
    service_delegation {
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
    }
  }

  # Due to VPC integration, only an admin has permission to create this
  # resource, so we should avoid operations that would destroy it.
  lifecycle {
    prevent_destroy = true
  }
}

# =======================================================================
# Container Apps Resources
#
# - Container App Environment
#
#   Because the subnet of the environment cannot be changed after creation, the
#   subnet must be created first. Further, from previous experience, we were not
#   able to create a container environment and integrate it with a subnet with
#   the level of access available to us, so this resource needs to be created by
#   an admin.

resource "azurerm_container_app_environment" "cae" {
  name                           = local.resource_names.cae
  location                       = var.resource_group_location
  resource_group_name            = var.resource_group_name
  infrastructure_subnet_id       = azurerm_subnet.aca.id
  internal_load_balancer_enabled = true
  mutual_tls_enabled             = false

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

  tags = local.cae_tags

  # Due to VPC integration, only an admin has permission to create this
  # resource, so we should avoid operations that would destroy it.
  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      log_analytics_workspace_id,
    ]
  }
}