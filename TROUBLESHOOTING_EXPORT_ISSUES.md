# Troubleshooting - Export Word & Image Display Issues

## Issue 1: Export Word Button Not Working

### Quick Diagnosis

**Run this command to check logs:**

```bash
az webapp log tail \
  --name geometriceng-icms-app \
  --resource-group geometrics-icms-rg
```

Then click "Export Word" and watch for errors.

### Possible Causes & Solutions

#### Cause 1: JavaScript Error (Most Likely)

**Check browser console:**
1. Open browser Developer Tools (F12)
2. Go to Console tab
3. Click "Export Word"
4. Look for red errors

**Common errors:**
- `Uncaught ReferenceError: ImageUrlCache is not defined`
- `ActionCable connection error`
- `Cannot read property of undefined`

**Solution:** The URL caching code might have JavaScript issues. Check:

```bash
# Check if export controller exists
ls -la app/javascript/controllers/report_export_controller.js
```

#### Cause 2: Missing Route

**Check routes:**
```bash
# In your local terminal
grep "export" config/routes.rb
```

**Expected:**
```ruby
post "reports/:id/start_export", to: "reports#start_export"
```

#### Cause 3: ActionCable/WebSocket Issue

**Check logs for:**
```
ActionCable connection failed
WebSocket connection to 'wss://...' failed
```

**Solution:** Check `config/cable.yml` is properly configured.

#### Cause 4: Background Job Not Running

**The export requires background jobs. Check if Sidekiq is running:**

```bash
# Check logs for Sidekiq
az webapp log tail \
  --name geometriceng-icms-app \
  --resource-group geometrics-icms-rg \
  | grep -i sidekiq
```

**If you see:** `Redis::CannotConnectError`
**Solution:** Sidekiq needs Redis OR async adapter.

---

## Issue 2: Image Thumbnails Not Displaying

### Quick Diagnosis

**Check browser console for 404 errors:**
1. Open Developer Tools (F12)
2. Go to Network tab
3. Refresh page
4. Look for failed image requests (red status)

### Possible Causes & Solutions

#### Cause 1: ActiveStorage Not Configured Properly

**Check if ActiveStorage is set up:**

```bash
# Check storage configuration
cat config/storage.yml
```

**Expected:**
```yaml
local:
  service: Disk
  root: <%= Rails.root.join("storage") %>
```

#### Cause 2: Image Variant Processing Failed

**Check logs for:**
```
ActiveStorage::FileNotFoundError
Error processing variants
```

**Solution:** Ensure `image_processing` gem is installed and vips/imagemagick available.

#### Cause 3: Missing Storage Directory

**Check if storage directory exists:**
```bash
# On Azure App Service
az webapp ssh --name geometriceng-icms-app --resource-group geometrics-icms-rg

# Inside container
ls -la /home/site/wwwroot/storage
```

**If missing:**
```bash
mkdir -p /home/site/wwwroot/storage
chown rails:rails /home/site/wwwroot/storage
```

#### Cause 4: Blob URL Generation Failing

**Check logs for:**
```
undefined method 'url' for ActiveStorage::Blob
```

**This could be the URL caching code!**

---

## Emergency Rollback (If URL Caching Broke It)

If the URL caching feature broke the export:

### Quick Rollback

```bash
# 1. Revert the code changes
cd /Users/sadgaonkar/gitlocal/Inspection-CMS

git revert HEAD

# 2. Rebuild and deploy
source .env.deployment

docker build --platform linux/amd64 -f Dockerfile.combined \
  -t geometricsicmsac01mar26.azurecr.io/cms-inspection-app:latest .

docker push geometricsicmsac01mar26.azurecr.io/cms-inspection-app:latest

az webapp restart \
  --name geometriceng-icms-app \
  --resource-group geometrics-icms-rg
```

---

## Diagnostic Commands

### 1. Check Application Status

```bash
az webapp show \
  --name geometriceng-icms-app \
  --resource-group geometrics-icms-rg \
  --query "state" -o tsv
```

Expected: `Running`

### 2. Check Recent Errors

```bash
az webapp log tail \
  --name geometriceng-icms-app \
  --resource-group geometrics-icms-rg \
  | grep -i "error\|exception\|failed"
```

### 3. Check ActiveStorage

```bash
az webapp log tail \
  --name geometriceng-icms-app \
  --resource-group geometrics-icms-rg \
  | grep -i "activestorage\|blob\|attachment"
```

### 4. Check Export Functionality

```bash
az webapp log tail \
  --name geometriceng-icms-app \
  --resource-group geometrics-icms-rg \
  | grep -i "export\|pythondocx\|report_export"
```

### 5. Check ImageUrlCache Errors

```bash
az webapp log tail \
  --name geometriceng-icms-app \
  --resource-group geometrics-icms-rg \
  | grep -i "imageurlcache"
```

