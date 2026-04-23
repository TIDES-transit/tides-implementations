# =============================================================================
# METABASE CONTAINER APP
# =============================================================================

locals {
  metabase_env_vars = {
    "MB_DB_TYPE"   = "postgres"
    "MB_DB_DBNAME" = var.has_db_registration ? azurerm_postgresql_flexible_server_database.metabase[0].name : ""
    "MB_DB_PORT"   = "5432"
    "MB_DB_USER"   = "metabase_user"
    "MB_DB_HOST"   = var.datahub_postgresql_flexible_server_fqdn
    "MB_SITE_URL"  = "https://metabase.${var.cae_dns_suffix}"
  }
}

resource "azurerm_postgresql_flexible_server_database" "metabase" {
  count = var.has_db_registration ? 1 : 0

  name      = "metabase"
  server_id = var.datahub_postgresql_flexible_server_id

  # Under normal circumstances, you wouldn't want to destroy this database on
  # accident, so protect it from happening with this TF lifecycle rule. We can
  # comment out the rule if we actually intend to replace or destroy the
  # database.
  lifecycle {
    prevent_destroy = true
  }
}

# Generate random password for Metabase PostgreSQL user
resource "random_password" "metabase_postgres_password" {
  length  = 32
  special = true
}

# Store Metabase PostgreSQL user password in Key Vault
resource "azurerm_key_vault_secret" "metabase_postgres_password" {
  name         = "[SECRET_NAME]"
  value        = random_password.metabase_postgres_password.result
  key_vault_id = var.datahub_key_vault_id
}

# Create PostgreSQL role/user for Metabase
resource "postgresql_role" "metabase_user" {
  count = var.has_db_registration ? 1 : 0

  name     = local.metabase_env_vars["MB_DB_USER"]
  login    = true
  password = random_password.metabase_postgres_password.result

  depends_on = [
    azurerm_postgresql_flexible_server_database.metabase
  ]
}

# Grant database-level permissions to Metabase user
resource "postgresql_grant" "metabase_database" {
  count = var.has_db_registration ? 1 : 0

  database    = azurerm_postgresql_flexible_server_database.metabase[0].name
  role        = postgresql_role.metabase_user[0].name
  object_type = "database"
  privileges  = ["CONNECT", "CREATE"]

  depends_on = [
    postgresql_role.metabase_user
  ]
}

# Grant schema-level permissions to Metabase user
resource "postgresql_grant" "metabase_schema" {
  count = var.has_db_registration ? 1 : 0

  database    = azurerm_postgresql_flexible_server_database.metabase[0].name
  role        = postgresql_role.metabase_user[0].name
  schema      = "public"
  object_type = "schema"
  privileges  = ["USAGE", "CREATE"]

  depends_on = [
    postgresql_role.metabase_user
  ]
}

resource "azurerm_container_app" "metabase" {
  count = var.has_entra ? 1 : 0

  name                         = var.app_name
  container_app_environment_id = var.datahub_container_app_environment_id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"
  workload_profile_name        = var.workload_profile_name

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.metabase.id]
  }

  secret {
    name                = "[SECRET_NAME]"
    identity            = azurerm_user_assigned_identity.metabase.id
    key_vault_secret_id = [KEY_VAULT_SECRET_REF]
  }

  template {
    min_replicas = 1
    max_replicas = 1

    container {
      name   = "metabase"
      image  = "metabase/metabase:${var.metabase_image_tag}"
      cpu    = 2.0
      memory = "4Gi"

      # Static environment variables
      dynamic "env" {
        for_each = local.metabase_env_vars
        content {
          name  = env.key
          value = env.value
        }
      }

      # Secret environment variables
      env {
        name        = "MB_DB_PASS"
        secret_name = "[SECRET_NAME]"
      }

      liveness_probe {
        transport = "HTTP"
        port      = 3000
        path      = "/"
      }

      readiness_probe {
        transport = "HTTP"
        port      = 3000
        path      = "/"
      }
    }
  }

  ingress {
    allow_insecure_connections = false
    external_enabled           = true
    target_port                = 3000

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  tags = {
    Department  = "[DEPARTMENT]"
    Environment = var.environment_name
    Owner       = "[TEAM]"
    Purpose     = "Metabase business intelligence application"
  }
}