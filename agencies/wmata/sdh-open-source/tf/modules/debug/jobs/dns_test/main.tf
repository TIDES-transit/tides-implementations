# =============================================================================
# DNS Test Container App Job
#
# A diagnostic job that tests DNS resolution for all private endpoints in the
# environment. This helps verify that private DNS zones are correctly configured
# and that Container Apps can resolve private endpoint hostnames.
# =============================================================================

locals {
  job_name = "${var.sys_short}-${var.env_short}-dns-test-caj"

  # Build the list of endpoints to test
  endpoints = {
    "PostgreSQL"         = var.postgresql_privatelink_fqdn
    "Container Registry" = var.container_registry_privatelink_fqdn
    "Key Vault"          = var.key_vault_privatelink_fqdn
    "Blob Storage"       = var.storage_blob_privatelink_fqdn
    "DFS Storage"        = var.storage_dfs_privatelink_fqdn
    "File Storage"       = var.storage_file_privatelink_fqdn
  }

  # Filter out empty endpoints
  active_endpoints = { for k, v in local.endpoints : k => v if v != null && v != "" }

  # Generate the dig commands for each endpoint
  dig_commands = join("\n", [
    for name, fqdn in local.active_endpoints : <<-EOT
        echo "========================================"
        echo "${name}"
        echo "========================================"
        echo "--- dig ${fqdn} ---"
        dig ${fqdn}
        echo ""
    EOT
  ])
}

resource "azurerm_container_app_job" "dns_test" {
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
      name   = "dns-test"
      image  = "alpine:${var.alpine_image_tag}"
      cpu    = 0.25
      memory = "0.5Gi"

      command = ["/bin/sh", "-c"]
      args = [
        <<-EOT
        apk add --no-cache bind-tools > /[env1]/null 2>&1

        echo "========================================"
        echo "DNS RESOLUTION DIAGNOSTIC"
        echo "========================================"
        echo "Date: $(date)"
        echo "Hostname: $(hostname)"
        echo ""
        echo "--- /etc/resolv.conf ---"
        cat /etc/resolv.conf
        echo ""

        ${local.dig_commands}
        echo "========================================"
        echo "DONE"
        echo "========================================"
        EOT
      ]
    }
  }

  tags = var.tags
}