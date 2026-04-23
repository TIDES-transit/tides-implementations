variable "resource_group_name" {
  description = "The name of the resource group"
  type        = string
}

variable "resource_group_location" {
  description = "The location of the resource group"
  type        = string
}

variable "datahub_container_app_environment_id" {
  description = "The ID of the Container Apps environment"
  type        = string
}

variable "sys_short" {
  description = "Short system name (e.g., '[project]')"
  type        = string
}

variable "env_short" {
  description = "Short environment name (e.g., '[env1]', '[env2]', 'prd')"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "alpine_image_tag" {
  description = "The tag for the Alpine container image"
  type        = string
  default     = "latest"
}

# Private endpoint FQDNs to test
# These should be the privatelink FQDNs, not the public FQDNs

variable "postgresql_privatelink_fqdn" {
  description = "The privatelink FQDN for PostgreSQL (e.g., myserver.privatelink.postgres.database.azure.com)"
  type        = string
  default     = ""
}

variable "container_registry_privatelink_fqdn" {
  description = "The privatelink FQDN for Container Registry (e.g., myregistry.privatelink.azurecr.io)"
  type        = string
  default     = ""
}

variable "key_vault_privatelink_fqdn" {
  description = "The privatelink FQDN for Key Vault (e.g., myvault.privatelink.vaultcore.azure.net)"
  type        = string
  default     = ""
}

variable "storage_blob_privatelink_fqdn" {
  description = "The privatelink FQDN for Blob Storage (e.g., mystorageaccount.privatelink.blob.core.windows.net)"
  type        = string
  default     = ""
}

variable "storage_dfs_privatelink_fqdn" {
  description = "The privatelink FQDN for DFS Storage (e.g., mystorageaccount.privatelink.dfs.core.windows.net)"
  type        = string
  default     = ""
}

variable "storage_file_privatelink_fqdn" {
  description = "The privatelink FQDN for File Storage (e.g., mystorageaccount.privatelink.file.core.windows.net)"
  type        = string
  default     = ""
}