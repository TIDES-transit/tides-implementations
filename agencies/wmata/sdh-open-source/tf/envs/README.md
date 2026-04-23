# Environment Configuration

This directory contains environment-specific configurations for deploying infrastructure.

## Infrastructure Deployment Overview

The infrastructure deployment is organized into multiple stages because different resources require different permissions and dependencies. This staged approach allows deployment to proceed incrementally as [AGENCY] grants the necessary permissions and provisions prerequisite resources.

### Why Staged Deployment?

Azure resources in this infrastructure have varying requirements:

1. **Managed Identities** can be created with minimal permissions (just the resource group), but other resources need to reference these identities.

2. **Network-integrated resources** (Container App Environments, Private Endpoints) require subnets to be provisioned by [AGENCY] first, since [CONTRACTOR] does not have permissions to create or modify virtual networks.

3. **Database resources** require the `Microsoft.DBforPostgreSQL` provider to be registered in the subscription, which requires subscription-level permissions that [CONTRACTOR] does not have.

4. **Entra-dependent resources** (resources that use managed identity authentication) require role assignments to be made by [AGENCY] after the managed identities are created.

### Configuration Flags

The deployment uses three boolean flags in the `.auto.tfvars` file to control which resources are created:

| Flag | Purpose |
|------|---------|
| `has_network` | Enables resources that require subnet integration (Container App Environments, Private Endpoints) |
| `has_db_registration` | Enables PostgreSQL database resources |
| `has_entra` | Enables resources that depend on Entra role assignments |

These flags allow you to incrementally enable resources as prerequisites are satisfied.

### Network Configuration Reference

Each environment contains a `network/` subfolder (e.g., `tf/envs/[env1]/network/`) that defines the network resources required for the environment. These resources must be created by someone with permission to create or modify virtual networks and their integrated resources.

The network configuration serves two purposes:

1. **Reference specification** - The `main.tf` file documents exactly how network resources need to be configured, including subnet address spaces, delegations, and the Container App Environment settings. [AGENCY] can use this as a specification when creating the resources.

2. **Validation via import** - The `imports.tf` file contains import blocks that allow OpenTofu to import existing resources into state. Running `tofu plan` in the network folder will verify that the actual Azure resources match the expected configuration, highlighting any discrepancies.

To validate network resources after [AGENCY] creates them:

```bash
cd tf/envs/<env>/network
tofu init
tofu plan
```

If the plan shows no changes, the resources are configured correctly. Any differences will appear as planned changes, indicating what needs to be adjusted.

## Creating a New Environment

### Prerequisites

The following items require [AGENCY] intervention and must be completed before certain deployment steps:

1. **Resource Group** - Create a resource group for the environment (before step 1)
2. **Virtual Network and Subnets** - Create subnets for (before step 3):
   - Container Apps (ACA)
   - Private Endpoints
   - Databases
3. **Provider Registration** - Register the `Microsoft.DBforPostgreSQL` provider in the subscription (before step 4)
4. **Role Assignments** - Assign appropriate roles to managed identities (after step 2, before step 5)

### Deployment Steps

Follow these steps in order to deploy a new environment:

#### Step 1: Prepare Configuration

Copy an existing environment folder in `envs/` and update the `.auto.tfvars` file with values specific to your environment.

**Required variables for initial setup:**

```hcl
# Azure subscription and resource group
arm_subscription_id     = "..."
resource_group_name     = "..."
resource_group_location = "eastus"

# Naming conventions
system_name      = "[Project Name]"
environment_name = "..."
sys_short        = "[project]"
env_short        = "..."

# Configuration flags (start with all false)
has_network         = false
has_entra           = false
has_db_registration = false
```

#### Step 2: Create Managed Identities

This step creates user-assigned managed identities for each application workload. These identities will later be granted permissions to access other Azure resources (storage accounts, databases, etc.).

**Prerequisites:** Resource group must exist.

**Configuration flags:**

- `has_network = false`
- `has_db_registration = false`
- `has_entra = false`

**Creates:** User-assigned managed identities for Dagster, Trino, Lakekeeper, and OpenMetadata.

**Next:** After this step, work with [AGENCY] to assign necessary roles to the managed identities.

**Run:**

```bash
tofu apply
```

#### Step 3: Deploy Network Resources

This step creates resources that integrate with the virtual network. Container App Environments need a dedicated subnet to run containers, and private endpoints provide secure connectivity to Azure services without exposing them to the public internet.

