# Infrastructure as Code with OpenTofu

The `tf/` directory contains all infrastructure configuration for the [Project Name], written in [OpenTofu](https://opentofu.org/) — an open-source implementation of Terraform. This document explains the structure of that directory and how to work with it.

## Background: How OpenTofu Works

If you're new to Terraform or OpenTofu, here are the key concepts you'll encounter.

### State

OpenTofu tracks the real-world resources it has created in a **state file**. This file maps configuration in the code to actual Azure resources. The state file for this project is stored remotely in an Azure Storage Account so that multiple engineers can share it. When you run `tofu init`, OpenTofu downloads the current state from Azure before doing anything else.

You should never manually edit the state file or delete Azure resources outside of OpenTofu without coordinating on state. If you do, the state will drift from reality and OpenTofu will get confused on the next apply.

For more background, see the [OpenTofu documentation on state](https://opentofu.org/docs/language/state/).

### Providers

Providers are plugins that teach OpenTofu how to talk to a particular service. This project uses the `azurerm` provider (for Azure Resource Manager), `azuread` (for Entra ID / Azure Active Directory), and a few others. When you run `tofu init`, OpenTofu downloads the required providers automatically.

### Modules

OpenTofu **modules** are reusable packages of configuration. Think of them like functions — a module accepts inputs (variables), creates some resources, and can return outputs.

This project uses a two-layer module structure:

- The **`common` module** contains shared infrastructure that all applications depend on: the storage accounts, key vault, PostgreSQL server, private endpoints, and Container App Environment.
- Each **app module** (e.g., `lakekeeper`, `trino`, `dagster`) contains the configuration for a single application. App modules receive the `common` module's outputs as inputs (e.g., the key vault ID, storage account ID).

The environment folders (e.g., `tf/envs/[env1]/`) are the entry points. They instantiate the `common` module and each app module, wiring them together with the right variables.

For more on modules, see [OpenTofu modules documentation](https://opentofu.org/docs/language/modules/).

---

## Directory Structure

```text
tf/
├── envs/                        # Environment-specific configurations (entry points)
│   ├── [env1]/                     # Development environment
│   ├── [env2]/                     # Staging environment (currently serving as production)
│   ├── consultant/              # Self-contained reference environment
│   └── [env3]/                     # Proof of concept (largely obsolete)
├── modules/
│   ├── common/                  # Shared infrastructure used by all environments
│   ├── apps/                    # Application-specific modules
│   │   ├── dagster/             # Dagster data orchestration platform
│   │   ├── lakekeeper/          # Lakekeeper Iceberg REST catalog
│   │   ├── trino/               # Trino distributed SQL query engine
│   │   ├── openmetadata/        # OpenMetadata data catalog
│   │   ├── metabase/            # Metabase business intelligence
│   │   ├── opa/                 # Open Policy Agent (access control policies)
│   │   └── openfga/             # OpenFGA fine-grained authorization
│   ├── machine_users/           # OAuth2 service principal (machine user) configuration
│   └── debug/                   # Debugging and network testing tools
└── create_state_storage.sh      # One-time script for bootstrapping Terraform state storage
```

### Environment folders (`envs/`)

Each environment folder is a self-contained OpenTofu root. You `cd` into it and run `tofu` commands from there. It contains:

| File | Purpose |
|------|---------|
| `main.tf` | Instantiates the common module and all app modules for this environment |
| `providers.tf` | Configures the Azure provider (subscription ID, state backend) |
| `variables.tf` | Declares input variables |
| `.auto.tfvars` | Provides variable values; loaded automatically by OpenTofu, and gitignored |
| `.tfvars.template` | Template showing what values are needed (safe to commit; actual values are in `.auto.tfvars` which is gitignored) |
| `.terraform.lock.hcl` | Records the exact provider versions in use; should be committed |
| `imports.tf` | Import blocks for any resources that were created outside OpenTofu and need to be brought under management; can usually be ignored; see the [OpenTofu Import documentation](https://opentofu.org/docs/language/import/) for details |

Some environments have a `network.tf` file — this is used to document the network resources that should be created in order for a [Project Name] environment to function correctly (see [Environment Provisioning](#environment-provisioning)).

### Common module (`modules/common/`)

Contains the foundational Azure resources shared across all application workloads:

| File | What it creates |
|------|----------------|
| `main.tf` | Container Registry, tags, and core resource orchestration |
| `identities.tf` | User-assigned managed identities for each application workload |
| `storage.tf` | Data lake storage account (ADLS Gen2), files storage account for OPA policies |
| `databases.tf` | PostgreSQL Flexible Server; databases and users for each application |
| `container_apps.tf` | Container App Environment integration |
| `networking.tf` | Private endpoints and DNS records for all Azure services |
| `secrets.tf` | Key Vault secrets for passwords, client secrets, and credentials |
| `entra.tf` | Entra ID resources (used only when `can_modify_entra = true`) |
| `outputs.tf` | Outputs passed to app modules (IDs, URLs, credentials) |
| `variables.tf` | All input variables accepted by the common module |

### Application modules (`modules/apps/`)

Each application module creates the Azure Container App(s) and supporting resources for one service:

| Module | What it deploys |
|--------|----------------|
| `dagster/` | Dagster daemon, webserver, and user-code containers; Entra authentication via Azure Container Apps built-in auth |
| `lakekeeper/` | Lakekeeper Iceberg REST catalog; warehouse ADLS containers; management Container App Jobs (migrations, bootstrap, warehouse sync, grants sync) |
| `trino/` | Trino coordinator and worker Container Apps; OAuth2/JWT/password authentication; Iceberg catalog configuration pointing to Lakekeeper |
| `openmetadata/` | OpenMetadata server and OpenSearch Container Apps; Entra SSO; JWT signing keys in Key Vault |
| `metabase/` | Metabase Container App; Entra authentication via Azure Container Apps built-in auth |
| `opa/` | Open Policy Agent Container App; downloads `.rego` policy files from the Lakekeeper repository; custom extension policies stored in Azure Files |
| `openfga/` | OpenFGA fine-grained authorization server; PostgreSQL database; bootstrap Container App Job |

See `docs/infrastructure/lakekeeper.md` for Lakekeeper-specific operational details, and `docs/infrastructure/trino.md` for Trino-specific details.

### Other modules

| Module | Purpose |
|--------|---------|
| `modules/machine_users/` | Configures OAuth2 service principals (non-human "machine users") that authenticate to the data platform programmatically |
| `modules/debug/` | Debug and connectivity test Container App Jobs: DNS resolution tests, PostgreSQL connectivity test, Trino connectivity test, PyIceberg/Lakekeeper test, and a general-purpose shell job |

---

## Environments

### `[env1]/` — Development

The primary environment for testing infrastructure changes. Changes should be applied here first before being promoted to staging. It shares a subscription and resource group with staging (`[RESOURCE_GROUP]`), but has its own subnets and Container App Environment.

### `[env2]/` — Staging

Currently serving as the production environment for the [Project Name]. Shares infrastructure with `[env1]/` at the networking level but is otherwise independent.

### `consultant/` — Reference environment

A self-contained environment that serves as a reference implementation of an ideal deployment. Unlike `[env1]/` and `[env2]/`, it has `can_modify_entra = true`, meaning OpenTofu manages the Entra ID app registrations directly (rather than requiring manual creation by a [AGENCY] administrator). It is useful as a model for what a fully automated future environment setup would look like.

### `[env3]/` — Proof of concept

The original proof-of-concept environment, used during initial development. It is largely obsolete — its configuration reflects earlier architectural decisions that have since been revised. It is kept in the repository for historical reference.

---

## Getting Set Up Locally

1. Install the [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)

2. Install [OpenTofu](https://opentofu.org/docs/intro/install/)

3. Ensure your Azure account (`AA...` account) has the **Contributor** role on the subscription. This is typically granted via **PIM (Privileged Identity Management)** → **My roles** → **Azure resources** → activate Just-in-time access.

4. Log in:

   ```bash
   az login
   # If using WSL and the browser doesn't open automatically:
   az login --use-device-code
   ```

5. `cd` into the environment you want to work with:

   ```bash
   cd tf/envs/[env1]
   ```

6. Initialize OpenTofu (downloads providers and pulls state from Azure):

   ```bash
   tofu init
   ```

7. Preview changes without applying them:

   ```bash
   tofu plan
   ```

8. Apply changes:

   ```bash
   tofu apply
   ```

---

## Environment Provisioning

Deploying a new environment (or adding new capabilities to an existing one) is a staged process. Some Azure resources can only be created after [AGENCY] has provisioned prerequisites — for example, subnets must exist before private endpoints can be created, and managed identities must exist before role assignments can be made.

Three feature flags in each environment's `.auto.tfvars` file control which resources are active:

| Flag | What it enables | When to set to `true` |
|------|----------------|----------------------|
| `has_db_registration` | PostgreSQL Flexible Server | After `Microsoft.DBforPostgreSQL` resource provider is registered |
| `has_network` | Container App Environment integration, all private endpoints, DNS records | After [AGENCY] provisions the VNet, subnets, and private DNS zones |
| `has_entra` | All Container App deployments (Dagster, Trino, Lakekeeper, etc.) | After [AGENCY] creates Entra ID app registrations and grants RBAC role assignments to managed identities |

The typical deployment sequence is:

1. **Intra engineer applies** with all flags `false` → creates managed identities, storage accounts, Key Vault, Container Registry
2. **[AGENCY] provisions** virtual network, subnets, Container App Environment, and private DNS zones
3. **Intra engineer applies** with `has_network = true` → creates private endpoints and Container App Environment integration
4. **[AGENCY] registers** the `Microsoft.DBforPostgreSQL` provider
5. **Intra engineer applies** with `has_db_registration = true` → creates PostgreSQL server and databases
6. **[AGENCY] creates** Entra ID app registrations, client secrets, and assigns RBAC roles to the managed identities
7. **Intra engineer applies** with `has_entra = true` → deploys all Container Apps

For the full [AGENCY]-side provisioning checklist, see [ENVIRONMENT_PROVISIONING_CHECKLIST.md](./ENVIRONMENT_PROVISIONING_CHECKLIST.md).

For detailed notes on each deployment step, including required variables and troubleshooting, see the [`tf/envs/README.md`](../../tf/envs/README.md) file in the repository.

### Network validation

Some environments have a `network/` subfolder (e.g., `tf/envs/[env3]/network/`). This is a separate OpenTofu root that imports the [AGENCY]-managed network resources into state and can be used to verify they are configured as expected:

```bash
cd tf/envs/<env>/network
tofu init
tofu plan
```

A clean plan (no changes) means the network resources match the specification. Any differences appear as planned changes, indicating what needs to be adjusted.

---

## Required Azure Permissions

The person running `tofu apply` needs the following:

| Permission | Scope | Why |
|-----------|-------|-----|
| **Contributor** | Resource group (or subscription) | Create and manage all Azure resources |
| **Key Vault Secrets Officer** (or Owner) | Key Vault | Read and write secrets created by OpenTofu |
| **Storage Blob Data Contributor** | Terraform state storage account | Read and write the OpenTofu state file |

Additionally, the following permissions are required for specific deployment stages:

| Permission | Scope | When needed |
|-----------|-------|-------------|
| **User Access Administrator** | Resource group | Only if OpenTofu is managing RBAC role assignments (typically done by [AGENCY] in `[env1]`/`[env2]`) |
| **Application Administrator** or **Cloud Application Administrator** | Entra ID | Only when `can_modify_entra = true` (e.g., `consultant` environment) |

In `[env1]` and `[env2]` environments, `can_modify_entra = false`, so Entra resources must be created manually by a [AGENCY] administrator before applying the final deployment stage. The [ENVIRONMENT_PROVISIONING_CHECKLIST.md](./ENVIRONMENT_PROVISIONING_CHECKLIST.md) covers exactly what needs to be created.