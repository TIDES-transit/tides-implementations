# Dagster Deployment Guide

This document provides information about the Dagster deployment in the [Project Name] project. The Terraform configuration files referenced in this guide are located in the `tf/` directory of the repository.

## Overview

We're using Dagster as the orchestration engine for the [Project Name] data pipelines. It's deployed in the Azure Kubernetes Service (AKS) cluster using Terraform and Helm.

## Architecture

The Dagster deployment consists of the following components:

1. **Dagster Webserver**: The web UI for Dagster, accessible at `[APP_URL]`
2. **Dagster Daemon**: The background process that runs schedules and sensors
3. **Dagster User Deployments**: The user code deployments that contain the assets, resources, and schedules

The deployment is configured with Entra ID authentication to secure access to the Dagster webserver.

## Prerequisites

- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
- [Terraform](https://www.terraform.io/downloads.html) or [OpenTofu](https://opentofu.org/docs/intro/install/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)

## Configuration

The Dagster deployment is configured using Terraform in the following files:

- `tf/dagster.tf`: The main Terraform configuration for the Dagster deployment
- `tf/secrets/gtfs-api-credentials.env.template`: Template for the GTFS API credentials

### Environment Setup

1. Log in to Azure CLI:

   ```bash
   az login
   ```

2. Verify you're using the correct subscription:

   ```bash
   az account show
   ```

3. Create a `.auto.tfvars` file based on the `.tfvars.template` file:

   ```bash
   cd tf
   cp .tfvars.template .auto.tfvars
   ```

4. Update the `.auto.tfvars` file with your environment-specific values, including:

   ```tf
   arm_subscription_id  = "your-subscription-id"
   dns_zone_name        = "your-dns-zone-name"
   # Other environment-specific values
   ```

   _Note: Authentication for Dagster and Trino is handled automatically through Azure AD OAuth machine users defined in machine_users.tf._

## Deployment

The Dagster deployment is managed through Terraform. To deploy or update Dagster:

1. Initialize Terraform:

   ```bash
   cd tf
   tofu init
   ```

2. Clean up existing Dagster resources (if needed):

   ```bash
   kubectl delete deployment -n dagster dagster-daemon dagster-dagster-user-deployments-tides-infra dagster-dagster-webserver
   kubectl delete service -n dagster dagster-dagster-webserver
   kubectl delete configmap -n dagster dagster-daemon-env dagster-dagster-user-deployments-tides-infra-user-env dagster-dagster-user-deployments-user-deployments-shared-env dagster-flower-env dagster-instance dagster-pipeline-env dagster-pipelines dagster-repository dagster-webserver-env dagster-workspace-yaml
   kubectl delete secret -n dagster dagster-postgresql-secret sh.helm.release.v1.dagster.v1 sh.helm.release.v1.dagster.v2 sh.helm.release.v1.dagster.v3 sh.helm.release.v1.dagster.v4
   ```

3. Generate a Terraform plan:

   ```bash
   tofu plan
   ```

4. Apply the Terraform configuration:

   ```bash
   tofu apply
   ```

## Accessing Dagster

After deployment, Dagster will be available at: <https://[APP_URL]>

## Environment-Specific Configuration

### [CONTRACTOR] Environment

The [CONTRACTOR] environment uses the following configuration:

- Resource Group: `datahub`
- Location: `East US 2`
- Subscription: `[AGENCY] Mockups`
- DNS Zone: `datahub.[AGENCY].[CONTRACTOR_DOMAIN]`
- Trino Host: `[APP_URL]`
- Trino Port: `8080`
- Trino Catalog: `datahub`
- Trino Schema: `public`

## Entra ID Authentication

Dagster is configured to use Microsoft Entra ID (formerly Azure Active Directory) for authentication. This provides secure access to the Dagster webserver and integrates with the organization's identity management.

### Authentication Architecture

The authentication system uses Azure AD OAuth machine users (service principals) for service-to-service authentication:

1. **OAuth Machine Users in machine_users.tf**:
   - The `machine_users` local variable in `machine_users.tf` defines OAuth-based service principals
   - Each machine user gets a single app registration and service principal
   - Access to services (Lakekeeper, Trino, Storage) is controlled by boolean flags
   - Credentials are stored in Azure Key Vault and injected into Kubernetes secrets
   - Note: Password-based users (e.g., for JDBC connections) are managed separately in `tf/trino_password_users.tf`

2. **Dagster Machine User**:
   - A dedicated OAuth machine user for Dagster is defined in the `machine_users` map
   - This user has both `lakekeeper = true` and `trino = true` flags set
   - Uses a single set of OAuth credentials to authenticate to both Lakekeeper and Trino
   - The credentials are injected into the Dagster pods via the `data-lake-credentials` Kubernetes secret

3. **Unified OAuth Credentials**:
   - The Dagster machine user uses the same Azure AD application for all services
   - OAuth2 client credentials flow is used for both Lakekeeper and Trino authentication
   - This simplifies credential management and reduces the number of service principals

### Authentication Flow

1. **Dagster Web UI Authentication**:
   - Users authenticate to the Dagster web UI using their Azure AD credentials
   - The `DAGSTER_AUTH_TYPE=microsoft` setting enables this integration
   - The `dagster-auth-credentials` secret provides the necessary Azure AD configuration

2. **Dagster to Lakekeeper/Trino Authentication**:
   - Dagster uses its unified machine user credentials to authenticate to both services
   - The OAuth2 client credentials flow is used to obtain access tokens
   - The `data-lake-credentials` secret provides all necessary OAuth2 configuration

### Authentication Troubleshooting

If you encounter issues with Entra ID authentication:

1. **Redirect URI Issues**:
   - Ensure the redirect URI in the application registration matches `https://[APP_URL]/oauth/callback`
   - Check that the DNS record for `[APP_URL]` is properly configured

2. **Permission Issues**:
   - Verify that the machine users have the necessary API permissions
   - Check if admin consent is required for the permissions
   - Verify the app role assignments in `tf/machine_users.tf`
   - Ensure the Dagster machine user has both `lakekeeper` and `trino` flags set to `true`

3. **Client Secret Issues**:
   - Ensure the client secrets have not expired
   - Check the Azure Key Vault for the correct secret values
   - Verify the Kubernetes secrets are correctly populated

4. **OAuth2 Token Issues**:
   - Check the Trino client logs for token acquisition errors
   - Verify the OAuth2 scope format is correct (`api://{server-client-id}/.default`)
   - Ensure the token URI is correctly formatted with the tenant ID

## Development

### Local Development

For local development, you can run Dagster locally using the following command:

```bash
cd [project-name]
dagster dev -f pipelines/definitions.py
```

This will start the Dagster UI at <http://localhost:3000>.

### Adding New Assets

To add new assets to the Dagster deployment:

1. Create a new asset directory in the `pipelines/`. The new directory should have assets.py, schdules.py, and other modules as needed
2. Import the asset in the `pipelines/definitions.py` file
3. Deploy the changes using Terraform

### Adding New Resources

To add new resources to the Dagster deployment:

1. Create a new resource file in the `pipelines/resources` directory
2. Import the resource in the `pipelines/definitions.py` file
3. Deploy the changes using Terraform

## Trino Integration

The Dagster deployment includes integration with Trino/Lakekeeper for data querying. The integration is configured using the following components:

1. `pipelines/resources/trino_client.py`: The Trino client resource
2. `pipelines/trino/trino_test.py`: A test asset for verifying the Trino connection
3. `tf/dagster.tf`: Configuration for the Trino credentials

## Configuration Details

The Dagster deployment is configured with the following settings:

### Container Image

We use a custom container image that includes all the necessary code and dependencies:

- Repository: `[CONTAINER_REGISTRY]/[project-name]-dagster`
- Tag: Version-based (e.g., `1.0.0`) or `latest`

#### Container Image Build and Push

For manual container image builds and pushes:

1. Pull environment variables from Azure Key Vault:

   ```bash
   # For [AGENCY]-managed environments (dev, stg, prd):
   scripts/pull-dotenv dev    # or stg, prd

   # For the legacy consultant environment:
   scripts/pull-dotenv-legacy
   ```

   This creates a `.env` file with all the build configuration (container registry, Trino settings, etc.).

2. Build the container image:

   ```bash
   scripts/build-dagster-containers
   ```

3. Authenticate to Azure Container Registry and push container images

   ```bash
   scripts/push-dagster-containers
   ```

4. Update the Terraform configuration:

   ```bash
   cd tf/envs/<env>
   tofu apply
   cd ../../..
   ```

5. Restart the Dagster containers to pick up the new image:

   ```bash
   scripts/restart-dagster-containers
   ```

### Resource Limits

Resource limits are configured as best practice to ensure stable operation:

- Dagster Webserver:
  - Requests: 512Mi memory, 250m CPU
  - Limits: 1Gi memory, 500m CPU

- Dagster Daemon:
  - Requests: 512Mi memory, 250m CPU
  - Limits: 1Gi memory, 500m CPU

- User Deployments:
  - Requests: 512Mi memory, 250m CPU
  - Limits: 1Gi memory, 500m CPU

### TLS Configuration

TLS is configured for secure communication:

- TLS Host: `dagster.${dns_zone_name}`
- TLS Secret Name: Uses the certificate specified in `tls_certificate_name` variable

### Sensitive Information Handling

Sensitive information is managed through Terraform variables:

- Stored in the gitignored `.auto.tfvars` file
- Referenced directly in the Helm chart values
- Includes tenant ID, client ID, and client secret for Entra ID authentication

## Troubleshooting

### Authentication Issues

#### Terraform Authentication Issues

- **Azure CLI Login Problems**:
  - If you encounter "Access denied" or "Insufficient privileges" when initializing Terraform:
    - Ensure you're logged in with `az login`
    - Try logging out and back in: `az logout` followed by `az login`
    - [Microsoft's Terraform auth guide](https://learn.microsoft.com/en-us/azure/developer/terraform/authenticate-to-azure) and [troubleshooting guide](https://learn.microsoft.com/en-us/azure/developer/terraform/troubleshoot)

- **Terraform State Access Issues**:
  - If you see "Error: Failed to get existing workspaces" or storage access errors:
    - Ensure your account has access to the storage account containing the TF state
    - Microsoft's [guide](https://learn.microsoft.com/en-us/azure/developer/terraform/store-state-in-azure-storage) for storing TF state in Azure Storage
    - HashiCorp's `azurerm` backend [docs](https://developer.hashicorp.com/terraform/language/backend/azurerm)

#### Entra ID Authentication Issues

- **Dagster Web UI Access Problems**:
  - If you can't log in to the Dagster web interface:
    - Check the `dagster-auth-credentials` Kubernetes secret for correct values
    - Verify the machine user for Dagster exists in Azure AD
    - Ensure the redirect URI is correctly set to `https://[APP_URL]/oauth/callback`
    - Verify the application has the required Microsoft Graph permissions (`openid`, `profile`, `email`, `User.Read`)
    - Microsoft's docs on [Redirect URI best practices](https://learn.microsoft.com/en-us/entra/identity-platform/reply-url) and [troubleshooting redirect URI mismatch errors](https://learn.microsoft.com/en-us/troubleshoot/entra/entra-id/app-integration/error-code-aadsts50011-redirect-uri-mismatch)

#### Trino Authentication Issues

- **Dagster to Trino Connection Problems**:
  - If Dagster assets fail with Trino connection errors:
    - Check the credentials in the `data-lake-credentials` Kubernetes secret
    - Verify the Trino host, port, user, catalog, and schema values
    - Ensure the `TRINO_USE_HTTPS` value is set correctly (should be "true" for prod)
    - Look for SSL/TLS handshake errors in the logs, which may indicate certificate issues
    - Verify the Dagster machine user has `trino = true` in `tf/machine_users.tf`

  - **SSL/TLS Certificate Issues**:
    - If you see "SSL: CERTIFICATE_VERIFY_FAILED" or similar errors:
      - Verify the Trino server's certificate is valid and not expired
      - Check if the certificate is trusted by the Dagster pods
      - For testing, we can temporarily set `verify=False` in the Trino client (this is, as you might expect, NOT recommended for production)

  - **Authorization Issues**:
    - If you see "Access Denied" errors from Trino:
      - Verify the Trino user has appropriate permissions for the catalog and schema
      - Check if Trino is configured with the correct authentication method
      - Ensure the user has SELECT privileges on the tables being queried

  - _[Trino docs on SSL/TLS config](https://trino.io/docs/current/security/tls.html)_

### Connection Issues

- **Database Connection Problems**:
  - If Dagster pods are stuck in Init state with PostgreSQL connection errors:
    - Verify the PostgreSQL server is running and accessible from the AKS cluster
    - Check network security groups and firewall rules
    - Ensure the database credentials are correct
    - [PostgreSQL K8s troubleshooting guide](https://www.crunchydata.com/blog/troubleshooting-postgres-in-kubernetes) from Crunchy Data and [EDB's PostgreSQL for Kubernetes troubleshooting docs](https://www.enterprisedb.com/docs/postgres_for_kubernetes/latest/troubleshooting/)

- **Trino Connection Timeouts**:
  - If queries to Trino time out:
    - Check if Trino is running and healthy: `kubectl get pods -n trino`
    - Verify network connectivity between the Dagster and Trino namespaces
    - Increase the timeout value in the TrinoClient's execute_query method
    - Check Trino server logs for performance issues or errors
    - DigitalOcean's [tutorial on inspecting K8s networking](https://www.digitalocean.com/community/tutorials/how-to-inspect-kubernetes-networking) and [query management properties docs](https://trino.io/docs/current/admin/properties-query-management.html) from Trino

### Asset Failures

If assets fail to run, check the logs in the Dagster UI for error messages.

### Deployment Issues

- If you encounter issues during deployment:
  - Check the Terraform logs for errors.
  - Verify that the AKS cluster is running and accessible.
  - Check the pods are running: `kubectl get pods -n dagster`. If something looks off, `describe` is your friend.

### Accessing Logs

You can access the Dagster logs through the Dagster UI or using kubectl:

```bash
kubectl logs -n dagster deployment/dagster-webserver
kubectl logs -n dagster deployment/dagster-daemon
kubectl logs -n dagster deployment/dagster-user-deployments-[project-name]
```

## References

- [Dagster Documentation](https://docs.dagster.io/)
- [Dagster Kubernetes Documentation](https://docs.dagster.io/deployment/guides/kubernetes)
- [Dagster Helm Chart](https://github.com/dagster-io/dagster/tree/master/helm/dagster)
- [Microsoft Entra ID Documentation](https://learn.microsoft.com/en-us/entra/identity/)