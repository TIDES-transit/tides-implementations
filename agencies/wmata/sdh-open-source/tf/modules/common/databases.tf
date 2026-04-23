# =======================================================================
# Database Resources
#
# - PostgreSQL Flexible Server (individual app-specific databases are created
#   within specific app modules)

resource "azurerm_postgresql_flexible_server" "psql" {
  count = var.has_db_registration ? 1 : 0

  administrator_login    = azurerm_key_vault_secret.psql_admin_username.value
  administrator_password = azurerm_key_vault_secret.psql_admin_password.value

  auto_grow_enabled                 = false
  backup_retention_days             = 7
  create_mode                       = null
  geo_redundant_backup_enabled      = false
  location                          = coalesce(var.db_location_override, var.resource_group_location)
  name                              = local.resource_names.psql
  point_in_time_restore_time_in_utc = null
  public_network_access_enabled     = var.public_network_access_enabled
  resource_group_name               = var.resource_group_name
  sku_name                          = "GP_Standard_D2ds_v4"
  source_server_id                  = null
  storage_mb                        = 32768
  storage_tier                      = "P4"
  tags                              = local.psql_tags
  version                           = "16"
  zone                              = "1"
  authentication {
    active_directory_auth_enabled = true
    password_auth_enabled         = true
    tenant_id                     = var.tenant_id
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_postgresql_flexible_server_configuration" "psql_extensions" {
  count = var.has_db_registration ? 1 : 0

  name      = "azure.extensions"
  server_id = azurerm_postgresql_flexible_server.psql[0].id

  # The uuid-ossp, pgcrypto, pg_trgm, and btree_gin PostgreSQL extensions are
  # used by the Lakekeeper database; citext is used by Metabase; we have to explicitly allow-list them.
  value = "UUID-OSSP,PGCRYPTO,PG_TRGM,BTREE_GIN,CITEXT"
}

# Increase max connections to handle OpenMetadata's connection requirements
resource "azurerm_postgresql_flexible_server_configuration" "psql_max_connections" {
  count = var.has_db_registration ? 1 : 0

  name      = "max_connections"
  server_id = azurerm_postgresql_flexible_server.psql[0].id
  value     = "100" # Default is 50 for B1ms, increasing to 100
}

# Firewall rules for PostgreSQL server (for public network access)
resource "azurerm_postgresql_flexible_server_firewall_rule" "rules" {
  for_each = var.has_db_registration ? var.psql_firewall_rules : {}

  name             = each.key
  server_id        = azurerm_postgresql_flexible_server.psql[0].id
  start_ip_address = each.value.start_ip_address
  end_ip_address   = each.value.end_ip_address
}

