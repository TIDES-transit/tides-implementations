# Trino Authentication Overview

> **Note**: For platform-wide authentication architecture, see the [Authentication Overview](../authentication/overview.md).

This document provides an overview of authentication methods available for accessing Trino in the [AGENCY] [Project Name] platform.

## Authentication Methods

The Trino deployment supports three authentication methods that can be used simultaneously:

### 1. Interactive OAuth2 Authentication

For human users accessing Trino through the web UI or CLI:

- **Web UI**: Navigate to the Trino URL and authenticate via Entra ID
- **CLI**: Use external authentication with the Trino CLI:

```bash
trino https://<trino-app-name>.<cae-dns-suffix>/ --external-authentication
```

This method uses the OAuth2 authorization code flow. The user must be a member of the [Project Name] Users (or Developers) Entra group, which grants an app role assignment on the Trino enterprise app.

**Admin consent**: The Trino app registration requires tenant-wide admin consent for delegated permissions (Microsoft Graph scopes and the Lakekeeper API scope). When `can_modify_entra = true`, this is handled automatically by OpenTofu. Otherwise, an Entra administrator must grant consent manually — see `tf/modules/apps/trino/entra.tf` for details.

### 2. OAuth2 Client Credentials (Service Principals)

For service-to-service access (e.g., Dagster running queries):

- Uses Azure AD service principal credentials
- Implements the OAuth2 client credentials flow
- The calling SP must have a default app role assignment on the Trino enterprise app

### 3. Password Authentication

For applications that require username/password authentication (typically JDBC-based tools):

- Uses bcrypt-hashed passwords stored in an `htpasswd`-format file
- Passwords are randomly generated and stored in Azure Key Vault
- Currently configured for: `tableau`

Password users are defined in `tf/modules/apps/trino/main.tf` in the `trino_password_users` local. To add a new password user, add an entry to that map and run `tofu apply`.

See [Trino Password Authentication](password-authentication.md) for setup and retrieval details.