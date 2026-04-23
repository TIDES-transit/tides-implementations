# =============================================================================
# Trino Test Container App Job
#
# A troubleshooting job that tests Trino connectivity, catalog access, and
# Iceberg write operations from within the Container Apps environment using
# the official Trino CLI.
#
# This job is useful for verifying that:
# - Trino coordinator is accessible from within the CAE
# - Password authentication works
# - Lakekeeper catalog connection is functioning
# - Iceberg table creation and data writes work (tests ADLS permissions)
#
# The write test creates a temporary schema and table, inserts test data,
# verifies the data can be read back, and cleans up after itself.
# =============================================================================

locals {
  job_name = "${var.sys_short}-${var.env_short}-trino-test-caj"
}

resource "azurerm_container_app_job" "trino_test" {
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
      name   = "trino-test"
      image  = "trinodb/trino:${var.trino_image_tag}"
      cpu    = 0.5
      memory = "1Gi"

      command = ["/bin/bash", "-c"]
      args = [
        <<-EOT
        sleep 3
        echo "========================================"
        echo "Trino CLI Connectivity Test"
        echo "========================================"
        echo ""
        echo "--- Configuration ---"
        echo "Server: ${var.trino_url}"
        echo "User: $TRINO_USER"
        echo "Catalog: ${var.trino_catalog}"
        echo ""
        echo "--- Trino CLI Version ---"
        /usr/bin/trino --version
        echo ""
        echo "--- Query Test: SHOW CATALOGS ---"
        /usr/bin/trino \
          --server "${var.trino_url}" \
          --user "$TRINO_USER" \
          --password \
          --execute "SHOW CATALOGS"
        SHOW_CATALOGS_EXIT=$?
        echo "Exit code: $SHOW_CATALOGS_EXIT"
        echo ""
        echo "--- Query Test: SHOW SCHEMAS FROM ${var.trino_catalog} ---"
        echo "(This tests the Lakekeeper connection)"
        /usr/bin/trino \
          --server "${var.trino_url}" \
          --user "$TRINO_USER" \
          --password \
          --catalog "${var.trino_catalog}" \
          --execute "SHOW SCHEMAS"
        SHOW_SCHEMAS_EXIT=$?
        echo "Exit code: $SHOW_SCHEMAS_EXIT"
        echo ""
        echo "--- Query Test: SELECT 1 ---"
        /usr/bin/trino \
          --server "${var.trino_url}" \
          --user "$TRINO_USER" \
          --password \
          --execute "SELECT 1 AS test"
        SELECT_EXIT=$?
        echo "Exit code: $SELECT_EXIT"
        echo ""
        echo "--- Write Test: Create Schema ---"
        TEST_SCHEMA="${local.job_name}"
        TEST_TABLE="write_test"
        echo "Creating schema: ${var.trino_catalog}.\"$TEST_SCHEMA\""
        /usr/bin/trino \
          --server "${var.trino_url}" \
          --user "$TRINO_USER" \
          --password \
          --catalog "${var.trino_catalog}" \
          --execute "CREATE SCHEMA IF NOT EXISTS \"$TEST_SCHEMA\""
        CREATE_SCHEMA_EXIT=$?
        echo "Exit code: $CREATE_SCHEMA_EXIT"
        echo ""
        echo "--- Write Test: Create Table ---"
        echo "Creating table: ${var.trino_catalog}.\"$TEST_SCHEMA\".\"$TEST_TABLE\""
        /usr/bin/trino \
          --server "${var.trino_url}" \
          --user "$TRINO_USER" \
          --password \
          --catalog "${var.trino_catalog}" \
          --schema "$TEST_SCHEMA" \
          --execute "CREATE TABLE IF NOT EXISTS \"$TEST_TABLE\" (rownum INTEGER, value VARCHAR)"
        CREATE_TABLE_EXIT=$?
        echo "Exit code: $CREATE_TABLE_EXIT"
        echo ""
        echo "--- Write Test: Insert Rows ---"
        /usr/bin/trino \
          --server "${var.trino_url}" \
          --user "$TRINO_USER" \
          --password \
          --catalog "${var.trino_catalog}" \
          --schema "$TEST_SCHEMA" \
          --execute "INSERT INTO \"$TEST_TABLE\" VALUES (1, 'foo'), (2, 'bar')"
        INSERT_EXIT=$?
        echo "Exit code: $INSERT_EXIT"
        echo ""
        echo "--- Write Test: Verify Data ---"
        /usr/bin/trino \
          --server "${var.trino_url}" \
          --user "$TRINO_USER" \
          --password \
          --catalog "${var.trino_catalog}" \
          --schema "$TEST_SCHEMA" \
          --execute "SELECT * FROM \"$TEST_TABLE\" ORDER BY rownum"
        SELECT_DATA_EXIT=$?
        echo "Exit code: $SELECT_DATA_EXIT"
        echo ""
        echo "--- Write Test: Cleanup ---"
        echo "Dropping table and schema..."
        /usr/bin/trino \
          --server "${var.trino_url}" \
          --user "$TRINO_USER" \
          --password \
          --catalog "${var.trino_catalog}" \
          --schema "$TEST_SCHEMA" \
          --execute "DROP TABLE IF EXISTS \"$TEST_TABLE\""
        /usr/bin/trino \
          --server "${var.trino_url}" \
          --user "$TRINO_USER" \
          --password \
          --catalog "${var.trino_catalog}" \
          --execute "DROP SCHEMA IF EXISTS \"$TEST_SCHEMA\""
        echo "Cleanup complete"
        echo ""
        echo "========================================"
        echo "SUMMARY"
        echo "========================================"
        echo "SHOW CATALOGS:  $([ $SHOW_CATALOGS_EXIT -eq 0 ] && echo 'PASS' || echo 'FAIL')"
        echo "SHOW SCHEMAS:   $([ $SHOW_SCHEMAS_EXIT -eq 0 ] && echo 'PASS' || echo 'FAIL')"
        echo "SELECT 1:       $([ $SELECT_EXIT -eq 0 ] && echo 'PASS' || echo 'FAIL')"
        echo "CREATE SCHEMA:  $([ $CREATE_SCHEMA_EXIT -eq 0 ] && echo 'PASS' || echo 'FAIL')"
        echo "CREATE TABLE:   $([ $CREATE_TABLE_EXIT -eq 0 ] && echo 'PASS' || echo 'FAIL')"
        echo "INSERT ROWS:    $([ $INSERT_EXIT -eq 0 ] && echo 'PASS' || echo 'FAIL')"
        echo "SELECT DATA:    $([ $SELECT_DATA_EXIT -eq 0 ] && echo 'PASS' || echo 'FAIL')"
        echo "========================================"
        EOT
      ]

      env {
        name  = "TRINO_USER"
        value = var.trino_user
      }

      env {
        name        = "TRINO_PASSWORD"
        secret_name = "[SECRET_NAME]"
      }
    }
  }

  secret {
    name  = "[SECRET_NAME]"
    value = var.trino_password
  }

  tags = var.tags
}