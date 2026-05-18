# =============================================================================
# Database

resource "azurerm_postgresql_flexible_server_database" "openfga" {
  count = var.has_db_registration ? 1 : 0

  name      = "openfga"
  server_id = var.datahub_postgresql_flexible_server_id

  lifecycle {
    prevent_destroy = true
  }
}

# Generate random password for OpenFGA PostgreSQL user
resource "random_password" "openfga_postgres_password" {
  length  = 32
  special = true
}

# Store OpenFGA PostgreSQL user password in Key Vault
resource "azurerm_key_vault_secret" "openfga_postgres_password" {
  name         = "[SECRET_NAME]"
  value        = random_password.openfga_postgres_password.result
  key_vault_id = var.datahub_key_vault_id
}

# Create PostgreSQL role/user for OpenFGA
resource "postgresql_role" "openfga_user" {
  count = var.has_db_registration ? 1 : 0

  name     = var.postgresql_username
  login    = true
  password = random_password.openfga_postgres_password.result

  depends_on = [
    azurerm_postgresql_flexible_server_database.openfga
  ]
}

# Grant database-level permissions to OpenFGA user
resource "postgresql_grant" "openfga_database" {
  count = var.has_db_registration ? 1 : 0

  database    = azurerm_postgresql_flexible_server_database.openfga[0].name
  role        = postgresql_role.openfga_user[0].name
  object_type = "database"
  privileges  = ["CONNECT", "CREATE"]

  depends_on = [
    postgresql_role.openfga_user
  ]
}

# Grant schema-level permissions to OpenFGA user
resource "postgresql_grant" "openfga_schema" {
  count = var.has_db_registration ? 1 : 0

  database    = azurerm_postgresql_flexible_server_database.openfga[0].name
  role        = postgresql_role.openfga_user[0].name
  schema      = "public"
  object_type = "schema"
  privileges  = ["USAGE", "CREATE"]

  depends_on = [
    postgresql_role.openfga_user
  ]
}

# =============================================================================
# Preshared Key for OpenFGA API Authentication

resource "random_password" "openfga_preshared_key" {
  length  = 40
  special = false
  upper   = true
  lower   = true
  numeric = true
}

resource "azurerm_key_vault_secret" "openfga_preshared_key" {
  name         = "[SECRET_NAME]"
  value        = random_password.openfga_preshared_key.result
  key_vault_id = var.datahub_key_vault_id
}

# =============================================================================
# Migration Job

locals {
  base_name  = trimsuffix(var.app_name, "-ca")
  short_base = "${var.sys_short}-${var.env_short}-openfga"

  openfga_db_uri = "postgres://${var.postgresql_username}:${urlencode(random_password.openfga_postgres_password.result)}@${var.datahub_postgresql_flexible_server_fqdn}:5432/${azurerm_postgresql_flexible_server_database.openfga[0].name}?sslmode=require"
}

resource "azurerm_container_app_job" "migration" {
  name                         = "${local.short_base}-migr-caj"
  location                     = var.resource_group_location
  container_app_environment_id = var.datahub_container_app_environment_id
  resource_group_name          = var.resource_group_name
  replica_timeout_in_seconds   = 3600
  workload_profile_name        = "Consumption"

  depends_on = [
    postgresql_role.openfga_user,
    postgresql_grant.openfga_database,
    postgresql_grant.openfga_schema,
  ]

  template {
    container {
      name   = "openfga-migration"
      image  = "openfga/openfga:${var.openfga_image_tag}"
      cpu    = 1.0
      memory = "2Gi"

      args = ["migrate"]

      env {
        name  = "OPENFGA_DATASTORE_ENGINE"
        value = "postgres"
      }
      env {
        name        = "OPENFGA_DATASTORE_URI"
        secret_name = "openfga-db-uri"
      }
    }
  }

  secret {
    name  = "openfga-db-uri"
    value = local.openfga_db_uri
  }

  manual_trigger_config {
    parallelism = 1
  }
}

# =============================================================================
# Migration Job Trigger

resource "null_resource" "migration_trigger" {
  triggers = {
    migration_job_id = azurerm_container_app_job.migration.id
  }

  provisioner "local-exec" {
    command = <<-EOT
      az containerapp job start \
        --name ${azurerm_container_app_job.migration.name} \
        --resource-group ${var.resource_group_name}
    EOT
  }

  depends_on = [
    azurerm_container_app_job.migration
  ]
}