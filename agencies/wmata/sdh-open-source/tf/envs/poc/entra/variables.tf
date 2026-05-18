variable "arm_subscription_id" {
  type        = string
  description = "The Azure Resource Manager subscription ID."
}

variable "resource_group_name" {
  type        = string
  description = "The name of the resource group where the Terraform state storage account is located."
}

variable "datahub_cae_dns_suffix" {
  type        = string
  description = "The container apps environment DNS suffix."
}

variable "datahub_users_group_id" {
  type        = string
  description = "The object ID of the DataHub Users group in Entra ID."
}

variable "datahub_lake_storage_account_id" {
  type        = string
  description = "The ID of the DataHub data lake Storage Account."
}

variable "datahub_key_vault_id" {
  type        = string
  description = "The ID of the Key Vault used by the [Project Name]."
}

variable "datahub_container_registry_id" {
  type        = string
  description = "The ID of the Container Registry used by the [Project Name]."
}

variable "lakekeeper_app_registration_object_id" {
  type        = string
  description = "The object ID of the Lakekeeper app registration in Entra ID."
}

variable "trino_app_registration_object_id" {
  type        = string
  description = "The object ID of the Trino app registration in Entra ID."
}

variable "dagster_app_registration_object_id" {
  type        = string
  description = "The object ID of the Dagster app registration in Entra ID."
}

variable "openmetadata_app_registration_object_id" {
  type        = string
  description = "The object ID of the OpenMetadata app registration in Entra ID."
}

variable "lakekeeper_app_registration_client_id" {
  type        = string
  description = "The client ID of the Lakekeeper app registration in Entra ID."
}

variable "trino_app_registration_client_id" {
  type        = string
  description = "The client ID of the Trino app registration in Entra ID."
}

variable "lakekeeper_oauth2_permission_scope_id" {
  type        = string
  description = "The OAuth2 permission scope ID for the Lakekeeper app registration in Entra ID."
}

variable "lakekeeper_app_service_principal_object_id" {
  type        = string
  description = "The object ID of the Lakekeeper app service principal in Entra ID."
}

variable "trino_app_service_principal_object_id" {
  type        = string
  description = "The object ID of the Trino app service principal in Entra ID."
}

variable "dagster_app_service_principal_object_id" {
  type        = string
  description = "The object ID of the Dagster app service principal in Entra ID."
}

variable "openmetadata_app_service_principal_object_id" {
  type        = string
  description = "The object ID of the OpenMetadata app service principal in Entra ID."
}

variable "trino_workload_identity_principal_id" {
  type        = string
  description = "The principal ID of the Trino workload identity."
}

variable "dagster_workload_identity_principal_id" {
  type        = string
  description = "The principal ID of the Dagster workload identity."
}

variable "openmetadata_workload_identity_principal_id" {
  type        = string
  description = "The principal ID of the OpenMetadata workload identity."
}

variable "trino_workload_identity_storage_delegator_id" {
  type        = string
  description = "The object ID of the Trino workload identity Storage Blob Data Contributor role assignment."
}

variable "trino_workload_identity_storage_contributor_id" {
  type        = string
  description = "The object ID of the Trino workload identity Storage Blob Data Contributor role assignment."
}

variable "dagster_workload_identity_key_vault_user_id" {
  type        = string
  description = "The object ID of the Dagster workload identity Key Vault user role assignment."
}

variable "dagster_workload_identity_acr_pull_id" {
  type        = string
  description = "The object ID of the Dagster workload identity ACR Pull role assignment."
}

variable "openmetadata_workload_identity_key_vault_user_id" {
  type        = string
  description = "The object ID of the OpenMetadata workload identity Key Vault user role assignment."
}

variable "datahub_users_group_lakekeeper_assignment_id" {
  type        = string
  description = "The role assignment ID for the DataHub Users group Lakekeeper access."
}

variable "datahub_users_group_trino_assignment_id" {
  type        = string
  description = "The role assignment ID for the DataHub Users group Trino access."
}

variable "datahub_users_group_dagster_assignment_id" {
  type        = string
  description = "The role assignment ID for the DataHub Users group Dagster access."
}

variable "datahub_users_group_openmetadata_assignment_id" {
  type        = string
  description = "The role assignment ID for the DataHub Users group OpenMetadata access."
}