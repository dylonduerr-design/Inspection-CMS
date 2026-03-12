# CRITICAL FIX: Azure Blob Storage Setup

## ROOT CAUSE OF ALL IMAGE ISSUES

Your production app is configured to use **local disk storage** (`config.active_storage.service = :local`), but Azure App Service containers are **ephemeral** - files are deleted on restart!

**This explains:**
1. ✗ Broken image thumbnails (404 errors)
2. ✗ Download buttons return 404
3. ✗ Images missing from Word exports
4. ✗ Images disappear after app restart

## THE FIX: Azure Blob Storage

You MUST use Azure Blob Storage for persistent file storage in production.

---

## Step 1: Create Azure Storage Account

```bash
# Load environment
source .env.deployment

# Create storage account (choose a unique name)
export STORAGE_ACCOUNT_NAME="icmsinspectionstorage"

az storage account create \
  --name $STORAGE_ACCOUNT_NAME \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --sku Standard_LRS \
  --kind StorageV2 \
  --allow-blob-public-access false

# Create blob container for uploads
az storage container create \
  --name inspection-uploads \
  --account-name $STORAGE_ACCOUNT_NAME \
  --auth-mode login

# Get storage account key
export STORAGE_KEY=$(az storage account keys list \
  --account-name $STORAGE_ACCOUNT_NAME \
  --resource-group $RESOURCE_GROUP \
  --query '[0].value' -o tsv)

echo "Storage Account: $STORAGE_ACCOUNT_NAME"
echo "Storage Key: $STORAGE_KEY"
```

---

## Step 2: Update Rails Configuration

### 2.1 Add Azure Storage to config/storage.yml

Add this configuration:

```yaml
azure:
  service: AzureStorage
  storage_account_name: <%= ENV['AZURE_STORAGE_ACCOUNT_NAME'] %>
  storage_access_key: <%= ENV['AZURE_STORAGE_ACCESS_KEY'] %>
  container: <%= ENV.fetch('AZURE_STORAGE_CONTAINER', 'inspection-uploads') %>
```

### 2.2 Update config/environments/production.rb

Change line 41 from:
```ruby
config.active_storage.service = :local
```

To:
```ruby
config.active_storage.service = :azure
```

---

## Step 3: Add Azure Storage Gem

Add to `Gemfile`:

```ruby
# Azure Blob Storage for production file uploads
gem "azure-storage-blob", "~> 2.0", require: false
```

Then run:
```bash
bundle install
```

---

## Step 4: Configure App Service Environment Variables

```bash
source .env.deployment

# Set the storage account name you created
export STORAGE_ACCOUNT_NAME="icmsinspectionstorage"

# Get the storage key
export STORAGE_KEY=$(az storage account keys list \
  --account-name $STORAGE_ACCOUNT_NAME \
  --resource-group $RESOURCE_GROUP \
  --query '[0].value' -o tsv)

# Configure in App Service
az webapp config appsettings set \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --settings \
    AZURE_STORAGE_ACCOUNT_NAME="$STORAGE_ACCOUNT_NAME" \
    AZURE_STORAGE_ACCESS_KEY="$STORAGE_KEY" \
    AZURE_STORAGE_CONTAINER="inspection-uploads"
```

---

## Step 5: Deploy the Fix

```bash
source .env.deployment

# 1. Commit changes
git add config/storage.yml config/environments/production.rb Gemfile Gemfile.lock
git commit -m "CRITICAL: Configure Azure Blob Storage for production

- Add Azure Storage configuration to storage.yml
- Change production to use :azure service
- Add azure-storage-blob gem
- Fixes: broken thumbnails, 404 errors, missing images in exports
"

# 2. Build with new dependencies
docker build --platform linux/amd64 -f Dockerfile.combined \
  -t $ACR_NAME.azurecr.io/cms-inspection-app:latest .

# 3. Push to registry
docker push $ACR_NAME.azurecr.io/cms-inspection-app:latest

# 4. Restart app (environment variables already set)
az webapp restart --name $APP_NAME --resource-group $RESOURCE_GROUP

# 5. Wait for startup
sleep 30

# 6. Test
echo "Test at: https://$APP_NAME.azurewebsites.net"
```

---

## Step 6: Test After Deployment

### Test 1: Upload New Images
1. Go to any report
2. Upload a test image
3. **Image thumbnail should appear** ✓
4. Click download button - **should download** ✓
5. Export Word - **images should be in document** ✓

### Test 2: Restart App (Persistence Test)
```bash
az webapp restart --name $APP_NAME --resource-group $RESOURCE_GROUP
```

Wait 30 seconds, then:
1. Go back to the report
2. **Image thumbnail should STILL appear** ✓ (this was broken before)
3. Download should STILL work ✓

### Test 3: Check Logs
```bash
az webapp log tail --name $APP_NAME --resource-group $RESOURCE_GROUP
```

Should see:
- No more "FILE NOT FOUND" errors
- No more 404 errors for images
- Successful image downloads
- Successful Word exports with images

---

## Why This Fixes Everything

### Before (Broken):
```
Upload → Local Disk → App Restart → Files DELETED → 404 Errors
```

### After (Fixed):
```
Upload → Azure Blob Storage → App Restart → Files PERSIST → Everything Works
```

---

## Migration Note: Existing Images

**Important:** Images uploaded before this fix are LOST (they were on ephemeral disk).

Users will need to re-upload images to existing reports. There's no way to recover them since they were never persisted to permanent storage.

---

## Cost

Azure Blob Storage pricing (Standard LRS, West US 3):
- Storage: ~$0.018 per GB/month
- Transactions: ~$0.004 per 10,000 operations

**Example:** 10 GB of images + 100,000 operations/month = ~$0.22/month

**Much cheaper than the image issues you're experiencing!**

---

## Troubleshooting

### If you see "azure-storage-blob not found"
Make sure the gem is in your Gemfile and run `bundle install` before building the Docker image.

### If you see "Container not found"
Make sure you created the blob container:
```bash
az storage container create \
  --name inspection-uploads \
  --account-name $STORAGE_ACCOUNT_NAME \
  --auth-mode login
```

### If images still 404 after deployment
Check environment variables are set:
```bash
az webapp config appsettings list \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --query "[?contains(name, 'AZURE_STORAGE')]"
```

---

## DO THIS FIX FIRST!

All other image fixes (URL caching, diagnostics, etc.) won't work until you have proper persistent storage configured.

**This is the foundation that everything else depends on.**