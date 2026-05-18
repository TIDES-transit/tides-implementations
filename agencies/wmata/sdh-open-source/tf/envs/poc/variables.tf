variable "has_entra" {
  description = "Whether the deployment has Entra ID resources configured (app registrations, role assignments)"
  type        = bool
}

variable "has_network" {
  type        = bool
  description = "Whether network resources (such as subnets and private links) have been integrated."
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
  default     = "[env3]"
  description = "The environment name (e.g., '[env1]', 'test', 'prod', '[env3]', 'consultant')"
}

# Standardized naming convention variables
variable "sys_short" {
  type        = string
  description = "The system/application name (e.g., 'bus-dss', '[Project Name]')"
  default     = "[project]"
}

variable "env_short" {
  type        = string
  description = "The environment name (e.g., '[env1]', 'test', 'prod', '[env3]', 'consultant')"
  default     = "[env3]"
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

variable "cae_dns_suffix" {
  type        = string
  default     = "[RESOURCE_NAME]"
  description = "The container apps environment DNS suffix."
}

variable "cae_subnet_id" {
  type        = string
  description = "The ID of the subnet to use for the Container Apps Environment."
}

variable "pe_subnet_id" {
  type        = string
  description = "The ID of the subnet to use for private endpoints."
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

variable "dagster_image_tag" {
  description = "The tag for the Dagster container images"
  type        = string
  default     = "latest"
}

variable "[Project Name]_environment" {
  description = "The [Project Name] environment identifier"
  type        = string
  default     = "[env3]"
}

variable "lakekeeper_app_registration_object_id" {
  description = "The object ID of the Lakekeeper app registration in Azure AD"
  type        = string
}

variable "lakekeeper_app_registration_client_id" {
  description = "The client ID of the Lakekeeper app registration in Azure AD"
  type        = string
}

variable "trino_app_registration_object_id" {
  description = "The object ID of the Trino app registration in Azure AD"
  type        = string
}

variable "trino_app_registration_client_id" {
  description = "The client ID of the Trino app registration in Azure AD"
  type        = string
}

variable "trino_app_registration_client_secret" {
  description = "A client secret for the Trino app registration in Azure AD; used for the Trino coordinator and workers to authenticate to Azure resources"
  type        = string
  sensitive   = true
}

variable "dagster_app_registration_client_id" {
  description = "The client ID of the Dagster app registration in Azure AD"
  type        = string
}

variable "dagster_app_registration_object_id" {
  description = "The object ID of the Dagster app registration in Azure AD"
  type        = string
}

variable "dagster_app_registration_client_secret" {
  description = "A client secret for the Dagster app registration in Azure AD; used by Dagster to authenticate to Azure resources"
  type        = string
  sensitive   = true
}

variable "openmetadata_app_registration_client_id" {
  description = "The client ID of the OpenMetadata app registration in Azure AD"
  type        = string
}

variable "openmetadata_app_registration_object_id" {
  description = "The object ID of the OpenMetadata app registration in Azure AD"
  type        = string
}

variable "openmetadata_app_registration_client_secret" {
  description = "A client secret for the OpenMetadata app registration in Azure AD; used by OpenMetadata to authenticate to Azure resources"
  type        = string
  sensitive   = true
}

variable "lakekeeper_app_service_principal_object_id" {
  description = "The object ID of the Lakekeeper app registration's service principal in Azure AD"
  type        = string
}

variable "trino_app_service_principal_object_id" {
  description = "The object ID of the Trino app registration's service principal in Azure AD"
  type        = string
}

variable "lakekeeper_oauth2_permission_scope_id" {
  description = "The OAuth2 permission scope ID for the 'lakekeeper' scope in the Lakekeeper app registration"
  type        = string
}

variable "dagster_app_service_principal_object_id" {
  description = "The object ID of the Dagster app registration's service principal in Azure AD"
  type        = string
}

variable "openmetadata_app_service_principal_object_id" {
  description = "The object ID of the OpenMetadata app registration's service principal in Azure AD"
  type        = string
}

variable "trino_workload_identity_principal_id" {
  description = "The principal ID of the Trino workload identity"
  type        = string
}

variable "datahub_users_group_id" {
  description = "The object ID of the DataHub Users group in Azure AD"
  type        = string
}