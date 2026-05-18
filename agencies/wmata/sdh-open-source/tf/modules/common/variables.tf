variable "has_network" {
  type        = bool
  description = "Whether network resources (such as subnets and private links) have been integrated."
}

variable "has_entra" {
  type        = bool
  description = "Whether Entra resources (such as app registrations and role assignments) have been integrated."
}

variable "has_db_registration" {
  description = "Whether the subscription is registered to use namespace 'Microsoft.DBforPostgreSQL'. See https://aka.ms/rps-not-found for how to register subscriptions. You can run `az provider register --namespace Microsoft.DBforPostgreSQL` to register, but need authorization to perform action 'Microsoft.DBforPostgreSQL/register/action'."
  type        = bool
}

variable "can_modify_network" {
  type        = bool
  description = "Whether this deployment has permissions to create and modify network resources. If false, network resources will be created manually and referenced by this deployment, but we will not attempt to manage them."
  default     = false
}

variable "can_modify_entra" {
  type        = bool
  description = "Whether this deployment has permissions to create and modify Entra resources. If false, Entra resources will be created manually and referenced by this deployment, but we will not attempt to manage them."
  default     = false
}

variable "tenant_id" {
  description = "The Azure tenant ID"
  type        = string
}

variable "resource_group_location" {
  type        = string
  default     = "eastus"
  description = "Location of the resource group."
}

variable "resource_group_name" {
  type        = string
  default     = "[RESOURCE_NAME]"
  description = "The resource group name in your Azure subscription."
}

# Standardized naming convention variables
variable "system_name" {
  type        = string
  description = "The system/application name (e.g., 'bus-dss', '[Project Name]')"
  default     = "[Project Name]"
}

variable "environment_name" {
  type        = string
  description = "The environment name (e.g., '[env1]', 'test', 'prod', '[env3]', 'consultant')"
}

variable "sys_short" {
  type        = string
  description = "Abbreviated system/application name (e.g., 'bdss', '[project]')"
  default     = "[project]"
}

variable "env_short" {
  type        = string
  description = "Abbreviated environment name (e.g., '[env1]', 'tst', 'prd', '[env3]', 'con')"
}

variable "resource_name_overrides" {
  type        = map(string)
  description = "Optional overrides for resource names."
  default     = {}
}

variable "arm_subscription_id" {
  type = string
}

variable "dns_zone_subscription_id" {
  type        = string
  description = "Subscription ID for the DNS zone resources; may be the same as the arm_subscription_id, or not."
}

variable "dns_zone_resource_group_name" {
  type        = string
  description = "Resource group name for the DNS zone resources; may be the same as the resource_group_name, or not."
}

variable "dns_zone_name" {
  type        = string
  default     = "[RESOURCE_NAME]"
  description = "The DNS zone name that will vary by environment."
}

variable "db_location_override" {
  type        = string
  default     = null
  description = "Optional override for the database location. If not set, defaults to the resource group location."
}

variable "cae_subnet_id" {
  type        = string
  description = "The ID of the subnet to use for the [Project Name] Container Apps Environment."
}

variable "cae_dns_suffix" {
  type        = string
  default     = "[RESOURCE_NAME]"
  description = "The container apps environment DNS suffix."
}

variable "pe_subnet_id" {
  type        = string
  description = "The ID of the subnet to use for private endpoints."
}

variable "vnet_id" {
  type        = string
  default     = null
  description = "The ID of the virtual network to link private DNS zones to. Required when can_modify_network is true."

  validation {
    condition     = var.can_modify_network == false || (var.can_modify_network == true && var.vnet_id != null)
    error_message = "vnet_id must be provided when can_modify_network is true."
  }
}

variable "openmetadata_initial_admin" {
  description = "List of initial admin users for OpenMetadata. For users in the principal domain, use just the username (e.g., 'john.doe'). For external users, use the full email (e.g., 'external.user@other.com')"
  type        = string
  default     = "admin"
}

variable "openmetadata_principal_domain" {
  description = "Principal domain for OpenMetadata users (e.g., '[AGENCY].com')"
  type        = string
  default     = "[AGENCY].com"
}

variable "private_ip_addresses" {
  type = object({
    aca_pe       = string
    cr_pe_1      = string
    cr_pe_2      = string
    kv_pe        = string
    lake_dfs_pe  = string
    lake_file_pe = string
    lake_blob_pe = string
    psql_pe      = string
  })
  default = {
    aca_pe       = "[PRIVATE_IP]"
    cr_pe_1      = "[PRIVATE_IP]"
    cr_pe_2      = "[PRIVATE_IP]"
    kv_pe        = "[PRIVATE_IP]"
    lake_dfs_pe  = "[PRIVATE_IP]"
    lake_file_pe = "[PRIVATE_IP]"
    lake_blob_pe = "[PRIVATE_IP]"
    psql_pe      = "[PRIVATE_IP]"
  }
  description = "Static private IP addresses for private endpoints"
}

variable "container_registry_name" {
  type        = string
  default     = "[RESOURCE_NAME]"
  description = "Name of the container registry"
}

variable "storage_account_name" {
  type        = string
  default     = "[STORAGE_ACCOUNT]"
  description = "Name of the storage account"
}

variable "key_vault_name" {
  type        = string
  default     = "[RESOURCE_NAME]"
  description = "Name of the key vault"
}

variable "postgresql_server_name" {
  type        = string
  default     = "[RESOURCE_NAME]"
  description = "Name of the PostgreSQL server"
}

variable "container_app_environment_name" {
  type        = string
  default     = "[RESOURCE_NAME]"
  description = "Name of the container app environment"
}

variable "log_analytics_workspace_name" {
  type        = string
  default     = "[RESOURCE_NAME]"
  description = "Name of the log analytics workspace"
}

variable "psql_firewall_rules" {
  type = map(object({
    start_ip_address = string
    end_ip_address   = string
  }))
  default     = {}
  description = "Map of firewall rules to allow access to the PostgreSQL server. Key is the rule name."
}

variable "public_network_access_enabled" {
  type        = bool
  default     = false
  description = "Whether public network access is enabled for the PostgreSQL server and the container registry. For enhanced security, this should be set to false and access should be granted via private endpoints and firewall rules."
}

variable "external_ingress_enabled" {
  type        = bool
  default     = false
  description = "Whether external ingress is enabled for the container app environment. If false, the environment will be isolated with internal ingress only, and private endpoints will be required to access applications running in the environment."
}