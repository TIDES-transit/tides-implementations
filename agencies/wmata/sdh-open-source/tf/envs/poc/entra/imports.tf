# ==========================================================================
# Groups

import {
  id = "/groups/${var.datahub_users_group_id}"
  to = module.common.azuread_group.users
}

# ==========================================================================
# App Registrations and Service Principals

import {
  id = "/applications/${var.lakekeeper_app_registration_object_id}"
  to = module.lakekeeper.azuread_application.lakekeeper
}

import {
  id = "/applications/${var.trino_app_registration_object_id}"
  to = module.trino.azuread_application.trino
}

import {
  id = "/applications/${var.dagster_app_registration_object_id}"
  to = module.dagster.azuread_application.dagster
}

import {
  id = "/applications/${var.openmetadata_app_registration_object_id}"
  to = module.openmetadata.azuread_application.openmetadata
}

import {
  id = "/servicePrincipals/${var.lakekeeper_app_service_principal_object_id}"
  to = module.lakekeeper.azuread_service_principal.lakekeeper
}

import {
  id = "/servicePrincipals/${var.trino_app_service_principal_object_id}"
  to = module.trino.azuread_service_principal.trino
}

import {
  id = "/servicePrincipals/${var.dagster_app_service_principal_object_id}"
  to = module.dagster.azuread_service_principal.dagster
}

import {
  id = "/servicePrincipals/${var.openmetadata_app_service_principal_object_id}"
  to = module.openmetadata.azuread_service_principal.openmetadata
}

import {
  id = "/applications/${var.lakekeeper_app_registration_object_id}/identifierUris/${base64encode("api://${var.lakekeeper_app_registration_client_id}")}"
  to = module.lakekeeper.azuread_application_identifier_uri.lakekeeper
}

import {
  id = "/applications/${var.trino_app_registration_object_id}/identifierUris/${base64encode("api://${var.trino_app_registration_client_id}")}"
  to = module.trino.azuread_application_identifier_uri.trino
}

import {
  id = "/applications/${var.lakekeeper_app_registration_object_id}/permissionScopes/${var.lakekeeper_oauth2_permission_scope_id}"
  to = module.lakekeeper.azuread_application_permission_scope.lakekeeper
}

# ==========================================================================
# Role Assignments


import {
  id = var.openmetadata_workload_identity_key_vault_user_id
  to = module.openmetadata.azurerm_role_assignment.openmetadata_key_vault_secrets_user
}

import {
  # id = var.datahub_users_group_lakekeeper_access_id
  id = "/servicePrincipals/${var.lakekeeper_app_service_principal_object_id}/appRoleAssignedTo/${var.datahub_users_group_lakekeeper_assignment_id}"
  to = module.lakekeeper.azuread_app_role_assignment.datahub_users_lakekeeper_access
}

import {
  id = "/servicePrincipals/${var.openmetadata_app_service_principal_object_id}/appRoleAssignedTo/${var.datahub_users_group_openmetadata_assignment_id}"
  to = module.openmetadata.azuread_app_role_assignment.datahub_users_openmetadata_access
}

import {
  id = "/servicePrincipals/${var.trino_app_service_principal_object_id}/appRoleAssignedTo/${var.datahub_users_group_trino_assignment_id}"
  to = module.trino.azuread_app_role_assignment.datahub_users_trino_access
}

import {
  id = "/servicePrincipals/${var.dagster_app_service_principal_object_id}/appRoleAssignedTo/${var.datahub_users_group_dagster_assignment_id}"
  to = module.dagster.azuread_app_role_assignment.datahub_users_dagster_access
}

import {
  id = var.trino_workload_identity_storage_delegator_id
  to = module.trino.azurerm_role_assignment.trino_workload_identity_storage_delegator
}

import {
  id = var.trino_workload_identity_storage_contributor_id
  to = module.trino.azurerm_role_assignment.trino_workload_identity_storage_contributor
}

import {
  id = var.dagster_workload_identity_key_vault_user_id
  to = module.dagster.azurerm_role_assignment.dagster_key_vault_secrets_user
}

import {
  id = var.dagster_workload_identity_acr_pull_id
  to = module.dagster.azurerm_role_assignment.dagster_acr_pull
}
