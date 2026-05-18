# =============================================================================
# PyIceberg Test Container App Job
#
# A troubleshooting job that tests PyIceberg connectivity to Lakekeeper and
# attempts to create a table, mimicking the behavior of the Dagster pipeline's
# IcebergClient.
#
# This job is useful for:
# - Verifying OAuth2 authentication to Lakekeeper works
# - Testing table creation (to reproduce 412 Precondition Failed errors)
# - Debugging PyIceberg connectivity issues from within the CAE
# =============================================================================

locals {
  job_name     = "${var.sys_short}-${var.env_short}-pyice-test-caj"
  test_schema  = "pyiceberg_test"
  test_table   = "write_test"
}

resource "azurerm_container_app_job" "pyiceberg_test" {
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
      name   = "pyiceberg-test"
      image  = "python:${var.python_image_tag}"
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "LAKEKEEPER_URL"
        value = var.lakekeeper_url
      }

      env {
        name  = "LAKEKEEPER_WAREHOUSE"
        value = var.lakekeeper_warehouse
      }

      env {
        name  = "AZURE_TENANT_ID"
        value = var.tenant_id
      }

      env {
        name  = "LAKEKEEPER_CLIENT_ID"
        value = var.lakekeeper_client_id
      }

      env {
        name        = "LAKEKEEPER_CLIENT_SECRET"
        secret_name = "[SECRET_NAME]"
      }

      env {
        name  = "LAKEKEEPER_OAUTH_SCOPE"
        value = var.lakekeeper_oauth_scope
      }

      env {
        name  = "TEST_SCHEMA"
        value = local.test_schema
      }

      env {
        name  = "TEST_TABLE"
        value = local.test_table
      }

      command = ["/bin/bash", "-c"]
      args = [
        <<-EOT
        echo "========================================"
        echo "PYICEBERG CONNECTIVITY TEST"
        echo "========================================"
        echo ""
        echo "Date: $(date)"
        echo "Hostname: $(hostname)"
        echo ""

        echo "--- Installing PyIceberg ---"
        pip install --quiet pyiceberg[adlfs] pyarrow requests pandas
        echo "Installation complete"
        echo ""

        echo "--- Environment ---"
        echo "LAKEKEEPER_URL: $LAKEKEEPER_URL"
        echo "LAKEKEEPER_WAREHOUSE: $LAKEKEEPER_WAREHOUSE"
        echo "LAKEKEEPER_CLIENT_ID: $LAKEKEEPER_CLIENT_ID"
        echo "LAKEKEEPER_OAUTH_SCOPE: $LAKEKEEPER_OAUTH_SCOPE"
        echo ""

        echo "--- Running PyIceberg Test ---"
        python3 << 'PYTHON_EOF'
import os
import sys
import traceback

# Configuration from environment
LAKEKEEPER_URL = os.environ.get("LAKEKEEPER_URL")
LAKEKEEPER_WAREHOUSE = os.environ.get("LAKEKEEPER_WAREHOUSE")
TENANT_ID = os.environ.get("AZURE_TENANT_ID")
CLIENT_ID = os.environ.get("LAKEKEEPER_CLIENT_ID")
CLIENT_SECRET = os.environ.get("LAKEKEEPER_CLIENT_SECRET")
OAUTH_SCOPE = os.environ.get("LAKEKEEPER_OAUTH_SCOPE")
TEST_SCHEMA = os.environ.get("TEST_SCHEMA", "pyiceberg_test")
TEST_TABLE = os.environ.get("TEST_TABLE", "write_test")

print("="*40)
print("STEP 1: Load Catalog")
print("="*40)

try:
    from pyiceberg.catalog import load_catalog
    import pyarrow as pa

    catalog = load_catalog(
        "lakekeeper",
        **{
            "type": "rest",
            "uri": f"{LAKEKEEPER_URL}/catalog",
            "credential": f"{CLIENT_ID}:{CLIENT_SECRET}",
            "oauth2-server-uri": f"https://login.microsoftonline.com/{TENANT_ID}/oauth2/v2.0/token",
            "scope": OAUTH_SCOPE,
            "warehouse": LAKEKEEPER_WAREHOUSE,
        },
    )
    print(f"SUCCESS: Connected to catalog at {LAKEKEEPER_URL}")
    print("")
except Exception as e:
    print(f"FAILED: Could not connect to catalog")
    print(f"Error: {e}")
    traceback.print_exc()
    sys.exit(1)

print("="*40)
print("STEP 2: List Namespaces")
print("="*40)

try:
    namespaces = catalog.list_namespaces()
    print(f"SUCCESS: Found {len(namespaces)} namespaces")
    for ns in namespaces:
        print(f"  - {ns}")
    print("")
except Exception as e:
    print(f"FAILED: Could not list namespaces")
    print(f"Error: {e}")
    traceback.print_exc()

print("="*40)
print("STEP 3: Create Test Namespace")
print("="*40)

try:
    catalog.create_namespace(TEST_SCHEMA)
    print(f"SUCCESS: Created namespace '{TEST_SCHEMA}'")
except Exception as e:
    if "already exists" in str(e).lower() or "AlreadyExistsError" in str(type(e).__name__):
        print(f"OK: Namespace '{TEST_SCHEMA}' already exists")
    else:
        print(f"FAILED: Could not create namespace")
        print(f"Error: {e}")
        traceback.print_exc()
print("")

print("="*40)
print("STEP 4: Create Test Table")
print("="*40)

table_id = f"{TEST_SCHEMA}.{TEST_TABLE}"
schema = pa.schema([
    pa.field("id", pa.int32()),
    pa.field("name", pa.string()),
])

try:
    # First try to load existing table
    try:
        table = catalog.load_table(table_id)
        print(f"OK: Table '{table_id}' already exists")
    except Exception:
        # Table doesn't exist, create it
        print(f"Creating table '{table_id}'...")
        table = catalog.create_table(
            identifier=table_id,
            schema=schema,
            properties={
                "write.format.default": "parquet",
            },
        )
        print(f"SUCCESS: Created table '{table_id}'")
except Exception as e:
    print(f"FAILED: Could not create table")
    print(f"Error type: {type(e).__name__}")
    print(f"Error: {e}")
    traceback.print_exc()
    # Don't exit - continue to try other operations
print("")

print("="*40)
print("STEP 5: Write Test Data")
print("="*40)

try:
    table = catalog.load_table(table_id)
    test_data = pa.table({
        "id": pa.array([1, 2, 3], type=pa.int32()),
        "name": ["alice", "bob", "charlie"],
    })
    table.append(test_data)
    print(f"SUCCESS: Wrote {len(test_data)} rows to '{table_id}'")
except Exception as e:
    print(f"FAILED: Could not write data")
    print(f"Error type: {type(e).__name__}")
    print(f"Error: {e}")
    traceback.print_exc()
print("")

print("="*40)
print("STEP 6: Read Test Data")
print("="*40)

try:
    table = catalog.load_table(table_id)
    scan = table.scan()
    result = scan.to_arrow()
    print(f"SUCCESS: Read {len(result)} rows from '{table_id}'")
    print(result.to_pandas())
except Exception as e:
    print(f"FAILED: Could not read data")
    print(f"Error type: {type(e).__name__}")
    print(f"Error: {e}")
    traceback.print_exc()
print("")

print("="*40)
print("STEP 7: Cleanup (optional)")
print("="*40)
print("Skipping cleanup - table will persist for inspection")
print("")

print("="*40)
print("DONE")
print("="*40)
PYTHON_EOF

        echo ""
        echo "========================================"
        echo "TEST COMPLETE"
        echo "========================================"
        EOT
      ]
    }
  }

  secret {
    name  = "[SECRET_NAME]"
    value = var.lakekeeper_client_secret
  }

  tags = var.tags
}