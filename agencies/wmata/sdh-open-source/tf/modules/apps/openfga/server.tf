# =============================================================================
# OpenFGA Server Container App
#
# OpenFGA exposes HTTP (REST API, playground, health) on port 8080 and gRPC
# (used by Lakekeeper) on port 8081. Both are exposed via ingress: port 8080
# as the primary ingress, and port 8081 via additionalPortMappings.
#
# WORKAROUND: The azurerm provider does not yet support additionalPortMappings
# (https://github.com/hashicorp/terraform-provider-azurerm/issues/26565), so
# we use azapi_update_resource to add the gRPC port. Once the azurerm provider
# supports this natively (PR https://github.com/hashicorp/terraform-provider-azurerm/pull/28148),
# this should be migrated back.

resource "azurerm_container_app" "openfga" {
  count = var.has_db_registration ? 1 : 0

  name                         = var.app_name
  container_app_environment_id = var.datahub_container_app_environment_id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"
  workload_profile_name        = "Consumption"

  depends_on = [null_resource.migration_trigger]

  template {
    min_replicas = 1
    max_replicas = 1

    container {
      name   = "openfga"
      image  = "openfga/openfga:${var.openfga_image_tag}"
      cpu    = 1.0
      memory = "2Gi"

      args = ["run"]

      env {
        name  = "OPENFGA_DATASTORE_ENGINE"
        value = "postgres"
      }
      env {
        name        = "OPENFGA_DATASTORE_URI"
        secret_name = "openfga-db-uri"
      }
      env {
        name  = "OPENFGA_AUTHN_METHOD"
        value = "preshared"
      }
      env {
        name        = "OPENFGA_AUTHN_PRESHARED_KEYS"
        secret_name = "[SECRET_NAME]"
      }
      env {
        name  = "OPENFGA_PLAYGROUND_ENABLED"
        value = tostring(var.enable_playground)
      }
      env {
        name  = "OPENFGA_HTTP_ADDR"
        value = "0.0.0.0:8080"
      }
      env {
        name  = "OPENFGA_GRPC_ADDR"
        value = "0.0.0.0:8081"
      }

      # Caching — reduces latency for repeated permission checks
      # at the cost of slightly stale results (bounded by TTL).
      # See https://openfga.[env1]/docs/getting-started/setup-openfga/configuration
      env {
        name  = "OPENFGA_CHECK_QUERY_CACHE_ENABLED"
        value = "true"
      }
      env {
        name  = "OPENFGA_CHECK_ITERATOR_CACHE_ENABLED"
        value = "true"
      }
      # Invalidate caches automatically when tuples are written.
      env {
        name  = "OPENFGA_CACHE_CONTROLLER_ENABLED"
        value = "true"
      }

      liveness_probe {
        transport = "HTTP"
        port      = 8080
        path      = "/healthz"
      }

      readiness_probe {
        transport = "HTTP"
        port      = 8080
        path      = "/healthz"
      }
    }
  }

  secret {
    name  = "openfga-db-uri"
    value = local.openfga_db_uri
  }

  secret {
    name  = "[SECRET_NAME]"
    value = random_password.openfga_preshared_key.result
  }

  ingress {
    allow_insecure_connections = true
    external_enabled           = false
    target_port                = 8080

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
}

# =============================================================================
# Expose gRPC port via additionalPortMappings (azapi workaround)
#
# WORKAROUND: The azurerm provider does not yet support additionalPortMappings.
# See https://github.com/hashicorp/terraform-provider-azurerm/issues/26565
# TODO: Replace with native azurerm support once PR #28148 is merged.

resource "azapi_update_resource" "openfga_grpc_port" {
  count = var.has_db_registration ? 1 : 0

  type        = "Microsoft.App/containerApps@2024-02-02-preview"
  resource_id = azurerm_container_app.openfga[0].id

  body = {
    properties = {
      configuration = {
        ingress = {
          additionalPortMappings = [
            {
              external   = false
              targetPort = 8081
            }
          ]
        }
        secrets = [
          {
            name  = "openfga-db-uri"
            value = local.openfga_db_uri
          },
          {
            name  = "[SECRET_NAME]"
            value = random_password.openfga_preshared_key.result
          }
        ]
      }
    }
  }
}