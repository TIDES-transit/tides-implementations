# [Project Name] Dev and Staging Environment Needs

This outlines the resources and settings needed to be able to apply the Terraform code for the [Project Name] [env1] and staging environments (both in the `[RESOURCE_GROUP]` resource group).

## Azure Subscription Requirements

- **Register Microsoft.DBforPostgreSQL Namespace**: The Azure subscription must be registered to use the `Microsoft.DBforPostgreSQL` namespace. This is necessary for creating and managing PostgreSQL databases within the subscription.

  - To register the namespace, you can run the following Azure CLI command:

    ```bash
    az provider register --namespace Microsoft.DBforPostgreSQL
    ```

- **Register Microsoft.App Namespace**: The Azure subscription must be registered to use the `Microsoft.App` namespace. This is necessary for creating and managing Container Apps.

  - To register the namespace, you can run the following Azure CLI command:

    ```bash
    az provider register --namespace Microsoft.App
    ```

## Manual Resource Creation

The following resources need to be created manually before applying the Terraform configuration.

### Virtual Network

- Create a virtual network with a /23 CIDR block.
- We will need to know the address prefix, and the addresses of the DNS servers.

### Subnets

- Create the PostgreSQL Flexible Server subnets named `[Project Name]-[env1]-psql-snet` and `[Project Name]-[env2]-psql-snet`, each delegated to `Microsoft.DBforPostgreSQL/flexibleServers`, with a /27 CIDR block:

  ```bash
  az network vnet subnet create \
    --name [Project Name]-[env1]-psql-snet \
    --resource-group [...] \
    --vnet-name [...] \
    --address-prefix [...]/27 \
    --delegations Microsoft.DBforPostgreSQL/flexibleServers
  az network vnet subnet create \
    --name [Project Name]-[env2]-psql-snet \
    --resource-group [...] \
    --vnet-name [...] \
    --address-prefix [...]/27 \
    --delegations Microsoft.DBforPostgreSQL/flexibleServers
  ```

- Create the Private Endpoint subnets named `[Project Name]-[env1]-pe-snet` and `[Project Name]-[env2]-pe-snet` with a /27 CIDR block:

  ```bash
  az network vnet subnet create \
    --name [Project Name]-[env1]-pe-snet \
    --resource-group [...] \
    --vnet-name [...] \
    --address-prefix [...]/27
  az network vnet subnet create \
    --name [Project Name]-[env2]-pe-snet \
    --resource-group [...] \
    --vnet-name [...] \
    --address-prefix [...]/27
  ```

- Create the Container Apps subnets named `[Project Name]-[env1]-aca-snet` and `[Project Name]-[env2]-aca-snet` delegated to `Microsoft.App/environments` with a /24 CIDR block:

  ```bash
  az network vnet subnet create \
    --name [Project Name]-[env1]-aca-snet \
    --resource-group [...] \
    --vnet-name [...] \
    --address-prefix [...]/24 \
    --delegations Microsoft.App/environments
  az network vnet subnet create \
    --name [Project Name]-[env2]-aca-snet \
    --resource-group [...] \
    --vnet-name [...] \
    --address-prefix [...]/24 \
    --delegations Microsoft.App/environments
  ```

### Container App Environment

Using the subnet ID for the container apps subnets...:

```bash
DEV_SUBNET_ID=$(az network vnet subnet show \
  --name [Project Name]-[env1]-aca-snet \
  --resource-group [...] \
  --vnet-name [...] \
  --query id \
  --output tsv)
STG_SUBNET_ID=$(az network vnet subnet show \
  --name [Project Name]-[env2]-aca-snet \
  --resource-group [...] \
  --vnet-name [...] \
  --query id \
  --output tsv)
```

Create Container App Environments named `[Project Name]-[env1]-cae` and `[Project Name]-[env2]-cae`. We're using a `D4` workload type (general purpose, 4 vCPUs, 16 G memory, 3-5 nodes):

([env1])

```bash
az containerapp env create \
  --name [Project Name]-[env1]-cae \
  --resource-group [RESOURCE_GROUP] \
  --location eastus \
  --infrastructure-subnet-resource-id "$DEV_SUBNET_ID" \
  --internal-only true \
  --enable-workload-profiles \
  --tags \
    Project="[Project Name]" \
    Environment="[env1]" \
    Description="Container app environment for hosting containerized applications"

az containerapp env workload-profile add \
  --name [Project Name]-[env1]-cae \
  --resource-group [RESOURCE_GROUP] \
  --workload-profile-name datahub-profile \
  --workload-profile-type D4 \
  --min-nodes 3 \
  --max-nodes 5
```

