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

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "alpine_image_tag" {
  description = "The tag for the Alpine container image"
  type        = string
  default     = "latest"
}