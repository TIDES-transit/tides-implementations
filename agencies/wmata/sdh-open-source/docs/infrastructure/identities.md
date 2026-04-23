# Identities and Permissions

This document is a reference for all identities (managed identities, service principals, Entra groups, database users) in the [Project Name], what they are used for, and what permissions they require.

For how these identities interact at runtime to enforce data access control, see [Authorization Architecture](./authorization.md).

---

## System Components

The following table maps each system component to the Azure or [project] service that hosts it, and documents which identities need access.

### Data Storage

| Service | Component | Purpose | Requirements |
|---------|-----------|---------|--------------|
| Azure Blob Storage (ADLS Gen2) | Data lake | Stores all Iceberg table data and metadata files | Readable/Writable by **Lakekeeper SP**, **Trino MI**, **Dagster MI** via `Storage Blob Data Contributor` role |
| Azure Files | OPA policy store | Stores `.rego` policy files loaded by OPA at startup | Written by the `tofu apply` provisioner (via storage account key); mounted read-only by **OPA Container App** |
| Azure Key Vault | Secret store | Stores passwords, client secrets, encryption keys, and Entra group membership data | Readable by **Dagster MI**, **OpenMetadata MI**, **Metabase MI** (`Key Vault Secrets User`); Readable/Writable by **Lakekeeper MI** (`Key Vault Secrets Officer`) |
| Azure Container Registry | Container image registry | Stores custom container images (Lakekeeper scripts, OpenFGA scripts, Dagster user code) | Pullable by **Dagster MI** (`AcrPull`); Lakekeeper and OpenFGA jobs use Dagster's MI for image pulls until their own MIs are granted `AcrPull` |

### Databases

| Service | Component | Purpose | Requirements |
|---------|-----------|---------|--------------|
| PostgreSQL Flexible Server | Lakekeeper database | Stores Lakekeeper's catalog metadata, warehouse configs, and encrypted secrets | Accessible by **lakekeeper** PostgreSQL user (CONNECT, CREATE on database; USAGE, CREATE on schema) |
| PostgreSQL Flexible Server | OpenMetadata database | Stores OpenMetadata's catalog, lineage, and governance data | Accessible by **openmetadata** PostgreSQL user (CONNECT, CREATE on database; USAGE, CREATE on schema) |
| PostgreSQL Flexible Server | OpenFGA database | Stores OpenFGA's authorization tuples and models | Accessible by **openfga_user** PostgreSQL user (CONNECT, CREATE on database; USAGE, CREATE on schema) |
| PostgreSQL Flexible Server | Metabase database | Stores Metabase application state (dashboards, questions, users) | Accessible by **metabase_user** PostgreSQL user (CONNECT, CREATE on database; USAGE, CREATE on schema) |

### Application Services

| Service | Component | Purpose | Requirements |
|---------|-----------|---------|--------------|
| Lakekeeper | Iceberg REST catalog | Indexes data tables in the data lake; mediates metadata access; defines the permission model for data access | Authenticated access by **Trino** (for catalog queries), **Dagster** (for table management), **OPA** (for permission checks). Human users access the Lakekeeper UI via OAuth2. |
| Trino | SQL query engine | Provides SQL access to data lake tables via the Iceberg catalog | Authenticated access by human users (OAuth2 / password) and service principals (Dagster). Delegates all authorization decisions to **OPA**. |
| OPA | Policy agent | Evaluates authorization decisions for Trino by checking permissions against the Lakekeeper API | Needs service principal credentials to authenticate to **Lakekeeper**. Currently uses the **Trino SP** credentials. |
| OpenFGA | Authorization store | Stores and evaluates Lakekeeper's fine-grained permission model (which users have which roles on which resources) | Called by **Lakekeeper** via gRPC. Authenticated with a preshared key stored in Key Vault. |
| Dagster | Data orchestration | Runs data pipelines (dbt transformations, metadata ingestion, table management) | Needs access to **Trino** (SQL queries), **Lakekeeper** (catalog API), **OpenMetadata** (metadata ingestion), **ADLS** (data files), **Key Vault** (secrets) |
| OpenMetadata | Data catalog UI | Provides data discovery, lineage tracking, and governance interface | Needs access to **PostgreSQL** (application state), **Key Vault** (JWT signing keys). Human users access via OAuth2. |
| Metabase | Business intelligence | Provides dashboards and data visualization | Needs access to **PostgreSQL** (application state), **Key Vault** (database credentials). Human users access via Entra authentication. |

