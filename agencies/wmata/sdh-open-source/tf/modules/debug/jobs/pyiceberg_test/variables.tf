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

variable "tenant_id" {
  description = "Azure tenant ID for OAuth2 authentication"
  type        = string
}

variable "lakekeeper_url" {
  description = "The URL of the Lakekeeper service (e.g., https://lakekeeper.example.com)"
  type        = string
}

variable "lakekeeper_warehouse" {
  description = "The warehouse name in Lakekeeper"
  type        = string
  default     = "[RESOURCE_NAME]"
}

variable "lakekeeper_client_id" {
  description = "The client ID for OAuth2 authentication to Lakekeeper"
  type        = string
}

variable "lakekeeper_client_secret" {
  description = "The client secret for OAuth2 authentication to Lakekeeper"
  type        = string
  sensitive   = true
}

variable "lakekeeper_oauth_scope" {
  description = "The OAuth2 scope for Lakekeeper (e.g., api://<client-id>/.default)"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "python_image_tag" {
  description = "The tag for the Python container image"
  type        = string
  default     = "3.12-slim"
}