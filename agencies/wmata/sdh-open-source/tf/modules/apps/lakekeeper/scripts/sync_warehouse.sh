#!/bin/bash
set -euo pipefail

# Sync Warehouse Script
# Creates or updates a warehouse in Lakekeeper with Azure ADLS Gen2 storage.
#
# Expected environment variables:
# - AZURE_TENANT_ID
# - LAKEKEEPER_AUTH_CLIENT_ID      - Client ID for authenticating to Lakekeeper API
# - LAKEKEEPER_AUTH_CLIENT_SECRET  - (optional) Client secret for app registration auth
# - LAKEKEEPER_APP_ID_URI          - App ID URI for Lakekeeper (e.g., api://<client-id>)
# - LAKEKEEPER_HOST                - Hostname of the Lakekeeper service
# - STORAGE_AUTH_CLIENT_ID         - Client ID for storage access credentials
# - STORAGE_AUTH_CLIENT_SECRET     - Client secret for storage access credentials
# - STORAGE_ACCOUNT_NAME           - Azure Storage account name
# - STORAGE_FILESYSTEM_NAME        - ADLS Gen2 filesystem (container) name
# - WAREHOUSE_NAME                 - Name for the warehouse in Lakekeeper
#
# Authentication modes (for Lakekeeper API access):
# 1. Client credentials: Set LAKEKEEPER_AUTH_CLIENT_SECRET for OAuth2 client credentials flow
# 2. Managed identity: Omit LAKEKEEPER_AUTH_CLIENT_SECRET; uses Azure Container Apps
#    managed identity (requires IDENTITY_ENDPOINT and IDENTITY_HEADER from the runtime)

echo "Starting Lakekeeper warehouse sync..."

# Validate required environment variables
REQUIRED_VARS=(
  AZURE_TENANT_ID
  LAKEKEEPER_AUTH_CLIENT_ID
  LAKEKEEPER_APP_ID_URI
  LAKEKEEPER_HOST
  STORAGE_AUTH_CLIENT_ID
  STORAGE_AUTH_CLIENT_SECRET
  STORAGE_ACCOUNT_NAME
  STORAGE_FILESYSTEM_NAME
  WAREHOUSE_NAME
)

for var in "${REQUIRED_VARS[@]}"; do
  if [[ -z "${!var:-}" ]]; then
    echo "ERROR: Required environment variable $var is not set"
    exit 1
  fi
done

echo "Warehouse name: ${WAREHOUSE_NAME}"
echo "Storage account: ${STORAGE_ACCOUNT_NAME}"
echo "Filesystem: ${STORAGE_FILESYSTEM_NAME}"

# Get an auth token for Lakekeeper using either client credentials or managed identity
if [[ -n "${LAKEKEEPER_AUTH_CLIENT_SECRET:-}" ]]; then
  # Client credentials flow: use client_id + client_secret to get a token from Azure AD
  echo "Obtaining authentication token via client credentials..."
  TOKEN_RESPONSE=$(curl \
    --silent \
    --request POST \
    --header 'Content-Type: application/x-www-form-urlencoded' \
    "https://login.microsoftonline.com/${AZURE_TENANT_ID}/oauth2/v2.0/token" \
    --data "client_id=${LAKEKEEPER_AUTH_CLIENT_ID}" \
    --data 'grant_type=client_credentials' \
    --data "scope=${LAKEKEEPER_APP_ID_URI}/.default" \
    --data "client_secret=${LAKEKEEPER_AUTH_CLIENT_SECRET}")

  LAKEKEEPER_AUTH_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token')
elif [[ -n "${IDENTITY_ENDPOINT:-}" ]] && [[ -n "${IDENTITY_HEADER:-}" ]]; then
  # Managed identity flow: use Azure Container Apps identity endpoint
  # See: https://learn.microsoft.com/en-us/azure/app-service/overview-managed-identity#rest-endpoint-reference
  echo "Obtaining authentication token via managed identity..."
  TOKEN_RESPONSE=$(curl \
    --silent \
    --request GET \
    "${IDENTITY_ENDPOINT}?resource=${LAKEKEEPER_APP_ID_URI}&api-version=2019-08-01&client_id=${LAKEKEEPER_AUTH_CLIENT_ID}" \
    --header "X-IDENTITY-HEADER: ${IDENTITY_HEADER}")

  LAKEKEEPER_AUTH_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token')
else
  echo "ERROR: No authentication method available."
  echo "Either set LAKEKEEPER_AUTH_CLIENT_SECRET for client credentials flow,"
  echo "or ensure the container has a managed identity assigned (IDENTITY_ENDPOINT/IDENTITY_HEADER)."
  exit 1
fi

if [[ "$LAKEKEEPER_AUTH_TOKEN" == "null" ]] || [[ -z "$LAKEKEEPER_AUTH_TOKEN" ]]; then
  echo "ERROR: Failed to obtain auth token. Response: $TOKEN_RESPONSE"
  exit 1