---

## Identity Inventory

### Managed Identities

Managed identities are Azure-native identities assigned to workloads. They authenticate automatically without stored credentials. The `entra.tf` file in each app module defines the ideal role assignments; in `[env1]`/`[env2]` these must be assigned manually by [AGENCY].

| Identity | Resource Name Pattern | Used By | Required Azure RBAC Roles |
|----------|----------------------|---------|---------------------------|
| Dagster MI | `{system}-{env}-workload-dagster-mi` | Dagster daemon, webserver, and user-code containers | `Storage Blob Data Contributor` and `Storage Blob Delegator` on data lake; `Key Vault Secrets User` on Key Vault; `AcrPull` on Container Registry |
| Trino MI | `{system}-{env}-workload-trino-mi` | Trino coordinator and worker containers (for direct ADLS access) | `Storage Blob Data Contributor` and `Storage Blob Delegator` on data lake |
| Lakekeeper MI | `{sys_short}-{env_short}-workload-lakekeeper-mi` | Lakekeeper bootstrap and grants sync Container App Jobs | `Key Vault Secrets Officer` on Key Vault; `AcrPull` on Container Registry; default app role on the Lakekeeper enterprise app |
| OpenMetadata MI | `{system}-{env}-workload-openmetadata-mi` | OpenMetadata server container | `Key Vault Secrets User` on Key Vault |
| Metabase MI | `{system}-{env}-workload-metabase-mi` | Metabase container | `Key Vault Secrets User` on Key Vault |

