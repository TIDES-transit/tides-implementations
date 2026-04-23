# Azure Container App Jobs

Several components of the [Project Name] run as Azure Container App Jobs rather than long-running Container Apps. Jobs are containers that run to completion — they're used for one-time operations like database migrations, initial bootstrapping, and recurring administrative tasks like syncing permissions.

## Debug and Diagnostic Jobs

The following jobs are always deployed and useful for testing connectivity:

| Job name pattern | Container | Purpose |
|-----------------|-----------|---------|
| `[project]-{env}-sh-test-caj` | `sh-test` | General-purpose Alpine shell with networking tools |
| `[project]-{env}-dns-test-caj` | `dns-test` | Tests DNS resolution for all private endpoints |
| `[project]-{env}-psql-test-caj` | `psql-test` | Tests PostgreSQL connectivity |
| `[project]-{env}-trino-test-caj` | `trino-test` | Tests Trino connectivity |
| `[project]-{env}-java-dns-caj` | `java-dns-test` | Tests DNS resolution using Java's InetAddress (same JVM as Trino) |
| `[project]-{env}-pyice-test-caj` | `pyiceberg-test` | Tests PyIceberg/Lakekeeper connectivity |

## Running a Job

Start a job execution:

```bash
az containerapp job start \
  --name "<job-name>" \
  --resource-group "<resource-group>" \
  -o json
```

The response includes the execution name, which you need when fetching logs for a specific run:

```text
{
  "name": "[project]-[env1]-sh-test-caj-abc123",
  ...
}
```

## Retrieving Logs

### Stream logs in real time (recommended)

Use `--follow` to watch logs as they stream — most useful when you're actively monitoring a running job:

```bash
az containerapp job logs show \
  --name "<job-name>" \
  --resource-group "<resource-group>" \
  --container "<container-name>" \
  --follow \
  --tail 300
```

### Get logs after the job completes

```bash
az containerapp job logs show \
  --name "<job-name>" \
  --resource-group "<resource-group>" \
  --container "<container-name>" \
  --tail 300 \
  --format text
```

### Get logs for a specific execution

```bash
az containerapp job logs show \
  --name "<job-name>" \
  --resource-group "<resource-group>" \
  --execution "<execution-name>" \
  --container "<container-name>" \
  --tail 300
```

### Tips

- `--tail <N>` — shows up to 300 lines (default is only 20; always include this)
- `--format text` — human-readable output instead of JSON
- Jobs typically start within ~5 seconds of being triggered

### Extracting just the log content

Logs in text format include timestamps and stream metadata. To extract just the message text:

```bash
az containerapp job logs show ... --format text 2>&1 \
  | grep "stdout F" \
  | sed 's/.*stdout F //'
```

## Checking Job Status

Check whether an execution succeeded:

```bash
az containerapp job execution show \
  --name "<job-name>" \
  --resource-group "<resource-group>" \
  --job-execution-name "<execution-name>" \
  --query "properties.status" \
  -o tsv
```

List recent executions:

```bash
az containerapp job execution list \
  --name "<job-name>" \
  --resource-group "<resource-group>" \
  -o table
```

## Common Issues

### "No replicas found for execution"

The execution has already completed and the container replica has been cleaned up. Solutions:

- Omit `--execution` to fetch the latest execution's logs
- Re-run the job and fetch logs immediately with `--follow`

### Logs appear truncated

The default is only 20 lines. Always pass `--tail 300` to get up to 300 lines.