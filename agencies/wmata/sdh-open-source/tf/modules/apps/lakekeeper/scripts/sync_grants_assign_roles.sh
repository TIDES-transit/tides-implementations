#!/bin/bash
set -euo pipefail

# Step 2: Assign Lakekeeper Roles from Key Vault Membership Data
#
# Reads group membership from Key Vault secrets (stored by step 1), creates
# Lakekeeper roles, assigns permissions to roles, and syfare role membership.
# Also applies app service principal grants.
#
# Expected environment variables:
# - AZURE_TENANT_ID
# - KEY_VAULT_NAME
# - ROLES_JSON                       - JSON describing role->group->permissions
# - APP_SP_GRANTS_JSON               - (optional) JSON describing app SP grants
# - LAKEKEEPER_AUTH_CLIENT_ID        - Client ID for Lakekeeper API auth
# - LAKEKEEPER_AUTH_CLIENT_SECRET    - (optional) Client secret for client credentials auth
# - LAKEKEEPER_APP_ID_URI
# - LAKEKEEPER_HOST

echo "=== Step 2: Assign Lakekeeper roles ==="

# Validate required environment variables
for var in AZURE_TENANT_ID LAKEKEEPER_AUTH_CLIENT_ID LAKEKEEPER_APP_ID_URI LAKEKEEPER_HOST; do
  if [[ -z "${!var:-}" ]]; then
    echo "ERROR: Required environment variable $var is not set"
    exit 1
  fi
done

# =============================================================================
# Authentication: Lakekeeper API

if [[ -n "${LAKEKEEPER_AUTH_CLIENT_SECRET:-}" ]]; then
  echo "Obtaining Lakekeeper auth token via client credentials..."
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
  echo "Obtaining Lakekeeper auth token via managed identity..."
  TOKEN_RESPONSE=$(curl \
    --silent \
    --request GET \
    "${IDENTITY_ENDPOINT}?resource=${LAKEKEEPER_APP_ID_URI}&api-version=2019-08-01&client_id=${LAKEKEEPER_AUTH_CLIENT_ID}" \
    --header "X-IDENTITY-HEADER: ${IDENTITY_HEADER}")

  LAKEKEEPER_AUTH_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token')
else
  echo "ERROR: No Lakekeeper authentication method available."
  echo "Either set LAKEKEEPER_AUTH_CLIENT_SECRET for client credentials flow,"
  echo "or ensure the container has a managed identity assigned."
  exit 1
fi

if [[ "$LAKEKEEPER_AUTH_TOKEN" == "null" ]] || [[ -z "$LAKEKEEPER_AUTH_TOKEN" ]]; then
  echo "ERROR: Failed to obtain Lakekeeper auth token. Response: $TOKEN_RESPONSE"
  exit 1
fi

echo "Successfully obtained Lakekeeper auth token."

# =============================================================================
# Authentication: Azure Key Vault

KV_TOKEN=""

get_kv_token() {
  if [[ -n "${IDENTITY_ENDPOINT:-}" ]] && [[ -n "${IDENTITY_HEADER:-}" ]]; then
    local mi_url="${IDENTITY_ENDPOINT}?resource=https%3A%2F%2Fvault.azure.net&api-version=2019-08-01"
    # When a user-assigned MI is present, we must specify its client_id
    if [[ -n "${AZURE_MI_CLIENT_ID:-}" ]]; then
      mi_url="${mi_url}&client_id=${AZURE_MI_CLIENT_ID}"
    fi
    local response
    response=$(curl \
      --silent \
      --request GET \
      "$mi_url" \
      --header "X-IDENTITY-HEADER: ${IDENTITY_HEADER}")
    echo "$response" | jq -r '.access_token // empty'
    return
  fi
}

kv_get_secret() {
  local vault_name="$1" secret_name="$2"

  # Option 1: az CLI (local [env1])
  if command -v az &>/[env1]/null; then
    az keyvault secret show \
      --vault-name "$vault_name" \
      --name "[SECRET_NAME]" \
      --query value -o tsv 2>/[env1]/null || true
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
    --request GET \
    --header "Authorization: Bearer ${KV_TOKEN}" \
    "https://${vault_name}.vault.azure.net/secrets/${secret_name}?api-version=7.4")

  local error
  error=$(echo "$response" | jq -r '.error.message // empty' 2>/[env1]/null || true)
  if [[ -n "$error" ]]; then
    echo "  WARNING: Key Vault GET error for '$secret_name': $error" >&2
    return 1
  fi

  echo "$response" | jq -r '.value // empty'
}

