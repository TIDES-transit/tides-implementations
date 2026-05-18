# Shell Test Job

A general-purpose troubleshooting Container App Job that runs an Alpine container with common networking tools (`bind-tools` for `dig`/`nslookup`, `curl`, etc.).

This job is useful for ad-hoc debugging, network connectivity testing, and other infrastructure troubleshooting from within the Container Apps environment.

For DNS resolution testing of private endpoints, see the dedicated `dns_test` job module.

## Deployment

The job is deployed as part of the main Terraform configuration. To deploy:

```bash
cd tf/envs/<environment>
tofu apply
```

## Running the Job

### Start the job

By default, the job displays basic environment information (hostname, resolv.conf, environment variables):

```bash
az containerapp job start \
  --name "<sys_short>-<env_short>-sh-test-caj" \
  --resource-group "<RESOURCE_GROUP>"
```

### Start with custom commands

Override the default commands to run custom diagnostics:

```bash
az containerapp job start \
  --name "<sys_short>-<env_short>-sh-test-caj" \
  --resource-group "<RESOURCE_GROUP>" \
  --image "alpine:latest" \
  --command "/bin/sh" "-c" "apk add --no-cache bind-tools && dig example.com"
```

## Retrieving Logs

### Method 1: Streaming logs (immediately after job runs)

```bash
# Get the execution name from the job start output, then:
az containerapp job logs show \
  --name "<sys_short>-<env_short>-sh-test-caj" \
  --resource-group "<RESOURCE_GROUP>" \
  --execution "<execution-name>" \
  --container "sh-test"
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
  --name "<sys_short>-<env_short>-sh-test-caj" \
  --resource-group "<RESOURCE_GROUP>" \
  -o table
```

## Common Use Cases

### DNS Resolution Testing

```bash
# Test DNS resolution
dig example.com

# Test with specific DNS server
dig @10.0.0.5 example.privatelink.postgres.database.azure.com

# Verbose DNS output
nslookup -debug example.com
```

### Network Connectivity Testing

```bash
# Test HTTP connectivity
curl -v https://example.com

# Test TCP connectivity (if netcat is installed)
nc -zv hostname 5432
```

### Environment Inspection

```bash
# View resolv.conf
cat /etc/resolv.conf

# View environment variables
env | sort
```