---

## Specific Checks for New URL Caching Code

### Check 1: ImageUrlCache Service Loading

```bash
# SSH into container
az webapp ssh --name geometriceng-icms-app --resource-group geometrics-icms-rg

# Check if file exists
ls -la /home/site/wwwroot/app/services/image_url_cache.rb

# Check Rails console
cd /home/site/wwwroot
bin/rails console

# In console, test:
ImageUrlCache.class
# Should return: Class
```

### Check 2: Concurrent-Ruby Available

```bash
# In Rails console
require 'concurrent'
Concurrent::Promise
# Should return: Concurrent::Promise
```

### Check 3: Blob URL Generation

```bash
# In Rails console
attachment = ReportAttachment.first
attachment.file.blob.url(expires_in: 7.days)
# Should return a URL string
```

---

## Most Likely Issues & Quick Fixes

### Issue A: URL Caching Code Has Bug

**Symptom:** Export button doesn't work after deployment

**Check:**
```bash
az webapp log tail \
  --name geometriceng-icms-app \
  --resource-group geometrics-icms-rg
```

Click export and look for:
```
NameError: uninitialized constant ImageUrlCache
NoMethodError: undefined method 'fetch_image'
```

**Fix:** The ImageUrlCache service might not be loaded.

Add to `config/application.rb`:
```ruby
config.autoload_paths += %W(#{config.root}/app/services)
```

### Issue B: Concurrent Promises Failing

**Symptom:** Export hangs or fails silently

**Check logs for:**
```
Concurrent::Promise execution failed
Thread error
```

**Fix:** Concurrent-ruby might not be working in production.

Revert to sequential downloads in `python_docx_exporter.rb`.

### Issue C: Blob Service URL Errors

**Symptom:** Images don't display, URL generation fails

**Check logs for:**
```
ActiveStorage::IntegrityError
Blob not found
```

**Fix:** ActiveStorage might not be configured for Azure.

---

## Step-by-Step Diagnosis

### Step 1: Get Current Logs

```bash
az webapp log tail \
  --name geometriceng-icms-app \
  --resource-group geometrics-icms-rg > current_logs.txt
```

Send me the output, especially any errors.

### Step 2: Check Browser Console

1. Open https://geometriceng-icms-app.azurewebsites.net
2. Press F12
3. Go to Console tab
4. Refresh page
5. Look for errors
6. Click "Export Word"
7. Look for new errors

### Step 3: Check Network Tab

1. Stay in Developer Tools
2. Go to Network tab
3. Click "Export Word"
4. Look for:
   - Failed requests (red)
   - 404 errors
   - 500 errors

### Step 4: Test in Rails Console

```bash
az webapp ssh --name geometriceng-icms-app --resource-group geometrics-icms-rg

cd /home/site/wwwroot
bin/rails console

# Test image URL generation
attachment = ReportAttachment.first
attachment.file.blob.url(expires_in: 7.days)

# Test ImageUrlCache
ImageUrlCache.cache_url(1, "test_url", filename: "test.jpg")
ImageUrlCache.get_cached_url(1)

# Test export
report = Report.first
PythonDocxExporter.generate(report)
```

---

## Quick Health Check Script

Run this to check everything:

```bash
#!/bin/bash

echo "=== Application Status ==="
az webapp show \
  --name geometriceng-icms-app \
  --resource-group geometrics-icms-rg \
  --query "state" -o tsv

echo ""
echo "=== Recent Errors (last 50 lines) ==="
az webapp log tail \
  --name geometriceng-icms-app \
  --resource-group geometrics-icms-rg 2>&1 | grep -i "error" | tail -50

echo ""
echo "=== Export-Related Logs ==="
az webapp log tail \
  --name geometriceng-icms-app \
  --resource-group geometrics-icms-rg 2>&1 | grep -i "export" | tail -20

echo ""
echo "=== ImageUrlCache Logs ==="
az webapp log tail \
  --name geometriceng-icms-app \
  --resource-group geometrics-icms-rg 2>&1 | grep -i "imageurlcache" | tail -20

echo ""
echo "=== ActiveStorage Logs ==="
az webapp log tail \
  --name geometriceng-icms-app \
  --resource-group geometrics-icms-rg 2>&1 | grep -i "activestorage" | tail -20
```

---

## Next Steps

**Please provide:**

1. **Browser console errors** (F12 → Console tab)
2. **Network errors** (F12 → Network tab)
3. **Application logs** (run the commands above)

With this information, I can provide an exact fix!

**Quick test to see if it's the URL caching:**

If you haven't deployed yet, **DON'T DEPLOY** the URL caching code until we diagnose the current issues.

If you already deployed and it broke, run the rollback commands above.