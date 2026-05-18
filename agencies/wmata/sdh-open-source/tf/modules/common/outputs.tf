output "lake_storage_account_id" {
  value = azurerm_storage_account.lake.id
}

output "lake_storage_account_name" {
  value = azurerm_storage_account.lake.name
}

output "key_vault_id" {
  value = azurerm_key_vault.kv.id
}

output "key_vault_name" {
  value = azurerm_key_vault.kv.name
}

output "container_app_environment_id" {
  value = var.has_network ? azurerm_container_app_environment.cae[0].id : null
}

output "container_app_environment_default_domain" {
  value = var.has_network ? azurerm_container_app_environment.cae[0].default_domain : null
}

output "postgres_flexible_server_id" {
  depends_on = [azurerm_postgresql_flexible_server_firewall_rule.rules] # ... in case there are firewall rules to apply
  value      = length(azurerm_postgresql_flexible_server.psql) > 0 ? azurerm_postgresql_flexible_server.psql[0].id : null
}

output "postgresql_flexible_server_fqdn" {
  depends_on = [azurerm_postgresql_flexible_server_firewall_rule.rules] # ... in case there are firewall rules to apply
  value      = length(azurerm_postgresql_flexible_server.psql) > 0 ? azurerm_postgresql_flexible_server.psql[0].fqdn : null
}

output "postgresql_admin_username" {
  value = azurerm_key_vault_secret.psql_admin_username.value
}

output "postgresql_admin_password" {
  value = azurerm_key_vault_secret.psql_admin_password.value
}

output "container_registry_id" {
  value = azurerm_container_registry.cr.id
}

output "container_registry_login_server" {
  value = azurerm_container_registry.cr.login_server
}

# Standardized application names for consistent usage tracking
output "app_names" {
  value       = local.app_names
  description = "Standardized application names following the naming convention"
}

# Private endpoint FQDNs for DNS resolution testing
# These are the privatelink FQDNs that should resolve to private IPs within the VNet

output "postgresql_privatelink_fqdn" {
  description = "The privatelink FQDN for PostgreSQL"
  value       = length(azurerm_postgresql_flexible_server.psql) > 0 ? "${azurerm_postgresql_flexible_server.psql[0].name}.privatelink.postgres.database.azure.com" : null
}

output "container_registry_privatelink_fqdn" {
  description = "The privatelink FQDN for Container Registry"
  value       = "${azurerm_container_registry.cr.name}.privatelink.azurecr.io"
}

output "key_vault_privatelink_fqdn" {
  description = "The privatelink FQDN for Key Vault"
  value       = "${azurerm_key_vault.kv.name}.privatelink.vaultcore.azure.net"
}

output "storage_blob_privatelink_fqdn" {
  description = "The privatelink FQDN for Blob Storage"
  value       = "${azurerm_storage_account.lake.name}.privatelink.blob.core.windows.net"
}

output "storage_dfs_privatelink_fqdn" {
  description = "The privatelink FQDN for DFS Storage"
  value       = "${azurerm_storage_account.lake.name}.privatelink.dfs.core.windows.net"
}

output "storage_file_privatelink_fqdn" {
  description = "The privatelink FQDN for File Storage"
  value       = "${azurerm_storage_account.lake.name}.privatelink.file.core.windows.net"
}

output "datahub_users_group_id" {
  description = "The ID of the DataHub users group in Azure AD"
  value       = var.can_modify_entra ? azuread_group.users[0].object_id : null
}

output "datahub_developers_group_id" {
  description = "The ID of the DataHub developers group in Azure AD"
  value       = var.can_modify_entra ? azuread_group.developers[0].object_id : null
}
