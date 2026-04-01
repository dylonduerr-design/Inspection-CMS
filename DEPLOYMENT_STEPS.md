# Deployment Steps - URL Caching Feature

**Quick reference for deploying to your Azure environment**

---

## Your Azure Configuration

```bash
Resource Group:  geometrics-icms-rg
Location:        westus3
App Name:        geometriceng-icms-app
ACR Name:        geometricsicmsac01mar26
DB Server:       icms-inspection-flex-pg-db-server01
DB Name:         icms_inspection_db
DB Admin User:   icms_dbadmin
```

**Application URL:** https://geometriceng-icms-app.azurewebsites.net

---

## Method 1: Automated Deployment (Recommended)

### Step 1: Set Environment Variables

```bash
# Option A: Source the environment file
source .env.deployment

# Option B: Set manually
export RESOURCE_GROUP="geometrics-icms-rg"
export APP_NAME="geometriceng-icms-app"
export ACR_NAME="geometricsicmsac01mar26"
export LOCATION="westus3"
```

### Step 2: Run Deployment Script

```bash
./deploy_url_caching.sh
```

**That's it!** Script handles everything automatically.

**Time:** 15-20 minutes

---

## Method 2: Manual Deployment

### Step 1: Set Environment Variables

```bash
source .env.deployment
```

### Step 2: Run Commands

```bash
# Login to Azure
az login

# Login to ACR
az acr login --name geometricsicmsac01mar26

# Build image (5-10 min)
docker build --platform linux/amd64 -f Dockerfile.combined \
  -t geometricsicmsac01mar26.azurecr.io/cms-inspection-app:latest .

# Push image (3-5 min)
docker push geometricsicmsac01mar26.azurecr.io/cms-inspection-app:latest

# Restart app
az webapp restart \
  --name geometriceng-icms-app \
  --resource-group geometrics-icms-rg

# Monitor logs
sleep 30
az webapp log tail \
  --name geometriceng-icms-app \
  --resource-group geometrics-icms-rg
```

---

## Testing After Deployment

### 1. Open Application

```bash
open https://geometriceng-icms-app.azurewebsites.net
```

### 2. Upload Test Images

1. Login to the application
2. Navigate to any report
3. Upload 2-3 images
4. Save the report

### 3. Monitor Cache Logs

```bash
az webapp log tail \
  --name geometriceng-icms-app \
  --resource-group geometrics-icms-rg \
  | grep ImageUrlCache
```

**Expected output:**
```
ImageUrlCache: Cached URL for attachment_id=123, filename=photo.jpg
ImageUrlCache: Cached URL for attachment_id=124, filename=photo2.jpg
```

### 4. Export to Word

1. Open the report with images
2. Click "Export Word"
3. Should complete in <1 second
4. Download and verify images in Word document

### 5. Check Export Logs

```bash
az webapp log tail \
  --name geometriceng-icms-app \
  --resource-group geometrics-icms-rg \
  | grep -E "Cache|Export"
```

**Expected output:**
```
PythonDocxExporter: URL cache stats - 3/3 cached (100.0% hit rate)
ImageUrlCache: Retrieved cached URL for attachment_id=123
ImageUrlCache: Downloaded from cached URL for attachment_id=123
PythonDocxExporter: Report generated successfully
```

---

## Success Checklist

- [ ] Application accessible at https://geometriceng-icms-app.azurewebsites.net
- [ ] Can login successfully
- [ ] Image upload shows cache logs
- [ ] Word export completes in <1 second
- [ ] Cache hit rate shows 100%
- [ ] All images appear in Word document
- [ ] No errors in logs

---

## Quick Commands

```bash
# Set environment
source .env.deployment

# Deploy
./deploy_url_caching.sh

# Check app status
az webapp show \
  --name geometriceng-icms-app \
  --resource-group geometrics-icms-rg \
  --query "state" -o tsv

# Tail logs
az webapp log tail \
  --name geometriceng-icms-app \
  --resource-group geometrics-icms-rg

# Filter cache logs only
az webapp log tail \
  --name geometriceng-icms-app \
  --resource-group geometrics-icms-rg \
  | grep Cache

# Restart app (if needed)
az webapp restart \
  --name geometriceng-icms-app \
  --resource-group geometrics-icms-rg
```

---

## Troubleshooting

### Build fails
```bash
# Check Dockerfile exists
ls -l Dockerfile.combined

# Try building without cache
docker build --no-cache --platform linux/amd64 \
  -f Dockerfile.combined -t test .
```

### Push fails
```bash
# Re-login
az acr login --name geometricsicmsac01mar26

# Check permissions
az acr show --name geometricsicmsac01mar26 --query adminUserEnabled
```

### App not starting
```bash
# Check logs for errors
az webapp log tail \
  --name geometriceng-icms-app \
  --resource-group geometrics-icms-rg
```

### Export still slow
```bash
# Verify cache is working
az webapp log tail \
  --name geometriceng-icms-app \
  --resource-group geometrics-icms-rg \
  | grep "cache stats"
```

---

## Performance Expectations

| Metric | Before | After |
|--------|--------|-------|
| Export time (6 images) | 5 seconds | 0.5 seconds |
| Cache hit rate | N/A | 100% |
| Cost | $0 | $0 |
| **Improvement** | - | **10x faster** ⚡ |

---

## Additional Resources

- **[DEPLOYMENT_GUIDE_QUICK.md](DEPLOYMENT_GUIDE_QUICK.md)** - Full guide with 3 options
- **[DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md)** - Detailed checklist
- **[docs/DEPLOYMENT_URL_CACHING.md](docs/DEPLOYMENT_URL_CACHING.md)** - Complete reference
- **[docs/IMAGE_URL_CACHING.md](docs/IMAGE_URL_CACHING.md)** - Feature documentation

---

**Ready to deploy? Run:**

```bash
source .env.deployment
./deploy_url_caching.sh
```

**Then test at:** https://geometriceng-icms-app.azurewebsites.net

---

**Last Updated:** 2026-03-10
**Your Environment:** geometrics-icms-rg / geometriceng-icms-app