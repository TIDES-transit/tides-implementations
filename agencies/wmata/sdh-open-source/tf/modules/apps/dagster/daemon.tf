# =============================================================================
# DAGSTER DAEMON CONTAINER APP
# =============================================================================

resource "azurerm_container_app" "dagster_daemon" {
  # Since we can't deploy the Dagster image unless we have access to pull from ACR,
  # we only create this resource if using role assignments.
  count = var.has_entra ? 1 : 0

  name                         = local.dagster_names.daemon
  container_app_environment_id = var.datahub_container_app_environment_id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"
  workload_profile_name        = var.workload_profile_name

  depends_on = [
    azurerm_container_app.dagster_user_code
  ]

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.dagster.id]
  }

  registry {
    identity = azurerm_user_assigned_identity.dagster.id
    server   = var.datahub_container_registry_login_server
  }

  template {
    min_replicas = 1
    max_replicas = 1

    container {
      name   = "dagster-daemon"
      image  = "${var.datahub_container_registry_login_server}/[project-name]-dagster-daemons:${var.dagster_image_tag}"
      cpu    = 2.0
      memory = "4Gi"

      # PostgreSQL connection environment variables
      env {
        name  = "DAGSTER_POSTGRES_USER"
        value = var.datahub_postgresql_admin_username
      }

      env {
        name  = "DAGSTER_POSTGRES_PASSWORD"
        value = var.datahub_postgresql_admin_password
      }

      env {
        name  = "DAGSTER_POSTGRES_HOSTNAME"
        value = var.datahub_postgresql_flexible_server_fqdn
      }

      env {
        name  = "DAGSTER_POSTGRES_DB"
        value = "dagster"
      }

      env {
        name  = "DAGSTER_POSTGRES_PORT"
        value = "5432"
      }

      env {
        name  = "DAGSTER_CONFIG_YAML"
        value = local.dagster_config_yaml
      }

      env {
        name  = "DAGSTER_WORKSPACE_YAML"
        value = local.workspace_yaml
      }

      # Workaround for getting config into files until: https://github.com/hashicorp/terraform-provider-azurerm/pull/29267
      command = ["/bin/bash"]
      args = [
        "-c",
        <<-EOT
echo "$${DAGSTER_CONFIG_YAML}" > /opt/dagster/home/dagster.yaml
echo "$${DAGSTER_WORKSPACE_YAML}" > /opt/dagster/home/workspace.yaml
exec dagster-daemon run -w /opt/dagster/home/workspace.yaml
        EOT
      ]
    }
  }

  # Daemon doesn't need ingress
}