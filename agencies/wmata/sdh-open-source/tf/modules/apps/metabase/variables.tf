# =============================================================================
# CORE INFRASTRUCTURE VARIABLES
# =============================================================================

variable "system_name" {
  type        = string
  description = "The system/application name (e.g., '[Project Name]')"
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

variable "has_entra" {
  type        = bool
  description = "Flag to indicate if Entra ID integration is enabled"
  default     = true
}

variable "can_modify_entra" {
  type        = bool
  description = "Flag to indicate if the module can modify Entra ID resources"
  default     = false
}

variable "resource_group_name" {
  description = "The name of the resource group"
  type        = string
}

variable "resource_group_location" {
  description = "The location of the resource group"
  type        = string
}

# =============================================================================
# CONTAINER APP ENVIRONMENT VARIABLES
# =============================================================================

variable "datahub_container_app_environment_id" {
  description = "The ID of the Data Hub container app environment"
  type        = string
}

variable "cae_dns_suffix" {
  description = "The DNS suffix for the container app environment"
  type        = string
}

variable "app_name" {
  description = "The name of the Metabase container app"
  type        = string
}

# =============================================================================
# KEY VAULT VARIABLES
# =============================================================================

variable "datahub_key_vault_id" {
  description = "The ID of the Data Hub Key Vault"
  type        = string
}

variable "datahub_key_vault_name" {
  description = "The name of the Data Hub Key Vault"
  type        = string
}

# =============================================================================
# POSTGRESQL VARIABLES
# =============================================================================

variable "has_db_registration" {
  description = "Flag to indicate if the Metabase database should be registered"
  type        = bool
  default     = true
}

variable "datahub_postgresql_flexible_server_id" {
  description = "The ID of the Data Hub PostgreSQL flexible server"
  type        = string
}

variable "datahub_postgresql_flexible_server_fqdn" {
  description = "The FQDN of the Data Hub PostgreSQL flexible server"
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

# =============================================================================
# METABASE CONFIGURATION VARIABLES
# =============================================================================

variable "metabase_image_tag" {
  description = "The tag for the Metabase container image"
  type        = string
  default     = "v0.55.6"
}

variable "workload_profile_name" {
  description = "The name of the workload profile to use"
  type        = string
  default     = "Consumption"
}