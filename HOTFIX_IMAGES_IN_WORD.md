# HOTFIX: Images Missing in Word Export

## Issue
Images are not appearing in exported Word documents.

## Root Cause
The `download_from_url` method in `ImageUrlCache` was using `URI.open` which may fail with Azure Blob Storage signed URLs.

## Fix Applied
Updated `app/services/image_url_cache.rb` with:
1. More robust HTTP download using `Net::HTTP`
2. Triple-layer fallback mechanism:
   - Try cached URL
   - Try generating new URL
   - Fallback to direct ActiveStorage download (always works)

## Deploy the Fix

### Quick Deployment

```bash
# 1. Set environment
source .env.deployment

# 2. Commit the fix
git add app/services/image_url_cache.rb
git commit -m "Fix: Images missing in Word export

- Replace URI.open with Net::HTTP for better compatibility
- Add triple-layer fallback mechanism
- Ensure images always download via ActiveStorage fallback
"

# 3. Build and deploy
docker build --platform linux/amd64 -f Dockerfile.combined \
  -t geometricsicmsac01mar26.azurecr.io/cms-inspection-app:latest .

docker push geometricsicmsac01mar26.azurecr.io/cms-inspection-app:latest

az webapp restart \
  --name geometriceng-icms-app \
  --resource-group geometrics-icms-rg

# 4. Wait and monitor
sleep 30
az webapp log tail \
  --name geometriceng-icms-app \
  --resource-group geometrics-icms-rg
```

**Time:** ~15-20 minutes

### Or Use the Script

```bash
source .env.deployment
./deploy_url_caching.sh
```

---

## Testing After Deployment

### 1. Upload Images
1. Go to a report
2. Upload 2-3 test images
3. Save

### 2. Export to Word
1. Click "Export Word"
2. Wait for download (should be <1 second)
3. Open Word document
4. **Verify images are present**

### 3. Check Logs

```bash
az webapp log tail \
  --name geometriceng-icms-app \
  --resource-group geometrics-icms-rg \
  | grep -E "ImageUrlCache|photo"
```

**Expected logs:**
```
ImageUrlCache: Cached URL for attachment_id=123
ImageUrlCache: Downloaded from cached URL for attachment_id=123, size=1234567 bytes
PythonDocxExporter: Report generated successfully
```

**Or if URL download fails (fallback working):**
```
ImageUrlCache: Failed to download from cached URL for attachment_id=123: [error], falling back to direct download
ImageUrlCache: Using direct ActiveStorage download for attachment_id=123
PythonDocxExporter: Report generated successfully
```

---

## What Changed

### Before (Broken)
```ruby
def download_from_url(url)
  require 'open-uri'
  URI.open(url, 'rb', &:read)  # Fails with Azure signed URLs
end
```

### After (Fixed)
```ruby
def download_from_url(url)
  require 'net/http'
  uri = URI.parse(url)

  response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
    request = Net::HTTP::Get.new(uri.request_uri)
    http.request(request)
  end

  unless response.is_a?(Net::HTTPSuccess)
    raise "Failed to download image: HTTP #{response.code}"
  end

  response.body
end
```

**Plus added triple fallback:**
1. Cached URL → download
2. New URL → download
3. **Direct ActiveStorage download** (always works)

---

## Success Criteria

✅ Word export completes successfully
✅ All images appear in Word document
✅ Images display correctly (not broken/corrupt)
✅ Logs show successful downloads
✅ No errors in application logs

---

## If Still Broken After Deployment

### Check Logs
```bash
az webapp log tail \
  --name geometriceng-icms-app \
  --resource-group geometrics-icms-rg \
  | grep -i error
```

### Check Specific Error
```bash
az webapp log tail \
  --name geometriceng-icms-app \
  --resource-group geometrics-icms-rg \
  | grep "Failed to process photo"
```

### Nuclear Option: Disable URL Caching Completely

If the fix doesn't work, we can temporarily disable URL caching and use direct downloads:

```ruby
# In app/services/python_docx_exporter.rb
# Replace process_photo method:

def self.process_photo(attachment)
  return nil unless attachment.file.attached?

  begin
    # Direct download (bypass URL cache)
    image_data = attachment.file.download

    {
      data: image_data,
      filename: attachment.file.filename.to_s,
      caption: attachment.caption || ""
    }
  rescue => e
    Rails.logger.error("PythonDocxExporter: Failed to process photo: #{e.message}")
    nil
  end
end
```

---

## Rollback Plan

If this fix breaks something else:

```bash
# Revert the commit
git revert HEAD

# Rebuild and deploy
source .env.deployment
docker build --platform linux/amd64 -f Dockerfile.combined \
  -t geometricsicmsac01mar26.azurecr.io/cms-inspection-app:latest .
docker push geometricsicmsac01mar26.azurecr.io/cms-inspection-app:latest
az webapp restart --name geometriceng-icms-app --resource-group geometrics-icms-rg
```

---

## Performance After Fix

The fix maintains performance benefits:
- ✅ URL caching still works (when URLs are valid)
- ✅ Parallel downloads still active
- ✅ Direct download fallback ensures reliability
- **Result:** Fast when cache works, reliable when it doesn't

---

**Deploy now to fix the images in Word exports!** 🚀