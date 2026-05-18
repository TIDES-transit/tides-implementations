resource "azurerm_container_app" "echo_http" {
  name                         = "echo-http"
  container_app_environment_id = var.datahub_container_app_environment_id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"
  workload_profile_name        = "Consumption"

  template {
    min_replicas = 1
    max_replicas = 1

    container {
      name   = "echo-http"
      image  = "mendhak/http-https-echo:${var.echo_http_image_tag}"
      cpu    = 0.5
      memory = "1Gi"

    }
  }

  ingress {
    allow_insecure_connections = true
    external_enabled           = true
    target_port                = 8080

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
}
