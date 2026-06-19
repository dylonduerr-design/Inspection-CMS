#!/bin/bash
#
# Complete Deployment Script with Azure Blob Storage
# Deploys the application with persistent image storage
#

set -e  # Exit on error

echo "======================================"
echo "Full Deployment with Azure Storage"
echo "======================================"
echo ""

# Load environment
if [ -f .env.deployment ]; then
  source .env.deployment
  echo "✓ Loaded environment variables"
else
  echo "✗ Error: .env.deployment not found"
  exit 1
fi

# Set storage account name
export STORAGE_ACCOUNT_NAME="icmsinspectionstorage"

echo ""
echo "Step 1: Login to Azure Container Registry..."

az acr login --name $ACR_NAME

echo ""
echo "✓ Logged in to ACR"
echo ""
echo "Step 2: Building Docker image..."
echo "  Registry: $ACR_NAME.azurecr.io"
echo "  Image: cms-inspection-app:latest"
echo ""

docker build --platform linux/amd64 -f Dockerfile.combined \
  -t $ACR_NAME.azurecr.io/cms-inspection-app:latest .

echo ""
echo "✓ Docker image built successfully"
echo ""
echo "Step 3: Pushing to Azure Container Registry..."

docker push $ACR_NAME.azurecr.io/cms-inspection-app:latest

echo ""
echo "✓ Image pushed to registry"
echo ""
echo "Step 4: Restarting App Service..."

az webapp restart \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP

echo ""
echo "✓ App Service restarted"
echo ""
echo "Step 5: Waiting for app to start (30 seconds)..."

sleep 30

echo ""
echo "======================================"
echo "Deployment Complete!"
echo "======================================"
echo ""
echo "Application URL: https://$APP_NAME.azurewebsites.net"
echo ""
echo "Storage Configuration:"
echo "  Account: $STORAGE_ACCOUNT_NAME"
echo "  Container: inspection-uploads"
echo ""
echo "Next Steps:"
echo "1. Test image upload in a report"
echo "2. Verify thumbnail displays correctly"
echo "3. Test image download"
echo "4. Export report to Word and check images"
echo "5. Restart app and verify images still work"
echo ""
echo "To monitor logs:"
echo "  az webapp log tail --name $APP_NAME --resource-group $RESOURCE_GROUP"
echo ""