# Python DOCX Exporter

This directory contains the Python-based document generation system using `docxtpl` for creating inspection reports with embedded images.

## Overview

The Python exporter uses the `docxtpl` library to render Word documents from templates with Jinja2-style placeholders. This approach is more robust than the Ruby `docx` gem, especially for handling inline images.

## Repo Hygiene Note

The Python virtualenv is created at `.venv/` and is intentionally **not tracked in git**. If the exporter fails after pulling changes, rerun:

```bash
./python/setup.sh
```

## Architecture

```
Rails App (Ruby)
    ↓
PythonDocxExporter Service
    ↓ (generates JSON + calls)
export_report.py (Python)
    ↓ (renders)
inspection_template.docx → final_report.docx
```

## Setup

### Development

```bash
# Run the setup script to create virtualenv and install dependencies
./python/setup.sh

# Or manually:
python3 -m venv .venv
source .venv/bin/activate
pip install -r python/requirements.txt
```

### Production/Docker

Add to your Dockerfile:

```dockerfile
# Install Python
RUN apt-get update && apt-get install -y python3 python3-pip python3-venv

# Setup Python environment
COPY python/requirements.txt /app/python/
RUN python3 -m venv /app/.venv && \
    /app/.venv/bin/pip install --upgrade pip && \
    /app/.venv/bin/pip install -r /app/python/requirements.txt
```

## Usage

### From Rails

The `PythonDocxExporter` service handles everything:

```ruby
temp_file = PythonDocxExporter.generate(@report)
send_data File.binread(temp_file.path), filename: "report.docx"
```

### Standalone (for testing)

```bash
source .venv/bin/activate

python3 python/export_report.py \
  --input sample_data.json \
  --template app/assets/Context/inspection_template.docx \
  --output output.docx
```

## Template Format

The template should use Jinja2/docxtpl syntax:

### Simple Variables
```
Project: {{ project }}
Inspector: {{ inspector }}
Date: {{ date }}
```

### Photos (InlineImage)
```
{{ photo_1 }}
Caption: {{ caption_1 }}
```

### Tables with Loops
```
{% for item in placed_quantities %}
{{ item.code }} | {{ item.desc }} | {{ item.qty }}
{% endfor %}
```

### Conditionals
```
{% if def_status != "N/A" %}
Deficiency: {{ def_desc }}
{% endif %}
```

## JSON Data Format

The Rails service generates JSON with this structure:

```json
{
  "project": "Highway 101 Reconstruction",
  "inspector": "john@example.com",
  "date": "01/15/2026",
  "photos": [
    {
      "path": "/tmp/photo1.jpg",
      "caption": "Foundation work"
    }
  ],
  "placed_quantities": [
    {
      "code": "203.1",
      "desc": "Excavation",
      "qty": "150.5",
      "notes": "Station 10+00 to 15+00"
    }
  ],
  "qa_entries": [...],
  "equipment_entries": [...],
  "crew_entries": [...]
}
```

## Debugging

Enable verbose logging:

```bash
python3 python/export_report.py --input data.json --template template.docx --output out.docx --verbose
```

Check Rails logs for errors:

```ruby
Rails.logger.info("PythonDocxExporter: ...")
```

## Notes

DOCX export is generated via the Python `docxtpl` pipeline. If exports fail, re-run `./python/setup.sh` and check Rails/Sidekiq logs for the Python error output.

## Dependencies

- **docxtpl** (0.18.0): Template rendering engine
- **python-docx** (1.1.0): Word document manipulation
- **Pillow** (10.2.0): Image processing

## Troubleshooting

### Python not found
Ensure Python 3.8+ is installed:
```bash
python3 --version
```

### Module not found
Run setup again:
```bash
./python/setup.sh
```

### Images not appearing
- Check that photo paths in JSON exist and are readable
- Verify image format (JPG, PNG supported)
- Check template has `{{ photo_1 }}` style placeholders

### Template errors
- Ensure all Jinja2 loops are closed (`{% endfor %}`)
- Check for typos in variable names
- Validate template opens in Word without errors
