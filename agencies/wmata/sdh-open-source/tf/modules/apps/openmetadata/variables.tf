variable "tenant_id" {
  description = "The Azure tenant ID"
  type        = string
}

variable "system_name" {
  type        = string
  description = "The system/application name (e.g., 'bus-dss', '[Project Name]')"
}

variable "environment_name" {
  type        = string
  description = "The environment name (e.g., '[env1]', 'test', 'prod', '[env3]', 'consultant')"
}

variable "sys_short" {
  type        = string
  description = "Abbreviated system/application name (e.g., '[project]' for [Project Name])"
}

variable "env_short" {
  type        = string
  description = "Abbreviated environment name (e.g., '[env1]', 'tst', 'prd', '[env3]', 'con')"
}

variable "resource_group_name" {
  description = "The name of the resource group"
  type        = string
}

variable "resource_group_location" {
  description = "The location of the resource group"
  type        = string
}

variable "datahub_users_group_id" {
  description = "The ID of the DataHub users group"
  type        = string
}

variable "datahub_container_app_environment_id" {
  description = "The ID of the Data Hub container app environment"
  type        = string
}

variable "cae_dns_suffix" {
  type        = string
  description = "The container apps environment DNS suffix."
}

variable "datahub_key_vault_id" {
  description = "The ID of the Data Hub Key Vault"
  type        = string
}

variable "datahub_key_vault_name" {
  description = "The name of the Data Hub Key Vault"
  type        = string
}

variable "datahub_postgresql_flexible_server_fqdn" {
  description = "The FQDN of the Data Hub PostgreSQL flexible server"
  type        = string
}

variable "datahub_postgresql_flexible_server_id" {
  description = "The ID of the Data Hub PostgreSQL flexible server"
  type        = string
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

variable "has_db_registration" {
  description = "Flag to indicate if the OpenMetadata database should be registered"
  type        = bool
  default     = true
}

variable "postgresql_username" {
  description = "The PostgreSQL username for OpenMetadata"
  type        = string
  default     = "openmetadata_user"
}

variable "openmetadata_initial_admin" {
  description = "The initial admin email for OpenMetadata"
  type        = string
}

variable "openmetadata_principal_domain" {
  description = "The principal domain for OpenMetadata authorization"
  type        = string
}

variable "openmetadata_image_tag" {
  description = "The tag for the OpenMetadata container image"
  type        = string
  default     = "1.11.8"
}

variable "opensearch_image_tag" {
  description = "The tag for the OpenSearch container image"
  type        = string
  default     = "2.19.3"
}

variable "workload_profile_name" {
  description = "The name of the workload profile to use for OpenMetadata containers"
  type        = string
  default     = "Consumption"
}

variable "has_entra" {
  description = "Whether the deployment has Entra ID resources configured (app registrations, role assignments)"
  type        = bool
}

variable "can_modify_entra" {
  description = "Whether the deployment has permissions to create/modify Entra ID resources"
  type        = bool
  default     = false
}

variable "app_registration_client_id" {
  description = "The client ID of an existing OpenMetadata app registration (required if can_modify_entra is false)"
  type        = string
  default     = null
}

variable "app_registration_client_secret" {
  description = "The client secret for an existing OpenMetadata app registration (required if can_modify_entra is false)"
  type        = string
  sensitive   = true
  default     = null
}

variable "app_name" {
  type        = string
  description = "Standardized application name for the main container app following {system}-{environment}-{purpose}-ca format"
}