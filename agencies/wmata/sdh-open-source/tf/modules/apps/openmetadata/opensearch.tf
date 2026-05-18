# =============================================================================
# OPENSEARCH CONTAINER APP
# =============================================================================

resource "azurerm_container_app" "opensearch" {
  count = var.has_entra ? 1 : 0

  name                         = local.openmetadata_names.opensearch
  container_app_environment_id = var.datahub_container_app_environment_id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"
  workload_profile_name        = var.workload_profile_name

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.openmetadata.id]
  }

  template {
    min_replicas = 1
    max_replicas = 1

    volume {
      name         = "opensearch-data"
      storage_type = "AzureFile"
      storage_name = azurerm_container_app_environment_storage.opensearch_storage.name
    }

    container {
      name   = "opensearch"
      image  = "opensearchproject/opensearch:${var.opensearch_image_tag}"
      cpu    = 2.0
      memory = "4Gi"

      # OpenSearch configuration based on Helm StatefulSet
      env {
        name  = "cluster.name"
        value = "opensearch"
      }

      env {
        name  = "node.name"
        value = "opensearch-0"
      }

      env {
        name  = "discovery.type"
        value = "single-node"
      }

      env {
        name  = "network.host"
        value = "[PRIVATE_IP]"
      }

      env {
        name  = "OPENSEARCH_JAVA_OPTS"
        value = "-Xmx1g -Xms1g"
      }

      env {
        name  = "node.roles"
        value = "master,ingest,data,remote_cluster_client"
      }

      # Disable security for simplicity (matches Helm config)
      env {
        name  = "DISABLE_SECURITY_PLUGIN"
        value = "true"
      }

      # Mount the Azure Files share for data persistence
      volume_mounts {
        name = "opensearch-data"
        path = "/usr/share/opensearch/data"
      }

      # ACA has no equivalent of Kubernetes' Recreate strategy. There is no way
      # to ensure old replicas are terminated before the new replica is created.
      # The OpenSearch lock file remains from the old replica, preventing the
      # new replica from ever becoming ready.
      #
      # TODO: Configure a [Remote Search Backend](https://docs.opensearch.org/latest/tuning-your-cluster/availability-and-recovery/remote-store/index/)
      # to point to a blob storage container instead of using mounted local
      # storage.

      # startup_probe {
      #   transport = "TCP"
      #   port      = 9200
      # }

      # liveness_probe {
      #   transport = "TCP"
      #   port      = 9200
      # }

      # readiness_probe {
      #   transport = "TCP"
      #   port      = 9200
      # }
    }
  }

  # Internal ingress only - OpenSearch should not be exposed externally
  ingress {
    external_enabled = false
    target_port      = 9200
    transport        = "tcp"

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
}