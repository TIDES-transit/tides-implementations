# =============================================================================
# Common resources used by Trino deployments

# Generate a random shared secret for Trino internal communication
resource "random_password" "trino_shared_secret" {
  length  = 64
  special = false
  upper   = true
  lower   = true
  numeric = true
}

# ============================================================================
# Password Authentication

# The following are resources for password-based authentication to Trino,
# separate from the OAuth-based machine users.
#
# Password authentication is used for services that cannot use OAuth2,
# such as Metabase's JDBC connection to Trino.

locals {
  # Naming configuration for multi-container Trino deployment
  base_name = trimsuffix(var.app_name, "-ca")
  trino_names = {
    coordinator = var.app_name                # Main app: [Project Name]-[env3]-trino-ca
    workers     = "${local.base_name}-wrk-ca" # Workers: [Project Name]-[env3]-trino-wrk-ca
  }

  # Standalone definition of Trino password-based users
  trino_password_users = {
    # metabase = {
    #   display_name = "trino-client-metabase"
    #   description  = "Metabase password authentication to Trino"
    # }
    # Add any other password-based users here in the future
    tableau = {
      display_name = "trino-client-tableau"
      description  = "Tableau password authentication to Trino"
    }
  }

  app_registration_client_id     = var.app_registration_client_id != null ? var.app_registration_client_id : (var.can_modify_entra ? azuread_application.trino[0].client_id : null)
  app_registration_client_secret = var.app_registration_client_secret != null ? var.app_registration_client_secret : (var.can_modify_entra ? azuread_application_password.trino[0].value : null)
}

# Generate random passwords for password-based Trino users
resource "random_password" "trino_password_users" {
  for_each = local.trino_password_users

  length  = 32
  special = true
}

# Store passwords in Key Vault
resource "azurerm_key_vault_secret" "trino_password_users" {
  for_each = local.trino_password_users

  name         = "[SECRET_NAME]"_", "-")}"
  value        = random_password.trino_password_users[each.key].result
  key_vault_id = var.datahub_key_vault_id
}

# Generate htpasswd entries for password users
resource "htpasswd_password" "trino_password_users" {
  for_each = local.trino_password_users

  password = random_password.trino_password_users[each.key].result
}

# ============================================================================
# Managed Identities

# Managed identity for Trino workload identity
resource "azurerm_user_assigned_identity" "trino_workload_identity" {
  name                = "${var.system_name}-${var.environment_name}-workload-trino-mi"
  location            = var.resource_group_location
  resource_group_name = var.resource_group_name

  tags = {
    Department  = "[DEPARTMENT]"
    Environment = var.environment_name
    Owner       = "[TEAM]"
    Purpose     = "Trino storage access via workload identity"
  }
}

# =============================================================================
# Container Apps

