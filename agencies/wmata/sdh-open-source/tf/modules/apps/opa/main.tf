# =============================================================================
# Storage for OPA policies (following openmetadata/main.tf pattern)

resource "azurerm_storage_account" "opa_storage" {
  name                     = "${var.sys_short}${var.env_short}opastrg01"
  resource_group_name      = var.resource_group_name
  location                 = var.resource_group_location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_share" "opa_policies" {
  name               = "opa-policies"
  storage_account_id = azurerm_storage_account.opa_storage.id
  quota              = 1 # 1 GB - policies are tiny
}

resource "azurerm_container_app_environment_storage" "opa_policies" {
  name                         = "opa-policies"
  container_app_environment_id = var.datahub_container_app_environment_id
  account_name                 = azurerm_storage_account.opa_storage.name
  access_key                   = azurerm_storage_account.opa_storage.primary_access_key
  share_name                   = azurerm_storage_share.opa_policies.name
  access_mode                  = "ReadOnly"
}

# =============================================================================
# Upload policy files

# Download OPA policies from Lakekeeper GitHub and upload to file share.
# The policies are at authz/opa-bridge/policies/ in the Lakekeeper repo and
# include multiple .rego files in a directory structure:
#   configuration.rego
#   trino/    (main.rego, user.rego, check.rego, allow_*.rego)
#   lakekeeper/ (authentication.rego, check.rego, identifiers.rego)
resource "null_resource" "upload_policies" {
  triggers = {
    opa_storage_name        = azurerm_storage_account.opa_storage.name
    opa_share_name          = azurerm_storage_share.opa_policies.name
    lakekeeper_version      = var.lakekeeper_version
    custom_policies_version = "v2"
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e

      ACCOUNT="${azurerm_storage_account.opa_storage.name}"
      ACCOUNT_KEY="${azurerm_storage_account.opa_storage.primary_access_key}"
      SHARE="${azurerm_storage_share.opa_policies.name}"
      BASE_URL="https://raw.githubusercontent.com/lakekeeper/lakekeeper/refs/tags/${var.lakekeeper_version}/authz/opa-bridge/policies"
      TMPDIR=$(mktemp -d)

      echo "Downloading Lakekeeper OPA policies..."

      # Top-level config
      curl -sSfL -o "$TMPDIR/configuration.rego" "$BASE_URL/configuration.rego"

      # Trino policies
      TRINO_POLICY_FILES="
        main.rego
        user.rego
        check.rego
        allow_catalog.rego
        allow_default_access.rego
        allow_schema.rego
        allow_table.rego
        allow_view.rego
      "
      mkdir -p "$TMPDIR/trino"
      for f in $TRINO_POLICY_FILES; do
        curl -sSfL -o "$TMPDIR/trino/$f" "$BASE_URL/trino/$f"
      done

      # Lakekeeper policies
      LAKEKEEPER_POLICY_FILES="
        authentication.rego
        check.rego
        identifiers.rego
      "
      mkdir -p "$TMPDIR/lakekeeper"
      for f in $LAKEKEEPER_POLICY_FILES; do
        curl -sSfL -o "$TMPDIR/lakekeeper/$f" "$BASE_URL/lakekeeper/$f"
      done

      echo "Downloaded $(find "$TMPDIR" -name '*.rego' | wc -l) policy files"

      # Custom permission policy extensions
      # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
      # Policies not  covered by the Lakekeeper bridge, which focuses on
      # catalog/schema/table access.
      #
      # These rules extend main.rego's incremental 'allow' rule.
      #
      cat > "$TMPDIR/trino/allow_extensions.rego" << 'REGO_EOF'
package trino

import future.keywords.if

# Allow all authenticated users to set system and catalog session properties.
# Session properties (e.g. task_concurrency) are user-scoped performance tuning,
# not a security boundary — authentication already gates access.
allow if {
    input.action.operation == "SetSystemSessionProperty"
}
allow if {
    input.action.operation == "SetCatalogSessionProperty"
}

# Allow reading from any table in the system catalog.
# allow_default_access.rego whitelists specific system.jdbc tables; this extends
# that to cover system.metadata.* and any other system schema (e.g. queried by dbt).
# The system catalog is Trino-internal metadata, not user data.
allow if {
    input.action.operation == "SelectFromColumns"
    input.action.resource.table.catalogName == "system"
}
REGO_EOF

      # Create directories in file share
      echo "Creating directories in file share..."
      az storage directory create \
        --account-name "$ACCOUNT" \
        --share-name "$SHARE" \
        --name trino \
        --account-key "$ACCOUNT_KEY" \
        --output none 2>/[env1]/null || true
      az storage directory create \
        --account-name "$ACCOUNT" \
        --share-name "$SHARE" \
        --name lakekeeper \
        --account-key "$ACCOUNT_KEY" \
        --output none 2>/[env1]/null || true

      # Upload all files
      echo "Uploading policy files to file share..."
      cd "$TMPDIR"
      find . -name '*.rego' -type f | while read -r f; do
        REL_PATH=$(echo "$f" | sed 's|^\./||')
        echo "  Uploading $REL_PATH..."
        az storage file upload \
          --account-name "$ACCOUNT" \
          --share-name "$SHARE" \
          --source "$f" \
          --path "$REL_PATH" \
          --account-key "$ACCOUNT_KEY" \
          --output none
      done

      rm -rf "$TMPDIR"
      echo "Successfully uploaded all OPA policy files"

      # Restart OPA if it's already running so it picks up the new policy files.
      # On first deploy the container doesn't exist yet, so this is a no-op.
      ACTIVE_REVISION=$(az containerapp revision list \
        --name "${var.app_name}" \
        --resource-group "${var.resource_group_name}" \
        --query "[?properties.active].name | [0]" \
        -o tsv 2>/[env1]/null || true)
      if [ -n "$ACTIVE_REVISION" ]; then
        echo "Restarting OPA revision $ACTIVE_REVISION to load updated policies..."
        az containerapp revision restart \
          --name "${var.app_name}" \
          --resource-group "${var.resource_group_name}" \
          --revision "$ACTIVE_REVISION"
      fi
    EOT
  }

  depends_on = [azurerm_storage_share.opa_policies]
}

