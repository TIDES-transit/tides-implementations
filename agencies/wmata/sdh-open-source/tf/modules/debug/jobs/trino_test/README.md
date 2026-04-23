# Trino Test Job

A troubleshooting Container App Job that uses the official Trino CLI to test connectivity and catalog access from within the Container Apps environment.

This job is useful for verifying:

- Trino coordinator is accessible from within the CAE
- Password authentication works
- Lakekeeper catalog connection is functioning

## Deployment

The job is deployed as part of the main Terraform configuration. To deploy:

```bash
cd tf/envs/[env1]
tofu apply
```

## Running the Job

### Start the job

```bash
az containerapp job start \
  --name "[project]-[env1]-trino-test-caj" \
  --resource-group "[RESOURCE_GROUP]"
```

## Retrieving Logs

### Method 1: Streaming logs (immediately after job runs)

```bash
# Get the execution name from the job start output, then:
az containerapp job logs show \
  --name "[project]-[env1]-trino-test-caj" \
  --resource-group "[RESOURCE_GROUP]" \
  --execution "<execution-name>" \
  --container "trino-test"
```

### Method 2: Log Analytics (for historical logs)

```bash
# Get the Log Analytics workspace ID
WORKSPACE_ID=$(az containerapp env show \
  --name [Project Name]-[env1]-cae \
  --resource-group [RESOURCE_GROUP] \
  --query 'properties.appLogsConfiguration.logAnalyticsConfiguration.customerId' \
  -o tsv)

# Query logs for this job (last hour)
az monitor log-analytics query \
  --workspace "$WORKSPACE_ID" \
  --analytics-query "ContainerAppConsoleLogs_CL | where ContainerJobName_s == '[project]-[env1]-trino-test-caj' | where TimeGenerated > ago(1h) | order by TimeGenerated asc | project Log_s" \
  -o json | jq -r '.[] | .Log_s'
```

### Method 3: List recent executions

```bash
# List recent job executions
az containerapp job execution list \
  --name "[project]-[env1]-trino-test-caj" \
  --resource-group "[RESOURCE_GROUP]" \
  -o table
```

## Test Output

A successful test will show output similar to:

```txt
========================================
Trino CLI Connectivity Test
========================================

--- Configuration ---
Server: https://trino.[CONTAINER_ENV].azurecontainerapps.io
User: tableau
Catalog: datahub

--- Trino CLI Version ---
Trino CLI 476

--- Query Test: SHOW CATALOGS ---
"datahub"
"system"
Exit code: 0

--- Query Test: SHOW SCHEMAS FROM datahub ---
(This tests the Lakekeeper connection)
"information_schema"
Exit code: 0

--- Query Test: SELECT 1 ---
"1"
Exit code: 0

========================================
SUMMARY
========================================
SHOW CATALOGS: PASS
SHOW SCHEMAS:  PASS
SELECT 1:      PASS
========================================
```

## Expected Errors

### Warehouse not found in Lakekeeper

If the `datahub` warehouse hasn't been created in Lakekeeper yet, `SHOW SCHEMAS` will fail with an error like:

```txt
Error running command: line 1:1: Catalog 'datahub' does not exist
```

or

```txt
Error running command: Warehouse 'datahub' not found
```

This is expected until the warehouse sync job succeeds (requires Storage Blob Data Contributor role).

### Authentication failure

If password authentication fails:

```txt
Error running command: Authentication failed
```

Check that the Trino password in Key Vault matches what was configured.

## Troubleshooting

### Connection refused or timeout

1. Verify Trino coordinator is running: `az containerapp show --name [Project Name]-[env1]-trino-ca --resource-group [RESOURCE_GROUP] --query properties.runningStatus`
2. Check that the internal hostname is correct (should use the Container App name, not the external FQDN)

### Catalog errors

If `SHOW CATALOGS` works but `SHOW SCHEMAS FROM datahub` fails, the issue is with the Lakekeeper connection, not Trino itself. Check:

1. Lakekeeper is running and healthy
2. The `datahub` warehouse exists in Lakekeeper
3. OAuth2 credentials for Trino -> Lakekeeper are correct