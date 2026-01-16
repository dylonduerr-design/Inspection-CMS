# Photo Tag Issue - Diagnosis and Solution

## Problem Identified

The photo tags in your Word template (`inspection_template.docx`) are not properly responding to the Python utility (`export_report.py`) because **photo_1 through photo_4 have excessive leading whitespace** in the XML structure.

### XML Comparison

**Problem tags (photo_1 to photo_4):**
```xml
<w:t xml:space="preserve">                                                                                               {{ photo_1 }}</w:t>
```
(~90 spaces before the tag)

**Working tags (photo_5 and photo_6):**
```xml
<w:t>{{ photo_5 }}</w:t>
```
(no extra spaces)

## Why This Breaks docxtpl

The `docxtpl` library uses Jinja2 template engine to find and replace `{{ variable }}` patterns. When there's excessive whitespace:
- The pattern matching may fail or behave unexpectedly
- The InlineImage replacement doesn't work correctly
- The whitespace is preserved due to `xml:space="preserve"` attribute

## Solutions

### Solution 1: Manual Fix in Word (Recommended)

1. Open `app/assets/documents/inspection_template.docx` in Microsoft Word
2. Find the photo sections (search for "{{ photo_1 }}")
3. For each of photo_1, photo_2, photo_3, and photo_4:
   - Select the entire placeholder text `{{ photo_X }}`
   - Cut it (Ctrl+X)
   - Delete any extra spaces/tabs before where it was
   - Paste it back (Ctrl+V) with NO leading spaces
4. Save the template
5. Test with: `python python/export_report.py --input /path/to/your_data.json --template app/assets/documents/inspection_template.docx --output /tmp/test.docx`

### Solution 2: Automated Script

I've created a Python script to fix this automatically:

```bash
cd /home/dylon/inspection_cms
python3 python/clean_template.py app/assets/documents/inspection_template.docx
```

This will:
- Remove orphaned image/drawing elements
- Clean up excessive whitespace around tags
- Fix the photo placeholder formatting

### Solution 3: Direct XML Edit (Advanced)

If you're comfortable with XML:

1. Unzip the .docx file (it's just a ZIP archive)
2. Edit `word/document.xml`
3. Find each photo tag and remove the leading spaces
4. Save and rezip

## How to Verify the Fix

After applying any solution, test with:

```bash
cd /home/dylon/inspection_cms/python
source ../.venv/bin/activate
python export_report.py \\
  --input /path/to/your_data.json \\
  --template ../app/assets/documents/inspection_template.docx \\
  --output /tmp/test_output.docx \\
  --verbose
```

Then open `/tmp/test_output.docx` and verify that photos appear in all 6 slots.

## Root Cause

This likely happened when:
- Photos 1-4 were added/edited in Word with different formatting than 5-6
- Copy/paste operations preserved extra formatting/whitespace
- The template was edited with "Show formatting marks" off, hiding the spaces

## Prevention

Going forward:
- Always use consistent formatting when adding placeholders
- Turn on "Show formatting marks" in Word (Ctrl+Shift+8) to see hidden characters
- Use the template guide and ensure no extra spaces around tags
- Test after each template edit

---

**Quick Fix Command:**

```bash
cd /home/dylon/inspection_cms
# Backup first
cp app/assets/documents/inspection_template.docx app/assets/documents/inspection_template_backup.docx

# Run the cleanup utility
python3 python/clean_template.py app/assets/documents/inspection_template.docx

# Test it
cd python && source ../.venv/bin/activate
python export_report.py -i /path/to/your_data.json -t ../app/assets/documents/inspection_template.docx -o /tmp/test.docx -v
```