(staging)

```bash
az containerapp env create \
  --name [Project Name]-[env2]-cae \
  --resource-group [RESOURCE_GROUP] \
  --location eastus \
  --infrastructure-subnet-resource-id "$STG_SUBNET_ID" \
  --internal-only true \
  --enable-workload-profiles \
  --tags \
    Project="[Project Name]" \
    Environment="[env2]" \
    Description="Container app environment for hosting containerized applications"

az containerapp env workload-profile add \
  --name [Project Name]-[env2]-cae \
  --resource-group [RESOURCE_GROUP] \
  --workload-profile-name datahub-profile \
  --workload-profile-type D4 \
  --min-nodes 3 \
  --max-nodes 5
```

We will need to know the default domains for these environments to set up the redirect URLs for the app registrations:

```bash
DEV_CAE_DOMAIN=$(az containerapp env show \
  --name [Project Name]-[env1]-cae \
  --resource-group [RESOURCE_GROUP] \
  --query properties.defaultDomain \
  --output tsv)
STG_CAE_DOMAIN=$(az containerapp env show \
  --name [Project Name]-[env2]-cae \
  --resource-group [RESOURCE_GROUP] \
  --query properties.defaultDomain \
  --output tsv)
```

## Entra ID (Azure Active Directory) Resources

The following Entra ID resources need to be created manually. These resources configure authentication and authorization for the [Project Name] applications.

The following reuses the Entra group that was created for the [env3] ("[Project Name] Users" group with ID `[AD_GROUP_ID]`), as well as the app registrations that were created for the apps in [env3].

### Update Application Registrations

We'll need four application registrations updated, and one additional one created.

#### Lakekeeper Application

- Add redirect URI: `https://[Project Name]-[env1]-lakekeeper-ca.${DEV_CAE_DOMAIN}/ui/callback`.
- Add redirect URI: `https://[Project Name]-[env2]-lakekeeper-ca.${STG_CAE_DOMAIN}/ui/callback`.

#### Trino Application

- Add redirect URI: `https://[Project Name]-[env1]-trino-ca.${DEV_CAE_DOMAIN}/oauth2/callback`.
- Add redirect URI: `https://[Project Name]-[env2]-trino-ca.${STG_CAE_DOMAIN}/oauth2/callback`.

#### Dagster Application

- Add redirect URI: `https://[Project Name]-[env1]-dagster-ca.${DEV_CAE_DOMAIN}/.auth/login/aad/callback`.
- Add redirect URI: `https://[Project Name]-[env2]-dagster-ca.${STG_CAE_DOMAIN}/.auth/login/aad/callback`.

#### OpenMetadata Application

- Add redirect URI: `https://[Project Name]-[env1]-openmetadata-ca.${DEV_CAE_DOMAIN}/callback`.
- Add redirect URI: `https://[Project Name]-[env2]-openmetadata-ca.${STG_CAE_DOMAIN}/callback`.

#### Metabase Application

This application will be set up similar to the Dagster application, with appropriate redirect URIs and permissions. The application will require `email`, `openid`, and `profile` permissions from Microsoft Graph, as well as delegated permissions to access the Lakekeeper API.

**Azure Portal:**

1. Navigate to **Microsoft Entra ID** → **App registrations** → **New registration**
2. Set **Name** to `Metabase - [Project Name]`
3. Leave **Supported account types** as `Accounts in this organizational directory only`
4. Under **Redirect URI**, select platform `Web` and add URIs: `https://[Project Name]-[env1]-metabase-ca.{DEV_CAE_DOMAIN}/.auth/login/aad/callback` and `https://[Project Name]-[env2]-metabase-ca.{STG_CAE_DOMAIN}/.auth/login/aad/callback`
5. Click **Register**
6. After creation, go to **Authentication**:
   - Under **Implicit grant and hybrid flows**, enable **ID tokens**
7. Go to **API permissions** and add:
   - **Microsoft Graph** → **Delegated permissions**:
     - `email`
     - `openid`
     - `profile`
   - **Lakekeeper - [Project Name]** → **Delegated permissions**
     - `Lakekeeper`

### Create Service Principals (Enterprise Applications)

For each application registration created above, a service principal needs to be created. The pre-existing apps already have one, but we'll need one for **Metabase** as well.

### Assign Users/Groups to Applications

