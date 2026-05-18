# Hello World Container App - Automated Build and Push

## Overview

The `hello_world` module builds and pushes the container image to Azure Container Registry as part of the Terraform apply process.

## How It Works

### 1. Content Change Detection

- A `data.external.app_hash` resource generates a hash of all files in the `app/` directory
- This hash is used as a trigger for the build and push operations
- Any change to files in `app/` (including `app.py`, `Containerfile`, `requirements.txt`) will trigger a rebuild

### 2. Build Process

- `null_resource.build_image` builds the container image using podman
- The image is tagged as `{registry}/hello-world-web-app:latest`
- Build is triggered when the app directory hash changes

### 3. Push Process

- `null_resource.push_image` authenticates and pushes the image to Azure Container Registry
- Depends on the build step completing successfully
- Uses Azure CLI to get an access token (`az acr login --expose-token`)
- Logs into ACR with podman using the token

### 4. Container App Deployment

- The `azurerm_container_app.hello_world` resource depends on the push completing
- This ensures the new image is available before the container app is updated

## Prerequisites

1. **Podman**: Must be installed and available in PATH

   ```bash
   podman --version
   ```

2. **Azure CLI**: Must be installed and authenticated

   ```bash
   az login
   az account show
   ```

3. **Permissions**: The Azure account must have the **AcrPush** role on the container registry

   To check your current permissions:

   ```bash
   az role assignment list --scope /subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/Microsoft.ContainerRegistry/registries/<registry-name> --assignee $(az ad signed-in-user show --query id -o tsv)
   ```

   To grant the AcrPush role (requires Owner or User Access Administrator role):

   ```bash
   az role assignment create --assignee $(az ad signed-in-user show --query id -o tsv) \
     --role AcrPush \
     --scope /subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/Microsoft.ContainerRegistry/registries/<registry-name>
   ```

## Workflow

When you run `terraform apply`:

1. Terraform calculates the hash of all files in `app/`
2. If the hash has changed (or this is the first run):
   - Builds the container image with podman
   - Pushes the image to Azure Container Registry
   - Updates/creates the container app with the new image
3. If the hash hasn't changed:
   - Skips build and push
   - Only applies other infrastructure changes if needed

## Making Changes to the App

1. Edit files in `tf/modules/apps/hello_world/app/`
2. Run `terraform plan` to see that the build/push will be triggered
3. Run `terraform apply` to build, push, and deploy

## Important Notes

- **Port Configuration**: The app listens on port 8000 (as configured in the Containerfile with gunicorn)
- **Container Registry**: Uses the registry specified in `var.datahub_container_registry_login_server`
- **Image Tag**: Always uses the `latest` tag
- **Workload Identity**: The container app uses user-assigned managed identity for ACR access

## Troubleshooting

### Build Fails

- Check that podman is installed and working: `podman version`
- Check the Containerfile syntax
- Review the build output in the Terraform logs

### Push Fails

**403 Forbidden / Access Denied Errors:**

Most commonly caused by missing permissions. The error log may show:

```text
CONNECTIVITY_REFRESH_TOKEN_ERROR
Access to registry was denied. Response code: 403.
```

Solutions:

1. **Verify Azure Login**: Ensure you're logged in and using the correct subscription

   ```bash
   az account show
   az account list
   az account set --subscription <subscription-id>
   ```

2. **Check Permissions**: Verify you have the AcrPush role

   ```bash
   az acr show --name <registry-name> --query id -o tsv
   # Use the ID from above in the scope parameter
   az role assignment list --scope <registry-resource-id> --assignee $(az ad signed-in-user show --query id -o tsv)
   ```

3. **Refresh Token**: Try manually getting a token to test

   ```bash
   az acr login --name <registry-name> --expose-token
   ```

4. **Grant Permissions**: If you have Owner/User Access Administrator role

   ```bash
   az role assignment create --assignee $(az ad signed-in-user show --query id -o tsv) \
     --role AcrPush \
     --scope <registry-resource-id>
   ```

**Other Issues:**

- Check that the registry name is correct
- Ensure the registry exists and is accessible
- If using a service principal, verify it has the correct permissions

### Container App Doesn't Update

- The container app will only update if the infrastructure changes
- Changes to the image alone may require a revision restart
- Check the container app logs in Azure Portal
