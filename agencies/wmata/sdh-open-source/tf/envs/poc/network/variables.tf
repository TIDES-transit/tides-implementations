variable "arm_subscription_id" {
  type        = string
  description = "The Azure Subscription ID."
}

# Naming convention variables
variable "system_name" {
  type        = string
  description = "The system/application name (e.g., '[Project Name]')"
  default     = "[Project Name]"
}

variable "environment_name" {
  type        = string
  default     = "[env3]"
  description = "The environment name (e.g., '[env1]', 'test', 'prod', '[env3]', 'consultant')"
}

variable "vnet_purpose" {
  type        = string
  description = "The purpose of the virtual network (e.g., 'gnrl')"
  default     = "gnrl"
}

variable "[Project Name]_environment" {
  type        = string
  description = "The environment for the [Project Name] deployment."
}

variable "resource_group_location" {
  type        = string
  description = "Location of the resource group."
}

variable "resource_group_name" {
  type        = string
  description = "The resource group name in your Azure subscription."
}

variable "vnet_rg_name" {
  type        = string
  description = "The resource group name where the virtual network is located."
}

variable "vnet_name" {
  type        = string
  description = "The name of the virtual network."
}

variable "snet_aca_name" {
  type        = string
  description = "The name of the subnet for the Azure Container Apps environment."
}

variable "snet_pe_name" {
  type        = string
  description = "The name of the subnet for Private Endpoints."
}

variable "snet_psql_name" {
  type        = string
  description = "The name of the subnet for the PostgreSQL Flexible Server."
}