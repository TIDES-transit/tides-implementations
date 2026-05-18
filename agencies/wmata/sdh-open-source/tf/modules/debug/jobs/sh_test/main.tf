# =============================================================================
# Shell Test Container App Job
#
# A general-purpose troubleshooting job that runs an Alpine container with
# common networking tools (bind-tools for dig/nslookup, curl, etc.).
#
# This job is useful for debugging DNS resolution, network connectivity,
# and other infrastructure issues from within the Container Apps environment.
#
# By default, the job displays basic environment info. Override the command
# at runtime to run custom diagnostics.
# =============================================================================

locals {
  job_name = "${var.sys_short}-${var.env_short}-sh-test-caj"
}

resource "azurerm_container_app_job" "sh_test" {
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
      name   = "sh-test"
      image  = "alpine:${var.alpine_image_tag}"
      cpu    = 0.25
      memory = "0.5Gi"

      command = ["/bin/sh", "-c"]
      args = [
        <<-EOT
        apk add --no-cache bind-tools curl > /[env1]/null 2>&1

        echo "========================================"
        echo "SHELL TEST JOB"
        echo "========================================"
        echo "Date: $(date)"
        echo "Hostname: $(hostname)"
        echo ""
        echo "--- /etc/resolv.conf ---"
        cat /etc/resolv.conf
        echo ""
        echo "--- Environment Variables ---"
        env | sort
        echo ""
        echo "========================================"
        echo "DONE"
        echo "========================================"
        echo ""
        echo "To run custom commands, use:"
        echo "  az containerapp job start --name ${local.job_name} \\"
        echo "    --resource-group <RESOURCE_GROUP> \\"
        echo "    --image alpine:latest \\"
        echo "    --command \"/bin/sh\" \"-c\" \"<your commands here>\""
        EOT
      ]
    }
  }

  tags = var.tags
}