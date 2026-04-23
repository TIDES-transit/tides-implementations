This simple app can help us verify that our Container Apps environment is set up to work with our Azure Container Registry.

You'll need to deploy the container for this app before you can `tofu apply` this module to the environment. To deploy this container to the Azure Container Registry, run the following commands:

```bash
# Log in to Azure
az login

# Log in to the Azure Container Registry and get an access token
# redacted: concrete registry name replaced with placeholder
ACR_TOKEN=`az acr login --name [CONTAINER_REGISTRY_NAME] --expose-token`

# The output of `az acr login` will look something like this:
# {
#   "accessToken": "...",
#   "loginServer": "[CONTAINER_REGISTRY_NAME]-abcd1234efgh5678.azurecr.io",
#   "refreshToken": "...",
#   "username": "00000000-0000-0000-0000-000000000000"
# }

# Pull the important information off of the token
ACR_LOGIN_SERVER=`echo $ACR_TOKEN | jq -r .loginServer`
ACR_USERNAME=`echo $ACR_TOKEN | jq -r .username`
ACR_PASSWORD=`echo $ACR_TOKEN | jq -r .accessToken`

# Authenticate Podman with the ACR
podman login "$ACR_LOGIN_SERVER" -u "$ACR_USERNAME" -p "$ACR_PASSWORD"

# Build and push the container image
podman build . -t "$ACR_LOGIN_SERVER/hello-world-web-app:latest"
podman push "$ACR_LOGIN_SERVER/hello-world-web-app:latest"
```
