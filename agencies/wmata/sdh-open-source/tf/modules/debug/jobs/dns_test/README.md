# DNS Test Job

A diagnostic Container App Job that tests DNS resolution for all private endpoints in the environment. This helps verify that private DNS zones are correctly configured and that Container Apps can resolve private endpoint hostnames.

## Tested Endpoints

The job tests DNS resolution for the following private endpoints (when configured):

- **PostgreSQL**: `*.privatelink.postgres.database.azure.com`
- **Container Registry**: `*.privatelink.azurecr.io`
- **Key Vault**: `*.privatelink.vaultcore.azure.net`
- **Blob Storage**: `*.privatelink.blob.core.windows.net`
- **DFS Storage**: `*.privatelink.dfs.core.windows.net`
- **File Storage**: `*.privatelink.file.core.windows.net`

## Deployment

The job is deployed as part of the main Terraform configuration. To deploy:

```bash
cd tf/envs/<environment>
tofu apply
```

## Running the Job

### Start the job

```bash
az containerapp job start \
  --name "<sys_short>-<env_short>-dns-test-caj" \
  --resource-group "<RESOURCE_GROUP>"
```

## Retrieving Logs

### Method 1: Streaming logs (immediately after job runs)

```bash
# Get the execution name from the job start output, then:
az containerapp job logs show \
  --name "<sys_short>-<env_short>-dns-test-caj" \
  --resource-group "<RESOURCE_GROUP>" \
  --execution "<execution-name>" \
  --container "dns-test"
```

### Method 2: Log Analytics (for historical logs)

```bash
# Get the Log Analytics workspace ID
WORKSPACE_ID=$(az containerapp env show \
  --name <cae-name> \
  --resource-group <RESOURCE_GROUP> \
  --query 'properties.appLogsConfiguration.logAnalyticsConfiguration.customerId' \
  -o tsv)

# Query logs (replace <execution-name> with your execution name)
az monitor log-analytics query \
  --workspace "$WORKSPACE_ID" \
  --analytics-query "ContainerAppConsoleLogs_CL | where ContainerGroupName_s startswith '<execution-name>' | where TimeGenerated > ago(1h) | project Log_s" \
  -o tsv
```

### Method 3: List recent executions

```bash
# List recent job executions
az containerapp job execution list \
  --name "<sys_short>-<env_short>-dns-test-caj" \
  --resource-group "<RESOURCE_GROUP>" \
  -o table
```

## Expected Output

When DNS resolution is working correctly, you should see each endpoint resolving to a private IP address (typically in the 10.x.x.x range). For example:

```txt
========================================
PostgreSQL
========================================
--- dig myserver.privatelink.postgres.database.azure.com ---
; <<>> DiG 9.18.x <<>> myserver.privatelink.postgres.database.azure.com
;; ANSWER SECTION:
myserver.privatelink.postgres.database.azure.com. 10 IN A 10.61.2.5
```

If DNS resolution is failing, you may see `NXDOMAIN` responses or no answer section, indicating that the private DNS zone is not linked to the VNet or the DNS server is not configured correctly.
