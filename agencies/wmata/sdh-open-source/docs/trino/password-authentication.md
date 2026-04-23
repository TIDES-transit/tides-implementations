# Trino Password Authentication

This guide explains how to create and use password authentication with Trino for applications that require username/password credentials.

## Overview

Password authentication in Trino uses bcrypt-hashed passwords stored in an `htpasswd`-format file mounted into the Trino coordinator container. This method is for applications that cannot use OAuth2 flows, such as JDBC-based tools like Metabase or Tableau.

Password users are defined in `tf/modules/apps/trino/main.tf` in the `trino_password_users` local.

## Adding a New Password User

### 1. Update OpenTofu Configuration

Edit `tf/modules/apps/trino/main.tf` and add your new user to the `trino_password_users` local:

```hcl
trino_password_users = {
    tableau = {
      display_name = "trino-client-tableau"
      description  = "Tableau password authentication to Trino"
    }
    your_new_user = {
      display_name = "trino-client-your-app"
      description  = "Your JDBC application authentication"
    }
}
```

### 2. Apply Changes

```bash
cd tf/envs/<environment>
tofu plan    # Review changes
tofu apply   # Apply
```

This creates:

1. A random 32-character password
2. A Key Vault secret named `trino-password-{username}`
3. A bcrypt-hashed `htpasswd` entry mounted into the Trino coordinator

### 3. Retrieve the Password

**From Key Vault (recommended):**

```bash
az keyvault secret show \
  --vault-name <keyvault-name> \
  --name "[SECRET_NAME]" \
  --query value -o tsv
```

**From OpenTofu output:**

```bash
tofu output -json password_user_credentials | jq -r '.your_new_user.password'
```

## Configuring Applications

For any application connecting to Trino via JDBC or password authentication:

| Setting | Value |
| --------- | ------- |
| Host | `<trino-app-name>.<cae-dns-suffix>` |
| Port | `443` |
| Username | The key from `trino_password_users` (e.g., `tableau`) |
| Password | Retrieved from Key Vault |
| SSL/TLS | Required (always HTTPS) |
| Catalog | `datahub` (or as configured) |

### Example: Metabase or Tableau Configuration

1. **Database type**: Trino
2. **Host**: the Trino Container App's external FQDN
3. **Port**: `443`
4. **Username**: `tableau`
5. **Password**: from Key Vault secret `trino-password-tableau`
6. **Catalog**: `datahub`
7. **Use SSL**: Yes

## Rotating Passwords

To rotate a password, force-replace the random password resource and re-apply:

```bash
cd tf/envs/<environment>
tofu apply -replace='module.trino.random_password.trino_password_users["tableau"]'
```

This generates a new password, updates the Key Vault secret, and regenerates the bcrypt hash. You will need to update the password in any applications that use it.