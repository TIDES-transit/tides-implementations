# =============================================================================
# OPENMETADATA SERVER CONTAINER APP
# =============================================================================

locals {
  openmetadata_names = {
    server     = var.app_name
    opensearch = "${local.env_base_name}-opensearch-ca"
  }
  openmetadata_env_vars = {
    # Database configuration
    "DB_DRIVER_CLASS" = "org.postgresql.Driver"
    "DB_SCHEME"       = "postgresql"
    "DB_HOST"         = var.datahub_postgresql_flexible_server_fqdn
    "DB_PORT"         = "5432"
    "DB_USER"         = var.postgresql_username
    "DB_PARAMS"       = "sslmode=require"
    "OM_DATABASE"     = azurerm_postgresql_flexible_server_database.openmetadata[0].name

    # OpenSearch configuration
    "SEARCH_TYPE"        = "opensearch"
    "ELASTICSEARCH_HOST" = local.openmetadata_names.opensearch

    # Authorization configuration (general)
    "AUTHORIZER_ADMIN_PRINCIPALS"            = "[${var.openmetadata_initial_admin}]"
    "AUTHORIZER_PRINCIPAL_DOMAIN"            = var.openmetadata_principal_domain
    "AUTHORIZER_ALLOWED_REGISTRATION_DOMAIN" = "[\"all\"]"
    "AUTHORIZER_ENFORCE_PRINCIPAL_DOMAIN"    = "false"
    "AUTHORIZER_ENABLE_SECURE_SOCKET"        = "false"
    "AUTHORIZER_USE_ROLES_FROM_PROVIDER"     = "false"

    # Authentication configuration (Azure-specific)
    # See: https://docs.open-metadata.org/latest/deployment/security/azure/confidential-client
    "AUTHENTICATION_PROVIDER"           = "azure"
    "AUTHENTICATION_CLIENT_TYPE"        = "confidential"
    "AUTHENTICATION_AUTHORITY"          = "https://login.microsoftonline.com/${var.tenant_id}"
    "AUTHENTICATION_PUBLIC_KEYS"        = "[https://${var.app_name}.${var.cae_dns_suffix}/api/v1/system/config/jwks, https://login.microsoftonline.com/common/discovery/keys, https://login.microsoftonline.com/${var.tenant_id}/discovery/v2.0/keys]"
    "AUTHENTICATION_ENABLE_SELF_SIGNUP" = "true"

    "AUTHENTICATION_JWT_PRINCIPAL_CLAIMS_MAPPING" = "[\"username:preferred_username\", \"email:email\"]"

    # OIDC Configuration (Azure-specific)
    "OIDC_TYPE"          = "azure"
    "OIDC_CLIENT_ID"     = var.app_registration_client_id
    "OIDC_CLIENT_SECRET" = var.app_registration_client_secret
    "OIDC_SCOPE"         = "openid email profile offline_access"
    "OIDC_DISCOVERY_URI" = "https://login.microsoftonline.com/${var.tenant_id}/v2.0/.well-known/openid-configuration"
    "OIDC_CALLBACK"      = "https://${var.app_name}.${var.cae_dns_suffix}/callback"
    "OIDC_SERVER_URL"    = "https://${var.app_name}.${var.cae_dns_suffix}"
    "OIDC_TENANT"        = var.tenant_id
    "OIDC_CUSTOM_PARAMS" = "{}"
    "OIDC_PROMPT_TYPE"   = "select_account"

    # JWT Configuration
    # Note: JWT_KEY_ID is configured as a secret below
    # Note: JWT keys are written to files by the entrypoint script
    "JWT_ISSUER" = "${var.app_name}.${var.cae_dns_suffix}"

    # Pipeline service configuration (disabled)
    "PIPELINE_SERVICE_CLIENT_ENABLED" = "false"

    # Heap configuration (custom memory settings)
    "OPENMETADATA_HEAP_OPTS" = "-Xmx1G -Xms1G"
  }
}