**Prerequisites:** [AGENCY] must have created the required subnets:

- Container Apps subnet (delegated to `Microsoft.App/environments`)
- Private Endpoints subnet

**Configuration flags:**

- `has_network = true`
- `has_db_registration = false`
- `has_entra = false`

**Additional variables required:**

```hcl
# Subnet resource IDs (provided by [AGENCY])
cae_subnet_id = "/subscriptions/.../subnets/...-aca-snet"
pe_subnet_id  = "/subscriptions/.../subnets/...-pe-snet"

# DNS zone for private endpoints
dns_zone_subscription_id     = "..."
dns_zone_resource_group_name = "..."
```

**Creates:** Container App Environments, private endpoints, network interfaces.

**Run:**

```bash
tofu apply
```

#### Step 4: Deploy Database Resources

This step creates the PostgreSQL Flexible Server instance. The database is deployed into a private subnet and uses private endpoints for secure access. PostgreSQL Flexible Server requires the `Microsoft.DBforPostgreSQL` provider to be registered at the subscription level.

**Prerequisites:**

- Subnets must exist (from Step 3)
- [AGENCY] must register the `Microsoft.DBforPostgreSQL` provider in the subscription

**Configuration flags:**

- `has_network = true`
- `has_db_registration = true`
- `has_entra = false`

**Optional variables:**

```hcl
# Development access (optional - for direct database access during development)
psql_firewall_rules = {
  "allow-developer-name" = {
    start_ip_address = "x.x.x.x"
    end_ip_address   = "x.x.x.x"
  }
}
```

**Creates:** PostgreSQL Flexible Server, database private endpoints, database configurations.

**Run:**

```bash
tofu apply
```

#### Step 5: Deploy Entra-Dependent Resources

This step deploys resources that require the managed identities to have Entra ID (Azure AD) role assignments. These include resources that authenticate using managed identity credentials, such as applications connecting to storage accounts or databases using Entra authentication.

**Prerequisites:**

- All previous steps completed
- [AGENCY] must assign the required roles to the managed identities created in Step 2. Required roles include:
  - Storage Blob Data Contributor on relevant storage accounts
  - Appropriate database roles for PostgreSQL access

**Configuration flags:**

- `has_network = true`
- `has_db_registration = true`
- `has_entra = true`

**Additional variables required:**

```hcl
# App Registrations (created by [AGENCY] in Entra ID)
lakekeeper_app_registration_object_id   = "..."
trino_app_registration_object_id        = "..."
dagster_app_registration_object_id      = "..."
openmetadata_app_registration_object_id = "..."

# Service Principals (created by [AGENCY] in Entra ID)
lakekeeper_app_service_principal_object_id   = "..."
trino_app_service_principal_object_id        = "..."
dagster_app_service_principal_object_id      = "..."
openmetadata_app_service_principal_object_id = "..."

# App Client IDs (for identifier URIs)
lakekeeper_app_registration_client_id   = "..."
trino_app_registration_client_id        = "..."
dagster_app_registration_client_id      = "..."
openmetadata_app_registration_client_id = "..."

# App Client Secrets (store securely - these are sensitive)
lakekeeper_app_registration_client_secret   = "..."
trino_app_registration_client_secret        = "..."
dagster_app_registration_client_secret      = "..."
openmetadata_app_registration_client_secret = "..."

# Groups for access control
datahub_users_group_id = "..."
datahub_developers_group_id = "..."
```

**Creates:** Container Apps with managed identity authentication, application configurations that depend on role assignments.

**Run:**

```bash
tofu apply
```

## Troubleshooting

### Database Name Conflicts

If you encounter a conflict like:

```txt
Error: The resource '[Project Name]-[env1]-psql' already exists in location 'eastus'
```

This occurs when a database was previously deleted but the name is still reserved (typically for 7 days). Solutions:

1. **Wait** for the name reservation to expire (7 days)
2. **Use a different name** by adding `resource_name_overrides` to your module call:

   ```hcl
   resource_name_overrides = {}
   ```

### Location Restrictions

If you encounter quota issues in a specific region, you can override the database location as a temporary workaround by adding the following to your `.auto.tfvars` file:

```hcl
db_location_override = "centralus"
resource_name_overrides = {}
```

> NOTE: This is a temporary fix and you should coordinate with [AGENCY] to resolve quota issues in the intended region. Afterwards, if you change the location, you will need to use a different database name due to name reservation rules.