# Dagster outputs
output "dagster_webserver_url" {
  value       = var.has_entra ? "https://${azurerm_container_app.dagster_webserver[0].latest_revision_fqdn}" : ""
  description = "The URL for accessing the Dagster Webserver on Azure Container Apps"
}

output "dagster_webserver_fqdn" {
  value       = var.has_entra ? azurerm_container_app.dagster_webserver[0].latest_revision_fqdn : ""
  description = "The FQDN for the Dagster Webserver on Azure Container Apps"
}

output "dagster_user_code_fqdn" {
  value       = var.has_entra ? azurerm_container_app.dagster_user_code[0].latest_revision_fqdn : ""
  description = "The FQDN for the Dagster User Code service on Azure Container Apps"
}

output "dagster_daemon_fqdn" {
  value       = var.has_entra ? azurerm_container_app.dagster_daemon[0].latest_revision_fqdn : ""
  description = "The FQDN for the Dagster Daemon service on Azure Container Apps"
}

output "dagster_workload_identity_id" {
  value       = azurerm_user_assigned_identity.dagster.id
  description = "The ID of the Dagster workload managed identity"
}
