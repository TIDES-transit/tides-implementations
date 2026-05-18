# ============================================================================
# Database

resource "azurerm_postgresql_flexible_server_database" "lakekeeper" {
  count = var.has_db_registration ? 1 : 0

  name      = "lakekeeper"
  server_id = var.datahub_postgresql_flexible_server_id

  # Under normal circumstances, you wouldn't want to destroy this database on
  # accident, so protect it from happening with this TF lifecycle rule. We can
  # comment out the rule if we actually intend to replace or destroy the
  # database.
  lifecycle {
    prevent_destroy = true
  }
}

# Generate random password for Lakekeeper PostgreSQL user
resource "random_password" "lakekeeper_postgres_password" {
  length  = 32
  special = true
}

# Store Lakekeeper PostgreSQL user password in Key Vault
resource "azurerm_key_vault_secret" "lakekeeper_postgres_password" {
  name         = "[SECRET_NAME]"
  value        = random_password.lakekeeper_postgres_password.result
  key_vault_id = var.datahub_key_vault_id
}

# Create PostgreSQL role/user for Lakekeeper
resource "postgresql_role" "lakekeeper_user" {
  count = var.has_db_registration ? 1 : 0

  name     = var.postgresql_username
  login    = true
  password = random_password.lakekeeper_postgres_password.result

  depends_on = [
    azurerm_postgresql_flexible_server_database.lakekeeper
  ]
}

# Grant database-level permissions to Lakekeeper user
resource "postgresql_grant" "lakekeeper_database" {
  count = var.has_db_registration ? 1 : 0

  database    = azurerm_postgresql_flexible_server_database.lakekeeper[0].name
  role        = postgresql_role.lakekeeper_user[0].name
  object_type = "database"
  privileges  = ["CONNECT", "CREATE"]

  depends_on = [
    postgresql_role.lakekeeper_user
  ]
}

# Grant schema-level permissions to Lakekeeper user
resource "postgresql_grant" "lakekeeper_schema" {
  count = var.has_db_registration ? 1 : 0

  database    = azurerm_postgresql_flexible_server_database.lakekeeper[0].name
  role        = postgresql_role.lakekeeper_user[0].name
  schema      = "public"
  object_type = "schema"
  privileges  = ["USAGE", "CREATE"]

  depends_on = [
    postgresql_role.lakekeeper_user
  ]
}

# =============================================================================
# Container App

# Generate a random encryption key for Lakekeeper
resource "random_password" "encryption_key" {
  length  = 40
  special = false
  upper   = true
  lower   = true
  numeric = true

  # Needed to support importing the original value during migration
  lifecycle {
    ignore_changes = [
      special,
    ]
  }
}

# Store the encryption key in Key Vault
resource "azurerm_key_vault_secret" "encryption_key" {
  name         = "[SECRET_NAME]"
  value        = random_password.encryption_key.result
  key_vault_id = var.datahub_key_vault_id
}

