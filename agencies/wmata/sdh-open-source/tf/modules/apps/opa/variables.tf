variable "tenant_id" {
  description = "The ID of the Azure AD tenant"
  type        = string
}

variable "sys_short" {
  type        = string
  description = "Short code for the system (e.g., '[project]' for [Project Name])"
}

variable "env_short" {
  type        = string
  description = "Short code for the environment (e.g., '[env1]', 'tst', 'prd', '[env3]', 'jrv')"
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

variable "app_name" {
  type        = string
  description = "Standardized application name for the container app following {system}-{environment}-{purpose}-ca format"
}

# =============================================================================
# Lakekeeper Integration

variable "lakekeeper_internal_url" {
  description = "The internal URL of the Lakekeeper service (for OPA policy HTTP calls)"
  type        = string
}

variable "lakekeeper_app_registration_client_id" {
  description = "The client ID of the Lakekeeper app registration (for OPA to authenticate to Lakekeeper)"
  type        = string
}

variable "lakekeeper_version" {
  description = "The version of Lakekeeper to pull OPA policies from (should be a git release tag)"
  type        = string
  default     = "v0.9.1"
}

variable "opa_client_id" {
  description = "The client ID for OPA to use when calling the Lakekeeper API; recommended to be the same user as for creating the catalog in Trino for same access"
  type        = string
}

variable "opa_client_secret" {
  description = "The client secret for OPA to use when calling the Lakekeeper API; recommended to be the same user as for creating the catalog in Trino for same access"
  type        = string
  sensitive   = true
}

# =============================================================================
# OPA Configuration

variable "opa_image_tag" {
  description = "The tag for the OPA container image"
  type        = string
  default     = "1.3.0"
}

variable "trino_catalog_name" {
  description = "The name of the Trino catalog that maps to the Lakekeeper warehouse"
  type        = string
  default     = "[RESOURCE_NAME]"
}

variable "lakekeeper_warehouse_name" {
  description = "The name of the Lakekeeper warehouse that the Trino catalog maps to"
  type        = string
  default     = "[RESOURCE_NAME]"
}