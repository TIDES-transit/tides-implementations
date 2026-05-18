# =============================================================================
# METABASE OUTPUTS
# =============================================================================

output "metabase_url" {
  value       = var.has_entra ? "https://${azurerm_container_app.metabase[0].latest_revision_fqdn}" : ""
  description = "The URL for accessing Metabase on Azure Container Apps"
}

output "metabase_fqdn" {
  value       = var.has_entra ? azurerm_container_app.metabase[0].latest_revision_fqdn : ""
  description = "The FQDN for Metabase on Azure Container Apps"
}

output "workload_id" {
  value       = azurerm_user_assigned_identity.metabase.id
  description = "The managed identity ID for Metabase"
}

output "workload_principal_id" {
  value       = azurerm_user_assigned_identity.metabase.principal_id
  description = "The principal ID of the Metabase managed identity"
}
