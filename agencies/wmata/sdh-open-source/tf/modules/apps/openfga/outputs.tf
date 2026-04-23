output "openfga_internal_url" {
  description = "The internal HTTP URL of the OpenFGA service (REST API, playground, health)"
  value       = length(azurerm_container_app.openfga) > 0 ? "http://${var.app_name}" : null
}

output "openfga_grpc_endpoint" {
  description = "The internal gRPC endpoint of the OpenFGA service (for Lakekeeper). Uses the additional port mapping on port 8081."
  value       = length(azurerm_container_app.openfga) > 0 ? "http://${var.app_name}:8081" : null
}

output "openfga_preshared_key" {
  description = "The preshared key for OpenFGA API authentication"
  value       = random_password.openfga_preshared_key.result
  sensitive   = true
}

output "openfga_store_name" {
  description = "The name of the OpenFGA store created by the bootstrap job"
  value       = "lakekeeper"
}
