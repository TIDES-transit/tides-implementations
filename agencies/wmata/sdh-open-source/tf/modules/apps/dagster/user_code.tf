# =============================================================================
# External Secret References

# data "azurerm_key_vault_secret" "openmetadata_ingestion_token" {
#   name         = "[SECRET_NAME]"
#   key_vault_id = azurerm_key_vault.kv_datahub.id
# }

# data "azurerm_key_vault_secret" "metabase_bot_username" {
#   name         = "[SECRET_NAME]"
#   key_vault_id = azurerm_key_vault.kv_datahub.id
# }

# data "azurerm_key_vault_secret" "metabase_bot_password" {
#   name         = "[SECRET_NAME]"
#   key_vault_id = azurerm_key_vault.kv_datahub.id
# }

# =============================================================================
# Dagster User Code Container App

resource "azurerm_container_app" "dagster_user_code" {
  # Since we can't deploy the Dagster image unless we have access to pull from ACR,
  # we only create this resource if using role assignments.
  count = var.has_entra ? 1 : 0

  name                         = local.dagster_names.user_code
  container_app_environment_id = var.datahub_container_app_environment_id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"
  workload_profile_name        = var.workload_profile_name

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.dagster.id]
  }

  registry {
    identity = azurerm_user_assigned_identity.dagster.id
    server   = var.datahub_container_registry_login_server
  }

  # Define secrets with Key Vault references
  secret {
    name                = "[SECRET_NAME]"
    identity            = azurerm_user_assigned_identity.dagster.id
    key_vault_secret_id = "[KEY_VAULT_SECRET_URL]"
  }

  # secret {
  #   name                = "[SECRET_NAME]"
  #   identity            = azurerm_user_assigned_identity.dagster.id
  #   key_vault_secret_id = "[KEY_VAULT_SECRET_URL]"
  # }

  # secret {
  #   name                = "[SECRET_NAME]"
  #   identity            = azurerm_user_assigned_identity.dagster.id
  #   key_vault_secret_id = "[KEY_VAULT_SECRET_URL]"
  # }

  secret {
    name                = "[SECRET_NAME]"
    identity            = azurerm_user_assigned_identity.dagster.id
    key_vault_secret_id = "[KEY_VAULT_SECRET_URL]"
  }

  template {
    min_replicas = 1
    max_replicas = 1

    container {
      name   = "[SECRET_NAME]"
      image  = "${var.datahub_container_registry_login_server}/[project-name]-dagster-pipelines:${var.dagster_image_tag}"
      cpu    = 4.0
      memory = "8Gi"

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
        name  = "DAGSTER_CURRENT_IMAGE"
        value = "${var.datahub_container_registry_login_server}/[project-name]-dagster-pipelines:${var.dagster_image_tag}"
      }

      env {
        name  = "[Project Name]_ENVIRONMENT"
        value = var.[Project Name]_environment
      }

      env {
        name  = "KEY_VAULT_NAME"
        value = var.datahub_key_vault_name
      }

      # Azure credentials
      env {
        name  = "AZURE_TENANT_ID"
        value = var.tenant_id
      }

      env {
        name  = "AZURE_CLIENT_ID"
        value = local.machine_user_client_id
      }

      env {
        name        = "AZURE_CLIENT_SECRET"
        secret_name = "[SECRET_NAME]"
      }

      # Storage accounts
      env {
        name  = "AZURE_GTFS_STORAGE_ACCOUNT"
        value = var.datahub_lake_storage_account_name
      }

      env {
        name  = "AZURE_FARE_STORAGE_ACCOUNT"
        value = var.datahub_lake_storage_account_name
      }

      # Lakekeeper connection
      env {
        name  = "LAKEKEEPER_URL"
        value = var.lakekeeper_url
      }

      env {
        name  = "LAKEKEEPER_OAUTH_SCOPE"
        value = "api://${var.lakekeeper_app_registration_client_id}/.default"
      }

      # Trino connection
      env {
        name  = "TRINO_HOST"
        value = var.trino_host
      }

      env {
        name  = "TRINO_PORT"
        value = "443"
      }

      env {
        name  = "TRINO_USER"
        value = local.machine_user_client_id
      }

      env {
        name  = "TRINO_CATALOG"
        value = "datahub"
      }

      env {
        name  = "TRINO_SCHEMA"
        value = "public"
      }

      env {
        name  = "TRINO_USE_HTTPS"
        value = "true"
      }

      env {
        name  = "TRINO_OAUTH_SCOPE"
        value = "api://${var.trino_app_registration_client_id}/.default"
      }

      # OpenMetadata connection
      env {
        name  = "OPENMETADATA_API_URL"
        value = var.openmetadata_api_url
      }

      env {
        name        = "OPENMETADATA_API_TOKEN"
        secret_name = "[SECRET_NAME]"
      }

      # Dagster ingestion connection
      env {
        name  = "DAGSTER_HOST"
        value = "https://${var.app_name}.${var.cae_dns_suffix}"
      }

      env {
        name  = "DAGSTER_TOKEN"
        value = "" # Blank as specified
      }

      # # Metabase connection
      # env {
      #   name  = "METABASE_HOST"
      #   value = "https://metabase.${var.cae_dns_suffix}"
      # }

      # env {
      #   name        = "METABASE_BOT_USERNAME"
      #   secret_name = "[SECRET_NAME]"
      # }

      # env {
      #   name        = "METABASE_BOT_PASSWORD"
      #   secret_name = "[SECRET_NAME]"
      # }

      readiness_probe {
        transport = "TCP"
        port      = 3030
      }
    }
  }

  ingress {
    external_enabled = false
    target_port      = 3030
    transport        = "tcp"

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  lifecycle {
    ignore_changes = [
      template[0].container[0].liveness_probe,
    ]
  }
}