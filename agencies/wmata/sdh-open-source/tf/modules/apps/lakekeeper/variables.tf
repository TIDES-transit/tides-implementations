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
  description = "Short code for the environment (e.g., '[env1]', 'tst', 'prd', '[env3]', 'con')"
}

variable "cae_dns_suffix" {
  type        = string
  description = "The container apps environment DNS suffix."
}

variable "resource_group_name" {
  description = "The name of the resource group for the Lakekeeper service"
  type        = string
}

variable "resource_group_location" {
  description = "The location of the resource group for the Lakekeeper service"
  type        = string
}

variable "machine_users" {
  description = "Map of machine users to give access to Lakekeeper"
  type = map(object({
    application = object({
      id = string
    })
    service_principal = object({
      object_id = string
    })
  }))
  default = {}
}

variable "datahub_users_group_id" {
  description = "The ID of the DataHub users group"
  type        = string
}

variable "datahub_developers_group_id" {
  description = "The ID of the DataHub developers group"
  type        = string
  default     = null
}

variable "datahub_key_vault_id" {
  description = "The ID of the DataHub Key Vault"
  type        = string
}

variable "datahub_key_vault_name" {
  description = "The name of the DataHub Key Vault"
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

variable "can_modify_entra" {
  description = "Whether the deployer can modify Entra settings (like creating permission scopes) in this environment"
  type        = bool
  default     = false
}

# If we can't modify Entra settings, we need to use a known value for some settings
variable "oauth2_permission_scope_id" {
  description = "The ID of the Lakekeeper OAuth2 permission scope. Only used if can_modify_entra is false."
  type        = string
  default     = null

  validation {
    condition     = var.can_modify_entra ? true : (var.oauth2_permission_scope_id != null && length(var.oauth2_permission_scope_id) == 36)
    error_message = "oauth2_permission_scope_id must be provided and be a valid UUID if can_modify_entra is false"
  }
}

variable "app_registration_client_id" {
  description = "The client ID of the Lakekeeper app registration; required if can_modify_entra is false."
  type        = string
  default     = null
}

variable "app_service_principal_object_id" {
  description = "The object ID of the Lakekeeper app service principal; required if can_modify_entra is false."
  type        = string
  default     = null
}

variable "app_name" {
  type        = string
  description = "Standardized application name for the container app following {system}-{environment}-{purpose}-ca format"
}

variable "app_listen_port" {
  type        = number
  default     = 8181
  description = "The port the Lakekeeper app listens on. Defaults to 8181 (Lakekeeper's default port)."
}

variable "has_db_registration" {
  description = "Whether the subscription is registered to use namespace 'Microsoft.DBforPostgreSQL'. See https://aka.ms/rps-not-found for how to register subscriptions. You can run `az provider register --namespace Microsoft.DBforPostgreSQL` to register, but need authorization to perform action 'Microsoft.DBforPostgreSQL/register/action'."
  type        = bool
}

variable "postgresql_username" {
  description = "The PostgreSQL username for Lakekeeper"
  type        = string
  default     = "lakekeeper_user"
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

# =============================================================================
# Bootstrap Job Configuration

variable "bootstrap_client_id" {
  description = "The client ID of the service principal to use for bootstrapping Lakekeeper. This service principal will become the initial admin. Required if can_modify_entra is false, optional otherwise (if can_modify_entra is true, the Lakekeeper app will be used)."
  type        = string
  default     = null
}

variable "bootstrap_client_secret" {
  description = "The client secret of the service principal to use for bootstrapping Lakekeeper. Required if can_modify_entra is false, optional otherwise (if can_modify_entra is true, a new client secret will be created for the bootstrap job)."
  type        = string
  sensitive   = true
  default     = null
}

variable "workload_identity_id" {
  description = "The ID of an existing user-assigned managed identity with AcrPull permissions. Used for pulling container images. If not provided, the bootstrap job will not be created."
  type        = string
  default     = null
}

# =============================================================================
# Warehouse Configuration

variable "datahub_lake_storage_account_id" {
  description = "The ID of the Azure Storage account for Iceberg data"
  type        = string
  default     = null
}

variable "datahub_lake_storage_account_name" {
  description = "The name of the Azure Storage account for Iceberg data"
  type        = string
  default     = null
}

variable "storage_client_id" {
  description = "The client ID of the service principal with Storage Blob Data Contributor access to the storage account. Used by Lakekeeper to manage Iceberg data."
  type        = string
  default     = null
}

variable "storage_client_secret" {
  description = "The client secret of the service principal for storage access."
  type        = string
  sensitive   = true
  default     = null
}

variable "lakekeeper_image_tag" {
  description = "The tag for the Lakekeeper container image"
  type        = string
  default     = "v0.9.1"
}

# =============================================================================
# Authorization (OpenFGA)

variable "openfga_endpoint" {
  description = "The gRPC endpoint of the OpenFGA service. When set, enables OpenFGA authorization backend."
  type        = string
  default     = null
}

variable "openfga_api_key" {
  description = "The preshared API key for authenticating to OpenFGA"
  type        = string
  sensitive   = true
  default     = null
}

variable "openfga_store_name" {
  description = "The name of the OpenFGA store to use"
  type        = string
  default     = "lakekeeper"
}

# =============================================================================
# Grants Configuration

variable "app_sp_grants" {
  description = "Map of application service principal object IDs to their project-level role (e.g., 'data_admin'). These are merged into the grants JSON as oidc~{object_id} identifiers."
  type        = map(string)
  default     = {}
}