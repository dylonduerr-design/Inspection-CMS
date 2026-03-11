# Diagnostic Deployment - Image Export Investigation

## What Changed

Added extensive diagnostic logging to the Python DOCX generation script to identify why images aren't appearing in Word exports.

**File modified:** `python/export_report.py`

## New Diagnostic Logs

The Python script will now log:

1. **Image Count**: Total number of photos being processed
2. **File Existence**: Whether each temp file exists
3. **File Size**: Size of each image file in bytes
4. **Validation Details**:
   - Image validation started
   - Image validation PASSED or FAILED
   - Specific error if validation fails
5. **InlineImage Creation**:
   - Success confirmation
   - Detailed error if creation fails
6. **Empty Slots**: Which photo slots are empty

## Deploy with Diagnostics

```bash
# 1. Load environment
source .env.deployment

# 2. Commit diagnostic changes
git add python/export_report.py
git commit -m "Add diagnostic logging to Word export for image troubleshooting

- Log file existence and size for each image
- Log image validation details (pass/fail with errors)
- Log InlineImage creation success/failure
- Track empty photo slots
- Help identify why images aren't appearing in exports
"

# 3. Build image
docker build --platform linux/amd64 -f Dockerfile.combined \
  -t geometricsicmsac01mar26.azurecr.io/cms-inspection-app:latest .

# 4. Push to registry
docker push geometricsicmsac01mar26.azurecr.io/cms-inspection-app:latest

# 5. Restart app
az webapp restart \
  --name geometriceng-icms-app \
  --resource-group geometrics-icms-rg

# 6. Wait for startup
sleep 30
```

---

## Test and Collect Logs

### 1. Start Log Monitoring

In a separate terminal, start tailing logs:

```bash
az webapp log tail \
  --name geometriceng-icms-app \
  --resource-group geometrics-icms-rg
```

### 2. Export a Report

1. Go to https://geometriceng-icms-app.azurewebsites.net
2. Find a report with images (or upload test images)
3. Click "Export Word"
4. Download the Word document

### 3. Check the Logs

Look for the diagnostic output in the log stream. You should see:

#### Expected Success Pattern:
```
INFO: PythonDocxExporter: Processing 3 images
INFO: PythonDocxExporter: Downloaded image for attachment_id=123, size=1234567 bytes
INFO: Processing 3 photos for export
INFO: Photo 1: path=/tmp/photo20240310-12345-abc123.jpg, exists=True
INFO: Validating image: /tmp/photo20240310-12345-abc123.jpg, size=1234567 bytes
INFO: Image validation PASSED: /tmp/photo20240310-12345-abc123.jpg
INFO: Creating InlineImage for photo 1: /tmp/photo20240310-12345-abc123.jpg
INFO: Photo 1 - SUCCESS: Added to document
INFO: Photo 2: path=/tmp/photo20240310-12345-def456.jpg, exists=True
INFO: Validating image: /tmp/photo20240310-12345-def456.jpg, size=2345678 bytes
INFO: Image validation PASSED: /tmp/photo20240310-12345-def456.jpg
INFO: Creating InlineImage for photo 2: /tmp/photo20240310-12345-def456.jpg
INFO: Photo 2 - SUCCESS: Added to document
...
INFO: Report generated successfully!
```

#### Possible Error Patterns:

**Pattern 1: File Not Found**
```
ERROR: Photo 1 - FILE NOT FOUND: /tmp/photo20240310-12345-abc123.jpg
```
→ **Cause**: Temp file was deleted before Python could read it

**Pattern 2: Validation Failed**
```
INFO: Validating image: /tmp/photo20240310-12345-abc123.jpg, size=1234567 bytes
ERROR: Image validation FAILED for /tmp/photo20240310-12345-abc123.jpg: UnrecognizedImageError: ...
ERROR: Photo 1 - VALIDATION FAILED: /tmp/photo20240310-12345-abc123.jpg
```
→ **Cause**: Image format not supported by python-docx

**Pattern 3: InlineImage Creation Failed**
```
INFO: Image validation PASSED: /tmp/photo20240310-12345-abc123.jpg
INFO: Creating InlineImage for photo 1: /tmp/photo20240310-12345-abc123.jpg
ERROR: Photo 1 - InlineImage creation FAILED (ValueError): ...
ERROR: Photo path was: /tmp/photo20240310-12345-abc123.jpg
```
→ **Cause**: InlineImage construction error (size, format, corruption)

**Pattern 4: No Photos in JSON**
```
INFO: Processing 0 photos for export
INFO: Photo 1 - Empty slot (no data)
INFO: Photo 2 - Empty slot (no data)
...
```
→ **Cause**: Ruby code isn't passing photos to Python

---

## Next Steps Based on Logs

### If "FILE NOT FOUND"
The temp files are being deleted too early. Need to:
- Check if Ruby is cleaning up files before Python finishes
- Verify file permissions
- Check if temp directory is shared between processes

### If "VALIDATION FAILED"
The image format isn't supported by python-docx. Need to:
- Check what image formats are uploaded (JPEG, PNG should work)
- Consider converting images to supported format before export
- Check if images are corrupted during download

### If "InlineImage creation FAILED"
The InlineImage object can't be created. Need to:
- Check image dimensions (might be too large/small)
- Verify image isn't corrupted
- Test with simpler image dimensions

### If "No Photos in JSON"
The Ruby code isn't passing photos to Python. Need to:
- Check `PythonDocxExporter.extract_photos` method
- Verify temp files are being created in Ruby
- Check JSON payload being sent to Python

---

## Save the Diagnostic Logs

Once you've captured the logs, save them to a file for analysis:

```bash
# Run export test, then capture last 100 lines
az webapp log tail \
  --name geometriceng-icms-app \
  --resource-group geometrics-icms-rg \
  > export_diagnostic_logs.txt

# Press Ctrl+C after export completes
```

Then share the `export_diagnostic_logs.txt` file for analysis.

---

## Rollback if Needed

If the diagnostic version causes issues:

```bash
git revert HEAD
docker build --platform linux/amd64 -f Dockerfile.combined \
  -t geometricsicmsac01mar26.azurecr.io/cms-inspection-app:latest .
docker push geometricsicmsac01mar26.azurecr.io/cms-inspection-app:latest
az webapp restart --name geometriceng-icms-app --resource-group geometrics-icms-rg
```

---

**The diagnostic logs will tell us exactly where the image pipeline is breaking!**