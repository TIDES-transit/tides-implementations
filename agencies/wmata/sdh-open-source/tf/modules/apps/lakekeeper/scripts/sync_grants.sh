#!/bin/bash
set -euo pipefail

# Sync Grants - Orchestrator
#
# Runs the two-step grants sync process:
#   1. Fetch Entra group members → Key Vault (may no-op if no Graph API access)
#   2. Read Key Vault → Create/sync Lakekeeper roles + apply SP grants
#
# Each step is a standalone script that can also be run independently.
# See individual scripts for required environment variables.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================="
echo "Lakekeeper Grants Sync"
echo "========================================="
echo ""

echo "Running step 1: Fetch Entra group members..."
echo ""
"$SCRIPT_DIR/sync_grants_fetch_entra.sh"

echo ""
echo "Running step 2: Assign Lakekeeper roles..."
echo ""
"$SCRIPT_DIR/sync_grants_assign_roles.sh"

echo ""
echo "========================================="
echo "All grants sync steps complete."
echo "========================================="