# =============================================================================
# Base URL and health check

PROTOCOL="${LAKEKEEPER_PROTOCOL:-http}"
BASE_URL="${PROTOCOL}://${LAKEKEEPER_HOST}"

echo "Checking Lakekeeper health..."
HEALTH_URL="${BASE_URL}/health"
if ! curl --silent --connect-timeout 10 --max-time 30 -o /[env1]/null -w "HTTP %{http_code}\n" "${HEALTH_URL}"; then
  echo "WARNING: Health check failed or timed out"
fi

# =============================================================================
# Lakekeeper API helpers

LK_HTTP_CODE=""
lk_api() {
  local method="$1"
  local endpoint="$2"
  local data="${3:-}"

  local args=(
    --silent
    --connect-timeout 30
    --max-time 60
    --request "$method"
    --header "Authorization: Bearer ${LAKEKEEPER_AUTH_TOKEN}"
    --header "Content-Type: application/json"
    --write-out "\n%{http_code}"
  )

  if [[ -n "$data" ]]; then
    args+=(--data "$data")
  fi

  local raw
  raw=$(curl "${args[@]}" "${BASE_URL}${endpoint}")

  LK_HTTP_CODE=$(echo "$raw" | tail -1)
  echo "$raw" | sed '$d'
}

# Find or create a Lakekeeper role by name. Prints role ID to stdout.
ensure_role() {
  local role_name="$1"

  # Search for existing role
  local search_body
  search_body=$(jq -n --arg name "$role_name" '{"search": $name}')

  local search_response
  search_response=$(lk_api POST "/management/v1/search/role" "$search_body")

  local role_id
  role_id=$(echo "$search_response" | jq -r --arg name "$role_name" '.roles[]? | select(.name == $name) | .id // empty' 2>/[env1]/null || true)

  if [[ -n "$role_id" ]]; then
    echo "  Found existing role '$role_name': $role_id" >&2
    echo "$role_id"
    return 0
  fi

  # Create the role
  local create_body
  create_body=$(jq -n --arg name "$role_name" '{"name": $name}')

  local create_response
  create_response=$(lk_api POST "/management/v1/role" "$create_body")

  # Try to extract role ID from response regardless of HTTP code —
  # the create endpoint may return the role directly on success
  role_id=$(echo "$create_response" | jq -r '.id // empty' 2>/[env1]/null || true)
  if [[ -n "$role_id" ]]; then
    echo "  Created role '$role_name': $role_id (HTTP ${LK_HTTP_CODE})" >&2
    echo "$role_id"
    return 0
  fi

  # 409 means the role already exists — list all roles and find it
  if [[ "$LK_HTTP_CODE" == "409" ]]; then
    local list_response
    list_response=$(lk_api GET "/management/v1/role")
    role_id=$(echo "$list_response" | jq -r --arg name "$role_name" '.roles[]? | select(.name == $name) | .id // empty' 2>/[env1]/null || true)
    if [[ -n "$role_id" ]]; then
      echo "  Found role '$role_name' (after 409): $role_id" >&2
      echo "$role_id"
      return 0
    fi
  fi

  echo "  ERROR: Failed to create/find role '$role_name'. HTTP ${LK_HTTP_CODE}: $create_response" >&2
  return 1
}

# Write a single permission assignment (handles 409)
# subject_type: "user" or "role"
write_assignment() {
  local endpoint="$1"
  local subject_type="$2"
  local subject_id="$3"
  local relation="$4"

  local request_body
  if [[ "$subject_type" == "role" ]]; then
    request_body=$(jq -n --arg role "$subject_id" --arg type "$relation" \
      '{"writes": [{"role": $role, "type": $type}]}')
  else
    request_body=$(jq -n --arg user "$subject_id" --arg type "$relation" \
      '{"writes": [{"user": $user, "type": $type}]}')
  fi

  lk_api POST "$endpoint" "$request_body" > /[env1]/null

  if [[ "$LK_HTTP_CODE" == "200" ]] || [[ "$LK_HTTP_CODE" == "204" ]]; then
    echo "      Added ($LK_HTTP_CODE)"
  elif [[ "$LK_HTTP_CODE" == "409" ]]; then
    echo "      Already exists (409)"
  else
    echo "      ERROR: HTTP $LK_HTTP_CODE"
    return 1
  fi
}

