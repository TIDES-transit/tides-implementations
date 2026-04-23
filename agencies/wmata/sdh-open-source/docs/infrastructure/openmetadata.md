# OpenMetadata

OpenMetadata is the data catalog for the [Project Name]. It stores metadata about datasets, pipelines, and data quality results, and provides a web interface for exploring and governing the data platform.

## Architecture

The OpenMetadata module deploys two Container Apps:

- **OpenMetadata server** (`[Project Name]-{env}-openmetadata-ca`): The main application, backed by PostgreSQL
- **OpenSearch** (`[Project Name]-{env}-openmetadata-opensearch-ca`): The search index used by OpenMetadata for full-text search

OpenMetadata is populated by Dagster pipelines that run dbt and push metadata through the OpenMetadata ingestion API. See the [OpenMetadata integration overview](../openmetadata/integration-overview.md) for how Dagster, dbt, and OpenMetadata fit together.

## JWT Signing Keys

OpenMetadata uses RSA key pairs to sign internal JWT tokens for service-to-service authentication. These keys are stored in Key Vault and mounted into the container at `/opt/openmetadata-jwt-keys/`.

The keys are committed to the repository in `tf/modules/apps/openmetadata/` as `private_key.der`, `public_key.der`, and `private_key.pem`. These are environment-shared keys — each environment uses the same keys.

### Regenerating the Keys

If you need to generate new JWT keys (e.g., for a new environment that needs its own keys):

```bash
# Generate RSA private key
openssl genrsa -out private_key.pem 2048

# Convert private key to PKCS8 DER format (required by OpenMetadata)
openssl pkcs8 -topk8 -inform PEM -outform DER -in private_key.pem -out private_key.der -nocrypt

# Extract public key in DER format
openssl rsa -in private_key.pem -pubout -outform DER -out public_key.der
```

Then store the keys in Key Vault:

```bash
az keyvault secret set \
  --vault-name <keyvault-name> \
  --name "[SECRET_NAME]" \
  --value "$(base64 -w 0 private_key.der)"

az keyvault secret set \
  --vault-name <keyvault-name> \
  --name "[SECRET_NAME]" \
  --value "$(base64 -w 0 public_key.der)"
```

## Authentication

OpenMetadata uses Entra ID (Azure AD) for user authentication via SSO. Users are redirected to their Azure AD login when they access the OpenMetadata web interface.

The app registration redirect URI is `https://[Project Name]-{env}-openmetadata-ca.{cae-domain}/callback`, and the logout URL is `https://[Project Name]-{env}-openmetadata-ca.{cae-domain}/signout`.