# DOCX Template Migration - Deployment Checklist

Use this checklist when deploying the Python-based DOCX export system.

## Pre-Deployment

### 1. Code Review
- [ ] All Python files committed to repository
- [ ] Rails service integration committed
- [ ] Controller changes committed
- [ ] Dockerfile changes committed
- [ ] Documentation committed

### 2. Local Testing
- [ ] Python environment setup successfully
  ```bash
  ./python/setup.sh
  ```
- [ ] Standalone Python script tested
  ```bash
  source .venv/bin/activate
  python3 python/export_report.py \
    --input /path/to/your_data.json \
    --template app/assets/Context/inspection_template.docx \
    --output test.docx
  ```
- [ ] Test output opens in Word without errors
- [ ] Rails integration tested locally
- [ ] Export action works from web interface

### 3. Template Preparation
- [ ] Template converted to docxtpl syntax
- [ ] All placeholders updated to Jinja2 format
- [ ] Table loops added for dynamic data
- [ ] Photo placeholders configured
- [ ] Template tested with sample data
- [ ] Formatting verified
- [ ] Template committed to repository

## Deployment

### 4. Server Prerequisites
- [ ] Python 3.8+ available on server
- [ ] `python3-venv` package installed
  ```bash
  sudo apt install python3-venv python3-pip
  ```

### 5. Application Deployment
- [ ] Code deployed to server
- [ ] Bundle install completed
- [ ] Python setup script executed
  ```bash
  cd /path/to/app
  ./python/setup.sh
  ```
- [ ] Verify .venv directory created
- [ ] Verify Python packages installed
  ```bash
  .venv/bin/pip list | grep docxtpl
  ```

### 6. Docker Deployment (if applicable)
- [ ] Dockerfile builds successfully
  ```bash
  docker build -t inspection_cms .
  ```
- [ ] Python dependencies installed in image
- [ ] Container runs without errors
- [ ] Export functionality tested in container

## Post-Deployment Verification

### 7. Smoke Tests
- [ ] Create a new report
- [ ] Add sample data and photos
- [ ] Click "Export to Word"
- [ ] Verify download starts
- [ ] Open downloaded file in Word
- [ ] Check all data appears correctly
- [ ] Verify photos are embedded
- [ ] Confirm tables are populated
- [ ] Check formatting is preserved

### 8. Error Handling Tests
- [ ] Test export with no photos (should not crash)
- [ ] Test export with no placed quantities
- [ ] Test export with special characters
- [ ] Verify fallback to Ruby exporter works if Python fails
- [ ] Check logs for errors

### 9. Performance Tests
- [ ] Export report with maximum photos (6)
- [ ] Export report with large tables (50+ rows)
- [ ] Verify export completes in reasonable time
- [ ] Check server memory usage
- [ ] Monitor for temp file cleanup

## Monitoring

### 10. Log Monitoring
Set up alerts for:
- [ ] Python script failures
- [ ] Missing template errors
- [ ] Image processing errors
- [ ] Timeout errors
- [ ] File system errors

### 11. Key Metrics to Track
- [ ] Export success rate
- [ ] Average export time
- [ ] File size of generated reports
- [ ] Python vs Ruby exporter usage ratio
- [ ] Error frequency and types

## Rollback Plan

### 12. Fallback Strategy
If Python exporter fails completely:

- [ ] Verify Ruby exporter still works
- [ ] Can temporarily disable Python by commenting out:
  ```ruby
  # temp_file = PythonDocxExporter.generate(@report)
  temp_file = WordReportExporter.generate(@report)
  ```
- [ ] Redeploy previous version if needed
- [ ] Users can still export (without improved image support)

## Documentation

### 13. Team Communication
- [ ] Notify team of deployment
- [ ] Share template editing guide
- [ ] Document any known issues
- [ ] Provide troubleshooting contacts

### 14. User Documentation
- [ ] Update user manual if needed
- [ ] Notify users of new features
- [ ] Provide examples of improved exports
- [ ] Collect feedback

## Long-term Maintenance

### 15. Template Management
- [ ] Establish process for template updates
- [ ] Version control for templates
- [ ] Testing procedure for template changes
- [ ] Rollback procedure for bad templates

### 16. Dependency Updates
- [ ] Monitor Python package updates
- [ ] Test updates in staging before production
- [ ] Keep requirements.txt up to date
- [ ] Document any breaking changes

## Success Criteria

The migration is successful when:

✅ All reports export correctly
✅ Images appear properly embedded
✅ Tables populate with correct data
✅ No increase in error rate
✅ Export time is acceptable
✅ Users report improved output quality
✅ Template editors can make changes without developer help

## Emergency Contacts

**Python Issues:**
- Check logs: `tail -f log/production.log | grep PythonDocx`
- Python script path: `/path/to/app/python/export_report.py`
- Virtual env: `/path/to/app/.venv/`

**Template Issues:**
- Template location: `app/assets/Context/inspection_template.docx`
- Template guide: `docs/TEMPLATE_GUIDE.md`

**Deployment Issues:**
- Setup script: `python/setup.sh`
- Setup docs: `python/SETUP.md`
- Implementation summary: `docs/IMPLEMENTATION_SUMMARY.md`

---

## Completion Sign-off

- [ ] All checklist items completed
- [ ] No critical errors in production
- [ ] Stakeholders notified
- [ ] Documentation updated

**Deployed by:** _______________
**Date:** _______________
**Version:** _______________
**Notes:** _______________________________________________
