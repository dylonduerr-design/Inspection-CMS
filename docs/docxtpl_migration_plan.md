# DOCX Template Migration Plan (docxtpl)

## Goals
- Preserve the exact visual layout of the existing Word template while automating text and photo population.
- Let non-developers keep editing the master template in Microsoft Word using simple placeholder tags.
- Keep the export pipeline reliable, testable, and runnable entirely on our infrastructure.

## High-Level Architecture
1. **Tagged Word Template**: Designers update `inspection_template.docx`, inserting `{{ variable }}` or `{% for item in collection %}` tags plus image placeholders where photos must appear.
2. **Python Exporter** (`docxtpl`): A small script loads the template, injects JSON data, renders inline images, and writes the final `.docx`.
3. **Rails Bridge**: The existing exporter gathers report data and photo blobs, calls the Python script (CLI or service), and streams the resulting file to the user.

## Implementation Steps
1. **Template Tagging**
   - Map every placeholder currently handled via Ruby string replacement to a `docxtpl` variable.
   - Use `{{ caption_1 }}` style tags for captions, and insert picture shapes named `{{ inline_image(photo_1) }}` for each slot.
   - Replace repeating table rows with `{% for entry in placed_quantities %}` loops to avoid manual row cloning.

2. **Python Environment**
   - Add a project-local virtual environment (e.g., `.venv`) with `docxtpl`, `python-docx`, and `Pillow` in `requirements.txt`.
   - Provide a helper script (e.g., `scripts/setup_python.sh`) so deployment and CI can install dependencies deterministically.

3. **Exporter Script**
   - Create `python/export_report.py` that:
     1. Parses JSON payload containing all report fields plus file paths for photos.
     2. Loads the tagged template (`DocxTemplate('inspection_template.docx')`).
     3. Builds the context dict, including `InlineImage` objects for supplied photos (fallback to a blank spacer when missing).
     4. Saves the rendered document to a temp path and prints its location or streams bytes to stdout.

4. **Rails Integration**
   - Extend `WordReportExporter` (or a new service) to:
     1. Serialize report data to JSON and stage photo files in a temp directory.
     2. Shell out to `python3 python/export_report.py --input payload.json --output report.docx` (or call an HTTP endpoint if preferred).
     3. Handle failures with clear logging and user-facing errors.
     4. Clean up temp assets after the file is returned.

5. **Testing & QA**
   - Add automated tests that compare known-good DOCX outputs (or at least confirm the script exits cleanly) for representative reports.
   - Run manual regression checks to ensure the new file opens cleanly in Word and matches the original layout pixel-for-pixel.

6. **Operational Readiness**
   - Document how to edit placeholders inside Word and how to run the Python exporter locally.
   - Update deployment scripts/Dockerfiles to install Python dependencies.
   - Monitor logs for exporter failures and add alerting for repeated errors.

## Open Questions
- Should the Python component run as a CLI (simpler) or a long-lived microservice (faster for bulk exports)?
- How do we version-control the template so edits are tracked without blocking non-developers?
- Do we need a fallback mechanism (e.g., keep the current DOCX exporter) during rollout?
