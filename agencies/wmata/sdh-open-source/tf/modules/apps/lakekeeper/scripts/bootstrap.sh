#!/bin/bash
set -euo pipefail

# Expected environment variables:
# - AZURE_TENANT_ID
# - LAKEKEEPER_AUTH_CLIENT_ID        - Client ID for auth (app registration or managed identity)
# - LAKEKEEPER_AUTH_CLIENT_SECRET    - (optional) Client secret for app registration auth
# - LAKEKEEPER_APP_ID_URI
# - LAKEKEEPER_HOST - can be just the app name for internal communication
# - LAKEKEEPER_PORT - (optional) target port for direct internal communication
#
# Authentication modes:
# 1. Client credentials: Set LAKEKEEPER_AUTH_CLIENT_SECRET for OAuth2 client credentials flow
# 2. Managed identity: Omit LAKEKEEPER_AUTH_CLIENT_SECRET; uses Azure Container Apps
#    managed identity (requires IDENTITY_ENDPOINT and IDENTITY_HEADER from the runtime)

echo "Starting Lakekeeper bootstrap process..."

# Validate required environment variables
for var in AZURE_TENANT_ID LAKEKEEPER_AUTH_CLIENT_ID LAKEKEEPER_APP_ID_URI LAKEKEEPER_HOST; do
  if [[ -z "${!var:-}" ]]; then
    echo "ERROR: Required environment variable $var is not set"
    exit 1
  fi
done

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

# Bootstrap Lakekeeper; this will result in either a 204 on a successful first
# run, or a 400 with type="CatalogAlreadyBootstrapped" if it has already been
# bootstrapped. Either of those responses are fine.

# Determine protocol and host
# For internal Container Apps communication, use HTTP directly to the app port
PROTOCOL="${LAKEKEEPER_PROTOCOL:-http}"
if [[ -n "${LAKEKEEPER_PORT:-}" ]]; then
  # Use direct internal communication with port
  BASE_URL="${PROTOCOL}://${LAKEKEEPER_HOST}:${LAKEKEEPER_PORT}"
else
  # Use the standard FQDN (goes through ingress)
  BASE_URL="${PROTOCOL}://${LAKEKEEPER_HOST}"
fi

BOOTSTRAP_URL="${BASE_URL}/management/v1/bootstrap"
echo "Calling bootstrap endpoint at ${BOOTSTRAP_URL} ..."

# Add timeout and verbose output for debugging
HEALTH_URL="${BASE_URL}/health/readiness"
echo "Testing connectivity to ${HEALTH_URL}..."
if ! curl --silent --connect-timeout 10 --max-time 30 -o /[env1]/null -w "HTTP %{http_code}\n" "${HEALTH_URL}"; then
  echo "WARNING: Health check failed or timed out"
fi

echo "Sending bootstrap request..."
BOOTSTRAP_HTTP_CODE=$(curl \
  --connect-timeout 30 \
  --max-time 120 \
  --fail-with-body \
  --silent \
  --show-error \
  --output /tmp/bootstrap_response.json \
  --write-out "%{http_code}" \
  --location "${BOOTSTRAP_URL}" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer ${LAKEKEEPER_AUTH_TOKEN}" \
  --data '{ "accept-terms-of-use": true }') || true

BOOTSTRAP_RESPONSE=$(cat /tmp/bootstrap_response.json 2>/[env1]/null || echo "")

echo "Bootstrap response code: $BOOTSTRAP_HTTP_CODE"
echo "Bootstrap response body: $BOOTSTRAP_RESPONSE"

# Check the HTTP status code and response
if [[ "$BOOTSTRAP_HTTP_CODE" == "204" ]]; then
  echo "SUCCESS: Lakekeeper bootstrapped successfully."
  exit 0
elif [[ "$BOOTSTRAP_HTTP_CODE" == "400" ]] && [[ "$BOOTSTRAP_RESPONSE" == *'"type":"CatalogAlreadyBootstrapped"'* ]]; then
  echo "OK: Lakekeeper was already bootstrapped."
  exit 0
else
  echo "ERROR: Failed to bootstrap Lakekeeper. HTTP code: $BOOTSTRAP_HTTP_CODE, Response: $BOOTSTRAP_RESPONSE"
  exit 1
fi