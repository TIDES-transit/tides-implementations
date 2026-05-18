# =======================================================================
# Networking Resources
#
# - Private DNS Zones
# - Private Endpoints

resource "azurerm_private_dns_zone" "aca" {
  count = var.can_modify_network ? 1 : 0

  name                = "privatelink.eastus.azurecontainerapps.io"
  resource_group_name = var.dns_zone_resource_group_name
}

resource "azurerm_private_dns_zone" "cr" {
  count = var.can_modify_network ? 1 : 0

  name                = "privatelink.azurecr.io"
  resource_group_name = var.dns_zone_resource_group_name
}

resource "azurerm_private_dns_zone" "kv" {
  count = var.can_modify_network ? 1 : 0

  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = var.dns_zone_resource_group_name
}

resource "azurerm_private_dns_zone" "lake_blob" {
  count = var.can_modify_network ? 1 : 0

  name                = "privatelink.blob.core.windows.net"
  resource_group_name = var.dns_zone_resource_group_name
}

resource "azurerm_private_dns_zone" "lake_dfs" {
  count = var.can_modify_network ? 1 : 0

  name                = "privatelink.dfs.core.windows.net"
  resource_group_name = var.dns_zone_resource_group_name
}

resource "azurerm_private_dns_zone" "lake_file" {
  count = var.can_modify_network ? 1 : 0

  name                = "privatelink.file.core.windows.net"
  resource_group_name = var.dns_zone_resource_group_name
}

resource "azurerm_private_dns_zone" "psql" {
  count = var.can_modify_network ? 1 : 0

  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = var.dns_zone_resource_group_name
}

# =======================================================================
# Private DNS Zone VNet Links
#
# Link each private DNS zone to the VNet so that resources within the VNet
# can resolve private endpoint FQDNs to their private IP addresses.

resource "azurerm_private_dns_zone_virtual_network_link" "aca" {
  count = var.can_modify_network ? 1 : 0

  name                  = "${local.base_name}-aca-vnet-link"
  resource_group_name   = var.dns_zone_resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.aca[0].name
  virtual_network_id    = var.vnet_id
}

resource "azurerm_private_dns_zone_virtual_network_link" "cr" {
  count = var.can_modify_network ? 1 : 0

  name                  = "${local.base_name}-cr-vnet-link"
  resource_group_name   = var.dns_zone_resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.cr[0].name
  virtual_network_id    = var.vnet_id
}

resource "azurerm_private_dns_zone_virtual_network_link" "kv" {
  count = var.can_modify_network ? 1 : 0

  name                  = "${local.base_name}-kv-vnet-link"
  resource_group_name   = var.dns_zone_resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.kv[0].name
  virtual_network_id    = var.vnet_id
}

resource "azurerm_private_dns_zone_virtual_network_link" "lake_blob" {
  count = var.can_modify_network ? 1 : 0

  name                  = "${local.base_name}-lake-blob-vnet-link"
  resource_group_name   = var.dns_zone_resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.lake_blob[0].name
  virtual_network_id    = var.vnet_id
}

resource "azurerm_private_dns_zone_virtual_network_link" "lake_dfs" {
  count = var.can_modify_network ? 1 : 0

  name                  = "${local.base_name}-lake-dfs-vnet-link"
  resource_group_name   = var.dns_zone_resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.lake_dfs[0].name
  virtual_network_id    = var.vnet_id
}

resource "azurerm_private_dns_zone_virtual_network_link" "lake_file" {
  count = var.can_modify_network ? 1 : 0

  name                  = "${local.base_name}-lake-file-vnet-link"
  resource_group_name   = var.dns_zone_resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.lake_file[0].name
  virtual_network_id    = var.vnet_id
}

resource "azurerm_private_dns_zone_virtual_network_link" "psql" {
  count = var.can_modify_network ? 1 : 0

  name                  = "${local.base_name}-psql-vnet-link"
  resource_group_name   = var.dns_zone_resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.psql[0].name
  virtual_network_id    = var.vnet_id
}

resource "azurerm_private_endpoint" "aca" {
  count = var.has_network && !var.external_ingress_enabled && length(azurerm_container_app_environment.cae) > 0 ? 1 : 0

  custom_network_interface_name = local.resource_names.nic_aca
  location                      = var.resource_group_location
  name                          = local.resource_names.pe_aca
  resource_group_name           = var.resource_group_name
  subnet_id                     = var.pe_subnet_id
  tags                          = local.common_tags

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = ["/subscriptions/${var.dns_zone_subscription_id}/resourceGroups/${lower(var.dns_zone_resource_group_name)}/providers/Microsoft.Network/privateDnsZones/privatelink.eastus.azurecontainerapps.io"]
  }
  private_service_connection {
    is_manual_connection           = false
    name                           = local.resource_names.pe_aca
    private_connection_resource_id = azurerm_container_app_environment.cae[0].id
    subresource_names              = ["managedEnvironments"]
  }

  depends_on = [
    azurerm_private_dns_zone.aca,
  ]

  lifecycle {
    ignore_changes = [
      private_dns_zone_group,
    ]
  }
}

resource "azurerm_private_endpoint" "cr" {
  # Private endpoints rely on an existing subnet.
  count = var.has_network ? 1 : 0

  custom_network_interface_name = local.resource_names.nic_cr
  location                      = var.resource_group_location
  name                          = local.resource_names.pe_cr
  resource_group_name           = var.resource_group_name
  subnet_id                     = var.pe_subnet_id
  tags                          = local.common_tags

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = ["/subscriptions/${var.dns_zone_subscription_id}/resourceGroups/${lower(var.dns_zone_resource_group_name)}/providers/Microsoft.Network/privateDnsZones/privatelink.azurecr.io"]
  }
  private_service_connection {
    is_manual_connection           = false
    name                           = local.resource_names.pe_cr
    private_connection_resource_id = azurerm_container_registry.cr.id
    subresource_names              = ["registry"]
  }

  depends_on = [
    azurerm_private_dns_zone.cr,
  ]

  lifecycle {
    ignore_changes = [
      private_dns_zone_group,
    ]
  }
}