resource "azurerm_container_app" "openmetadata" {
  count = var.has_entra && var.has_db_registration ? 1 : 0

  name                         = local.openmetadata_names.server
  container_app_environment_id = var.datahub_container_app_environment_id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"
  workload_profile_name        = var.workload_profile_name

  depends_on = [
    azurerm_container_app.opensearch,
    azurerm_postgresql_flexible_server_database.openmetadata,
    azurerm_key_vault_secret.openmetadata_postgres_password,
    postgresql_role.openmetadata_user,
    postgresql_grant.openmetadata_database,
    postgresql_grant.openmetadata_schema
  ]

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.openmetadata.id]
  }

  # Define secrets with Key Vault references
  dynamic "secret" {
    for_each = var.has_entra ? [1] : []
    content {
      name                = "[SECRET_NAME]"
      identity            = azurerm_user_assigned_identity.openmetadata.id
      key_vault_secret_id = [KEY_VAULT_SECRET_REF]
    }
  }

  dynamic "secret" {
    for_each = var.has_entra ? [1] : []
    content {
      name                = "[SECRET_NAME]"
      identity            = azurerm_user_assigned_identity.openmetadata.id
      key_vault_secret_id = [KEY_VAULT_SECRET_REF]
    }
  }

  dynamic "secret" {
    for_each = var.has_entra ? [1] : []
    content {
      name                = "[SECRET_NAME]"
      identity            = azurerm_user_assigned_identity.openmetadata.id
      key_vault_secret_id = [KEY_VAULT_SECRET_REF]
    }
  }

  dynamic "secret" {
    for_each = var.has_entra ? [1] : []
    content {
      name                = "[SECRET_NAME]"
      identity            = azurerm_user_assigned_identity.openmetadata.id
      key_vault_secret_id = "[KEY_VAULT_SECRET_URL]"
    }
  }

  dynamic "secret" {
    for_each = var.has_entra ? [1] : []
    content {
      name                = "[SECRET_NAME]"
      identity            = azurerm_user_assigned_identity.openmetadata.id
      key_vault_secret_id = "[KEY_VAULT_SECRET_URL]"
    }
  }

  template {
    min_replicas = 1
    max_replicas = 1

    container {
      name   = "openmetadata-server"
      image  = "docker.getcollate.io/openmetadata/server:${var.openmetadata_image_tag}"
      cpu    = 2.0
      memory = "4Gi"

      # Environment variables from local map
      dynamic "env" {
        for_each = local.openmetadata_env_vars
        content {
          name  = env.key
          value = env.value
        }
      }

      # Secret environment variables from Key Vault
      dynamic "env" {
        for_each = var.has_entra ? [1] : []
        content {
          name        = "DB_USER_PASSWORD"
          secret_name = "[SECRET_NAME]"
        }
      }

      dynamic "env" {
        for_each = var.has_entra ? [1] : []
        content {
          name        = "OIDC_CLIENT_SECRET"
          secret_name = "[SECRET_NAME]"
        }
      }

      dynamic "env" {
        for_each = var.has_entra ? [1] : []
        content {
          name        = "JWT_KEY_ID"
          secret_name = "[SECRET_NAME]"
        }
      }

      dynamic "env" {
        for_each = var.has_entra ? [1] : []
        content {
          name        = "JWT_PRIVATE_KEY"
          secret_name = "[SECRET_NAME]"
        }
      }

      dynamic "env" {
        for_each = var.has_entra ? [1] : []
        content {
          name        = "JWT_PUBLIC_KEY"
          secret_name = "[SECRET_NAME]"
        }
      }

      # Custom entrypoint to run migration then server
      command = ["/bin/bash"]
      args = [
        "-c",
        <<-EOT
        set -e

        # Write JWT keys from environment variables to files
        # Workaround until: https://github.com/hashicorp/terraform-provider-azurerm/pull/29267
        echo "Writing JWT keys to files..."
        echo "$${JWT_PRIVATE_KEY}" | base64 -d > /opt/openmetadata/conf/private_key.der
        echo "$${JWT_PUBLIC_KEY}" | base64 -d > /opt/openmetadata/conf/public_key.der

        echo "Running OpenMetadata database migration..."
        ./bootstrap/openmetadata-ops.sh migrate
        echo "Migration completed. Starting OpenMetadata server..."
        exec /openmetadata-start.sh
        EOT
      ]

      # liveness_probe {
      #   transport = "HTTP"
      #   port      = 8586
      #   path      = "/healthcheck"
      # }

      # readiness_probe {
      #   transport = "HTTP"
      #   port      = 8586
      #   path      = "/healthcheck"
      # }
    }
  }

  ingress {
    allow_insecure_connections = true
    external_enabled           = true
    target_port                = 8585

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
}