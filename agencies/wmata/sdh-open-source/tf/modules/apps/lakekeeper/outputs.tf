output "app_registration_client_id" {
  value       = local.app_registration_client_id
  description = "The client ID of the Lakekeeper app registration"
}

output "app_registration_client_secret" {
  value       = local.app_registration_client_secret
  description = "The client secret of the Lakekeeper app registration (only available when can_modify_entra is true)"
  sensitive   = true
}

output "oauth2_permission_scope_id" {
  value       = local.oauth2_permission_scope_id
  description = "The ID of the Lakekeeper app registration OAuth2 permission scope"
}

output "app_service_principal_object_id" {
  value       = var.can_modify_entra ? azuread_service_principal.lakekeeper[0].object_id : var.app_service_principal_object_id
  description = "The object ID of the Lakekeeper app service principal"
}

output "app_fqdn" {
  description = "The FQDN of the Lakekeeper container app"
  value       = length(azurerm_container_app.lakekeeper) > 0 ? azurerm_container_app.lakekeeper[0].ingress[0].fqdn : null
}

output "lakekeeper_url" {
  description = "The base URL of the Lakekeeper service"
  value       = length(azurerm_container_app.lakekeeper) > 0 ? "https://${azurerm_container_app.lakekeeper[0].ingress[0].fqdn}" : null
}

output "lakekeeper_catalog_url" {
  description = "The URL of the Lakekeeper REST catalog endpoint (for Trino/Iceberg clients)"
  value       = length(azurerm_container_app.lakekeeper) > 0 ? "https://${azurerm_container_app.lakekeeper[0].ingress[0].fqdn}/catalog" : null
}

# =============================================================================
# Workload Identity Outputs

output "workload_identity_id" {
  description = "The ID of the Lakekeeper workload identity"
  value       = azurerm_user_assigned_identity.lakekeeper.id
}

output "workload_identity_principal_id" {
  description = "The principal ID of the Lakekeeper workload identity (needed for AcrPull role assignment)"
  value       = azurerm_user_assigned_identity.lakekeeper.principal_id
}

output "workload_identity_client_id" {
  description = "The client ID of the Lakekeeper workload identity"
  value       = azurerm_user_assigned_identity.lakekeeper.client_id
}
