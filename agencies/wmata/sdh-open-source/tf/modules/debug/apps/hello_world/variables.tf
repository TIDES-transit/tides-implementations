variable "arm_subscription_id" {
  description = "The subscription ID where the Lakekeeper service resources will be created"
  type        = string
}

variable "resource_group_name" {
  description = "The name of the resource group for the Lakekeeper service"
  type        = string
}

variable "resource_group_location" {
  description = "The location of the resource group for the Lakekeeper service"
  type        = string
}

variable "datahub_container_app_environment_id" {
  description = "The ID of the DataHub container app environment"
  type        = string
}

variable "datahub_container_registry_id" {
  description = "The ID of the DataHub container registry"
  type        = string
}

variable "datahub_container_registry_login_server" {
  description = "The login server of the DataHub container registry"
  type        = string
}

variable "workload_identity_resource_id" {
  description = "The resource id of the workload identity used by the Hello World container app"
  type        = string
}

variable "has_entra" {
  description = "Whether Entra resources (such as app registrations and role assignments) have been integrated."
  type        = bool
}
