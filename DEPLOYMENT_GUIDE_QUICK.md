# Quick Deployment Guide - URL Caching Feature

Three ways to deploy the URL caching feature to Azure. Choose the one that works best for you.

---

## 🚀 Option 1: Automated Script (Recommended)

**Fastest and easiest method.**

### Step 1: Set environment variables

```bash
export RESOURCE_GROUP="geometrics-icms-rg"
export APP_NAME="geometriceng-icms-app"
export ACR_NAME="geometricsicmsac01mar26"
export LOCATION="westus3"
```

### Step 2: Run deployment script

```bash
./deploy_url_caching.sh
```

**That's it!** The script will:
- ✅ Check prerequisites
- ✅ Login to Azure and ACR
- ✅ Build Docker image
- ✅ Push to registry
- ✅ Restart application
- ✅ Verify deployment

**Time:** ~15-20 minutes

---

## 📋 Option 2: Step-by-Step Commands

**If you prefer to run commands manually.**

### Prerequisites

```bash
# Set environment variables
export RESOURCE_GROUP="geometrics-icms-rg"
export APP_NAME="geometriceng-icms-app"
export ACR_NAME="geometricsicmsac01mar26"
export LOCATION="westus3"
```

### Deploy

```bash
# 1. Login to Azure
az login

# 2. Login to ACR
az acr login --name $ACR_NAME

# 3. Build image (5-10 min)
docker build --platform linux/amd64 -f Dockerfile.combined \
  -t ${ACR_NAME}.azurecr.io/cms-inspection-app:latest .

# 4. Push image (3-5 min)
docker push ${ACR_NAME}.azurecr.io/cms-inspection-app:latest

# 5. Restart app
az webapp restart --name $APP_NAME --resource-group $RESOURCE_GROUP

# 6. Wait and monitor
sleep 30
az webapp log tail --name $APP_NAME --resource-group $RESOURCE_GROUP
```

**Time:** ~15-20 minutes

---

## 📖 Option 3: Detailed Guide

**For complete step-by-step instructions with troubleshooting.**

Follow: **[docs/DEPLOYMENT_URL_CACHING.md](docs/DEPLOYMENT_URL_CACHING.md)**

Includes:
- Detailed explanations for each step
- Troubleshooting guide
- Testing procedures
- Verification steps
- Rollback instructions

**Time:** ~30-40 minutes (with testing)

---

## ✅ After Deployment - Testing

### Quick Test

1. **Open application**
   ```bash
   open https://${APP_NAME}.azurewebsites.net
   # Or: https://geometriceng-icms-app.azurewebsites.net
   ```

2. **Upload an image**
   - Go to any report
   - Upload 2-3 images
   - Save report

3. **Export to Word**
   - Click "Export Word"
   - Should complete in <1 second
   - Download and verify images

4. **Check logs**
   ```bash
   az webapp log tail --name $APP_NAME --resource-group $RESOURCE_GROUP | grep Cache
   ```

   **Expected:**
   ```
   ImageUrlCache: Cached URL for attachment_id=123
   PythonDocxExporter: URL cache stats - 3/3 cached (100.0% hit rate)
   ImageUrlCache: Retrieved cached URL for attachment_id=123
   ```

---

## 📊 Success Criteria

Deployment is successful if:

- ✅ Application accessible at `https://${APP_NAME}.azurewebsites.net`
- ✅ Image upload works (check logs for cache messages)
- ✅ Word export completes in <1 second
- ✅ Cache hit rate shows 100%
- ✅ All images appear in Word document
- ✅ No errors in logs

---

## 🔧 Troubleshooting

### Issue: Build fails

```bash
# Check Dockerfile exists
ls -l Dockerfile.combined

# Ensure using correct platform
docker build --platform linux/amd64 -f Dockerfile.combined -t test .
```

### Issue: App won't start

```bash
# Check logs for errors
az webapp log tail --name $APP_NAME --resource-group $RESOURCE_GROUP
```

### Issue: Export still slow

```bash
# Verify cache is working
az webapp log tail --name $APP_NAME --resource-group $RESOURCE_GROUP | grep "cache stats"
```

---

## 📚 Documentation

- **[DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md)** - Quick checklist
- **[docs/DEPLOYMENT_URL_CACHING.md](docs/DEPLOYMENT_URL_CACHING.md)** - Detailed guide
- **[docs/IMAGE_URL_CACHING.md](docs/IMAGE_URL_CACHING.md)** - Feature documentation
- **[docs/IMAGE_CACHING_IMPLEMENTATION_SUMMARY.md](docs/IMAGE_CACHING_IMPLEMENTATION_SUMMARY.md)** - Implementation summary

---

## 🎯 Performance Expectations

After deployment:

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| Export time (6 images) | 5 seconds | 0.5 seconds | **10x faster** |
| Cache hit rate | N/A | 100% | New feature |
| Cost | $0 | $0 | **No change** |

---

## 💡 Tips

1. **First deployment?** Use the automated script (`./deploy_url_caching.sh`)
2. **Want control?** Use step-by-step commands
3. **Need details?** Follow the detailed guide
4. **Having issues?** Check troubleshooting section
5. **After deployment:** Monitor logs for 24 hours to verify cache performance

---

## 🆘 Need Help?

1. Check logs: `az webapp log tail --name $APP_NAME --resource-group $RESOURCE_GROUP`
2. Review detailed guide: [docs/DEPLOYMENT_URL_CACHING.md](docs/DEPLOYMENT_URL_CACHING.md)
3. Check implementation summary: [docs/IMAGE_CACHING_IMPLEMENTATION_SUMMARY.md](docs/IMAGE_CACHING_IMPLEMENTATION_SUMMARY.md)

---

**Ready to deploy? Choose your option above and get started! 🚀**