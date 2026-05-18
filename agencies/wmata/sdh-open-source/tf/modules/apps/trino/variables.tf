variable "tenant_id" {
  description = "The Azure tenant ID"
  type        = string
}

variable "system_name" {
  type        = string
  description = "The system name (e.g., 'datahub')"
}

variable "environment_name" {
  type        = string
  description = "The environment name (e.g., '[env1]', 'test', 'prod', '[env3]', 'consultant')"
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
  type        = string
  description = "The container apps environment DNS suffix."
}

variable "machine_users" {
  description = "A map of machine user ids"
  type = map(object({
    service_principal = object({
      object_id = string
    })
  }))
  default = {}
}

variable "datahub_users_group_id" {
  description = "The object ID of the Data Hub Users group"
  type        = string
}

variable "datahub_key_vault_id" {
  description = "The ID of the Data Hub Key Vault"
  type        = string
}

variable "datahub_lake_storage_account_id" {
  description = "The ID of the Data Hub Lake Storage account"
  type        = string
}

variable "lakekeeper_app_registration_client_id" {
  description = "The client ID of the Lakekeeper API app registration"
  type        = string
}

variable "lakekeeper_oauth2_permission_scope_id" {
  description = "The ID of the Lakekeeper API app registration OAuth2 permission scope"
  type        = string
}

variable "has_entra" {
  description = "Whether the deployment has Entra ID resources configured (app registrations, role assignments)"
  type        = bool
}

variable "can_modify_entra" {
  description = "Whether this module can create and manage Entra ID app registrations and service principals"
  type        = bool
  default     = false
}

# Only required if can_modify_entra is false
variable "app_registration_client_id" {
  description = "The client ID of an existing Trino app registration (required if can_modify_entra is false)"
  type        = string
  default     = null
}

variable "app_registration_client_secret" {
  description = "The client secret for the existing Trino app registration (required if can_modify_entra is false)"
  type        = string
  sensitive   = true
  default     = null
}

variable "app_name" {
  type        = string
  description = "Standardized application name for the main container app following {system}-{environment}-{purpose}-ca format"
}

variable "trino_image_tag" {
  description = "The tag for the Trino container image"
  type        = string
  default     = "476"
}

variable "lakekeeper_catalog_url" {
  description = "The URL of the Lakekeeper REST catalog endpoint"
  type        = string
}

variable "opa_policy_uri" {
  description = "The URI for the OPA Trino allow policy endpoint. If set, OPA access control is enabled."
  type        = string
  default     = null
}

variable "opa_batch_policy_uri" {
  description = "The URI for the OPA Trino batch policy endpoint (used for filter operations)."
  type        = string
  default     = null
}

variable "workload_profile_name" {
  description = "The name of the workload profile to use for Trino containers"
  type        = string
  default     = "Consumption"
}

variable "worker_cpu" {
  description = "CPU cores for each Trino worker container"
  type        = number
  default     = 2.0
}

variable "worker_memory" {
  description = "Memory for each Trino worker container (e.g., '4Gi')"
  type        = string
  default     = "4Gi"
}

variable "min_workers" {
  description = "Minimum number of Trino worker replicas"
  type        = number
  default     = 2
}

variable "max_workers" {
  description = "Maximum number of Trino worker replicas"
  type        = number
  default     = 4
}