locals {
  # Generate password file content for Trino password authentication
  trino_password_file_content = join("\n", [
    for k, v in htpasswd_password.trino_password_users : "${k}:${v.bcrypt}"
  ])

  # Base config shared by both coordinator and workers
  trino_base_config_properties = <<-EOT
internal-communication.shared-secret=$${ENV:SHARED_SECRET}
http-server.process-forwarded=true
EOT

  # Authentication config only for the coordinator (not workers)
  trino_coordinator_auth_properties = <<-EOT
# Authentication configuration
http-server.authentication.type=OAUTH2,JWT,PASSWORD

# Azure AD OAuth2 Configuration for human users
http-server.authentication.oauth2.issuer=https://sts.windows.net/${var.tenant_id}/
http-server.authentication.oauth2.oidc.discovery=false
http-server.authentication.oauth2.auth-url=https://login.microsoftonline.com/${var.tenant_id}/oauth2/v2.0/authorize
http-server.authentication.oauth2.token-url=https://login.microsoftonline.com/${var.tenant_id}/oauth2/v2.0/token
http-server.authentication.oauth2.jwks-url=https://login.microsoftonline.com/${var.tenant_id}/discovery/v2.0/keys
http-server.authentication.oauth2.client-id=$${ENV:OAUTH2_CLIENT_ID}
http-server.authentication.oauth2.client-secret=$${ENV:OAUTH2_CLIENT_SECRET}
http-server.authentication.oauth2.principal-field=oid
http-server.authentication.oauth2.scopes=offline_access,api://${var.lakekeeper_app_registration_client_id}/Lakekeeper
http-server.authentication.oauth2.additional-audiences=api://${var.lakekeeper_app_registration_client_id}
http-server.authentication.oauth2.refresh-tokens=true
http-server.authentication.oauth2.refresh-tokens.issued-token.timeout=12h

# JWT Configuration for machine users
http-server.authentication.jwt.key-file=https://login.microsoftonline.com/${var.tenant_id}/discovery/v2.0/keys
http-server.authentication.jwt.required-issuer=https://sts.windows.net/${var.tenant_id}/
http-server.authentication.jwt.required-audience=api://${local.app_registration_client_id}
http-server.authentication.jwt.principal-field=oid

# Web UI OAuth2 configuration
web-ui.enabled=true
web-ui.authentication.type=oauth2
EOT

  # Authorization config only for the coordinator; will only be used if opa_policy_uri is not null
  trino_access_control_properties = <<-EOT
access-control.name=opa
opa.policy.uri=${coalesce(var.opa_policy_uri, "null")}
opa.policy.batched-uri=${coalesce(var.opa_batch_policy_uri, "null")}
opa.log-requests=true
opa.log-responses=true
EOT

  // Need to use FQDN to connect to Lakekeeper extrnally until: https://github.com/microsoft/azure-container-apps/issues/1308
  trino_datahub_catalog_properties = <<-EOT
connector.name=iceberg
iceberg.catalog.type=rest
iceberg.rest-catalog.uri=${var.lakekeeper_catalog_url}
iceberg.rest-catalog.warehouse=datahub

# OAuth2 Authentication to Lakekeeper
iceberg.rest-catalog.security=OAUTH2
iceberg.rest-catalog.oauth2.credential=$${ENV:LAKEKEEPER_OAUTH_CLIENT_ID}:$${ENV:LAKEKEEPER_OAUTH_CLIENT_SECRET}
iceberg.rest-catalog.oauth2.scope=$${ENV:LAKEKEEPER_OAUTH_SCOPE}
iceberg.rest-catalog.oauth2.server-uri=$${ENV:LAKEKEEPER_OAUTH_TOKEN_URI}

# Azure Storage Configuration
fs.native-azure.enabled=true
azure.auth-type=DEFAULT
azure.user-assigned-managed-identity.client-id=${azurerm_user_assigned_identity.trino_workload_identity.client_id}
EOT
}

