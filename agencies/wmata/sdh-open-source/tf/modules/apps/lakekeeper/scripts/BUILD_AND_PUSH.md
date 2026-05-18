# Building and Pushing the Lakekeeper Scripts Image

This directory contains scripts used by Lakekeeper Container App Jobs (bootstrap, sync_warehouse, etc.). These scripts need to be packaged into a container image and pushed to the Azure Container Registry. The build and push process is taken care of as part of the OpenTofu apply process, but this document outlines how to do it manually if needed.

## Prerequisites

1. Podman installed locally
2. Azure CLI installed and logged in (`az login`)
3. Access to the Azure Container Registry

## Building the Image

From this directory (`tf/modules/apps/lakekeeper/scripts/`):

```bash
# Build the image
podman build -t lakekeeper-scripts:latest -f Containerfile .
```

## Pushing to Azure Container Registry

### 1. Get the ACR login server

For [env1] environment:

```bash
# Get the ACR login server name
az acr list --resource-group [RESOURCE_GROUP] --query "[].loginServer" -o tsv
```

This should return something like `[CONTAINER_REGISTRY]`.

### 2. Log in to ACR with Podman

Since podman doesn't integrate directly with `az acr login`, use `--expose-token` to get credentials:

```bash
# Get the ACR token and log in with podman
ACR_TOKEN=$(az acr login --name sdhdevcr01 --expose-token --output tsv --query accessToken)
podman login [CONTAINER_REGISTRY] --username 00000000-0000-0000-0000-000000000000 --password "$ACR_TOKEN"
```

### 3. Tag and push the image

```bash
# Tag the image for ACR
podman tag lakekeeper-scripts:latest [CONTAINER_REGISTRY]/lakekeeper-scripts:latest

# Push to ACR
podman push [CONTAINER_REGISTRY]/lakekeeper-scripts:latest
```

## One-liner for Dev Environment

```bash
# Build, tag, and push in one go
podman build -t lakekeeper-scripts:latest -f Containerfile . && \
ACR_TOKEN=$(az acr login --name sdhdevcr01 --expose-token --output tsv --query accessToken) && \
podman login [CONTAINER_REGISTRY] --username 00000000-0000-0000-0000-000000000000 --password "$ACR_TOKEN" && \
podman tag lakekeeper-scripts:latest [CONTAINER_REGISTRY]/lakekeeper-scripts:latest && \
podman push [CONTAINER_REGISTRY]/lakekeeper-scripts:latest
```

## Verifying the Image

After pushing, you can verify the image exists in ACR:

```bash
az acr repository show-tags --name sdhdevcr01 --repository lakekeeper-scripts
```

## Scripts Included

- `bootstrap.sh` - Bootstraps Lakekeeper by calling the `/management/v1/bootstrap` endpoint. Makes the first caller the initial admin.
- `sync_warehouse.sh` - Creates or updates a warehouse in Lakekeeper with storage credentials.

## Environment Variables

The bootstrap job requires these environment variables (configured in Terraform):

| Variable | Description |
|----------|-------------|
| `AZURE_TENANT_ID` | Azure AD tenant ID |
| `LAKEKEEPER_AUTH_CLIENT_ID` | Client ID of the service principal for authentication |
| `LAKEKEEPER_AUTH_CLIENT_SECRET` | Client secret for authentication |
| `LAKEKEEPER_APP_ID_URI` | App ID URI for Lakekeeper (e.g., `api://<client-id>`) |
| `LAKEKEEPER_HOST` | Hostname of the Lakekeeper service |
| `LAKEKEEPER_PORT` (Optional) |  Port that Lakekeeper listens on, if different from the default for HTTPS (443). |