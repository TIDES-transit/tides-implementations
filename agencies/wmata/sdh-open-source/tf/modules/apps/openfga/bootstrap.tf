# =============================================================================
# Bootstrap Job
#
# Creates an OpenFGA store and writes the Lakekeeper authorization model.
# The bootstrap script:
# 1. Creates a store named "lakekeeper"
# 2. Downloads Lakekeeper's OpenFGA schema from GitHub
# 3. Converts the schema.fga to JSON using the OpenFGA API
# 4. Writes the authorization model to the store

locals {
  bootstrap_enabled = (
    var.has_entra &&
    var.has_db_registration
  )

  bootstrap_image = local.bootstrap_enabled ? "${var.datahub_container_registry_login_server}/openfga-scripts:latest" : null
  scripts_dir     = "${path.module}/scripts"
  acr_name        = local.bootstrap_enabled ? split(".", var.datahub_container_registry_login_server)[0] : null

  effective_workload_identity_id = coalesce(
    var.workload_identity_id,
    null
  )
}

# =============================================================================
# Build and Push OpenFGA Scripts Image

resource "null_resource" "build_scripts_image" {
  count = local.bootstrap_enabled ? 1 : 0

  triggers = {
    containerfile_hash = filesha256("${local.scripts_dir}/Containerfile")
    bootstrap_hash     = filesha256("${local.scripts_dir}/bootstrap.sh")
    acr_server         = var.datahub_container_registry_login_server
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e

      echo "Building openfga-scripts image..."
      podman build -t openfga-scripts:latest -f "${local.scripts_dir}/Containerfile" "${local.scripts_dir}"

      echo "Logging into ACR ${local.acr_name}..."
      ACR_TOKEN=$(az acr login --name ${local.acr_name} --expose-token --output tsv --query accessToken)
      podman login ${var.datahub_container_registry_login_server} --username 00000000-0000-0000-0000-000000000000 --password "$ACR_TOKEN"

      echo "Tagging and pushing image to ${var.datahub_container_registry_login_server}..."
      podman tag openfga-scripts:latest ${var.datahub_container_registry_login_server}/openfga-scripts:latest
      podman push ${var.datahub_container_registry_login_server}/openfga-scripts:latest

      echo "Successfully pushed openfga-scripts:latest to ${var.datahub_container_registry_login_server}"
    EOT
  }
}

resource "azurerm_container_app_job" "bootstrap" {
  count = local.bootstrap_enabled && local.effective_workload_identity_id != null ? 1 : 0

  name                         = "${local.short_base}-boot-caj"
  location                     = var.resource_group_location
  container_app_environment_id = var.datahub_container_app_environment_id
  resource_group_name          = var.resource_group_name
  replica_timeout_in_seconds   = 300
  workload_profile_name        = "Consumption"

  template {
    container {
      name    = "openfga-bootstrap"
      image   = local.bootstrap_image
      cpu     = 0.25
      memory  = "0.5Gi"
      command = ["/bin/bash", "/app/bootstrap.sh"]

      env {
        name  = "OPENFGA_HOST"
        value = "${var.app_name}.internal.${var.cae_dns_suffix}"
      }
      env {
        name        = "OPENFGA_PRESHARED_KEY"
        secret_name = "[SECRET_NAME]"
      }
      env {
        name  = "OPENFGA_STORE_NAME"
        value = "lakekeeper"
      }
      env {
        name  = "LAKEKEEPER_SCHEMA_VERSION"
        value = var.lakekeeper_openfga_schema_version
      }
    }
  }

  secret {
    name  = "[SECRET_NAME]"
    value = random_password.openfga_preshared_key.result
  }

  registry {
    server   = var.datahub_container_registry_login_server
    identity = local.effective_workload_identity_id
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [local.effective_workload_identity_id]
  }

  manual_trigger_config {
    parallelism = 1
  }

  depends_on = [
    azurerm_container_app.openfga,
    null_resource.build_scripts_image
  ]
}

# Trigger the bootstrap job when the OpenFGA app is deployed
resource "null_resource" "bootstrap_trigger" {
  count = local.bootstrap_enabled && local.effective_workload_identity_id != null ? 1 : 0

  triggers = {
    openfga_app_id   = azurerm_container_app.openfga[0].id
    bootstrap_job_id = azurerm_container_app_job.bootstrap[0].id
    bootstrap_image  = local.bootstrap_image
    scripts_image_id = null_resource.build_scripts_image[0].id
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for OpenFGA to be ready..."
      sleep 30

      az containerapp job start \
        --name ${azurerm_container_app_job.bootstrap[0].name} \
        --resource-group ${var.resource_group_name}
    EOT
  }

  depends_on = [
    azurerm_container_app_job.bootstrap,
    azurerm_container_app.openfga
  ]
}