locals {
  base_name  = trimsuffix(var.app_name, "-ca")
  short_base = "${var.sys_short}-${var.env_short}-lakekeeper"

  lakekeeper_env__vars = merge(
    {
      # Database configuration
      "ICEBERG_REST__PG_DATABASE" = azurerm_postgresql_flexible_server_database.lakekeeper[0].name
      "ICEBERG_REST__PG_HOST_R"   = var.datahub_postgresql_flexible_server_fqdn
      "ICEBERG_REST__PG_HOST_W"   = var.datahub_postgresql_flexible_server_fqdn
      "ICEBERG_REST__PG_PORT"     = "5432"
      "ICEBERG_REST__PG_USER"     = var.datahub_postgresql_admin_username
      "ICEBERG_REST__PG_PASSWORD" = var.datahub_postgresql_admin_password

      # Secret storage
      "ICEBERG_REST__SECRET_BACKEND"    = "Postgres"
      "ICEBERG_REST__PG_ENCRYPTION_KEY" = azurerm_key_vault_secret.encryption_key.value

      # Basic server configuration
      "LAKEKEEPER__LISTEN_PORT" = tostring(var.app_listen_port)

      # Authorization backend: use OpenFGA if endpoint is provided, otherwise allowall
      "LAKEKEEPER__AUTHZ_BACKEND" = var.openfga_endpoint != null ? "openfga" : "allowall"

      # OpenID Configuration for authentication
      "LAKEKEEPER__OPENID_PROVIDER_URI"       = "https://login.microsoftonline.com/${var.tenant_id}/v2.0"
      "LAKEKEEPER__OPENID_AUDIENCE"           = "api://${local.app_registration_client_id}"
      "LAKEKEEPER__OPENID_ADDITIONAL_ISSUERS" = "https://sts.windows.net/${var.tenant_id}/"

      # UI Configuration
      "LAKEKEEPER__UI__OPENID_CLIENT_ID" = local.app_registration_client_id
      "LAKEKEEPER__UI__OPENID_SCOPE"     = "openid profile api://${local.app_registration_client_id}/Lakekeeper"
    },
    # OpenFGA configuration (only when endpoint is provided)
    var.openfga_endpoint != null ? {
      "LAKEKEEPER__OPENFGA__ENDPOINT"   = var.openfga_endpoint
      "LAKEKEEPER__OPENFGA__STORE_NAME" = var.openfga_store_name
    } : {},
  )

  # Sensitive env vars are stored as container app secrets and referenced by name.
  # The secret name is derived from the env var name (lowercased, underscores to hyphens).
  lakekeeper_env__secrets = merge(
    var.openfga_api_key != null ? {
      "LAKEKEEPER__OPENFGA__API_KEY" = var.openfga_api_key
    } : {},
  )

  app_registration_client_id     = var.can_modify_entra ? azuread_application.lakekeeper[0].client_id : var.app_registration_client_id
  app_registration_client_secret = var.can_modify_entra ? azuread_application_password.lakekeeper[0].value : null
  oauth2_permission_scope_id     = var.can_modify_entra ? azuread_application_permission_scope.lakekeeper[0].scope_id : var.oauth2_permission_scope_id
}

resource "azurerm_container_app_job" "migration" {
  name                         = "${local.short_base}-migr-caj"
  location                     = var.resource_group_location
  container_app_environment_id = var.datahub_container_app_environment_id
  resource_group_name          = var.resource_group_name
  replica_timeout_in_seconds   = 3600
  workload_profile_name        = "Consumption"

  depends_on = [
    postgresql_role.lakekeeper_user,
    postgresql_grant.lakekeeper_database,
    postgresql_grant.lakekeeper_schema,
  ]

  template {
    container {
      name   = "lakekeeper-migration"
      image  = "quay.io/lakekeeper/catalog:${var.lakekeeper_image_tag}"
      cpu    = 1.0
      memory = "2Gi"

      args = ["migrate"]

      dynamic "env" {
        for_each = local.lakekeeper_env__vars
        content {
          name  = env.key
          value = env.value
        }
      }

      dynamic "env" {
        for_each = local.lakekeeper_env__secrets
        content {
          name        = env.key
          secret_name = lower(replace(replace(env.key, "__", "-"), "_", "-"))
        }
      }

    }
  }

  dynamic "secret" {
    for_each = local.lakekeeper_env__secrets
    content {
      name  = lower(replace(replace(secret.key, "__", "-"), "_", "-"))
      value = secret.value
    }
  }

  manual_trigger_config {
    parallelism = 1
  }
}

