variable "resource_group_name" {
  description = "The name of the resource group for the Lakekeeper service"
  type        = string
}

variable "datahub_container_app_environment_id" {
  description = "The ID of the DataHub container app environment"
  type        = string
}

variable "echo_http_image_tag" {
  description = "The tag for the echo HTTP container image"
  type        = string
  default     = "latest"
}
