variable "tenant_id" {
  description = "The ID of the Azure AD tenant"
  type        = string
}

variable "environment_name" {
  type        = string
  description = "The environment name (e.g., '[env1]', 'test', 'prod', '[env3]', 'consultant')"
}

variable "sys_short" {
  type        = string
  description = "Short code for the system (e.g., '[project]' for [Project Name])"
}

variable "env_short" {
  type        = string
  description = "Short code for the environment (e.g., '[env1]', 'tst', 'prd', '[env3]', 'jrv')"
}

variable "cae_dns_suffix" {
  type        = string
  description = "The container apps environment DNS suffix."
}

variable "resource_group_name" {
  description = "The name of the resource group"
  type        = string
}

variable "resource_group_location" {
  description = "The location of the resource group"
  type        = string
}

variable "datahub_key_vault_id" {
  description = "The ID of the DataHub Key Vault"
  type        = string
}

variable "datahub_container_app_environment_id" {
  description = "The ID of the DataHub container app environment"
  type        = string
}

variable "datahub_postgresql_flexible_server_id" {
  description = "The ID of the DataHub PostgreSQL flexible server"
  type        = string
}

variable "datahub_postgresql_flexible_server_fqdn" {
  description = "The FQDN of the DataHub PostgreSQL flexible server"
  type        = string
}

variable "datahub_postgresql_admin_username" {
  description = "The admin username for the DataHub PostgreSQL flexible server"
  type        = string
}

variable "datahub_postgresql_admin_password" {
  description = "The admin password for the DataHub PostgreSQL flexible server"
  type        = string
}

variable "app_name" {
  type        = string
  description = "Standardized application name for the container app following {system}-{environment}-{purpose}-ca format"
}

variable "has_entra" {
  type        = bool
  description = "Whether the deployment has Entra ID resources configured (app registrations, role assignments)"
}

variable "has_db_registration" {
  description = "Whether the subscription is registered to use namespace 'Microsoft.DBforPostgreSQL'."
  type        = bool
}

variable "postgresql_username" {
  description = "The PostgreSQL username for OpenFGA"
  type        = string
  default     = "openfga_user"
}

# =============================================================================
# Container Registry (for bootstrap job image)

variable "datahub_container_registry_id" {
  description = "The ID of the DataHub container registry"
  type        = string
  default     = null
}

variable "datahub_container_registry_login_server" {
  description = "The login server URL of the DataHub container registry"
  type        = string
  default     = null
}

variable "workload_identity_id" {
  description = "The ID of an existing user-assigned managed identity with AcrPull permissions. Used for pulling container images."
  type        = string
  default     = null
}

# =============================================================================
# OpenFGA Configuration

variable "openfga_image_tag" {
  description = "The tag for the OpenFGA container image"
  type        = string
  default     = "v1.8.3"
}

variable "enable_playground" {
  description = "Whether to enable the OpenFGA playground UI"
  type        = bool
  default     = false
}

variable "lakekeeper_openfga_schema_version" {
  description = "The version of the Lakekeeper OpenFGA schema to use. Must match the Lakekeeper image version. See https://github.com/lakekeeper/lakekeeper/tree/{version}/authz/openfga"
  type        = string
  default     = "v3.4"
}