#!/bin/bash

# This script is adapted from https://learn.microsoft.com/en-us/azure/developer/terraform/store-state-in-azure-storage?tabs=azure-cli#2-configure-remote-state-storage-account

# Usage: ./create_state_storage.sh [-r, --resource-group] <resource_group_name> [-s, --subscription-id] <subscription_id>

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -r|--resource-group) RESOURCE_GROUP_NAME="$2"; shift ;;
        -s|--subscription-id) SUBSCRIPTION_ID="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

# Ensure that both the resource group and subscription id are provided.
if [ -z "$RESOURCE_GROUP_NAME" ] || [ -z "$SUBSCRIPTION_ID" ]; then
  echo "Error: RESOURCE_GROUP_NAME and SUBSCRIPTION_ID must be set either via command line arguments or environment variables."
  echo
  echo "Usage: ./create_state_storage.sh [-r|--resource-group <resource_group_name>] [-s|--subscription-id <subscription_id>]"
  exit 1
fi

set -e # Exit immediately if a command exits with a non-zero status.

# The tfstate container needs to exist before state can be stored there. Create
# a storage account for the state, named according to the resource group name
# and the subscription. Storage account names must be globally unique, which is
# why we use all of these pieces of information. Also, they can only contain
# numbers and lowercase letters, and can be no longer than 24 characters, so we
# use tr to transform the string.
STORAGE_ACCOUNT_NAME=$(
    echo "iac${SUBSCRIPTION_ID}" |
    tr '[:upper:]' '[:lower:]' |
    tr --delete --complement '[:alnum:]' |
    head -c 24
)
CONTAINER_NAME=tfstate

# Create storage account
echo "Creating storage account $STORAGE_ACCOUNT_NAME in resource group $RESOURCE_GROUP_NAME"
az storage account create --resource-group $RESOURCE_GROUP_NAME --name $STORAGE_ACCOUNT_NAME --sku Standard_LRS --encryption-services blob

# Create blob container
echo "Creating blob container $CONTAINER_NAME in storage account $STORAGE_ACCOUNT_NAME"
az storage container create --name $CONTAINER_NAME --account-name $STORAGE_ACCOUNT_NAME

# TODO:
#
# This script can be used to initialize [env1] and/or prod from CI, so we should do the following as well:
#
# - Initialize tofu
#   tofu init
#
# - Import the storage account and container into tofu
#   tofu import azurerm_storage_account.tfstate /subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP_NAME}/providers/Microsoft.Storage/storageAccounts/${STORAGE_ACCOUNT_NAME}
#   tofu import azurerm_storage_container.tfstate https://${STORAGE_ACCOUNT_NAME}.blob.core.windows.net/tfstate