# Delete a single permission assignment (handles 404)
# subject_type: "user" or "role"
delete_assignment() {
  local endpoint="$1"
  local subject_type="$2"
  local subject_id="$3"
  local relation="$4"

  local request_body
  if [[ "$subject_type" == "role" ]]; then
    request_body=$(jq -n --arg role "$subject_id" --arg type "$relation" \
      '{"deletes": [{"role": $role, "type": $type}]}')
  else
    request_body=$(jq -n --arg user "$subject_id" --arg type "$relation" \
      '{"deletes": [{"user": $user, "type": $type}]}')
  fi

  lk_api POST "$endpoint" "$request_body" > /[env1]/null

  if [[ "$LK_HTTP_CODE" == "200" ]] || [[ "$LK_HTTP_CODE" == "204" ]]; then
    echo "      Removed ($LK_HTTP_CODE)"
  elif [[ "$LK_HTTP_CODE" == "404" ]]; then
    echo "      Not found (404), skipping"
  else
    echo "      ERROR: HTTP $LK_HTTP_CODE"
    return 1
  fi
}

# Get current assignees for a role (newline-separated user IDs)
get_role_assignees() {
  local role_id="$1"

  local response
  response=$(lk_api GET "/management/v1/permissions/role/${role_id}/assignments")

  # Lakekeeper v0.9.x returns 409 instead of 200 for this GET (upstream bug)
  if [[ "$LK_HTTP_CODE" != "200" ]] && [[ "$LK_HTTP_CODE" != "409" ]]; then
    echo "  ERROR: Failed to get role assignments (HTTP $LK_HTTP_CODE): $response" >&2
    return 1
  fi

  echo "$response" | jq -r '.assignments[]? | select(.type == "assignee") | .user // empty' 2>/[env1]/null || true
}

# Ensure a role has the right permissions at a given level
ensure_role_permissions() {
  local role_id="$1"
  local level="$2"
  shift 2
  local relations=("$@")

  local endpoint
  case "$level" in
    server)  endpoint="/management/v1/permissions/server/assignments" ;;
    project) endpoint="/management/v1/permissions/project/assignments" ;;
    *)
      echo "    WARNING: Unknown permission level '$level', skipping"
      return 0
      ;;
  esac

  for relation in "${relations[@]}"; do
    echo "    Ensuring ${level}.${relation} for role..."
    write_assignment "$endpoint" "role" "$role_id" "$relation" || true
  done
}

# =============================================================================
# Main: Sync roles from Key Vault membership data

