# =============================================================================
# DAGSTER WEBSERVER CONTAINER APP
# =============================================================================

resource "azurerm_container_app" "dagster_webserver" {
  # Since we can't deploy the Dagster image unless we have access to pull from ACR,
  # we only create this resource if using role assignments.
  count = var.has_entra ? 1 : 0

  name                         = local.dagster_names.webserver
  container_app_environment_id = var.datahub_container_app_environment_id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"
  workload_profile_name        = var.workload_profile_name

  depends_on = [
    azurerm_container_app.dagster_user_code[0]
  ]

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.dagster.id]
  }

  registry {
    identity = azurerm_user_assigned_identity.dagster.id
    server   = var.datahub_container_registry_login_server
  }

  secret {
    name                = "[SECRET_NAME]"
    identity            = azurerm_user_assigned_identity.dagster.id
    key_vault_secret_id = "[KEY_VAULT_SECRET_URL]"
  }

  template {
    min_replicas = 1
    max_replicas = 1

    container {
      name   = "dagster-webserver"
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
exec dagster-webserver -h 0.0.0.0 -p 80 -w /opt/dagster/home/workspace.yaml
        EOT
      ]

      readiness_probe {
        transport = "HTTP"
        port      = 80
        path      = "/server_info"
      }
    }
  }

  ingress {
    allow_insecure_connections = false
    external_enabled           = true
    target_port                = 80

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
}

# Require authentication via AzAPI until azurerm provider supports auth: https://github.com/hashicorp/terraform-provider-azurerm/issues/22213
resource "azapi_resource_action" "dagster_user_code_authentication" {
  count = var.has_entra ? 1 : 0

  type        = "Microsoft.App/containerApps/authConfigs@2024-03-01"
  resource_id = "${azurerm_container_app.dagster_webserver[0].id}/authConfigs/current"
  method      = "PUT"

  body = {
    location = var.resource_group_location
    properties = {
      globalValidation = {
        redirectToProvider          = "azureactivedirectory"
        unauthenticatedClientAction = "RedirectToLoginPage"
      }
      identityProviders = {
        azureActiveDirectory = {
          registration = {
            clientId                = local.app_registration_client_id
            clientSecretSettingName = azurerm_key_vault_secret.dagster_oauth_client_secret.name
            openIdIssuer            = "https://sts.windows.net/${var.tenant_id}/v2.0"
          }
          validation = {
            defaultAuthorizationPolicy = {
              allowedApplications = [
                local.app_registration_client_id,
              ]
            }
          }
        }
      }
      platform = {
        enabled = true
      }
    }
  }
}