resource "azurerm_private_endpoint" "kv" {
  # Private endpoints rely on an existing subnet.
  count = var.has_network ? 1 : 0

  custom_network_interface_name = local.resource_names.nic_kv
  location                      = var.resource_group_location
  name                          = local.resource_names.pe_kv
  resource_group_name           = var.resource_group_name
  subnet_id                     = var.pe_subnet_id
  tags                          = local.common_tags

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = ["/subscriptions/${var.dns_zone_subscription_id}/resourceGroups/${lower(var.dns_zone_resource_group_name)}/providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net"]
  }
  private_service_connection {
    is_manual_connection           = false
    name                           = local.resource_names.pe_kv
    private_connection_resource_id = azurerm_key_vault.kv.id
    subresource_names              = ["vault"]
  }

  depends_on = [
    azurerm_private_dns_zone.kv,
  ]

  lifecycle {
    ignore_changes = [
      private_dns_zone_group,
    ]
  }
}

resource "azurerm_private_endpoint" "lake_blob" {
  # Private endpoints rely on an existing subnet.
  count = var.has_network ? 1 : 0

  custom_network_interface_name = local.resource_names.nic_lake_blob
  location                      = var.resource_group_location
  name                          = local.resource_names.pe_lake_blob
  resource_group_name           = var.resource_group_name
  subnet_id                     = var.pe_subnet_id
  tags                          = local.common_tags

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = ["/subscriptions/${var.dns_zone_subscription_id}/resourceGroups/${lower(var.dns_zone_resource_group_name)}/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net"]
  }
  private_service_connection {
    is_manual_connection           = false
    name                           = local.resource_names.pe_lake_blob
    private_connection_resource_id = azurerm_storage_account.lake.id
    subresource_names              = ["blob"]
  }

  depends_on = [
    azurerm_private_dns_zone.lake_blob,
  ]

  lifecycle {
    ignore_changes = [
      private_dns_zone_group,
    ]
  }
}

resource "azurerm_private_endpoint" "lake_dfs" {
  # Private endpoints rely on an existing subnet.
  count = var.has_network ? 1 : 0

  custom_network_interface_name = local.resource_names.nic_lake_dfs
  location                      = var.resource_group_location
  name                          = local.resource_names.pe_lake_dfs
  resource_group_name           = var.resource_group_name
  subnet_id                     = var.pe_subnet_id
  tags                          = local.common_tags

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = ["/subscriptions/${var.dns_zone_subscription_id}/resourceGroups/${lower(var.dns_zone_resource_group_name)}/providers/Microsoft.Network/privateDnsZones/privatelink.dfs.core.windows.net"]
  }
  private_service_connection {
    is_manual_connection           = false
    name                           = local.resource_names.pe_lake_dfs
    private_connection_resource_id = azurerm_storage_account.lake.id
    subresource_names              = ["dfs"]
  }

  depends_on = [
    azurerm_private_dns_zone.lake_dfs,
  ]

  lifecycle {
    ignore_changes = [
      private_dns_zone_group,
    ]
  }
}

resource "azurerm_private_endpoint" "lake_file" {
  # Private endpoints rely on an existing subnet.
  count = var.has_network ? 1 : 0

  custom_network_interface_name = local.resource_names.nic_lake_file
  location                      = var.resource_group_location
  name                          = local.resource_names.pe_lake_file
  resource_group_name           = var.resource_group_name
  subnet_id                     = var.pe_subnet_id
  tags                          = local.common_tags

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = ["/subscriptions/${var.dns_zone_subscription_id}/resourceGroups/${lower(var.dns_zone_resource_group_name)}/providers/Microsoft.Network/privateDnsZones/privatelink.file.core.windows.net"]
  }
  private_service_connection {
    is_manual_connection           = false
    name                           = local.resource_names.pe_lake_file
    private_connection_resource_id = azurerm_storage_account.lake.id
    subresource_names              = ["file"]
  }

  depends_on = [
    azurerm_private_dns_zone.lake_file,
  ]

  lifecycle {
    ignore_changes = [
      private_dns_zone_group,
    ]
  }
}

resource "azurerm_private_endpoint" "psql" {
  # Private endpoints rely on an existing subnet.
  count = var.has_network && var.has_db_registration ? 1 : 0

  custom_network_interface_name = local.resource_names.nic_psql
  location                      = var.resource_group_location
  name                          = local.resource_names.pe_psql
  resource_group_name           = var.resource_group_name
  subnet_id                     = var.pe_subnet_id
  tags                          = local.common_tags

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = ["/subscriptions/${var.dns_zone_subscription_id}/resourceGroups/${lower(var.dns_zone_resource_group_name)}/providers/Microsoft.Network/privateDnsZones/privatelink.postgres.database.azure.com"]
  }
  private_service_connection {
    is_manual_connection           = false
    name                           = local.resource_names.pe_psql
    private_connection_resource_id = azurerm_postgresql_flexible_server.psql[0].id
    subresource_names              = ["postgresqlServer"]
  }

  depends_on = [
    azurerm_private_dns_zone.psql,
  ]

  lifecycle {
    ignore_changes = [
      private_dns_zone_group,
    ]
  }
}
