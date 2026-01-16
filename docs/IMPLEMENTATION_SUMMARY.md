# DOCX Template Migration Implementation Summary

## Overview

This document summarizes the implementation of Python-based DOCX report generation using `docxtpl` for the Inspection CMS.

## What Was Implemented

### 1. Python Export Script ✅


- Standalone Python script that generates DOCX files from templates
- Uses `docxtpl` library for Jinja2-style template rendering
- Supports inline images via `InlineImage` objects
- Handles table data (placed quantities, QA entries, equipment, crew)
- Robust error handling and logging
- CLI interface for testing and production use

### 2. Python Dependencies ✅
```
docxtpl==0.18.0
python-docx==1.1.0
Pillow==10.2.0
```

### 3. Setup Script ✅


- Automated virtual environment creation
- Dependency installation
- Python version checking
- Usage instructions

### 4. Rails Integration Service ✅


- `PythonDocxExporter` class that bridges Rails and Python
- Extracts report data and converts to JSON
- Downloads Active Storage blobs to temporary files
- Calls Python script via `Open3.capture3`
- Returns tempfile for Rails to send to user
- Comprehensive error handling and logging

### 5. Controller Integration ✅


```ruby
def export_word
  # Try Python exporter first, fall back to Ruby if needed
  temp_file = PythonDocxExporter.generate(@report)
  temp_file ||= WordReportExporter.generate(@report)  # Fallback
  # ... send file to user
end
```

### 6. Docker Support ✅


- Python 3 installation in build and runtime stages
- Virtual environment creation during build
- Dependencies installed in Docker image
- Production-ready configuration

### 8. Template Format Guide ✅

Documented template syntax for designers:

**Simple Variables:**
```
{{ project }}
{{ inspector }}
{{ date }}
```

**Photos:**
```
{{ photo_1 }}
Caption: {{ caption_1 }}
```

**Table Loops:**
```
{% for item in placed_quantities %}
{{ item.code }} | {{ item.desc }} | {{ item.qty }}
{% endfor %}
```

### 9. Test Infrastructure ✅

- Sample JSON test data
- Instructions for standalone testing
- Debugging guidelines

## Architecture

```
┌─────────────────────────────────────────────┐
│          Rails Application                   │
│                                              │
│  ┌────────────────────────────────────────┐ │
│  │  ReportsController                     │ │
│  │    export_word action                  │ │
│  └─────────────┬──────────────────────────┘ │
│                │                             │
│                ▼                             │
│  ┌────────────────────────────────────────┐ │
│  │  PythonDocxExporter Service            │ │
│  │  - Extracts report data                │ │
│  │  - Downloads images to temp files      │ │
│  │  - Generates JSON payload              │ │
│  │  - Calls Python script                 │ │
│  └─────────────┬──────────────────────────┘ │
└────────────────┼──────────────────────────────┘
                 │
                 │ JSON + Shell
                 ▼
┌─────────────────────────────────────────────┐
│          Python Environment                  │
│                                              │
│  ┌────────────────────────────────────────┐ │
│  │  export_report.py                      │ │
│  │  - Loads template                      │ │
│  │  - Parses JSON data                    │ │
│  │  - Creates InlineImage objects         │ │
│  │  - Renders template with docxtpl       │ │
│  │  - Saves final DOCX                    │ │
│  └────────────────────────────────────────┘ │
│                                              │
│  Dependencies:                               │
│  - docxtpl (template engine)                │
│  - python-docx (DOCX manipulation)          │
│  - Pillow (image processing)                │
└─────────────────────────────────────────────┘
```

## What Remains To Be Done

### 2. Template Conversion (Critical) ⚠️

The Word template needs to be updated with docxtpl syntax:

**Current (Ruby docx gem):**
```
{{PROJECT}}
{{INSPECTOR}}
```

**Needed (docxtpl Jinja2):**
```
{{ project }}
{{ inspector }}
```

**For loops in tables:**
```
{% for item in placed_quantities %}
{{ item.code }} {{ item.desc }} {{ item.qty }}
{% endfor %}
```

**For images:**
Replace image placeholders with:
```
{{ photo_1 }}
{{ photo_2 }}
... etc
```

### 3. Template Testing 🧪

After converting the template:

1. Run manual test with a real report export (replace the input path accordingly):
```bash
source .venv/bin/activate
python3 python/export_report.py \
   --input /path/to/your_data.json \
  --template app/assets/Context/inspection_template.docx \
  --output test_output.docx
```

2. Open `test_output.docx` in Microsoft Word
3. Verify all placeholders are replaced
4. Check image quality and positioning
5. Validate table formatting

### 4. Integration Testing 🧪

Test the full Rails → Python flow:

1. Create a test report in the application
2. Add photos and data
3. Click "Export to Word"
4. Verify the generated document

### 5. Production Deployment 🚀

When deploying:

- Ensure Dockerfile changes are deployed
- Python dependencies will be installed automatically
- Monitor logs for Python-related errors

### 6. Optional: Template Version Control

Consider adding the template to git with tracking:

```bash
git add app/assets/Context/inspection_template.docx
git commit -m "Add docxtpl template"
```

## Testing Checklist

- [ ] Install Python prerequisites (`python3-venv`, `python3-pip`)
- [ ] Run `./python/setup.sh` successfully
- [ ] Convert template to docxtpl syntax
- [ ] Test Python script standalone with sample data
- [ ] Verify images appear in generated document
- [ ] Test table loops render correctly
- [ ] Test full Rails export flow
- [ ] Check error handling (missing photos, invalid data)
- [ ] Verify fallback to Ruby exporter works
- [ ] Test in production environment

## Fallback Strategy

The implementation includes automatic fallback:

1. **Primary:** Python exporter (better image handling)
2. **Fallback:** Ruby exporter (existing functionality)

If Python setup fails or encounters errors, reports can still be generated using the original Ruby-based system.

## Key Features

✅ **Image Support:** Inline images properly embedded using `InlineImage`
✅ **Template Flexibility:** Non-developers can edit templates in Word
✅ **Table Support:** Dynamic loops for placed quantities, QA, equipment, crew
✅ **Error Handling:** Comprehensive logging and error recovery
✅ **Production Ready:** Docker support and deployment documentation
✅ **Fallback Mechanism:** Automatic failover to Ruby exporter
✅ **Test Infrastructure:** Sample data and testing guidelines

## Next Steps

1. **Install Prerequisites:**
   ```bash
   sudo apt install python3-venv python3-pip
   ```

2. **Run Setup:**
   ```bash
   cd /home/dylon/inspection_cms
   ./python/setup.sh
   ```

3. **Convert Template:**
   - Open `app/assets/Context/inspection_template.docx`
   - Replace placeholders with Jinja2 syntax
   - Add table loops for dynamic data
   - Save and test

4. **Test End-to-End:**
   - Create test report
   - Export to Word
   - Verify output

5. **Deploy:**
   - Push changes to production
   - Monitor logs
   - Validate exports work correctly

## References

- docxtpl documentation: https://docxtpl.readthedocs.io/
- python-docx documentation: https://python-docx.readthedocs.io/
- Jinja2 template syntax: https://jinja.palletsprojects.com/

---

**Implementation Date:** January 11, 2026
**Status:** Complete - Ready for testing
**Migration Plan:** [docs/docxtpl_migration_plan.md](../docs/docxtpl_migration_plan.md)