> **Note — `[env1]`/`[env2]` workaround:** The Lakekeeper MI does not yet have `AcrPull` in `[env1]`/`[env2]`. Until [AGENCY] assigns this role, the Lakekeeper and OpenFGA Container App Jobs use the **Dagster MI** for image pulls. See [Credential Sharing](#credential-sharing-between-services) below.

### App Registrations (Service Principals)

App registrations are Entra ID identities used for OAuth2 authentication. The `entra.tf` file in each app module defines the ideal configuration (used in the `consultant` environment where `can_modify_entra = true`). In `[env1]` and `[env2]`, these are created manually by [AGENCY] to match the same specification.

| Service Principal | Display Name | Purpose | Key Permissions |
|-------------------|--------------|---------|-----------------|
| Lakekeeper SP | Lakekeeper - [Project Name] | OAuth2 authentication for Lakekeeper UI; ADLS storage access for warehouse data; Graph API access for grants sync job | `Storage Blob Data Contributor` on data lake; `GroupMember.Read.All` (Microsoft Graph application permission — for reading Entra group membership); self-assigned default app role (for client credentials flow); defines a custom OAuth2 scope (`Lakekeeper`) consumed by Trino and Dagster |
| Trino SP | Trino - [Project Name] | OAuth2 authentication for human users logging into Trino; client credentials for Trino-to-Lakekeeper catalog access | Default app role on Lakekeeper SP (enables client credentials flow); admin consent grants for Microsoft Graph (`User.Read`, `offline_access`, `openid`, `profile`, `email`) and Lakekeeper API (`user_impersonation`) scopes |
| Dagster SP | Dagster - [Project Name] | OAuth2 authentication for Dagster webserver (via Container Apps built-in auth); client credentials for Dagster-to-Trino and Dagster-to-Lakekeeper access | Default app role on Trino SP and Lakekeeper SP; Lakekeeper API scope access; `data_admin` grant in Lakekeeper (project-level) |
| OpenMetadata SP | OpenMetadata - [Project Name] | OAuth2 authentication for OpenMetadata web UI | Implicit grant flow (ID token issuance); default app role assigned to users group |

> **Note — `[env1]`/`[env2]` workaround:** OPA and the Lakekeeper bootstrap job each need an SP with a default app role on the Lakekeeper enterprise app (to use client credentials flow against the Lakekeeper API). In the ideal setup, these would be separate SPs. In `[env1]`/`[env2]`, they both use the **Trino SP** because it already has this role assignment, avoiding additional Entra provisioning. See [Credential Sharing](#credential-sharing-between-services) below.

### Entra ID Groups

| Group | Display Name | Purpose | Application Access |
|-------|--------------|---------|-------------------|
| Users group | [Project Name] Users - {env} | Human users with read-only access — can query data through Trino and reference documentation in OpenMetadata | App role assignments on **Lakekeeper**, **Trino**, **Metabase**, and **OpenMetadata** (grants login access); maps to Lakekeeper `users` role via grants sync |
| Developers group | [Project Name] Developers - {env} | Human users with read/write access — can also kick off data processing pipelines and manage table definitions | All of the above, plus app role assignment on **Dagster**; maps to Lakekeeper `developers` role via grants sync |

### PostgreSQL Database Users

All database passwords are randomly generated and stored in Key Vault.

| User | Database | Key Vault Secret | Privileges |
|------|----------|-----------------|------------|
| `lakekeeper_user` (configurable) | `lakekeeper` | `lakekeeper-postgres-password` | CONNECT, CREATE on database; USAGE, CREATE on public schema |
| `openmetadata_user` (configurable) | `openmetadata` | `openmetadata-postgres-password` | CONNECT, CREATE on database; USAGE, CREATE on public schema |
| `openfga_user` | `openfga` | `openfga-postgres-password` | CONNECT, CREATE on database; USAGE, CREATE on public schema |
| `metabase_user` | `metabase` | `metabase-postgres-password` | CONNECT, CREATE on database; USAGE, CREATE on public schema |

### Lakekeeper Roles (Data Access)

These roles are defined in Lakekeeper and synced from Entra group membership by the grants sync job. They control who can query what data via Trino.

| Lakekeeper Role | Mapped From | Scope | Grants |
|-----------------|-------------|-------|--------|
| `users` | Users Entra group<br>via `grants-caj` job | Project level | `describe`, `select` (read-only access to all tables in the project) |
| `developers` | Developers Entra group<br>via `grants-caj` job | Server level | `admin`, `operator` (full management access) |
| `data_admin` (Dagster SP) | Direct assignment via `app_sp_grants` | Project level | Full data admin (read, write, create, drop tables) |
| `data_admin` (Trino SP) | Direct assignment via `app_sp_grants` | Project level | Full data admin (read, write, create, drop tables) |

For more on Lakekeeper's grant model, see the [Lakekeeper authorization documentation](https://docs.lakekeeper.io/docs/0.9.x/authorization/#grants).

---

## Credential Sharing Between Services

In the `[env1]` and `[env2]` environments (where `can_modify_entra = false`), some services share credentials out of practical necessity:

| Credential | Owner | Also Used By | Why |
|-----------|-------|-------------|-----|
| Trino SP client ID/secret | Trino | OPA (as `opa_client_id`/`opa_client_secret`), Lakekeeper bootstrap job (as `bootstrap_client_id`/`bootstrap_client_secret`) | The Trino SP has an app role assignment on the Lakekeeper enterprise app, which is required for client credentials flow. Creating separate SPs for OPA and bootstrap would require additional [AGENCY] Entra provisioning. |
| Dagster MI | Dagster | Lakekeeper jobs and OpenFGA jobs (as `workload_identity_id` for ACR image pulls) | Dagster's MI has the `AcrPull` role. Lakekeeper and OpenFGA MIs need this role assigned separately by the [AGENCY] security team. |

In the `consultant` environment (where `can_modify_entra = true`), each service has its own dedicated credentials.

---

## Related Documentation

- [Authorization Architecture](./authorization.md) — How these identities interact at runtime to enforce data access control
- [Environment Provisioning Checklist](./ENVIRONMENT_PROVISIONING_CHECKLIST.md) — Step-by-step guide for [AGENCY] to create these identities
- [Authentication Overview](../authentication/overview.md) — How users and services authenticate to each component