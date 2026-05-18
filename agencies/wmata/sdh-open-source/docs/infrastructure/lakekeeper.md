# Lakekeeper

Lakekeeper is an open-source Iceberg REST catalog that manages metadata for Iceberg tables. It provides a centralized catalog service that Trino and other query engines use to discover and access Iceberg tables.

## Architecture

Lakekeeper runs as an Azure Container App and stores its metadata in PostgreSQL. It manages warehouses that point to ADLS Gen2 storage containers where the actual Iceberg table data resides.

Access control is enforced by Open Policy Agent (OPA), which Trino consults before executing queries. OPA in turn calls Lakekeeper's permissions API to check what a user is allowed to access. Users and their permissions are managed through Entra ID groups (see [Role & Permission Management](#role--permission-management) below).

## Warehouse Configuration

Warehouses in Lakekeeper are managed via OpenTofu in the `tf/modules/apps/lakekeeper/main.tf` file. Each warehouse is defined in the `warehouses` local variable:

```hcl
locals {
  warehouses = {
    datahub = {
      name       = "datahub"
      short_name = "dh"        # Used in job naming (max 4 chars)
      filesystem = "iceberg"   # ADLS Gen2 container name
    }
  }
}
```

### Adding a New Warehouse

To add a new warehouse:

1. Add an entry to the `warehouses` map in `tf/modules/apps/lakekeeper/main.tf`
2. Keep `short_name` to 4 characters or less (due to Container App Job 32-character name limit)
3. Run `tofu apply` to create:
   - The ADLS Gen2 storage container
   - A warehouse sync Container App Job
   - Trigger the job to create the warehouse in Lakekeeper

### Storage Permissions

The Lakekeeper service principal needs **Storage Blob Data Contributor** role on the storage account to manage Iceberg data in the warehouse filesystems.

## Container App Jobs

Lakekeeper uses several Container App Jobs for management tasks:

| Job | Purpose |
|-----|---------|
| `*-lakekeeper-migr-caj` | Database migrations (runs on every `tofu apply`) |
| `*-lakekeeper-boot-caj` | Bootstrap Lakekeeper (initial setup, runs on first apply) |
| `*-lakekeeper-{short_name}-sync-caj` | Sync warehouse configuration |
| `*-lakekeeper-grants-caj` | Sync Entra group membership to Lakekeeper roles |

These jobs run automatically during `tofu apply` and can also be manually triggered via the Azure CLI. See [Container App Jobs](./container-app-jobs.md) for general instructions on running and monitoring jobs.

---

## Role & Permission Management

Lakekeeper roles are managed through Entra ID groups. Group membership is synced to Lakekeeper via a two-step process run by the `[project]-{env}-lakekeeper-grants-caj` Container App Job.

**Step 1 — Fetch Entra group members** (`sync_grants_fetch_entra.sh`): Reads Entra group membership via the Microsoft Graph API and stores the member lists as JSON secrets in Azure Key Vault.

**Step 2 — Assign Lakekeeper roles** (`sync_grants_assign_roles.sh`): Reads membership data from Key Vault, creates Lakekeeper roles, assigns permissions to those roles, syfare role membership, and applies any service principal grants.

An orchestrator script (`sync_grants.sh`) runs both steps in sequence. This is what the container app job executes.

### Role Definitions

Roles are defined in `tf/modules/apps/lakekeeper/main.tf` and map Entra groups to Lakekeeper permissions:

| Role | Entra Group Variable | Permissions |
|------|---------------------|-------------|
| `users` | `datahub_users_group_id` | project: `describe`, `select` |
| `developers` | `datahub_developers_group_id` | server: `admin`, `operator` |

A role is only created if its corresponding group ID variable is non-null.

### Service Principal Grants

In addition to group-based roles, individual service principals can be granted project-level permissions via the `app_sp_grants` variable. In the [env1] environment this grants Dagster and Trino `data_admin` access so they can manage tables:

```hcl
app_sp_grants = {
  (var.dagster_app_service_principal_object_id) = "data_admin"
  (var.trino_app_service_principal_object_id)   = "data_admin"
}
```

These are applied as direct `oidc~{object_id}` permission assignments at the project level, independent of the role system.

### How to Add or Remove Users

Users are managed exclusively through Entra group membership:

1. **Add a user**: Add them to the appropriate Entra group (`[Project Name] Users` or `[Project Name] Developers`) in the Azure portal.
2. **Remove a user**: Remove them from the Entra group.
3. **Sync changes**: Run the grants sync job (see below). The sync is bidirectional — it adds new members and removes stale ones.

### Running the Grants Sync

#### Full sync (runs both steps in ACA)

Trigger the container app job:

```bash
az containerapp job start \
  --name "[project]-{env}-lakekeeper-grants-caj" \
  --resource-group "{resource-group}" \
  -o json
```

Then check the logs:

```bash
az containerapp job logs show \
  --name "[project]-{env}-lakekeeper-grants-caj" \
  --resource-group "{resource-group}" \
  --container "lakekeeper-grants-sync" \
  --tail 300 --follow
```

#### Step 1 only (run locally)

In environments where the service principal doesn't have `GroupMember.Read.All` permission (i.e., `can_modify_entra = false`), Step 1 must be run locally by a user with Graph API access:

```bash
export AZURE_TENANT_ID="<tenant-id>"
export KEY_VAULT_NAME="[Project Name]-{env}-kv"
export ROLES_JSON='{"users":{"group_id":"<users-group-id>","permissions":{"project":["describe","select"]}},"developers":{"group_id":"<developers-group-id>","permissions":{"server":["admin","operator"]}}}'

cd tf/modules/apps/lakekeeper/scripts
./sync_grants_fetch_entra.sh
```

This uses your `az` CLI credentials to read the Graph API and write secrets to Key Vault. After running, trigger Step 2 via the ACA job.

### Required Permissions for the Grants Sync Job

| Service | Requirement |
|---------|------------|
| Microsoft Graph API | `GroupMember.Read.All` application permission (with admin consent) |
| Azure Key Vault | **Key Vault Secrets User** role on the Key Vault for the job's managed identity |
| Lakekeeper API | App role assignment on the Lakekeeper enterprise application |

### Key Vault Secrets Created by the Sync

| Secret Name | Contents |
|-------------|----------|
| `lakekeeper-role-users-members` | JSON array of `{id, displayName, userPrincipalName}` |
| `lakekeeper-role-developers-members` | JSON array of `{id, displayName, userPrincipalName}` |

---

## Troubleshooting

### "Could not obtain Graph API token"

Expected in environments where `can_modify_entra = false`. Run Step 1 locally instead (see above).

### "No Key Vault token available"

The job's managed identity can't get a Key Vault token. Check that:

- The managed identity assigned to the job has **Key Vault Secrets User** role
- `AZURE_MI_CLIENT_ID` is set correctly in the container app job configuration

### "No membership data found in Key Vault"

Step 1 hasn't been run yet, or the Key Vault secrets don't exist. Run Step 1 locally or ensure the Graph API credentials are configured.

### Role creation returns 409

The role already exists — this is expected and handled automatically. The script falls back to listing roles and finding the existing one by name.