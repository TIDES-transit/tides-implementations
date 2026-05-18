variable "resource_group_name" {
  description = "The name of the resource group"
  type        = string
}

variable "resource_group_location" {
  description = "The location of the resource group"
  type        = string
}

variable "datahub_container_app_environment_id" {
  description = "The ID of the Container Apps environment"
  type        = string
}

variable "sys_short" {
  description = "Short system name (e.g., '[project]')"
  type        = string
}

variable "env_short" {
  description = "Short environment name (e.g., '[env1]', '[env2]', 'prd')"
  type        = string
}

variable "trino_url" {
  description = "The full URL of the Trino coordinator (e.g., 'https://[Project Name]-[env1]-trino-ca.[CONTAINER_ENV].azurecontainerapps.io'). Must use HTTPS for password authentication."
  type        = string
}

variable "trino_user" {
  description = "The username for Trino password authentication"
  type        = string
  default     = "tableau"
}

variable "trino_password" {
  description = "The password for Trino authentication"
  type        = string
  sensitive   = true
}

variable "trino_catalog" {
  description = "The default catalog to test (e.g., 'datahub' for Lakekeeper)"
  type        = string
  default     = "[RESOURCE_NAME]"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "trino_image_tag" {
  description = "The tag for the Trino CLI container image"
  type        = string
  default     = "479"
}