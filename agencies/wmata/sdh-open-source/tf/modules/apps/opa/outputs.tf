output "opa_policy_uri" {
  description = "The URI for the OPA Trino allow policy endpoint"
  value       = length(azurerm_container_app.opa) > 0 ? "http://${var.app_name}/v1/data/trino/allow" : null
}

output "opa_batch_policy_uri" {
  description = "The URI for the OPA Trino batch policy endpoint"
  value       = length(azurerm_container_app.opa) > 0 ? "http://${var.app_name}/v1/data/trino/batch" : null
}

output "opa_internal_url" {
  description = "The internal base URL of the OPA service"
  value       = length(azurerm_container_app.opa) > 0 ? "http://${var.app_name}" : null
}
