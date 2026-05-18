# PostgreSQL Test Job

A troubleshooting Container App Job that runs a PostgreSQL client container for testing database connectivity from within the Container Apps environment.

This job is useful for verifying that Container Apps can connect to the PostgreSQL server via private endpoints, testing DNS resolution, and debugging database connectivity issues.

## Deployment

The job is deployed as part of the main Terraform configuration. To deploy:

```bash
cd tf/envs/[env1]
tofu apply
```

## Running the Job

### Start the job (default connectivity test)

```bash
az containerapp job start \
  --name "[project]-[env1]-psql-test-caj" \
  --resource-group "[RESOURCE_GROUP]"
```

### Start with actual database credentials

To test with real credentials, you can pass them via environment variables. Note that due to Azure CLI limitations, you must also pass the `--image` flag when using `--env-vars`:

```bash
az containerapp job start \
  --name "[project]-[env1]-psql-test-caj" \
  --resource-group "[RESOURCE_GROUP]" \
  --image "postgres:16-alpine" \
  --env-vars "PGHOST=[Project Name]-[env1]-psql-v2.postgres.database.azure.com" "PGPORT=5432" "PGDATABASE=postgres" "PGUSER=your_username" "PGPASSWORD=your_password" \
  --command "/bin/sh" "-c" "pg_isready && psql -c 'SELECT version();'"
```

## Retrieving Logs

### Method 1: Streaming logs (immediately after job runs)

```bash
# Get the execution name from the job start output, then:
az containerapp job logs show \
  --name "[project]-[env1]-psql-test-caj" \
  --resource-group "[RESOURCE_GROUP]" \
  --execution "<execution-name>" \
  --container "psql-test"
```

### Method 2: Log Analytics (for historical logs)

```bash
# Get the Log Analytics workspace ID
WORKSPACE_ID=$(az containerapp env show \
  --name [Project Name]-[env1]-cae \
  --resource-group [RESOURCE_GROUP] \
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
  --name "[project]-[env1]-psql-test-caj" \
  --resource-group "[RESOURCE_GROUP]" \
  -o table
```

## Test Output

A successful test will show output similar to:

```txt
========================================
PostgreSQL Connectivity Test
========================================

--- DNS Resolution ---
Host: [Project Name]-[env1]-psql-v2.postgres.database.azure.com
10.61.74.137      [Project Name]-[env1]-psql-v2.privatelink.postgres.database.azure.com

--- pg_isready Test ---
[Project Name]-[env1]-psql-v2.postgres.database.azure.com:5432 - accepting connections

--- Connection Test (no credentials) ---
Attempting to connect with psql (will fail without valid credentials)...
psql: error: connection to server ... failed: fe_sendauth: no password supplied
(Expected failure - no valid credentials provided)

========================================
DONE
========================================
```

Key indicators:

- **DNS Resolution**: Should show the private IP (e.g., `10.61.74.137`), not the public IP
- **pg_isready**: Should show "accepting connections"
- **Connection Test**: Will fail without credentials, but confirms TCP connectivity

## Troubleshooting

### DNS resolves to public IP instead of private IP

This indicates the Private DNS Zone is not linked to the VNet. The network team needs to add a Virtual Network Link from `privatelink.postgres.database.azure.com` to the Container Apps VNet.

### pg_isready times out

This could indicate:

1. Firewall rules blocking the connection
2. Network routing issues
3. PostgreSQL server not running

### Connection refused

The PostgreSQL server may not be accepting connections on port 5432, or there may be a firewall rule blocking the connection.