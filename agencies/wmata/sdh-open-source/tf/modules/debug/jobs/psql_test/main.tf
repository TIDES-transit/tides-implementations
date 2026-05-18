# =============================================================================
# PostgreSQL Test Container App Job
#
# A troubleshooting job that runs a PostgreSQL client container for testing
# database connectivity from within the Container Apps environment.
#
# This job is useful for verifying that Container Apps can connect to the
# PostgreSQL server via private endpoints, testing credentials, and debugging
# database connectivity issues.
# =============================================================================

locals {
  job_name = "${var.sys_short}-${var.env_short}-psql-test-caj"
}

resource "azurerm_container_app_job" "psql_test" {
  name                         = local.job_name
  location                     = var.resource_group_location
  container_app_environment_id = var.datahub_container_app_environment_id
  resource_group_name          = var.resource_group_name

  replica_timeout_in_seconds = 300
  replica_retry_limit        = 0
  workload_profile_name      = "Consumption"

  manual_trigger_config {
    parallelism              = 1
    replica_completion_count = 1
  }

  template {
    container {
      name   = "psql-test"
      image  = "postgres:${var.postgres_image_tag}"
      cpu    = 0.25
      memory = "0.5Gi"

      command = ["/bin/sh", "-c"]
      args = [
        <<-EOT
        sleep 3
        echo "========================================"
        echo "PostgreSQL Connectivity Test"
        echo "========================================"
        echo ""
        echo "--- DNS Resolution ---"
        echo "Host: ${var.postgresql_host}"
        getent hosts ${var.postgresql_host}
        echo ""
        echo "--- pg_isready Test ---"
        pg_isready -h ${var.postgresql_host} -p ${var.postgresql_port} -t 10 2>&1
        echo ""
        echo "--- Connection Test (no credentials) ---"
        echo "Attempting to connect with psql (will fail without valid credentials)..."
        PGCONNECT_TIMEOUT=10 psql "host=${var.postgresql_host} port=${var.postgresql_port} dbname=postgres user=testuser sslmode=require" -c "SELECT 1;" 2>&1 || echo "(Expected failure - no valid credentials provided)"
        echo ""
        echo "========================================"
        echo "DONE"
        echo "========================================"
        EOT
      ]
    }
  }

  tags = var.tags
}
