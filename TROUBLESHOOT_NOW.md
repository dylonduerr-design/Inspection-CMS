# TROUBLESHOOTING: Images Still Missing from Word Export

## Current Status

✅ Azure Blob Storage configured (`icmsinspectionstorage`)
✅ Azure Storage environment variables set in App Service
✅ Production config changed to use `:azure` service
✅ `azure-storage-blob` gem installed
✅ Python diagnostic logging deployed
✅ Latest code deployed

## CRITICAL: Are You Testing with NEW or OLD Images?

**OLD images** (uploaded before Azure Storage fix) are **PERMANENTLY DELETED** and cannot be recovered.

You MUST:
1. Upload NEW images to a report (after the storage fix deployment)
2. Test Word export with these NEW images

## Step-by-Step Test

### Test 1: Upload Fresh Images

1. Go to https://geometriceng-icms-app.azurewebsites.net
2. Open any report (or create a new one)
3. **Delete all existing image attachments** (they're broken anyway)
4. Upload 2-3 NEW test images (JPEG or PNG)
5. Save the report
6. **Verify thumbnails display** ← Should work now with Azure Storage

### Test 2: Check Image URLs

After uploading NEW images:

1. Right-click on an image thumbnail
2. Select "Open image in new tab"
3. Check the URL:

**SHOULD SEE (Azure Blob Storage - GOOD):**
```
https://icmsinspectionstorage.blob.core.windows.net/inspection-uploads/...
```

**SHOULD NOT SEE (Local disk - BAD):**
```
/rails/active_storage/disk/...
```

If you still see `/disk/` URLs, the app isn't using Azure Storage properly.

### Test 3: Export to Word

1. Click "Export Word" on a report with NEW images
2. Download the .docx file
3. Open in Microsoft Word
4. **Check if images appear**

### Test 4: Monitor Logs During Export

Open a terminal and run:
```bash
az webapp log tail \
  --name geometriceng-icms-app \
  --resource-group geometrics-icms-rg | grep -i "python\|photo\|image\|validat"
```

Then click "Export Word" while logs are running.

**Look for these diagnostic messages:**

#### SUCCESS Pattern:
```
INFO: Processing 3 photos for export
INFO: Photo 1: path=/tmp/photo..., exists=True
INFO: Validating image: /tmp/photo..., size=123456 bytes
INFO: Image validation PASSED: /tmp/photo...
INFO: Creating InlineImage for photo 1: /tmp/photo...
INFO: Photo 1 - SUCCESS: Added to document
```

#### FAILURE Patterns:

**Pattern A: File Not Found**
```
ERROR: Photo 1 - FILE NOT FOUND: /tmp/photo...
```
→ Temp file deleted before Python could read it

**Pattern B: Validation Failed**
```
ERROR: Image validation FAILED for /tmp/photo...: UnrecognizedImageError
```
→ Image format not supported by python-docx

**Pattern C: No Photos Passed**
```
INFO: Processing 0 photos for export
```
→ Ruby isn't passing images to Python (ActiveStorage download failed)

**Pattern D: InlineImage Creation Failed**
```
ERROR: Photo 1 - InlineImage creation FAILED (ValueError): ...
```
→ python-docx can't create InlineImage object

## Possible Issues & Solutions

### Issue 1: Still seeing `/disk/` URLs

**Cause:** App not using Azure Storage

**Solution:**
```bash
# Verify environment variables are set
az webapp config appsettings list \
  --name geometriceng-icms-app \
  --resource-group geometrics-icms-rg \
  --query "[?contains(name, 'AZURE_STORAGE')]"

# Should show:
# - AZURE_STORAGE_ACCOUNT_NAME
# - AZURE_STORAGE_ACCESS_KEY
# - AZURE_STORAGE_CONTAINER

# If missing, run:
source .env.deployment
./setup_azure_storage.sh
```

### Issue 2: Gem not loaded error

**Log shows:** `cannot load such file -- azure/storage/blob`

**Solution:** Gem not installed in Docker image. Rebuild:
```bash
source .env.deployment
./deploy_with_azure_storage.sh
```

### Issue 3: Images download but don't appear in Word

**Logs show:** `Photo 1 - SUCCESS` but Word doc still empty

**Possible causes:**
1. Template doesn't have photo placeholders (`{{photo_1}}`)
2. Python docxtpl rendering issue
3. Word document corruption

**Solution:** Check template file has placeholders:
```bash
# Check if template exists
ls -la app/assets/documents/inspection_template.docx
```

### Issue 4: ActiveStorage::FileNotFoundError

**Log shows:** `ActiveStorage::FileNotFoundError`

**Cause:** Azure Storage credentials wrong or container doesn't exist

**Solution:**
```bash
# Verify storage container exists
az storage container show \
  --name inspection-uploads \
  --account-name icmsinspectionstorage \
  --auth-mode login

# If not found, create it:
az storage container create \
  --name inspection-uploads \
  --account-name icmsinspectionstorage \
  --auth-mode login
```

## Quick Diagnostic Commands

```bash
# 1. Check Azure Storage configuration
az webapp config appsettings list \
  --name geometriceng-icms-app \
  --resource-group geometrics-icms-rg \
  --query "[?contains(name, 'AZURE')]" -o table

# 2. Check storage container
az storage container list \
  --account-name icmsinspectionstorage \
  --auth-mode login -o table

# 3. Check recent app logs
az webapp log tail \
  --name geometriceng-icms-app \
  --resource-group geometrics-icms-rg

# 4. Check deployed image tag
az webapp config container show \
  --name geometriceng-icms-app \
  --resource-group geometrics-icms-rg
```

## Next Steps

1. **Upload NEW test images** (don't use old ones - they're gone)
2. **Run Test 1-4 above** with fresh images
3. **Capture the diagnostic logs** during export
4. **Share the logs** to identify the exact failure point

The diagnostic logging will tell us EXACTLY where it's failing:
- Is Azure Storage working?
- Are temp files being created?
- Is Python receiving the images?
- Is image validation passing?
- Is InlineImage creation succeeding?

**Without testing with NEW images and checking logs, we can't diagnose further!**