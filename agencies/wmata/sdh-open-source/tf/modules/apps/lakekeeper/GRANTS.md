# Lakekeeper Role & Permission Management

## Overview

Lakekeeper roles are managed through Entra ID groups. Group membership is
synced to Lakekeeper via a two-step process run by the `[project]-{env}-lakekeeper-grants-caj`
container app job.

**Step 1 — Fetch Entra group members** (`sync_grants_fetch_entra.sh`):
Reads Entra group membership via Microsoft Graph API and stores the member
lists as JSON secrets in Azure Key Vault.

**Step 2 — Assign Lakekeeper roles** (`sync_grants_assign_roles.sh`):
Reads membership data from Key Vault, creates Lakekeeper roles, assigns
permissions to those roles, syfare role membership, and applies any service
principal grants.

An orchestrator script (`sync_grants.sh`) runs both steps in sequence. This is
what the container app job executes.

## Role Definitions

Roles are defined in `main.tf` as a `locals` block and map Entra groups to
Lakekeeper permissions:

| Role | Entra Group Variable | Permissions |
| ------ | --------------------- | ------------- |
| `users` | `datahub_users_group_id` | project: `describe`, `select` |
| `developers` | `datahub_developers_group_id` | server: `admin`, `operator` |

A role is only created if its corresponding group ID variable is non-null.

## Service Principal Grants

In addition to group-based roles, individual service principals can be granted
project-level permissions via the `app_sp_grants` variable. Example from the
[env1] environment:

```hcl
app_sp_grants = {
  (var.dagster_app_service_principal_object_id) = "data_admin"
  (var.trino_app_service_principal_object_id)   = "data_admin"
}
```

These are applied as direct `oidc~{object_id}` permission assignments at the
project level, independent of the role system.

## How to Add/Remove Users

Users are managed exclusively through Entra group membership:

1. **Add a user**: Add them to the appropriate Entra group (`[Project Name] Users`
   or `[Project Name] Developers`) in the Azure portal.
2. **Remove a user**: Remove them from the Entra group.
3. **Sync changes**: Run the grants sync job (see below). The sync is
   bidirectional — it adds new members and removes stale ones.

## Running the Grants Sync

### Full sync (both steps, in ACA)

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

### Step 1 only (locally)

If the environment's service principal doesn't have `GroupMember.Read.All`
permission (e.g., `can_modify_entra = false`), step 1 must be run locally by
a user who has Graph API access:

```bash
export AZURE_TENANT_ID="<tenant-id>"
export KEY_VAULT_NAME="[Project Name]-{env}-kv"
export ROLES_JSON='{"users":{"group_id":"<users-group-id>","permissions":{"project":["describe","select"]}},"developers":{"group_id":"<developers-group-id>","permissions":{"server":["admin","operator"]}}}'

cd tf/modules/apps/lakekeeper/scripts
./sync_grants_fetch_entra.sh
```

This uses your `az` CLI credentials to read the Graph API and write secrets to
Key Vault. After running, trigger step 2 via the ACA job.

### Step 2 only (in ACA)

Step 2 always runs as part of the full job. It reads Key Vault secrets written
by step 1 and syfare them to Lakekeeper. If step 1 hasn't been run (no secrets
exist), step 2 skips role sync and only applies service principal grants.

## Authentication

The grants sync job authenticates to multiple services:

| Service | ACA (container job) | Local |
| --------- | ------------------- | ------- |
| **Microsoft Graph API** | Client credentials (`GRAPH_CLIENT_ID` / `GRAPH_CLIENT_SECRET`) | `az` CLI token |
| **Azure Key Vault** (write, step 1) | Managed identity | `az` CLI |
| **Azure Key Vault** (read, step 2) | Managed identity (`AZURE_MI_CLIENT_ID`) | `az` CLI |
| **Lakekeeper API** | Client credentials (`LAKEKEEPER_AUTH_CLIENT_ID` / `LAKEKEEPER_AUTH_CLIENT_SECRET`) | — |

### Required Azure RBAC

- The job's managed identity needs **Key Vault Secrets User** on the Key Vault
- The Graph API client needs **GroupMember.Read.All** application permission
  (with admin consent)
- The Lakekeeper auth client needs an **app role assignment** on the Lakekeeper
  enterprise application

## Key Vault Secrets

The sync stores one secret per role:

| Secret Name | Contents |
| ------------- | ---------- |
| `lakekeeper-role-users-members` | JSON array of `{id, displayName, userPrincipalName}` |
| `lakekeeper-role-developers-members` | JSON array of `{id, displayName, userPrincipalName}` |

## Troubleshooting

### "Could not obtain Graph API token"

Expected in environments where `can_modify_entra = false`. Run step 1 locally
instead (see above).

### "No Key Vault token available"

The job's managed identity can't get a Key Vault token. Check that:

- The managed identity assigned to the job has **Key Vault Secrets User** role
- `AZURE_MI_CLIENT_ID` is set correctly (required when the container has a
  user-assigned managed identity)

### "No membership data found in Key Vault"

Step 1 hasn't been run yet, or the Key Vault secrets don't exist. Run step 1
locally or ensure the Graph API credentials are configured.

### Role creation returns 409

The role already exists — this is handled automatically. The script falls back
to listing roles and finding the existing one by name.