resource "azurerm_container_app" "lakekeeper" {
  count = var.has_db_registration ? 1 : 0

  name                         = var.app_name
  container_app_environment_id = var.datahub_container_app_environment_id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"
  workload_profile_name        = "Consumption"

  # Wait for migration to complete before deploying the app
  depends_on = [
    null_resource.migration_trigger
  ]

  template {
    min_replicas = 1
    max_replicas = 1

    container {
      name   = "lakekeeper"
      image  = "quay.io/lakekeeper/catalog:${var.lakekeeper_image_tag}"
      cpu    = 2.0
      memory = "4Gi"

      args = ["serve"]

      dynamic "env" {
        for_each = local.lakekeeper_env__vars
        content {
          name  = env.key
          value = env.value
        }
      }

      dynamic "env" {
        for_each = local.lakekeeper_env__secrets
        content {
          name        = env.key
          secret_name = lower(replace(replace(env.key, "__", "-"), "_", "-"))
        }
      }

      liveness_probe {
        transport = "HTTP"
        port      = var.app_listen_port
        path      = "/health"
      }

      readiness_probe {
        transport = "HTTP"
        port      = var.app_listen_port
        path      = "/health"
      }
    }
  }

  dynamic "secret" {
    for_each = local.lakekeeper_env__secrets
    content {
      name  = lower(replace(replace(secret.key, "__", "-"), "_", "-"))
      value = secret.value
    }
  }

  ingress {
    allow_insecure_connections = true
    external_enabled           = true
    target_port                = var.app_listen_port

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
}

# =============================================================================
# Migration Job Trigger
#
# This null_resource triggers the migration job whenever the migration job
# configuration changes. The migration runs before the Lakekeeper app is
# deployed to ensure database schema is up to date.

resource "null_resource" "migration_trigger" {
  # Trigger when the migration job configuration changes
  triggers = {
    migration_job_id = azurerm_container_app_job.migration.id
    lakekeeper_db_id = azurerm_postgresql_flexible_server_database.lakekeeper[0].id
  }

  # Execute the migration job when triggered
  provisioner "local-exec" {
    command = <<-EOT
      az containerapp job start \
        --name ${azurerm_container_app_job.migration.name} \
        --resource-group ${var.resource_group_name}
    EOT
  }

  # Ensure the migration job exists before trying to execute it
  depends_on = [
    azurerm_container_app_job.migration
  ]
}

# =============================================================================
# Managed Identity for Lakekeeper Workload
#
# This identity is used by Lakekeeper container app jobs (bootstrap, etc.)
# to pull images from the container registry. The AcrPull role assignment
# must be done separately by a security team member (see entra.tf).

resource "azurerm_user_assigned_identity" "lakekeeper" {
  name                = "${var.sys_short}-${var.env_short}-workload-lakekeeper-mi"
  location            = var.resource_group_location
  resource_group_name = var.resource_group_name

  tags = {
    Department  = "[DEPARTMENT]"
    Environment = var.environment_name
    Owner       = "[TEAM]"
    Purpose     = "Lakekeeper workload identity for container apps"
  }
}

# Look up the external workload identity's client_id when one is provided.
# Needed so container jobs can request MI tokens for the correct identity.
data "azurerm_user_assigned_identity" "external" {
  count = var.workload_identity_id != null ? 1 : 0

  name                = split("/", var.workload_identity_id)[8]
  resource_group_name = split("/", var.workload_identity_id)[4]
}

# =============================================================================
# Bootstrap Job
#
# This job bootstraps Lakekeeper by calling the /management/v1/bootstrap
# endpoint. The first caller becomes the initial admin. The job is idempotent -
# if Lakekeeper is already bootstrapped, it will succeed without changes.

locals {
  # Use the provided workload identity if available, otherwise use the Lakekeeper identity.
  # This allows using an existing identity (like Dagster's) that already has AcrPull,
  # until the security team assigns AcrPull to the Lakekeeper identity.
  effective_workload_identity_id = coalesce(
    var.workload_identity_id,
    azurerm_user_assigned_identity.lakekeeper.id
  )
  effective_workload_identity_client_id = (
    var.workload_identity_id != null
    ? data.azurerm_user_assigned_identity.external[0].client_id
    : azurerm_user_assigned_identity.lakekeeper.client_id
  )

  # For storage credentials passed to Lakekeeper (so Lakekeeper can access ADLS).
  # These must always be app registration client credentials (client_id + secret),
  # since Lakekeeper stores and uses them internally. Falls back to the auto-generated
  # app registration when can_modify_entra is true.
  storage_client_id = coalesce(
    var.storage_client_id,
    var.can_modify_entra ? azuread_application.lakekeeper[0].client_id : null
  )
  storage_client_secret = coalesce(
    var.storage_client_secret,
    var.can_modify_entra ? azuread_application_password.lakekeeper[0].value : null
  )

  # For bootstrap/warehouse sync Lakekeeper API auth:
  # fall back to the managed identity client_id (script detects MI mode when
  # client_secret is absent).
  bootstrap_client_id = coalesce(
    var.bootstrap_client_id,
    azurerm_user_assigned_identity.lakekeeper.client_id
  )
  bootstrap_client_secret = var.bootstrap_client_secret

  # Non-sensitive check for the presence of bootstrap coniguration (useful for
  # conditionally enabling the bootstrap job and related resources). We can't use
  # sensitive values in things like for_each.
  bootstrap_config_present = (
    var.datahub_container_registry_login_server != null &&
    (
      var.bootstrap_client_id != null ||
      var.can_modify_entra
    )
  )

  # Bootstrap is enabled if we have a container registry and some form of auth:
  # 1. Explicit client credentials (bootstrap_client_id + bootstrap_client_secret)
  # 2. Managed identity (can_modify_entra is true, so we can assign the necessary
  #    roles on the MI to authenticate to the Lakekeeper API)
  bootstrap_enabled = (
    var.datahub_container_registry_login_server != null &&
    (
      (var.bootstrap_client_id != null && var.bootstrap_client_secret != null) ||
      var.can_modify_entra
    )
  )

  bootstrap_image = local.bootstrap_enabled ? "${var.datahub_container_registry_login_server}/lakekeeper-scripts:latest" : null
  scripts_dir     = "${path.module}/scripts"
  acr_name        = local.bootstrap_enabled ? split(".", var.datahub_container_registry_login_server)[0] : null
}

# =============================================================================
# Build and Push Lakekeeper Scripts Image
#
# This null_resource builds the lakekeeper-scripts container image using podman
# and pushes it to the Azure Container Registry. The image contains the bootstrap
# and warehouse sync scripts used by the Container App Jobs.

resource "null_resource" "build_scripts_image" {
  count = local.bootstrap_enabled ? 1 : 0

  # Rebuild when any of the scripts or Containerfile change
  triggers = {
    containerfile_hash      = filesha256("${local.scripts_dir}/Containerfile")
    bootstrap_hash          = filesha256("${local.scripts_dir}/bootstrap.sh")
    sync_hash               = filesha256("${local.scripts_dir}/sync_warehouse.sh")
    sync_grants_hash        = filesha256("${local.scripts_dir}/sync_grants.sh")
    sync_grants_fetch_hash  = filesha256("${local.scripts_dir}/sync_grants_fetch_entra.sh")
    sync_grants_assign_hash = filesha256("${local.scripts_dir}/sync_grants_assign_roles.sh")
    acr_server              = var.datahub_container_registry_login_server
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e

      echo "Building lakekeeper-scripts image..."
      podman build -t lakekeeper-scripts:latest -f "${local.scripts_dir}/Containerfile" "${local.scripts_dir}"

      echo "Logging into ACR ${local.acr_name}..."
      ACR_TOKEN=$(az acr login --name ${local.acr_name} --expose-token --output tsv --query accessToken)
      podman login ${var.datahub_container_registry_login_server} --username 00000000-0000-0000-0000-000000000000 --password "$ACR_TOKEN"

      echo "Tagging and pushing image to ${var.datahub_container_registry_login_server}..."
      podman tag lakekeeper-scripts:latest ${var.datahub_container_registry_login_server}/lakekeeper-scripts:latest
      podman push ${var.datahub_container_registry_login_server}/lakekeeper-scripts:latest

      echo "Successfully pushed lakekeeper-scripts:latest to ${var.datahub_container_registry_login_server}"
    EOT
  }
}

resource "azurerm_container_app_job" "bootstrap" {
  count = local.bootstrap_enabled ? 1 : 0

  name                         = "${local.short_base}-boot-caj"
  location                     = var.resource_group_location
  container_app_environment_id = var.datahub_container_app_environment_id
  resource_group_name          = var.resource_group_name
  replica_timeout_in_seconds   = 300
  workload_profile_name        = "Consumption"

  template {
    container {
      name   = "lakekeeper-bootstrap"
      image  = local.bootstrap_image
      cpu    = 0.25
      memory = "0.5Gi"

      command = ["/bin/bash", "/app/bootstrap.sh"]

      env {
        name  = "AZURE_TENANT_ID"
        value = var.tenant_id
      }
      env {
        name  = "LAKEKEEPER_AUTH_CLIENT_ID"
        value = local.bootstrap_client_id
      }
      # Only pass client secret when using client credentials auth;
      # when null, the script falls back to managed identity
      dynamic "env" {
        for_each = var.bootstrap_client_secret != null ? [1] : []
        content {
          name        = "LAKEKEEPER_AUTH_CLIENT_SECRET"
          secret_name = "[SECRET_NAME]"
        }
      }
      env {
        name  = "LAKEKEEPER_APP_ID_URI"
        value = "api://${local.app_registration_client_id}"
      }
      env {
        name  = "LAKEKEEPER_HOST"
        value = var.app_name
      }
    }
  }

  dynamic "secret" {
    for_each = var.bootstrap_client_secret != null ? [1] : []
    content {
      name  = "[SECRET_NAME]"
      value = var.bootstrap_client_secret
    }
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
    azurerm_container_app.lakekeeper,
    null_resource.build_scripts_image
  ]
}

# Trigger the bootstrap job when the Lakekeeper app is deployed
resource "null_resource" "bootstrap_trigger" {
  count = local.bootstrap_enabled ? 1 : 0

  # Trigger when the Lakekeeper app, bootstrap job, or database changes
  triggers = {
    lakekeeper_app_id = azurerm_container_app.lakekeeper[0].id
    lakekeeper_db_id  = azurerm_postgresql_flexible_server_database.lakekeeper[0].id
    bootstrap_job_id  = azurerm_container_app_job.bootstrap[0].id
    bootstrap_image   = local.bootstrap_image
    scripts_image_id  = null_resource.build_scripts_image[0].id
  }

  # Execute the bootstrap job when triggered
  provisioner "local-exec" {
    command = <<-EOT
      # Wait for Lakekeeper to be ready
      echo "Waiting for Lakekeeper to be ready..."
      sleep 30

      az containerapp job start \
        --name ${azurerm_container_app_job.bootstrap[0].name} \
        --resource-group ${var.resource_group_name}
    EOT
  }

  depends_on = [
    azurerm_container_app_job.bootstrap,
    azurerm_container_app.lakekeeper
  ]
}

# =============================================================================
# Warehouse Sync Job
#
# This job creates or updates warehouses in Lakekeeper with ADLS Gen2 storage.
# One job per warehouse - Azure Container Apps Jobs don't support runtime env
# var overrides without replacing the entire container config, so we bake the
# warehouse config into each job definition.

locals {
  # Define the warehouses to create/sync.
  # Each warehouse has a name, short_name, and filesystem (container) in the
  # storage account.
  #
  # NOTE: Container App Job names have a 32-character limit. The job name format
  # is: ${local.short_base}-${short_name}-sync-caj
  # With short_base = "[project]-[env1]-lakekeeper" (18 chars) + "-" + "-sync-caj" (9 chars),
  # that leaves only 4 characters for short_name. Keep short_name to 4 chars or less.
  warehouses = {
    datahub = {
      name       = "datahub"
      short_name = "dh"
      filesystem = "iceberg"
    }
  }

  # Non-sensitive check for for_each (can't use sensitive values in for_each).
  # Like bootstrap, storage auth can use explicit credentials or managed identity.
  warehouse_config_present = (
    var.datahub_lake_storage_account_name != null &&
    local.bootstrap_config_present &&
    (
      (var.storage_client_id != null) ||
      var.can_modify_entra
    )
  )

  # Full check including sensitive values (for count-based resources).
  # Warehouse is enabled if config is present and we have storage credentials
  # (either explicitly provided or auto-generated from the app registration).
  warehouse_enabled = (
    local.warehouse_config_present &&
    local.bootstrap_enabled &&
    local.storage_client_secret != null
  )
}

# =============================================================================
# Storage Containers (Filesystems) for Warehouses
#
# Each warehouse needs a dedicated filesystem (container) in the ADLS Gen2
# storage account. These are created before the warehouse sync job runs.

resource "azurerm_storage_container" "warehouse_filesystem" {
  for_each = local.warehouses

  name                  = each.value.filesystem
  storage_account_id    = var.datahub_lake_storage_account_id
  container_access_type = "private"

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_container_app_job" "warehouse_sync" {
  for_each = local.warehouse_config_present ? local.warehouses : {}

  name                         = "${local.short_base}-${each.value.short_name}-sync-caj"
  location                     = var.resource_group_location
  container_app_environment_id = var.datahub_container_app_environment_id
  resource_group_name          = var.resource_group_name
  replica_timeout_in_seconds   = 300
  workload_profile_name        = "Consumption"

  template {
    container {
      name   = "lakekeeper-warehouse-sync"
      image  = local.bootstrap_image
      cpu    = 0.25
      memory = "0.5Gi"

      command = ["/bin/bash", "/app/sync_warehouse.sh"]

      # Lakekeeper API authentication
      env {
        name  = "AZURE_TENANT_ID"
        value = var.tenant_id
      }
      env {
        name  = "LAKEKEEPER_AUTH_CLIENT_ID"
        value = local.bootstrap_client_id
      }
      # Only pass client secret when using client credentials auth;
      # when null, the script falls back to managed identity
      dynamic "env" {
        for_each = var.bootstrap_client_secret != null ? [1] : []
        content {
          name        = "LAKEKEEPER_AUTH_CLIENT_SECRET"
          secret_name = "[SECRET_NAME]"
        }
      }
      env {
        name  = "LAKEKEEPER_APP_ID_URI"
        value = "api://${local.app_registration_client_id}"
      }
      env {
        name  = "LAKEKEEPER_HOST"
        value = var.app_name
      }

      # Storage configuration
      env {
        name  = "STORAGE_AUTH_CLIENT_ID"
        value = local.storage_client_id
      }
      # Storage secret is provided from either explicit vars or auto-generated
      # app registration credentials (see local.storage_client_secret)
      dynamic "env" {
        for_each = local.storage_client_secret != null ? [1] : []
        content {
          name        = "STORAGE_AUTH_CLIENT_SECRET"
          secret_name = "[SECRET_NAME]"
        }
      }
      env {
        name  = "STORAGE_ACCOUNT_NAME"
        value = var.datahub_lake_storage_account_name
      }

      # Warehouse-specific config (baked into the job)
      env {
        name  = "WAREHOUSE_NAME"
        value = each.value.name
      }
      env {
        name  = "STORAGE_FILESYSTEM_NAME"
        value = each.value.filesystem
      }
    }
  }

  dynamic "secret" {
    for_each = var.bootstrap_client_secret != null ? [1] : []
    content {
      name  = "[SECRET_NAME]"
      value = var.bootstrap_client_secret
    }
  }

  dynamic "secret" {
    for_each = local.storage_client_secret != null ? [1] : []
    content {
      name  = "[SECRET_NAME]"
      value = local.storage_client_secret
    }
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
    azurerm_container_app_job.bootstrap,
    postgresql_grant.lakekeeper_database,
    postgresql_grant.lakekeeper_schema,
    null_resource.bootstrap_trigger
  ]
}

# Trigger the warehouse sync job for each warehouse after bootstrap completes
resource "null_resource" "warehouse_sync_trigger" {
  for_each = local.warehouse_config_present ? local.warehouses : {}

  # Trigger when configuration changes
  triggers = {
    bootstrap_trigger_id = null_resource.bootstrap_trigger[0].id
    warehouse_job_id     = azurerm_container_app_job.warehouse_sync[each.key].id
    warehouse_name       = each.value.name
    filesystem           = each.value.filesystem
    storage_account      = var.datahub_lake_storage_account_name
  }

  # Start the warehouse-specific sync job
  provisioner "local-exec" {
    command = <<-EOT
      echo "Syncing warehouse '${each.value.name}' with filesystem '${each.value.filesystem}'..."
      sleep 5

      az containerapp job start \
        --name ${azurerm_container_app_job.warehouse_sync[each.key].name} \
        --resource-group ${var.resource_group_name}
    EOT
  }

  depends_on = [
    azurerm_container_app_job.warehouse_sync,
    azurerm_storage_container.warehouse_filesystem,
    null_resource.bootstrap_trigger
  ]
}

# =============================================================================
# Grants Sync Job
#
# Applies permission assignments (server admin, etc.) in Lakekeeper via the
# management API. Reads a grants configuration passed as JSON and resolves
# user emails to Lakekeeper user IDs at runtime.

locals {
  # Roles: map Entra groups to Lakekeeper roles with permission assignments.
  # Roles with null group_id are filtered out (e.g., when the group doesn't
  # exist because can_modify_entra is false in the common module).
  roles = {
    for name, config in {
      "users" = {
        group_id = var.datahub_users_group_id
        permissions = {
          project = ["describe", "select"]
        }
      }
      "developers" = {
        group_id = var.datahub_developers_group_id
        permissions = {
          server = ["admin", "operator"]
        }
      }
    } : name => config if config.group_id != null
  }

  roles_json = jsonencode(local.roles)

  # Build app SP grants JSON: project-level grants grouped by role.
  # e.g. { "project": { "data_admin": ["oidc~abc123", "oidc~def456"] } }
  app_sp_project_roles = {
    for role in distinct(values(var.app_sp_grants)) :
    role => [for sp_id, sp_role in var.app_sp_grants : "oidc~${sp_id}" if sp_role == role]
  }

  app_sp_grants_json = length(var.app_sp_grants) > 0 ? jsonencode({
    project = local.app_sp_project_roles
  }) : "{}"

  grants_enabled = (
    (length(local.roles) > 0 || length(var.app_sp_grants) > 0) &&
    local.bootstrap_enabled
  )
}

resource "azurerm_container_app_job" "grants_sync" {
  count = local.grants_enabled ? 1 : 0

  name                         = "${local.short_base}-grants-caj"
  location                     = var.resource_group_location
  container_app_environment_id = var.datahub_container_app_environment_id
  resource_group_name          = var.resource_group_name
  replica_timeout_in_seconds   = 300
  workload_profile_name        = "Consumption"

  template {
    container {
      name   = "lakekeeper-grants-sync"
      image  = local.bootstrap_image
      cpu    = 0.25
      memory = "0.5Gi"

      command = ["/bin/bash", "/app/sync_grants.sh"]

      # Lakekeeper API authentication
      env {
        name  = "AZURE_TENANT_ID"
        value = var.tenant_id
      }
      env {
        name  = "LAKEKEEPER_AUTH_CLIENT_ID"
        value = local.bootstrap_client_id
      }
      dynamic "env" {
        for_each = var.bootstrap_client_secret != null ? [1] : []
        content {
          name        = "LAKEKEEPER_AUTH_CLIENT_SECRET"
          secret_name = "[SECRET_NAME]"
        }
      }
      env {
        name  = "LAKEKEEPER_APP_ID_URI"
        value = "api://${local.app_registration_client_id}"
      }
      env {
        name  = "LAKEKEEPER_HOST"
        value = "${var.app_name}.internal.${var.cae_dns_suffix}"
      }

      # Managed identity client ID for MI token requests (needed when
      # the container has a user-assigned MI, to disambiguate which identity)
      env {
        name  = "AZURE_MI_CLIENT_ID"
        value = local.effective_workload_identity_client_id
      }

      # Key Vault for storing/reading Entra group membership data
      env {
        name  = "KEY_VAULT_NAME"
        value = var.datahub_key_vault_name
      }

      # Roles configuration (Entra group -> Lakekeeper role sync)
      env {
        name  = "ROLES_JSON"
        value = local.roles_json
      }

      # App SP grants configuration
      env {
        name  = "APP_SP_GRANTS_JSON"
        value = local.app_sp_grants_json
      }

      # Graph API credentials for reading Entra group membership
      env {
        name  = "GRAPH_CLIENT_ID"
        value = local.app_registration_client_id
      }
      dynamic "env" {
        for_each = local.app_registration_client_secret != null ? [1] : []
        content {
          name        = "GRAPH_CLIENT_SECRET"
          secret_name = "[SECRET_NAME]"
        }
      }
    }
  }

  dynamic "secret" {
    for_each = var.bootstrap_client_secret != null ? [1] : []
    content {
      name  = "[SECRET_NAME]"
      value = var.bootstrap_client_secret
    }
  }

  dynamic "secret" {
    for_each = local.app_registration_client_secret != null ? [1] : []
    content {
      name  = "[SECRET_NAME]"
      value = local.app_registration_client_secret
    }
  }

  registry {
    server   = var.datahub_container_registry_login_server
    identity = local.effective_workload_identity_id
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [local.effective_workload_identity_id]
  }

  schedule_trigger_config {
    cron_expression          = "* * * * *"
    parallelism              = 1
    replica_completion_count = 1
  }

  depends_on = [
    azurerm_container_app.lakekeeper,
    null_resource.build_scripts_image,
    null_resource.bootstrap_trigger
  ]
}

# Trigger the grants sync job when grants configuration or bootstrap changes
resource "null_resource" "grants_sync_trigger" {
  count = local.grants_enabled ? 1 : 0

  triggers = {
    roles_json           = local.roles_json
    app_sp_grants_json   = local.app_sp_grants_json
    bootstrap_trigger_id = null_resource.bootstrap_trigger[0].id
    grants_job_id        = azurerm_container_app_job.grants_sync[0].id
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Syncing Lakekeeper grants..."
      sleep 5

      az containerapp job start \
        --name ${azurerm_container_app_job.grants_sync[0].name} \
        --resource-group ${var.resource_group_name}
    EOT
  }

  depends_on = [
    azurerm_container_app_job.grants_sync,
    null_resource.bootstrap_trigger
  ]
}