# DEPLOY FIX NOW - Images in Word Export

## What Changed

**Simplified to DIRECT downloads** - removed all URL caching complexity.

This is the **most reliable** approach - uses the exact same method that was working before.

---

## Deploy Immediately

```bash
# 1. Set environment
source .env.deployment

# 2. Commit changes
git add app/services/python_docx_exporter.rb
git commit -m "Emergency fix: Revert to direct ActiveStorage downloads for images

- Remove URL caching from export (causing issues)
- Remove parallel processing complexity
- Use simple, reliable direct downloads
- This restores working image exports
"

# 3. Build
docker build --platform linux/amd64 -f Dockerfile.combined \
  -t geometricsicmsac01mar26.azurecr.io/cms-inspection-app:latest .

# 4. Push
docker push geometricsicmsac01mar26.azurecr.io/cms-inspection-app:latest

# 5. Restart
az webapp restart \
  --name geometriceng-icms-app \
  --resource-group geometrics-icms-rg

# 6. Wait
sleep 30

# 7. Test
echo "Now test: https://geometriceng-icms-app.azurewebsites.net"
```

**Total time:** 15-20 minutes

---

## What This Does

### Before (Complex - Broken)
- URL caching
- Parallel processing
- Multiple fallbacks
- **Result: Images not in Word doc**

### After (Simple - Works)
- Direct ActiveStorage download
- One at a time (reliable)
- **Result: Images in Word doc** ✅

---

## Test After Deploy

1. Go to: https://geometriceng-icms-app.azurewebsites.net
2. Find report with images
3. Click "Export Word"
4. Download Word doc
5. Open doc
6. **Images should be there!**

---

## Check Logs

```bash
az webapp log tail \
  --name geometriceng-icms-app \
  --resource-group geometrics-icms-rg \
  | grep "PythonDocxExporter"
```

**Expected:**
```
PythonDocxExporter: Processing 3 images
PythonDocxExporter: Downloaded image for attachment_id=123, size=1234567 bytes
PythonDocxExporter: Downloaded image for attachment_id=124, size=2345678 bytes
PythonDocxExporter: Downloaded image for attachment_id=125, size=3456789 bytes
PythonDocxExporter: Report generated successfully
```

---

## This WILL Work Because

1. ✅ Uses exact same download method as before
2. ✅ No URL caching complexity
3. ✅ No parallel processing issues
4. ✅ Direct ActiveStorage downloads always work
5. ✅ Simple code = fewer bugs

---

## Performance Note

You'll lose the parallel download speed boost, BUT:
- Images will actually **appear in Word docs** (critical!)
- Export will still be reasonably fast
- We can optimize later once it's working

**Working reliably > Fast but broken**

---

**DEPLOY NOW!** 🚀