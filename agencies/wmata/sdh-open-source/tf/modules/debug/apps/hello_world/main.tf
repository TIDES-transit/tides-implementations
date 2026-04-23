# =======================================================================
# Build and push container image
# =======================================================================

# Generate hash of app directory to trigger rebuilds on content changes
data "external" "app_hash" {
  # Tar the app directory and compute its SHA256 hash; print as a JSON object
  # with an attribute "hash".
  program = ["sh", "-c", <<-EOT
    tar -C ${path.module}/app -cf - . | sha256sum | awk '{print "{\"hash\":\""$1"\"}"}'
  EOT
  ]
}

# Build the container image
resource "null_resource" "build_image" {
  triggers = {
    app_hash = data.external.app_hash.result.hash
  }

  provisioner "local-exec" {
    command = <<-EOT
      cd ${path.module}/app
      podman build -t ${var.datahub_container_registry_login_server}/hello-world-web-app:latest -f Containerfile .
    EOT
  }
}

# Push the container image to ACR
resource "null_resource" "push_image" {
  depends_on = [null_resource.build_image]

  triggers = {
    app_hash = data.external.app_hash.result.hash
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Get ACR access token and login with podman
      ACR_NAME=${replace(var.datahub_container_registry_login_server, ".azurecr.io", "")}
      TOKEN=$(az acr login --name $ACR_NAME --expose-token --output tsv --query accessToken)
      echo $TOKEN | podman login ${var.datahub_container_registry_login_server} --username 00000000-0000-0000-0000-000000000000 --password-stdin

      # Push the image
      podman push ${var.datahub_container_registry_login_server}/hello-world-web-app:latest
    EOT
  }
}

# =======================================================================
# Hello World Container App
resource "azurerm_container_app" "hello_world" {
  count = var.has_entra ? 1 : 0

  depends_on                   = [null_resource.push_image]
  name                         = "hello-world"
  container_app_environment_id = var.datahub_container_app_environment_id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"
  workload_profile_name        = "Consumption"

  identity {
    type         = "UserAssigned"
    identity_ids = [var.workload_identity_resource_id]
  }

  registry {
    identity = var.workload_identity_resource_id
    server   = var.datahub_container_registry_login_server
  }

  template {
    min_replicas = 1
    max_replicas = 1

    container {
      name   = "hello-world"
      image  = "${var.datahub_container_registry_login_server}/hello-world-web-app:latest"
      cpu    = 0.5
      memory = "1Gi"
    }
  }

  ingress {
    allow_insecure_connections = true
    external_enabled           = true
    target_port                = 8000

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
}
