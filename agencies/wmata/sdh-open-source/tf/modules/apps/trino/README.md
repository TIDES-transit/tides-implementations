# Trino Module

This module deploys a Trino distributed SQL query engine on Azure Container Apps with OAuth2/JWT/Password authentication.

## Architecture

The module deploys Trino in a distributed configuration:

- **Coordinator** (`{app_name}`): Handles query planning, authentication, and web UI
- **Workers** (`{app_name}-wrk-ca`): Execute query fragments and process data

Both coordinator and workers connect to:

- **Lakekeeper**: REST catalog for Iceberg tables
- **Azure Data Lake Storage**: For reading/writing data files

## Authentication Methods

Trino supports three authentication methods:

| Method | Use Case | Configuration |
|--------|----------|---------------|
| **OAuth2** | Human users via web UI | Azure AD login with refresh tokens |
| **JWT** | Machine-to-machine (e.g., Dagster) | Service principal access tokens |
| **Password** | Legacy clients (e.g., Tableau, Metabase) | htpasswd file with bcrypt hashes |

## Prerequisites

### Admin Consent (Required)

The Trino app registration requires tenant-wide admin consent before users can sign in. This is because the app requests delegated permissions for:

- Microsoft Graph: `User.Read`, `offline_access`, `openid`, `profile`, `email`
- Lakekeeper API: `user_impersonation`

**When `can_modify_entra = true`:**

Admin consent is granted automatically via OpenTofu using `azuread_service_principal_delegated_permission_grant` resources.

**When `can_modify_entra = false`:**

An Azure AD administrator must manually grant consent:

1. **Via Azure Portal:**
   - Navigate to **Microsoft Entra ID** > **Enterprise applications**
   - Find **"Trino - [Project Name]"**
   - Go to **Permissions** > Click **"Grant admin consent for [tenant]"**

2. **Via Admin Consent URL:**

   ```txt
   https://login.microsoftonline.com/{tenant-id}/adminconsent?client_id={trino-client-id}
   ```

### Other Prerequisites

- Azure Container App Environment
- Lakekeeper service deployed and accessible
- Azure Data Lake Storage account with appropriate RBAC
- Key Vault for storing secrets

## Usage

```hcl
module "trino" {
  source = "../../modules/apps/trino"

  tenant_id                             = data.azurerm_client_config.current.tenant_id
  system_name                           = "[Project Name]"
  environment_name                      = "[env1]"
  cae_dns_suffix                        = "example.eastus.azurecontainerapps.io"
  resource_group_name                   = "my-resource-group"
  resource_group_location               = "eastus"
  datahub_users_group_id                = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  datahub_container_app_environment_id  = module.common.container_app_environment_id
  datahub_key_vault_id                  = module.common.key_vault_id
  datahub_lake_storage_account_id       = module.common.lake_storage_account_id
  lakekeeper_app_registration_client_id = module.lakekeeper.app_registration_client_id
  lakekeeper_oauth2_permission_scope_id = module.lakekeeper.oauth2_permission_scope_id
  lakekeeper_catalog_url                = module.lakekeeper.lakekeeper_catalog_url
  can_modify_entra                      = false

  # Required when can_modify_entra = false
  app_registration_client_id     = var.trino_app_registration_client_id
  app_registration_client_secret = var.trino_app_registration_client_secret
  app_name                       = "[Project Name]-[env1]-trino-ca"
}
```

## Variables

| Name | Description | Type | Required |
|------|-------------|------|----------|
| `tenant_id` | Azure AD tenant ID | string | yes |
| `system_name` | System name (e.g., "[Project Name]") | string | yes |
| `environment_name` | Environment name (e.g., "[env1]", "prod") | string | yes |
| `app_name` | Container app name following `{system}-{env}-trino-ca` format | string | yes |
| `cae_dns_suffix` | DNS suffix for the Container App Environment | string | yes |
| `can_modify_entra` | Whether OpenTofu can manage Entra ID resources | bool | no (default: false) |
| `trino_image_tag` | Trino container image tag | string | no (default: "473") |
| `lakekeeper_catalog_url` | URL of Lakekeeper REST catalog endpoint | string | yes |

See `variables.tf` for the complete list of variables.

## Outputs

| Name | Description |
|------|-------------|
| `app_registration_client_id` | Client ID of the Trino app registration |
| `trino_url` | URL of the Trino coordinator (for clients) |
| `password_user_credentials` | Credentials for password-authenticated users (e.g., Tableau) |

## Password Users

Password-based authentication is configured for clients that cannot use OAuth2 (e.g., JDBC connections from Tableau or Metabase). Passwords are:

1. Auto-generated using `random_password`
2. Stored in Key Vault as `trino-password-{username}`
3. Hashed with bcrypt for the Trino password file

Current password users:

- `tableau`: For Tableau Server/Desktop connections

To add a new password user, add an entry to `local.trino_password_users` in `main.tf`.

## Troubleshooting

### "Approval required" error on login

See [Admin Consent](#admin-consent-required) above. An administrator needs to grant consent for the Trino app.

### Workers not connecting to coordinator

Check that workers can resolve the coordinator's internal DNS name. Workers use `discovery.uri=http://{coordinator-app-name}` for service discovery.

### Lakekeeper catalog not accessible

Verify:

1. The `lakekeeper_catalog_url` is correct (should be the FQDN, not a hardcoded subdomain)
2. Trino's OAuth2 credentials have the Lakekeeper API scope
3. Lakekeeper service is running and healthy