# =============================================================================
# Container App

resource "azurerm_container_app" "opa" {
  count = 1

  name                         = var.app_name
  container_app_environment_id = var.datahub_container_app_environment_id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"
  workload_profile_name        = "Consumption"

  depends_on = [
    null_resource.upload_policies,
    azurerm_container_app_environment_storage.opa_policies,
  ]

  template {
    min_replicas = 1
    max_replicas = 1

    volume {
      name         = "opa-policies"
      storage_name = azurerm_container_app_environment_storage.opa_policies.name
      storage_type = "AzureFile"
    }

    container {
      name   = "opa"
      image  = "openpolicyagent/opa:${var.opa_image_tag}"
      cpu    = 0.5
      memory = "1Gi"

      args = ["run", "--server", "--addr=0.0.0.0:8181", "/policies"]

      volume_mounts {
        name = "opa-policies"
        path = "/policies"
      }

      env {
        name  = "LAKEKEEPER_URL"
        value = var.lakekeeper_internal_url
      }
      env {
        name  = "LAKEKEEPER_TOKEN_ENDPOINT"
        value = "https://login.microsoftonline.com/${var.tenant_id}/oauth2/v2.0/token"
      }
      env {
        name  = "LAKEKEEPER_CLIENT_ID"
        value = var.opa_client_id
      }
      env {
        name        = "LAKEKEEPER_CLIENT_SECRET"
        secret_name = "[SECRET_NAME]"
      }
      env {
        name  = "LAKEKEEPER_SCOPE"
        value = "api://${var.lakekeeper_app_registration_client_id}/.default"
      }
      env {
        name  = "TRINO_LAKEKEEPER_CATALOG_NAME"
        value = var.trino_catalog_name
      }
      env {
        name  = "LAKEKEEPER_LAKEKEEPER_WAREHOUSE"
        value = var.lakekeeper_warehouse_name
      }

      liveness_probe {
        transport = "HTTP"
        port      = 8181
        path      = "/health"
      }

      readiness_probe {
        transport = "HTTP"
        port      = 8181
        path      = "/health"
      }
    }
  }

  secret {
    name  = "[SECRET_NAME]"
    value = var.opa_client_secret
  }

  ingress {
    allow_insecure_connections = true
    external_enabled           = false
    target_port                = 8181

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
}