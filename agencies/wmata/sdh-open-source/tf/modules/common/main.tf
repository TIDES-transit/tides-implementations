locals {
  # Base naming pattern for consistent resource naming -
  base_name          = "${var.system_name}-${var.env_short}"
  base_name_alphanum = replace("${var.sys_short}${var.env_short}", "/[^a-zA-Z0-9]/", "")

  # Common tags applied to all resources
  common_tags = {
    Project     = "[Project Name]"
    Environment = var.environment_name
    # TODO: Replace these values with variables filled during CD
    SourceBranch     = "main"
    SourceRepository = "https://github.com/[ORGANIZATION]/[project-name]"
    Release          = "<commit-hash>"
  }

  # Container app names following {system/application}-{environment}-{otherqualifier, project, purpose}-ca
  app_names = {
    lakekeeper   = "${local.base_name}-lakekeeper-ca"
    dagster      = "${local.base_name}-dagster-ca"
    trino        = "${local.base_name}-trino-ca"
    openmetadata = "${local.base_name}-openmetadata-ca"
    metabase     = "${local.base_name}-metabase-ca"
    openfga      = "${local.base_name}-openfga-ca"
    opa          = "${local.base_name}-opa-ca"
  }

  # Resource names following {system}-{environment}-{qualifier}-pep pattern
  resource_names = merge({
    # Private Endpoints - {system/application}-{environment}-{host,purpose, resource other qualifier}-pep
    pe_aca       = "${local.base_name}-aca-pep"
    pe_cr        = "${local.base_name}-cr-pep"
    pe_kv        = "${local.base_name}-kv-pep"
    pe_lake_blob = "${local.base_name}-lake-blob-pep"
    pe_lake_dfs  = "${local.base_name}-lake-dfs-pep"
    pe_lake_file = "${local.base_name}-lake-file-pep"
    pe_psql      = "${local.base_name}-psql-pep"
    # Network Interfaces - {system/application}-{environment}-{host,purpose, resource other qualifier}-pep-nic-{##}
    nic_aca       = "${local.base_name}-aca-pep-nic-01"
    nic_cr        = "${local.base_name}-cr-pep-nic-01"
    nic_kv        = "${local.base_name}-kv-pep-nic-01"
    nic_lake_blob = "${local.base_name}-lake-blob-pep-nic-01"
    nic_lake_dfs  = "${local.base_name}-lake-dfs-pep-nic-01"
    nic_lake_file = "${local.base_name}-lake-file-pep-nic-01"
    nic_psql      = "${local.base_name}-psql-pep-nic-01"
    # Storage Account following {system}{environment}strg{##} format - character limited
    sa_lake = "${local.base_name_alphanum}lakestrg01"
    # Database Server following {system/application}-{environment}-{purpose}-{db type} format
    psql = "${local.base_name}-psql"
    # Key Vault
    kv = "${local.base_name}-kv"
    # Container Registry - {system}-{environment}-cr{##}
    cr = "${local.base_name_alphanum}cr01"
    # Container App Environment - {system/application}-{environment}-{otherqualifier, project, purpose}-cae
    cae = "${local.base_name}-cae"
    # Log Analytics Workspace - {system}-{environment}-{purpose}-log{##}
    log = "${local.base_name}-analytics-log01"
    # Identities - {system/application}-{environment}-{purpose}-mi
    # TODO: docs show identity and logs share a format but not sure there
    id = "${local.base_name}-azureapp-mi"
  }, var.resource_name_overrides)
  # Per-resource tags
  psql_tags = merge(local.common_tags, {
    SourceFile  = "tf/modules/common/databases.tf"
    Description = "PostgreSQL flexible server for data storage and application databases"
  })

  sa_lake_tags = merge(local.common_tags, {
    SourceFile  = "tf/modules/common/storage.tf"
    Description = "Data lake storage account for raw and processed data"
  })
  kv_tags = merge(local.common_tags, {
    SourceFile  = "tf/modules/common/secrets.tf"
    Description = "Key vault for secure storage of secrets and certificates"
  })
  cr_tags = merge(local.common_tags, {
    SourceFile  = "tf/modules/common/container_apps.tf"
    Description = "Container registry for storing application images"
  })
  cae_tags = merge(local.common_tags, {
    SourceFile  = "tf/modules/common/container_apps.tf"
    Description = "Container app environment for hosting containerized applications"
  })
  log_tags = merge(local.common_tags, {
    SourceFile  = "tf/modules/common/container_apps.tf"
    Description = "Log analytics workspace for monitoring and diagnostics"
  })
  id_tags = merge(local.common_tags, {
    SourceFile  = "tf/modules/common/identities.tf"
    Description = "Managed identity for secure access to Azure resources"
  })
}