variable "has_entra" {
  description = "Whether the deployment has Entra ID resources configured (app registrations, role assignments)"
  type        = bool
}

variable "has_db_registration" {
  description = "Whether the PostgreSQL provider is registered and database resources can be created"
  type        = bool
  default     = false
}

variable "can_modify_entra" {
  description = "Whether this module can create and manage Entra ID resources (app registrations, role assignments)"
  type        = bool
  default     = false
}

variable "tenant_id" {
  description = "The Azure tenant ID"
  type        = string
}

variable "system_name" {
  type        = string
  description = "The system name (e.g., '[Project Name]')"
}

variable "environment_name" {
  type        = string
  description = "The environment name (e.g., '[env1]', 'test', 'prod', '[env3]', 'consultant')"
}

variable "env_short" {
  type        = string
  description = "Short code for the environment (e.g., '[env1]', 'tst', 'prd', '[env3]', 'con')"
}

variable "arm_subscription_id" {
  description = "The Azure subscription ID"
  type        = string
}

variable "resource_group_name" {
  description = "The name of the resource group"
  type        = string
}

variable "resource_group_location" {
  description = "The location of the resource group"
  type        = string
}

variable "datahub_container_app_environment_id" {
  description = "The ID of the Data Hub container app environment"
  type        = string
}

variable "cae_dns_suffix" {
  description = "The DNS suffix for the container app environment"
  type        = string
}

variable "dagster_machine_user_client_id" {
  description = "The client ID of the Dagster machine user"
  type        = string
  default     = null
}

variable "dagster_machine_user_object_id" {
  description = "The object ID of the Dagster machine user service principal"
  type        = string
  default     = null
}

variable "dagster_machine_user_client_secret" {
  description = "The client secret for the Dagster machine user"
  type        = string
  sensitive   = true
  default     = null
}

variable "datahub_users_group_id" {
  description = "The object ID of the Data Hub Users group"
  type        = string
}

variable "datahub_key_vault_id" {
  description = "The ID of the Data Hub Key Vault"
  type        = string
}

variable "datahub_key_vault_name" {
  description = "The name of the Data Hub Key Vault"
  type        = string
}

variable "datahub_lake_storage_account_id" {
  description = "The ID of the Data Hub Lake Storage account"
  type        = string
}

variable "datahub_lake_storage_account_name" {
  description = "The name of the Data Hub Lake Storage account"
  type        = string
}

variable "datahub_container_registry_login_server" {
  description = "The login server URL of the Data Hub Container Registry"
  type        = string
}

variable "datahub_container_registry_id" {
  description = "The ID of the Data Hub Container Registry"
  type        = string
}

variable "datahub_postgresql_flexible_server_fqdn" {
  description = "The FQDN of the Data Hub PostgreSQL flexible server"
  type        = string
}

variable "datahub_postgresql_flexible_server_id" {
  description = "The ID of the Data Hub PostgreSQL flexible server (required for database creation)"
  type        = string
  default     = null
}

variable "datahub_postgresql_admin_username" {
  description = "The admin username for the Data Hub PostgreSQL flexible server"
  type        = string
}

variable "datahub_postgresql_admin_password" {
  description = "The admin password for the Data Hub PostgreSQL flexible server"
  type        = string
  sensitive   = true
}

variable "lakekeeper_app_registration_client_id" {
  description = "The client ID of the Lakekeeper API app registration"
  type        = string
}

variable "lakekeeper_oauth2_permission_scope_id" {
  description = "The ID of the Lakekeeper API app registration OAuth2 permission scope"
  type        = string
}

variable "lakekeeper_app_service_principal_object_id" {
  description = "The object ID of the Lakekeeper API app registration service principal (only needed if can_modify_entra is true)"
  type        = string
  default     = ""
}

variable "trino_app_registration_client_id" {
  description = "The client ID of the Trino app registration"
  type        = string
}

variable "trino_app_service_principal_object_id" {
  description = "The object ID of the Trino app registration service principal (only needed if can_modify_entra is true)"
  type        = string
  default     = ""

  validation {
    condition     = var.can_modify_entra ? length(var.trino_app_service_principal_object_id) > 0 : true
    error_message = "trino_app_service_principal_object_id must be provided if can_modify_entra is true"
  }
}

variable "dagster_image_tag" {
  description = "The tag for the Dagster container images"
  type        = string
  default     = "latest"
}

variable "[Project Name]_environment" {
  description = "The [Project Name] environment identifier"
  type        = string
}

variable "workload_profile_name" {
  description = "The name of the workload profile to use for Dagster containers"
  type        = string
  default     = "Consumption"
}

# The following variables need to be set if can_modify_entra is false
variable "app_registration_client_id" {
  description = "The client ID of an existing Dagster app registration (required if can_modify_entra is false)"
  type        = string
  default     = null
}

variable "app_registration_client_secret" {
  description = "The client secret for the Dagster app registration (required if can_modify_entra is false)"
  type        = string
  sensitive   = true
  default     = null
}

variable "app_name" {
  type        = string
  description = "Standardized application name for the main container app following {system}-{environment}-{purpose}-ca format"
}

variable "lakekeeper_url" {
  description = "The base URL of the Lakekeeper service"
  type        = string
}

variable "trino_host" {
  description = "The hostname of the Trino service"
  type        = string
}

variable "openmetadata_api_url" {
  description = "The URL for the OpenMetadata API"
  type        = string
}