output "machine_users" {
  value = {
    for k, v in local.machine_users : k => merge(
      v,
      { service_principal = azuread_service_principal.machine_users[k] },
      { application = azuread_application.machine_users[k] }
    )
  }
  description = "Machine users"
}

output "lakekeeper_machine_users" {
  value = {
    for k, v in local.lakekeeper_machine_users : k => merge(
      v,
      { service_principal = azuread_service_principal.machine_users[k] },
      { application = azuread_application.machine_users[k] }
    )
  }
  description = "Lakekeeper machine users"
}

output "trino_machine_users" {
  value = {
    for k, v in local.trino_machine_users : k => merge(
      v,
      { service_principal = azuread_service_principal.machine_users[k] },
      { application = azuread_application.machine_users[k] }
    )
  }
  description = "Trino machine users"
}

output "dagster_machine_user_client_id" {
  value       = contains(keys(azuread_application.machine_users), "dagster") ? azuread_application.machine_users["dagster"].client_id : ""
  description = "The client ID of the Dagster machine user"
}

output "dagster_machine_user_object_id" {
  value       = contains(keys(azuread_service_principal.machine_users), "dagster") ? azuread_service_principal.machine_users["dagster"].object_id : ""
  description = "The object ID of the Dagster machine user service principal"
}
