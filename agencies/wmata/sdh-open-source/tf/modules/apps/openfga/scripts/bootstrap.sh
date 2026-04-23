#!/bin/bash
set -euo pipefail

# Expected environment variables:
# - OPENFGA_HOST                  - OpenFGA server host (e.g., app-name.internal.dns-suffix)
# - OPENFGA_PORT                  - OpenFGA server port (default: 8080)
# - OPENFGA_PRESHARED_KEY         - Preshared key for authentication
# - OPENFGA_STORE_NAME            - Name of the store to create (default: lakekeeper)
# - LAKEKEEPER_SCHEMA_VERSION     - Lakekeeper OpenFGA schema version (default: v4.3)

echo "Starting OpenFGA bootstrap process..."

# Validate required environment variables
for var in OPENFGA_HOST OPENFGA_PRESHARED_KEY; do
  if [[ -z "${!var:-}" ]]; then
    echo "ERROR: Required environment variable $var is not set"
    exit 1
  fi
done

OPENFGA_STORE_NAME="${OPENFGA_STORE_NAME:-lakekeeper}"
LAKEKEEPER_SCHEMA_VERSION="${LAKEKEEPER_SCHEMA_VERSION:-v4.3}"
BASE_URL="http://${OPENFGA_HOST}"
AUTH_HEADER="Authorization: Bearer ${OPENFGA_PRESHARED_KEY}"

# Wait for OpenFGA to be healthy
echo "Checking OpenFGA health at ${BASE_URL}/healthz..."
for i in $(seq 1 30); do
  if curl --silent --fail "${BASE_URL}/healthz" > /[env1]/null 2>&1; then
    echo "OpenFGA is healthy."
    break
  fi
  if [[ $i -eq 30 ]]; then
    echo "ERROR: OpenFGA did not become healthy after 30 attempts"
    exit 1
  fi
  echo "Waiting for OpenFGA to be healthy (attempt $i/30)..."
  sleep 2
done

# =============================================================================
# Step 1: Create or find the store

echo "Listing existing stores..."
STORES_RESPONSE=$(curl --silent --fail \
  --header "${AUTH_HEADER}" \
  "${BASE_URL}/stores")

EXISTING_STORE_ID=$(echo "$STORES_RESPONSE" | jq -r ".stores[] | select(.name == \"${OPENFGA_STORE_NAME}\") | .id" | head -1)

if [[ -n "$EXISTING_STORE_ID" ]]; then
  echo "Store '${OPENFGA_STORE_NAME}' already exists with ID: ${EXISTING_STORE_ID}"
  STORE_ID="$EXISTING_STORE_ID"
else
  echo "Creating store '${OPENFGA_STORE_NAME}'..."
  CREATE_RESPONSE=$(curl --silent --fail \
    --header "${AUTH_HEADER}" \
    --header "Content-Type: application/json" \
    --data "{\"name\": \"${OPENFGA_STORE_NAME}\"}" \
    "${BASE_URL}/stores")

  STORE_ID=$(echo "$CREATE_RESPONSE" | jq -r '.id')
  if [[ -z "$STORE_ID" ]] || [[ "$STORE_ID" == "null" ]]; then
    echo "ERROR: Failed to create store. Response: ${CREATE_RESPONSE}"
    exit 1
  fi
  echo "Created store '${OPENFGA_STORE_NAME}' with ID: ${STORE_ID}"
fi

# =============================================================================
# Step 2: Download Lakekeeper's OpenFGA schema (JSON format)

SCHEMA_URL="https://raw.githubusercontent.com/lakekeeper/lakekeeper/main/authz/openfga/${LAKEKEEPER_SCHEMA_VERSION}/schema.json"
echo "Downloading Lakekeeper OpenFGA schema ${LAKEKEEPER_SCHEMA_VERSION} from ${SCHEMA_URL}..."
if ! curl --silent --fail -o /tmp/schema.json "$SCHEMA_URL"; then
  echo "ERROR: Failed to download schema.json from ${SCHEMA_URL}"
  echo "Check that version '${LAKEKEEPER_SCHEMA_VERSION}' exists at https://github.com/lakekeeper/lakekeeper/tree/main/authz/openfga"
  exit 1
fi
echo "Downloaded schema.json ($(wc -c < /tmp/schema.json) bytes)"

# =============================================================================
# Step 3: Write the authorization model

echo "Writing authorization model to store ${STORE_ID}..."
WRITE_RESPONSE=$(curl --silent --fail-with-body \
  --header "${AUTH_HEADER}" \
  --header "Content-Type: application/json" \
  --data @/tmp/schema.json \
  "${BASE_URL}/stores/${STORE_ID}/authorization-models")

MODEL_ID=$(echo "$WRITE_RESPONSE" | jq -r '.authorization_model_id // empty')
if [[ -n "$MODEL_ID" ]]; then
  echo "SUCCESS: Authorization model written with ID: ${MODEL_ID}"
else
  ERROR_CODE=$(echo "$WRITE_RESPONSE" | jq -r '.code // empty')
  if [[ "$ERROR_CODE" == "validation_error" ]]; then
    echo "ERROR: Model validation error. Response: ${WRITE_RESPONSE}"
    exit 1
  fi
  echo "WARNING: Unexpected response when writing model: ${WRITE_RESPONSE}"
  echo "The model may have been written successfully - check the OpenFGA logs."
fi

echo "OpenFGA bootstrap complete."
echo "Store ID: ${STORE_ID}"
echo "Store Name: ${OPENFGA_STORE_NAME}"
echo "Schema Version: ${LAKEKEEPER_SCHEMA_VERSION}"