#!/bin/bash

# Deployment Script for URL Caching Feature
# This script automates the deployment of the URL caching feature to Azure

set -e  # Exit on any error

echo "=========================================="
echo "URL Caching Feature Deployment Script"
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print colored output
print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "ℹ️  $1"
}

# Check if environment variables are set
echo "Step 1: Checking environment variables..."
if [ -z "$RESOURCE_GROUP" ] || [ -z "$APP_NAME" ] || [ -z "$ACR_NAME" ]; then
    print_error "Environment variables not set!"
    echo ""
    echo "Please set the following environment variables:"
    echo ""
    echo "export RESOURCE_GROUP=\"geometrics-icms-rg\""
    echo "export APP_NAME=\"geometriceng-icms-app\""
    echo "export ACR_NAME=\"geometricsicmsac01mar26\""
    echo ""
    exit 1
fi

print_success "Environment variables set"
print_info "Resource Group: $RESOURCE_GROUP"
print_info "App Name: $APP_NAME"
print_info "ACR Name: $ACR_NAME"
echo ""

# Verify Azure CLI is installed
echo "Step 2: Verifying Azure CLI..."
if ! command -v az &> /dev/null; then
    print_error "Azure CLI not found. Please install it first."
    echo "Install: brew install azure-cli"
    exit 1
fi
print_success "Azure CLI found"
echo ""

# Verify Docker is installed
echo "Step 3: Verifying Docker..."
if ! command -v docker &> /dev/null; then
    print_error "Docker not found. Please install it first."
    exit 1
fi
print_success "Docker found"
echo ""

# Check if logged in to Azure
echo "Step 4: Checking Azure login..."
if ! az account show &> /dev/null; then
    print_warning "Not logged in to Azure"
    print_info "Running: az login"
    az login
fi
print_success "Logged in to Azure"
SUBSCRIPTION=$(az account show --query name -o tsv)
print_info "Subscription: $SUBSCRIPTION"
echo ""

# Login to ACR
echo "Step 5: Logging in to Azure Container Registry..."
print_info "Running: az acr login --name $ACR_NAME"
if az acr login --name "$ACR_NAME"; then
    print_success "Logged in to ACR"
else
    print_error "Failed to login to ACR"
    exit 1
fi
echo ""

# Build Docker image
echo "Step 6: Building Docker image..."
print_warning "This may take 5-10 minutes..."
print_info "Running: docker build --platform linux/amd64 -f Dockerfile.combined -t ${ACR_NAME}.azurecr.io/cms-inspection-app:latest ."

if docker build --platform linux/amd64 \
    -f Dockerfile.combined \
    -t "${ACR_NAME}.azurecr.io/cms-inspection-app:latest" \
    . ; then
    print_success "Docker image built successfully"
else
    print_error "Failed to build Docker image"
    exit 1
fi
echo ""

# Verify image was created
echo "Step 7: Verifying Docker image..."
if docker images | grep -q "cms-inspection-app.*latest"; then
    IMAGE_ID=$(docker images | grep "cms-inspection-app.*latest" | awk '{print $3}')
    print_success "Image created: $IMAGE_ID"
else
    print_error "Image not found"
    exit 1
fi
echo ""

# Push to ACR
echo "Step 8: Pushing image to Azure Container Registry..."
print_warning "This may take 3-5 minutes..."
print_info "Running: docker push ${ACR_NAME}.azurecr.io/cms-inspection-app:latest"

if docker push "${ACR_NAME}.azurecr.io/cms-inspection-app:latest"; then
    print_success "Image pushed to ACR"
else
    print_error "Failed to push image"
    exit 1
fi
echo ""

# Verify image in registry
echo "Step 9: Verifying image in registry..."
if az acr repository show-tags \
    --name "$ACR_NAME" \
    --repository cms-inspection-app \
    --output table | grep -q "latest"; then
    print_success "Image verified in ACR"
else
    print_error "Image not found in ACR"
    exit 1
fi
echo ""

# Restart application
echo "Step 10: Restarting Azure App Service..."
print_info "Running: az webapp restart --name $APP_NAME --resource-group $RESOURCE_GROUP"

if az webapp restart \
    --name "$APP_NAME" \
    --resource-group "$RESOURCE_GROUP"; then
    print_success "App restart initiated"
else
    print_error "Failed to restart app"
    exit 1
fi
echo ""

# Wait for app to start
echo "Step 11: Waiting for application to start..."
print_info "Waiting 30 seconds..."
sleep 30
print_success "Wait complete"
echo ""

# Check app status
echo "Step 12: Checking application status..."
APP_STATE=$(az webapp show \
    --name "$APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query "state" \
    --output tsv)

if [ "$APP_STATE" == "Running" ]; then
    print_success "Application is running"
else
    print_warning "Application state: $APP_STATE"
fi
echo ""

# Get app URL
APP_URL="https://${APP_NAME}.azurewebsites.net"
print_info "Application URL: $APP_URL"
echo ""

# Summary
echo "=========================================="
echo "Deployment Summary"
echo "=========================================="
print_success "Deployment completed successfully!"
echo ""
echo "Next steps:"
echo "1. Open application: $APP_URL"
echo "2. Login and test image upload"
echo "3. Export a report to Word"
echo "4. Verify cache logs:"
echo "   az webapp log tail --name $APP_NAME --resource-group $RESOURCE_GROUP | grep Cache"
echo ""
echo "Expected performance:"
echo "- Upload: URLs cached automatically"
echo "- Export: <1 second for 6 images"
echo "- Cache hit rate: 100% for cached images"
echo ""
print_success "Deployment script finished!"
echo "=========================================="