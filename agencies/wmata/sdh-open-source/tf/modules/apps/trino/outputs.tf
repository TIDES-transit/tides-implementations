# Output for Trino password user credentials
output "password_user_credentials" {
  value = {
    for k, v in local.trino_password_users : k => {
      description = v.description
      username    = k
      password    = random_password.trino_password_users[k].result
      trino_url   = "https://${var.app_name}.${var.cae_dns_suffix}"
    }
  }
  sensitive   = true
  description = "Credentials for Trino password-based authentication users"
}

output "app_registration_client_id" {
  value       = var.can_modify_entra ? azuread_application.trino[0].client_id : var.app_registration_client_id
  description = "The client ID of the Trino application registration in Entra ID"
}

output "app_service_principal_object_id" {
  value       = var.can_modify_entra ? azuread_service_principal.trino[0].object_id : null
  description = "The object ID of the Trino application service principal in Entra ID"
}

output "trino_host" {
  description = "The hostname of the Trino coordinator"
  value       = length(azurerm_container_app.trino_coordinator) > 0 ? azurerm_container_app.trino_coordinator[0].ingress[0].fqdn : null
}
