# Upgrading OpenMetadata

Reference: <https://docs.open-metadata.org/v1.11.x/deployment/upgrade>

## Steps

1. **Back up the metadata database** using `pg_dump` before making any changes.

2. **Update the image tag** in the environment's `main.tf` (e.g., `openmetadata_image_tag = "1.11.8"`), then apply with OpenTofu.

3. **Database migration runs automatically.** The container entrypoint runs `./bootstrap/openmetadata-ops.sh migrate` on every startup, which handles database schema migrations.

4. **Recreate search indexes** after the server is up and healthy. This is a manual step:
   - Log into the OpenMetadata UI as an admin
   - Go to **Settings > Applications > Search Indexing**
   - Click the **Configuration** tab
   - Check **Recreate Indexes**
   - Click **Save**, then go to the **Schedule** tab and click **Run now**
   - Wait for the run to complete with "Success" status

## Why is the reindex manual?

The `migrate` command attempts to update OpenSearch index mappings, but OpenSearch cannot change the type of an existing field via a mapping update -- the index must be dropped and recreated. The `reindex` operation also requires the server to be running, so it cannot be added to the entrypoint before server startup.
