# Housekeeping in Iceberg

Iceberg maintains snapshots of data over time, similar to a git commit. This facilitates schema evolution, and allows rolling back to a known good state.

Snapshots are incremental, and have individual IDs. You can roll back to individual snapshots, and see what snapshot a specific change was layered on.

For example:

1) Initial data load - has a snapshot_id, has a NULL parent_id
2) Delete some records - has a snapshot_id, has a parent_id of step 1

You can restore to either state using the snapshot_id.

## Common Operations

### Restore snapshots

This does not currently have a dagster job available, and must be executed via SQL in the Trino connector. The example below from [the Trino docs](https://trino.io/docs/current/connector/iceberg.html#using-snapshots) details how to retrieve a list of snapshots, and then restore to a snapshot.

```sql
SELECT * -- use the snapshot_id column to identify a value to roll back to
-- the result will snow the date of each snapshot, the id, and if it was the result of an APPEND/INSERT/DELETE
FROM example.testdb."customer_orders$snapshots" -- note this syntax
ORDER BY committed_at DESC LIMIT 1;
```

```sql
-- now we can change the table back to this snapshot
ALTER TABLE testdb.customer_orders EXECUTE rollback_to_snapshot(8954597067493422955);
```

### Truncate tables

`TRUNCATE`-ing a table deletes all records from the table, but preserves the structure and table itself. The data in the table can be restored by rolling back to a snapshot.

This can be performed using the `truncate_job` in dagster, and by setting:

- The schema of the table to be truncated
- The name of the table to be truncated

See [the Trino docs](https://trino.io/docs/current/sql/truncate.html#truncate) for more information, including SQL examples.

### Expire snapshots

Snapshots contain the data and metadata required to restore a table to a specific state at a point in time. Expiring a snapshot, as a result, will remove snapshots older than a certain period. The period is specified in the command, though there is a not-to-exceed minimum specified in the service configuration. The service also is configured to preserve a minimum number of snapshots, ensuring that this does not drop all data.

This can be performed using the `expire_job` in dagster, and by setting:

- The schema of the table which will have its snapshots expired
- The name of the table which will have its snapshots expired
- The minimum age of snapshots to retain (e.g., if set to 14, a snapshot older than 15 days will be removed)

See [the Trino docs](https://trino.io/docs/current/connector/iceberg.html#expire-snapshots) for more information, including SQL examples.

### Remove Oprhan Files (#orphan)

Data operations may at times result in so-called orphan files within the iceberg service. These are files that are not referred to by any table data, metadata, or snapshot.

This can be performed using the `orphan_files_job` in dagster, and by setting:

- The schema of the table which will have its orphan files removed
- The name of the table which will have its orphan files removed
- The minimum age of orphan files to preserve (e.g., if set to 14, an orphan file older than 15 days will be removed)

See [the Trino docs](https://trino.io/docs/current/connector/iceberg.html#remove-orphan-files) for more information, including SQL examples.

### Optimize Tables

Data operations may at times result in scattered, smaller files that are connected to a table. Optimizing the table will combine multiple small files into a larger table, which can speed up table scan operations.

This can be performed using the `optime_job` in dagster, and by setting:

- The schema of the table which will have its orphan files removed
- The name of the table which will have its orphan files removed
- The minimum file size to optimize (in megabytes, such as `128` for 128MB)

See [the Trino docs](https://trino.io/docs/current/connector/iceberg.html#optimize) for more information, including SQL examples.

### Drop Tables

This does not currently have a dagster job and is not currently recommended as it immediately deletes all data and metadata files, which does not allow restoring from a snapshot.

### Optimize Manifests

This does not currently have a dagster job, but works similarly to Optimize.
