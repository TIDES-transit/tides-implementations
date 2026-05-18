variable "tenant_id" {
  description = "The ID of the Azure AD tenant"
  type        = string
}

variable "datahub_key_vault_id" {
  description = "The ID of the DataHub Key Vault"
  type        = string
}

variable "datahub_lake_storage_account_id" {
  description = "The ID of the DataHub Lake Storage account"
  type        = string
}