Assign the "**[Project Name] Users**" group to each application so members can access them (the four existing applications should be already configured for this, and **Metabase** will be added similarly).

**Azure Portal:**
For each application (Lakekeeper, Trino, Dagster, OpenMetadata, Metabase):

1. Navigate to **Microsoft Entra ID** → **Enterprise applications** → Select the application
2. Go to **Users and groups** → **Add user/group**
3. Click **None Selected** under **Users and groups**
4. Search for and select `[Project Name] Users`
5. Click **Select** → **Assign**

### Azure RBAC Role Assignments

The following Azure RBAC roles need to be assigned to service principals for accessing both [env1] and staging resources.

#### Dagster Role Assignments

**Azure CLI:**

```bash
# Get Dagster's managed identity principal ID (this is the workload identity, not the app registration)
DAGSTER_PRINCIPAL_ID="[PRINCIPAL_ID]"
```

Give the **Dagster** app's service principal **Storage Blob Data Contributor** role

```bash
az role assignment create \
  --assignee $DAGSTER_PRINCIPAL_ID \
  --role "Storage Blob Data Contributor" \
  --scope "/subscriptions/[SUBSCRIPTION_ID]/resourceGroups/[RESOURCE_GROUP]/providers/Microsoft.Storage/storageAccounts/[STORAGE_ACCOUNT]"
az role assignment create \
  --assignee $DAGSTER_PRINCIPAL_ID \
  --role "Storage Blob Data Contributor" \
  --scope "/subscriptions/[SUBSCRIPTION_ID]/resourceGroups/[RESOURCE_GROUP]/providers/Microsoft.Storage/storageAccounts/[STORAGE_ACCOUNT]"
```

Give the **Dagster** app's service principal **Storage Blob Delegator** role

```bash
az role assignment create \
  --assignee $DAGSTER_PRINCIPAL_ID \
  --role "Storage Blob Delegator" \
  --scope "/subscriptions/[SUBSCRIPTION_ID]/resourceGroups/[RESOURCE_GROUP]/providers/Microsoft.Storage/storageAccounts/[STORAGE_ACCOUNT]"
az role assignment create \
  --assignee $DAGSTER_PRINCIPAL_ID \
  --role "Storage Blob Delegator" \
  --scope "/subscriptions/[SUBSCRIPTION_ID]/resourceGroups/[RESOURCE_GROUP]/providers/Microsoft.Storage/storageAccounts/[STORAGE_ACCOUNT]"
```

Give the **Dagster** app's service principal **Key Vault Secrets User** role

```bash
az role assignment create \
  --assignee $DAGSTER_PRINCIPAL_ID \
  --role "Key Vault Secrets User" \
  --scope "/subscriptions/[SUBSCRIPTION_ID]/resourceGroups/[RESOURCE_GROUP]/providers/Microsoft.KeyVault/vaults/[KEY_VAULT]"
az role assignment create \
  --assignee $DAGSTER_PRINCIPAL_ID \
  --role "Key Vault Secrets User" \
  --scope "/subscriptions/[SUBSCRIPTION_ID]/resourceGroups/[RESOURCE_GROUP]/providers/Microsoft.KeyVault/vaults/[KEY_VAULT]"
```

Give the **Dagster** app's service principal **AcrPull** role

```bash
az role assignment create \
  --assignee $DAGSTER_PRINCIPAL_ID \
  --role "AcrPull" \
  --scope "/subscriptions/[SUBSCRIPTION_ID]/resourceGroups/[RESOURCE_GROUP]"
```

#### Trino Role Assignments

**Azure CLI:**

```bash
# Get Trino's managed identity principal ID
TRINO_PRINCIPAL_ID="[REDACTED_ID]"
```

Give the **Trino** app's service principal **Storage Blob Data Contributor** role

```bash
az role assignment create \
  --assignee $TRINO_PRINCIPAL_ID \
  --role "Storage Blob Data Contributor" \
  --scope "/subscriptions/[SUBSCRIPTION_ID]/resourceGroups/[RESOURCE_GROUP]/providers/Microsoft.Storage/storageAccounts/[STORAGE_ACCOUNT]"
az role assignment create \
  --assignee $TRINO_PRINCIPAL_ID \
  --role "Storage Blob Data Contributor" \
  --scope "/subscriptions/[SUBSCRIPTION_ID]/resourceGroups/[RESOURCE_GROUP]/providers/Microsoft.Storage/storageAccounts/[STORAGE_ACCOUNT]"
```