if [[ -n "${ROLES_JSON:-}" ]] && [[ "$ROLES_JSON" != "{}" ]]; then
  if [[ -z "${KEY_VAULT_NAME:-}" ]]; then
    echo "WARNING: KEY_VAULT_NAME not set. Skipping role sync."
  else
    echo ""
    echo "========================================="
    echo "Syncing Lakekeeper roles from Key Vault"
    echo "========================================="

    for role_name in $(echo "$ROLES_JSON" | jq -r 'keys[]'); do
      permissions=$(echo "$ROLES_JSON" | jq -c ".\"${role_name}\".permissions")
      secret_name="lakekeeper-role-${role_name}-members"

      echo ""
      echo "--- Role: $role_name ---"

      # Read membership from Key Vault
      echo "  Reading members from Key Vault secret: $secret_name"
      members=""
      if ! members=$(kv_get_secret "$KEY_VAULT_NAME" "$secret_name"); then
        echo "  WARNING: Could not read Key Vault secret '$secret_name'. Skipping role."
        continue
      fi

      if [[ -z "$members" ]] || [[ "$members" == "null" ]]; then
        echo "  No membership data found in Key Vault. Skipping role."
        echo "  (Run sync_grants_fetch_entra.sh first to populate membership data.)"
        continue
      fi

      member_count=$(echo "$members" | jq 'length' 2>/[env1]/null || echo 0)
      echo "  Found $member_count members in Key Vault"

      # Create or find the Lakekeeper role
      role_id=""
      if ! role_id=$(ensure_role "$role_name"); then
        echo "  SKIPPED: Could not create/find role '$role_name'"
        continue
      fi

      if [[ -z "$role_id" ]]; then
        echo "  SKIPPED: No role ID returned for '$role_name'"
        continue
      fi

      # Ensure the role has the correct permissions
      for level in $(echo "$permissions" | jq -r 'keys[]'); do
        readarray -t relations < <(echo "$permissions" | jq -r ".\"${level}\"[]")
        echo "  Setting ${level}-level permissions: ${relations[*]}"
        ensure_role_permissions "$role_id" "$level" "${relations[@]}"
      done

      # Build desired user IDs (oidc~{entra-object-id})
      readarray -t desired_users < <(echo "$members" | jq -r '.[].id' | sed 's/^/oidc~/')

      # Get current role assignees
      echo "  Fetching current role assignees..."
      current_assignees=""
      if current_assignees=$(get_role_assignees "$role_id"); then
        current_count=$(echo "$current_assignees" | grep -c . 2>/[env1]/null || echo 0)
        echo "  Found $current_count current assignees"
      else
        echo "  ERROR: Could not list current assignees for role '$role_name'. Aborting to avoid leaving stale members."
        exit 1
      fi

      # Add new members to the role
      role_endpoint="/management/v1/permissions/role/${role_id}/assignments"
      for user_id in "${desired_users[@]}"; do
        [[ -z "$user_id" ]] && continue

        if echo "$current_assignees" | grep -qF "$user_id"; then
          echo "    Already assigned: $user_id"
        else
          display_name=$(echo "$members" | jq -r --arg id "${user_id#oidc~}" '.[] | select(.id == $id) | .displayName // .userPrincipalName // "unknown"')
          echo "    Adding: $user_id ($display_name)"
          write_assignment "$role_endpoint" "user" "$user_id" "assignee" || true
        fi
      done

      # Remove stale members from the role
      if [[ -n "$current_assignees" ]]; then
        while IFS= read -r current_user; do
          [[ -z "$current_user" ]] && continue

          is_desired=false
          for desired in "${desired_users[@]}"; do
            if [[ "$desired" == "$current_user" ]]; then
              is_desired=true
              break
            fi
          done

          if [[ "$is_desired" == "false" ]]; then
            echo "    Removing stale: $current_user"
            delete_assignment "$role_endpoint" "user" "$current_user" "assignee" || true
          fi
        done <<< "$current_assignees"
      fi

      echo "  Role '$role_name' sync complete."
    done
  fi
fi

# =============================================================================
# Main: Apply app service principal grants

if [[ -n "${APP_SP_GRANTS_JSON:-}" ]] && [[ "$APP_SP_GRANTS_JSON" != "{}" ]]; then
  echo ""
  echo "========================================="
  echo "Applying app service principal grants"
  echo "========================================="

  for level in $(echo "$APP_SP_GRANTS_JSON" | jq -r 'keys[]'); do
    endpoint=""
    case "$level" in
      server)  endpoint="/management/v1/permissions/server/assignments" ;;
      project) endpoint="/management/v1/permissions/project/assignments" ;;
      *)
        echo "  WARNING: Unknown permission level '$level', skipping"
        continue
        ;;
    esac

    for relation in $(echo "$APP_SP_GRANTS_JSON" | jq -r ".\"${level}\" | keys[]"); do
      users=$(echo "$APP_SP_GRANTS_JSON" | jq -r ".\"${level}\".\"${relation}\"[]")

      while IFS= read -r user_id; do
        [[ -z "$user_id" ]] && continue
        echo "  ${level}.${relation}: $user_id"
        write_assignment "$endpoint" "user" "$user_id" "$relation" || true
      done <<< "$users"
    done
  done
fi

echo ""
echo "Role assignment complete."