fi

echo "Successfully obtained auth token."

# Determine the base URL for Lakekeeper API
PROTOCOL="${LAKEKEEPER_PROTOCOL:-http}"
BASE_URL="${PROTOCOL}://${LAKEKEEPER_HOST}"

# Common storage configuration used for both create and update
STORAGE_CREDENTIAL_JSON='{
  "client-id": "'"${STORAGE_AUTH_CLIENT_ID}"'",
  "client-secret": "'"${STORAGE_AUTH_CLIENT_SECRET}"'",
  "credential-type": "client-credentials",
  "tenant-id": "'"${AZURE_TENANT_ID}"'",
  "type": "az"
}'

STORAGE_PROFILE_JSON='{
  "account-name": "'"${STORAGE_ACCOUNT_NAME}"'",
  "filesystem": "'"${STORAGE_FILESYSTEM_NAME}"'",
  "type": "adls"
}'

# Get the list of existing warehouses
echo "Checking for existing warehouse..."
WAREHOUSES_RESPONSE=$(curl \
  --silent \
  --connect-timeout 30 \
  --max-time 60 \
  --request GET \
  --location "${BASE_URL}/management/v1/warehouse" \
  --header "Authorization: Bearer ${LAKEKEEPER_AUTH_TOKEN}" \
  --header "Content-Type: application/json")

echo "Warehouses response: $WAREHOUSES_RESPONSE"

# Get the id of the warehouse, if it exists
WAREHOUSE_ID=$(echo "${WAREHOUSES_RESPONSE}" | jq -r ".warehouses[] | select(.name == \"${WAREHOUSE_NAME}\") | .id" 2>/[env1]/null || echo "")

if [[ -n "${WAREHOUSE_ID}" ]]; then
  echo "Warehouse '${WAREHOUSE_NAME}' already exists with ID: ${WAREHOUSE_ID}"
  echo "Updating storage profile and credentials..."

  # Update both storage profile and credential using the storage endpoint
  # See: https://docs.lakekeeper.io/docs/nightly/api/management/#tag/warehouse/operation/update_storage_profile
  UPDATE_RESPONSE=$(curl \
    --silent \
    --connect-timeout 30 \
    --max-time 60 \
    --request POST \
    --location "${BASE_URL}/management/v1/warehouse/${WAREHOUSE_ID}/storage" \
    --header "Authorization: Bearer ${LAKEKEEPER_AUTH_TOKEN}" \
    --header "Content-Type: application/json" \
    --write-out "\n%{http_code}" \
    --data '{
      "storage-credential": '"${STORAGE_CREDENTIAL_JSON}"',
      "storage-profile": '"${STORAGE_PROFILE_JSON}"'
    }')

  HTTP_CODE=$(echo "$UPDATE_RESPONSE" | tail -1)
  RESPONSE_BODY=$(echo "$UPDATE_RESPONSE" | sed '$d')

  echo "Update response code: $HTTP_CODE"
  echo "Update response body: $RESPONSE_BODY"

  if [[ "$HTTP_CODE" == "200" ]] || [[ "$HTTP_CODE" == "204" ]]; then
    echo "SUCCESS: Warehouse storage updated successfully."
    exit 0
  else
    echo "ERROR: Failed to update warehouse storage. HTTP code: $HTTP_CODE"
    exit 1
  fi
else
  echo "Creating new warehouse '${WAREHOUSE_NAME}'..."

  # Create new warehouse
  CREATE_RESPONSE=$(curl \
    --silent \
    --connect-timeout 30 \
    --max-time 60 \
    --request POST \
    --location "${BASE_URL}/management/v1/warehouse" \
    --header "Authorization: Bearer ${LAKEKEEPER_AUTH_TOKEN}" \
    --header "Content-Type: application/json" \
    --write-out "\n%{http_code}" \
    --data '{
      "warehouse-name": "'"${WAREHOUSE_NAME}"'",
      "delete-profile": { "type": "hard" },
      "storage-credential": '"${STORAGE_CREDENTIAL_JSON}"',
      "storage-profile": '"${STORAGE_PROFILE_JSON}"'
    }')

  HTTP_CODE=$(echo "$CREATE_RESPONSE" | tail -1)
  RESPONSE_BODY=$(echo "$CREATE_RESPONSE" | sed '$d')

  echo "Create response code: $HTTP_CODE"
  echo "Create response body: $RESPONSE_BODY"

  if [[ "$HTTP_CODE" == "200" ]] || [[ "$HTTP_CODE" == "201" ]]; then
    echo "SUCCESS: Warehouse '${WAREHOUSE_NAME}' created successfully."
    exit 0
  else
    echo "ERROR: Failed to create warehouse. HTTP code: $HTTP_CODE"
    exit 1
  fi
fi