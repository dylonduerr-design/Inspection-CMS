#!/bin/bash
#
# Azure Blob Storage Setup Script
# This script creates and configures Azure Blob Storage for persistent file uploads
#

set -e  # Exit on error

echo "======================================"
echo "Azure Blob Storage Setup"
echo "======================================"
echo ""

# Load environment variables
if [ -f .env.deployment ]; then
  source .env.deployment
  echo "✓ Loaded environment from .env.deployment"
else
  echo "✗ Error: .env.deployment file not found"
  exit 1
fi

# Check required variables
if [ -z "$RESOURCE_GROUP" ] || [ -z "$LOCATION" ] || [ -z "$APP_NAME" ]; then
  echo "✗ Error: Required environment variables not set"
  echo "  Required: RESOURCE_GROUP, LOCATION, APP_NAME"
  exit 1
fi

echo "Configuration:"
echo "  Resource Group: $RESOURCE_GROUP"
echo "  Location: $LOCATION"
echo "  App Name: $APP_NAME"
echo ""

# Storage account name (must be unique, lowercase, no hyphens)
STORAGE_ACCOUNT_NAME="icmsinspectionstorage"
CONTAINER_NAME="inspection-uploads"

echo "Step 1: Creating Azure Storage Account..."
echo "  Account Name: $STORAGE_ACCOUNT_NAME"
echo "  Container: $CONTAINER_NAME"
echo ""

# Check if storage account already exists
if az storage account show --name $STORAGE_ACCOUNT_NAME --resource-group $RESOURCE_GROUP &>/dev/null; then
  echo "✓ Storage account already exists: $STORAGE_ACCOUNT_NAME"
else
  echo "Creating storage account..."
  az storage account create \
    --name $STORAGE_ACCOUNT_NAME \
    --resource-group $RESOURCE_GROUP \
    --location $LOCATION \
    --sku Standard_LRS \
    --kind StorageV2 \
    --allow-blob-public-access false \
    --min-tls-version TLS1_2

  echo "✓ Storage account created: $STORAGE_ACCOUNT_NAME"
fi

echo ""
echo "Step 2: Creating blob container..."

# Check if container already exists
if az storage container show --name $CONTAINER_NAME --account-name $STORAGE_ACCOUNT_NAME --auth-mode login &>/dev/null; then
  echo "✓ Container already exists: $CONTAINER_NAME"
else
  echo "Creating container..."
  az storage container create \
    --name $CONTAINER_NAME \
    --account-name $STORAGE_ACCOUNT_NAME \
    --auth-mode login

  echo "✓ Container created: $CONTAINER_NAME"
fi

echo ""
echo "Step 3: Retrieving storage account key..."

STORAGE_KEY=$(az storage account keys list \
  --account-name $STORAGE_ACCOUNT_NAME \
  --resource-group $RESOURCE_GROUP \
  --query '[0].value' -o tsv)

if [ -z "$STORAGE_KEY" ]; then
  echo "✗ Error: Failed to retrieve storage account key"
  exit 1
fi

echo "✓ Storage key retrieved"
echo ""
echo "Step 4: Configuring App Service environment variables..."

az webapp config appsettings set \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --settings \
    AZURE_STORAGE_ACCOUNT_NAME="$STORAGE_ACCOUNT_NAME" \
    AZURE_STORAGE_ACCESS_KEY="$STORAGE_KEY" \
    AZURE_STORAGE_CONTAINER="$CONTAINER_NAME" \
  --output table

echo ""
echo "✓ App Service configured with Azure Storage credentials"
echo ""
echo "======================================"
echo "Azure Storage Setup Complete!"
echo "======================================"
echo ""
echo "Storage Account: $STORAGE_ACCOUNT_NAME"
echo "Container: $CONTAINER_NAME"
echo "Region: $LOCATION"
echo ""
echo "Next Steps:"
echo "1. Deploy the updated application (config changes already committed)"
echo "2. Test image upload and download"
echo "3. Verify images persist after app restart"
echo ""
echo "To deploy now, run:"
echo "  ./deploy_with_azure_storage.sh"
echo ""