# =======================================================================
# Storage Resources
#
# - Storage Account
# - Blob Containers

resource "azurerm_storage_account" "lake" {
  access_tier                       = "Hot"
  account_kind                      = "StorageV2"
  account_replication_type          = "LRS"
  account_tier                      = "Standard"
  allow_nested_items_to_be_public   = true
  cross_tenant_replication_enabled  = false
  default_to_oauth_authentication   = true
  dns_endpoint_type                 = "Standard"
  https_traffic_only_enabled        = true
  infrastructure_encryption_enabled = false
  is_hns_enabled                    = true
  large_file_share_enabled          = false
  local_user_enabled                = true
  location                          = var.resource_group_location
  min_tls_version                   = "TLS1_2"
  name                              = local.resource_names.sa_lake
  nfsv3_enabled                     = false
  public_network_access_enabled     = false
  queue_encryption_key_type         = "Service"
  resource_group_name               = var.resource_group_name
  sftp_enabled                      = false
  shared_access_key_enabled         = false
  table_encryption_key_type         = "Service"
  tags                              = local.sa_lake_tags
  blob_properties {
    change_feed_enabled      = false
    last_access_time_enabled = false
    versioning_enabled       = false
  }
  network_rules {
    bypass                     = ["AzureServices"]
    default_action             = "Deny"
    ip_rules                   = []
    virtual_network_subnet_ids = []
  }
  routing {
    choice                      = "MicrosoftRouting"
    publish_internet_endpoints  = false
    publish_microsoft_endpoints = true
  }
  share_properties {
    retention_policy {
      days = 7
    }
  }

  # We don't want to delete the contents of this storage account accidentally,
  # so we prevent destroy operations.
  lifecycle {
    prevent_destroy = true
  }
}

