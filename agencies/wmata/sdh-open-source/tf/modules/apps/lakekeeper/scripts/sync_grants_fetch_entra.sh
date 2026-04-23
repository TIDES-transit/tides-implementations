#!/bin/bash
set -euo pipefail

# Step 1: Fetch Entra Group Members → Key Vault
#
# Reads members of each Entra group defined in ROLES_JSON and stores the
# membership list as a JSON secret in Azure Key Vault. This allows the
# role assignment step (sync_grants_assign_roles.sh) to run without needing
# Graph API permissions.
#
# Can be run locally (uses `az` CLI) or in ACA (uses client credentials +
# managed identity). When no Graph API access is available, the script exits
# cleanly without error.
#
# Expected environment variables:
# - AZURE_TENANT_ID
# - KEY_VAULT_NAME
# - ROLES_JSON                       - JSON describing role->group->permissions
# - GRAPH_CLIENT_ID                  - (optional) Client ID for Graph API client credentials
# - GRAPH_CLIENT_SECRET              - (optional) Client secret for Graph API client credentials
#
# Key Vault secret format (per role):
#   Secret name: lakekeeper-role-{role_name}-members
#   Secret value: [{"id": "...", "displayName": "...", "userPrincipalName": "..."}, ...]

echo "=== Step 1: Fetch Entra group members ==="

# Validate required env vars
for var in AZURE_TENANT_ID KEY_VAULT_NAME; do
  if [[ -z "${!var:-}" ]]; then
    echo "ERROR: Required environment variable $var is not set"
    exit 1
  fi
done

if [[ -z "${ROLES_JSON:-}" ]] || [[ "$ROLES_JSON" == "{}" ]]; then
  echo "No roles configured. Nothing to do."
  exit 0
fi

# =============================================================================
# Authentication: Microsoft Graph API
#
# Try client credentials first (ACA with app registration), then fall back to
# az CLI (local [env1]). If neither works, exit cleanly.

get_graph_token() {
  # Option 1: Client credentials flow (ACA / CI)
  if [[ -n "${GRAPH_CLIENT_ID:-}" ]] && [[ -n "${GRAPH_CLIENT_SECRET:-}" ]]; then
    local response
    response=$(curl \
      --silent \
      --request POST \
      --header 'Content-Type: application/x-www-form-urlencoded' \
      "https://login.microsoftonline.com/${AZURE_TENANT_ID}/oauth2/v2.0/token" \
      --data "client_id=${GRAPH_CLIENT_ID}" \
      --data 'grant_type=client_credentials' \
      --data 'scope=https://graph.microsoft.com/.default' \
      --data "client_secret=${GRAPH_CLIENT_SECRET}")
    echo "$response" | jq -r '.access_token // empty'
    return
  fi

  # Option 2: az CLI (local [env1])
  if command -v az &>/[env1]/null; then
    az account get-access-token --resource https://graph.microsoft.com --query accessToken -o tsv 2>/[env1]/null || true
    return
  fi
}

GRAPH_TOKEN=$(get_graph_token)
if [[ -z "$GRAPH_TOKEN" ]] || [[ "$GRAPH_TOKEN" == "null" ]]; then
  echo "Could not obtain Graph API token. Skipping Entra group fetch."
  echo "(This is expected when running without GroupMember.Read.All permission.)"
  exit 0
fi

echo "Successfully obtained Graph API token."

# =============================================================================
# Authentication: Azure Key Vault
#
# Try az CLI first (local [env1]), then fall back to managed identity (ACA).

KV_TOKEN=""

get_kv_token() {
  # Option 1: Managed identity (ACA)
  if [[ -n "${IDENTITY_ENDPOINT:-}" ]] && [[ -n "${IDENTITY_HEADER:-}" ]]; then
    local response
    response=$(curl \
      --silent \
      --request GET \
      "${IDENTITY_ENDPOINT}?resource=https%3A%2F%2Fvault.azure.net&api-version=2019-08-01" \
      --header "X-IDENTITY-HEADER: ${IDENTITY_HEADER}")
    echo "$response" | jq -r '.access_token // empty'
    return
  fi
}