Give the **Trino** app's service principal **Storage Blob Delegator** role

```bash
az role assignment create \
  --assignee $TRINO_PRINCIPAL_ID \
  --role "Storage Blob Delegator" \
  --scope "/subscriptions/[SUBSCRIPTION_ID]/resourceGroups/[RESOURCE_GROUP]/providers/Microsoft.Storage/storageAccounts/[STORAGE_ACCOUNT]"
az role assignment create \
  --assignee $TRINO_PRINCIPAL_ID \
  --role "Storage Blob Delegator" \
  --scope "/subscriptions/[SUBSCRIPTION_ID]/resourceGroups/[RESOURCE_GROUP]/providers/Microsoft.Storage/storageAccounts/[STORAGE_ACCOUNT]"
```

#### OpenMetadata Role Assignments

**Azure CLI:**

```bash
# Get OpenMetadata's managed identity principal ID
OPENMETADATA_PRINCIPAL_ID="[REDACTED_ID]"
```

Give the **OpenMetadata** app's service principal **Key Vault Secrets User** role

```bash
az role assignment create \
  --assignee $OPENMETADATA_PRINCIPAL_ID \
  --role "Key Vault Secrets User" \
  --scope "/subscriptions/[SUBSCRIPTION_ID]/resourceGroups/[RESOURCE_GROUP]/providers/Microsoft.KeyVault/vaults/[KEY_VAULT]"
az role assignment create \
  --assignee $OPENMETADATA_PRINCIPAL_ID \
  --role "Key Vault Secrets User" \
  --scope "/subscriptions/[SUBSCRIPTION_ID]/resourceGroups/[RESOURCE_GROUP]/providers/Microsoft.KeyVault/vaults/[KEY_VAULT]"
```

#### Metabase Role Assignments

**Azure CLI:**

```bash
# Get Metabase's managed identity principal ID
METABASE_PRINCIPAL_ID="[...]"
```

Give the **Metabase** app's service principal **Storage Blob Data Contributor** role

```bash
az role assignment create \
  --assignee $METABASE_PRINCIPAL_ID \
  --role "Storage Blob Data Contributor" \
  --scope "/subscriptions/[SUBSCRIPTION_ID]/resourceGroups/[RESOURCE_GROUP]/providers/Microsoft.Storage/storageAccounts/[STORAGE_ACCOUNT]"
az role assignment create \
  --assignee $METABASE_PRINCIPAL_ID \
  --role "Storage Blob Data Contributor" \
  --scope "/subscriptions/[SUBSCRIPTION_ID]/resourceGroups/[RESOURCE_GROUP]/providers/Microsoft.Storage/storageAccounts/[STORAGE_ACCOUNT]"
```

Give the **Metabase** app's service principal **Storage Blob Delegator** role

```bash
az role assignment create \
  --assignee $METABASE_PRINCIPAL_ID \
  --role "Storage Blob Delegator" \
  --scope "/subscriptions/[SUBSCRIPTION_ID]/resourceGroups/[RESOURCE_GROUP]/providers/Microsoft.Storage/storageAccounts/[STORAGE_ACCOUNT]"
az role assignment create \
  --assignee $METABASE_PRINCIPAL_ID \
  --role "Storage Blob Delegator" \
  --scope "/subscriptions/[SUBSCRIPTION_ID]/resourceGroups/[RESOURCE_GROUP]/providers/Microsoft.Storage/storageAccounts/[STORAGE_ACCOUNT]"
```

Give the **Metabase** app's service principal **Key Vault Secrets User** role

```bash
az role assignment create \
  --assignee $METABASE_PRINCIPAL_ID \
  --role "Key Vault Secrets User" \
  --scope "/subscriptions/[SUBSCRIPTION_ID]/resourceGroups/[RESOURCE_GROUP]/providers/Microsoft.KeyVault/vaults/[KEY_VAULT]"
az role assignment create \
  --assignee $METABASE_PRINCIPAL_ID \
  --role "Key Vault Secrets User" \
  --scope "/subscriptions/[SUBSCRIPTION_ID]/resourceGroups/[RESOURCE_GROUP]/providers/Microsoft.KeyVault/vaults/[KEY_VAULT]"
```

Give the **Metabase** app's service principal **AcrPull** role

```bash
az role assignment create \
  --assignee $METABASE_PRINCIPAL_ID \
  --role "AcrPull" \
  --scope "/subscriptions/[SUBSCRIPTION_ID]/resourceGroups/[RESOURCE_GROUP]"
```