resource "azurerm_container_app" "trino_coordinator" {
  count = var.has_entra ? 1 : 0

  name                         = local.trino_names.coordinator
  container_app_environment_id = var.datahub_container_app_environment_id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"
  workload_profile_name        = var.workload_profile_name

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.trino_workload_identity.id]
  }

  template {
    min_replicas = 1
    max_replicas = 1

    container {
      name   = "trino-coordinator"
      image  = "trinodb/trino:${var.trino_image_tag}"
      cpu    = 2.0
      memory = "4Gi"

      env {
        name  = "SHARED_SECRET"
        value = random_password.trino_shared_secret.result
      }

      # OAuth2 credentials for human users
      env {
        name  = "OAUTH2_CLIENT_ID"
        value = local.app_registration_client_id
      }

      env {
        name  = "OAUTH2_CLIENT_SECRET"
        value = local.app_registration_client_secret
      }

      # OAuth2 credentials for Lakekeeper access
      env {
        name  = "LAKEKEEPER_OAUTH_CLIENT_ID"
        value = local.app_registration_client_id
      }

      env {
        name  = "LAKEKEEPER_OAUTH_CLIENT_SECRET"
        value = local.app_registration_client_secret
      }

      # If the var.lakekeeper_app_registration_client_id is true, then set the LAKEKEEPER_OAUTH_SCOPE environment variable. Otherwise, keep it blank.
      env {
        name  = "LAKEKEEPER_OAUTH_SCOPE"
        value = "api://${var.lakekeeper_app_registration_client_id}/.default"
      }

      env {
        name  = "LAKEKEEPER_OAUTH_TOKEN_URI"
        value = "https://login.microsoftonline.com/${var.tenant_id}/oauth2/v2.0/token"
      }

      # Password file content
      env {
        name  = "PASSWORD_FILE_CONTENT"
        value = local.trino_password_file_content
      }

      # Password authenticator properties
      env {
        name  = "PASSWORD_AUTHENTICATOR_PROPERTIES"
        value = <<-EOT
password-authenticator.name=file
file.password-file=/etc/trino/auth/password/password.db
EOT
      }

      env {
        name  = "TRINO_CONFIG_PROPERTIES"
        value = <<-EOT
coordinator=true
node-scheduler.include-coordinator=false
http-server.http.port=8080
discovery.uri=http://localhost:8080

${local.trino_base_config_properties}
${local.trino_coordinator_auth_properties}
EOT
      }

      env {
        name  = "DATAHUB_CATALOG_PROPERTIES"
        value = local.trino_datahub_catalog_properties
      }

      env {
        name  = "ACCESS_CONTROL_PROPERTIES"
        value = var.opa_policy_uri != null ? local.trino_access_control_properties : ""
      }

      // Workaround for getting config into files until: https://github.com/hashicorp/terraform-provider-azurerm/pull/29267
      command = ["/bin/bash"]
      args = [
        "-c",
        <<-EOT
echo "$${TRINO_CONFIG_PROPERTIES}" > /etc/trino/config.properties
echo "$${DATAHUB_CATALOG_PROPERTIES}" > /etc/trino/catalog/datahub.properties
echo "$${PASSWORD_AUTHENTICATOR_PROPERTIES}" > /etc/trino/password-authenticator.properties
mkdir -p /etc/trino/auth/password
echo "$${PASSWORD_FILE_CONTENT}" > /etc/trino/auth/password/password.db
if [ -n "$${ACCESS_CONTROL_PROPERTIES}" ]; then echo "$${ACCESS_CONTROL_PROPERTIES}" > /etc/trino/access-control.properties; fi
exec /usr/lib/trino/bin/run-trino
        EOT
      ]

      liveness_probe {
        transport = "HTTP"
        port      = 8080
        path      = "/v1/info"
      }

      readiness_probe {
        transport = "HTTP"
        port      = 8080
        path      = "/v1/info"
      }
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

resource "azurerm_container_app" "trino_workers" {
  count = var.has_entra ? 1 : 0

  name                         = local.trino_names.workers
  container_app_environment_id = var.datahub_container_app_environment_id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"
  workload_profile_name        = var.workload_profile_name

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.trino_workload_identity.id]
  }

  template {
    min_replicas = var.min_workers
    max_replicas = var.max_workers

    custom_scale_rule {
      name             = "cpu-scaling"
      custom_rule_type = "cpu"
      metadata = {
        type  = "Utilization"
        value = "70"
      }
    }

    custom_scale_rule {
      name             = "memory-scaling"
      custom_rule_type = "memory"
      metadata = {
        type  = "Utilization"
        value = "70"
      }
    }

    container {
      name   = "trino-worker"
      image  = "trinodb/trino:${var.trino_image_tag}"
      cpu    = var.worker_cpu
      memory = var.worker_memory

      env {
        name  = "SHARED_SECRET"
        value = random_password.trino_shared_secret.result
      }

      # OAuth2 credentials for Lakekeeper access (workers need this too)
      env {
        name  = "LAKEKEEPER_OAUTH_CLIENT_ID"
        value = local.app_registration_client_id
      }

      env {
        name  = "LAKEKEEPER_OAUTH_CLIENT_SECRET"
        value = local.app_registration_client_secret
      }

      env {
        name  = "LAKEKEEPER_OAUTH_SCOPE"
        value = "api://${var.lakekeeper_app_registration_client_id}/.default"
      }

      env {
        name  = "LAKEKEEPER_OAUTH_TOKEN_URI"
        value = "https://login.microsoftonline.com/${var.tenant_id}/oauth2/v2.0/token"
      }

      env {
        name  = "TRINO_CONFIG_PROPERTIES"
        value = <<-EOT
coordinator=false
http-server.http.port=8080
discovery.uri=http://${local.trino_names.coordinator}

${local.trino_base_config_properties}
EOT
      }

      env {
        name  = "DATAHUB_CATALOG_PROPERTIES"
        value = local.trino_datahub_catalog_properties
      }

      // Workaround for getting config into files until: https://github.com/hashicorp/terraform-provider-azurerm/pull/29267
      command = ["/bin/bash"]
      args = [
        "-c",
        <<-EOT
echo "$${TRINO_CONFIG_PROPERTIES}" > /etc/trino/config.properties
echo "$${DATAHUB_CATALOG_PROPERTIES}" > /etc/trino/catalog/datahub.properties
exec /usr/lib/trino/bin/run-trino
        EOT
      ]

      liveness_probe {
        transport = "HTTP"
        port      = 8080
        path      = "/v1/info"
      }

      readiness_probe {
        transport = "HTTP"
        port      = 8080
        path      = "/v1/info"
      }
    }
  }

  # Workers don't need external ingress
  # They communicate internally with the coordinator
}