kv_set_secret() {
  local vault_name="$1" secret_name="$2" value="$3"

  # Option 1: az CLI (local [env1])
  if command -v az &>/[env1]/null; then
    az keyvault secret set \
      --vault-name "$vault_name" \
      --name "[SECRET_NAME]" \
      --value "$value" \
      -o none 2>&1
    return
  fi

  # Option 2: REST API with managed identity token (ACA)
  if [[ -z "$KV_TOKEN" ]]; then
    KV_TOKEN=$(get_kv_token)
  fi

  if [[ -z "$KV_TOKEN" ]] || [[ "$KV_TOKEN" == "null" ]]; then
    echo "  ERROR: No Key Vault token available" >&2
    return 1
  fi

  local response
  response=$(curl \
    --silent \
    --request PUT \
    --header "Authorization: Bearer ${KV_TOKEN}" \
    --header "Content-Type: application/json" \
    --write-out "\n%{http_code}" \
    --data "$(jq -n --arg v "$value" '{value: $v}')" \
    "https://${vault_name}.vault.azure.net/secrets/${secret_name}?api-version=7.4")

  local http_code
  http_code=$(echo "$response" | tail -1)
  if [[ "$http_code" != "200" ]]; then
    local body
    body=$(echo "$response" | sed '$d')
    echo "  ERROR: Key Vault PUT returned HTTP $http_code: $body" >&2
    return 1
  fi
}

# =============================================================================
# Helper: Get all members of an Entra group via Microsoft Graph API
# Returns JSON array of {id, displayName, userPrincipalName} objects

get_group_members() {
  local group_id="$1"
  local url="https://graph.microsoft.com/v1.0/groups/${group_id}/members?\$select=id,displayName,userPrincipalName&\$top=999"
  local all_members="[]"

  while [[ -n "$url" ]] && [[ "$url" != "null" ]]; do
    local response
    response=$(curl \
      --silent \
      --connect-timeout 10 \
      --max-time 30 \
      --header "Authorization: Bearer ${GRAPH_TOKEN}" \
      "$url")

    local error
    error=$(echo "$response" | jq -r '.error.message // empty' 2>/[env1]/null || true)
    if [[ -n "$error" ]]; then
      echo "  ERROR from Graph API: $error" >&2
      return 1
    fi

    local page_members
    page_members=$(echo "$response" | jq '[.value[] | {id, displayName, userPrincipalName}]' 2>/[env1]/null || echo "[]")
    all_members=$(echo "$all_members" "$page_members" | jq -s 'add')

    url=$(echo "$response" | jq -r '."@odata.nextLink" // empty' 2>/[env1]/null || true)
  done

  echo "$all_members"
}

# =============================================================================
# Main: For each role, fetch group members and store in Key Vault

for role_name in $(echo "$ROLES_JSON" | jq -r 'keys[]'); do
  group_id=$(echo "$ROLES_JSON" | jq -r ".\"${role_name}\".group_id")
  secret_name="lakekeeper-role-${role_name}-members"

  echo ""
  echo "--- Role: $role_name (group: $group_id) ---"

  members=$(get_group_members "$group_id")
  count=$(echo "$members" | jq 'length')
  echo "  Found $count members in Entra group"

  if [[ "$count" == "0" ]]; then
    echo "  Storing empty member list in Key Vault secret: $secret_name"
  else
    echo "  Members:"
    echo "$members" | jq -r '.[] | "    \(.displayName // "?") (\(.userPrincipalName // .id))"'
    echo "  Storing in Key Vault secret: $secret_name"
  fi

  kv_set_secret "$KEY_VAULT_NAME" "$secret_name" "$members"
  echo "  Done."
done

echo ""
echo "Entra group fetch complete."