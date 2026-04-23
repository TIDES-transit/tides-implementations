output "openmetadata_api_url" {
  value = length(azurerm_container_app.openmetadata) > 0 ? "https://${azurerm_container_app.openmetadata[0].ingress[0].fqdn}/api" : null
  description = "The URL for accessing the OpenMetadata API on Azure Container Apps"
}

output "openmetadata_server_url" {
  value       = length(azurerm_container_app.openmetadata) > 0 ? "https://${azurerm_container_app.openmetadata[0].latest_revision_fqdn}" : null
  description = "The URL for accessing the OpenMetadata server on Azure Container Apps"
}

output "openmetadata_server_fqdn" {
  value       = length(azurerm_container_app.openmetadata) > 0 ? azurerm_container_app.openmetadata[0].latest_revision_fqdn : null
  description = "The FQDN for the OpenMetadata server on Azure Container Apps"
}

output "app_registration_client_id" {
  value       = var.can_modify_entra ? azuread_application.openmetadata[0].client_id : var.app_registration_client_id
  description = "The client ID of the OpenMetadata app registration"
}

output "app_registration_client_secret" {
  value       = var.can_modify_entra ? azuread_application_password.openmetadata[0].value : var.app_registration_client_secret
  description = "The client secret for the OpenMetadata app registration"
  sensitive   = true
}

output "openmetadata_workload_identity_id" {
  value       = azurerm_user_assigned_identity.openmetadata.id
  description = "The ID of the OpenMetadata workload managed identity"
}
