# Inspection CMS

Inspection CMS is a Rails 7.1 app for creating inspection reports, managing review/revision/finalization workflows, and exporting data to downstream tools.

- **Workflow:** reports move through `in_progress` → `review` → (`revise` if returned) → `finalize`.
- **Audit logging:** key workflow events are recorded per report.
- **Tracking:** async Word exports are tracked with status/progress and stored as attachments.
- **Exports:** high-fidelity Word (.docx) export plus **CSV export (Excel-friendly)** from the reports index.

Word export is implemented as an **async background job** with **real-time progress** via ActionCable, utilizing a **Python `docxtpl` exporter** for high-fidelity rendering.

## Core stack (quick)

- Ruby 3.2.2 / Rails 7.1
- Postgres + Redis
- Sidekiq for background jobs
- Python 3.8+ for DOCX export

## Exports

### Word (.docx)

Open a report and click **Export Word**. You’ll see a progress bar, and then a **Download Export** button.

Under the hood: this runs in the background (Sidekiq + Redis) and uses a Python exporter for the final document.

Template file (checked into the repo):

- `app/assets/documents/inspection_template.docx`

### .CSV

The reports index supports a CSV export (filename like `Project_Master_Log_<date>.csv`). This CSV is designed to be opened directly in Excel/Google Sheets.

Tip: Apply filters in the UI first, then click **Export CSV** to export the filtered result set.

## Local Setup

### 1. Prerequisites

- Ruby 3.2.2 & Bundler
- PostgreSQL & Redis (running locally)
- Python 3.8+ (required for DOCX generation)

Ubuntu/Debian users (for the Python exporter):

```bash
sudo apt update && sudo apt install -y python3-venv python3-pip
```

### 2. Installation

```bash
# Install Ruby gems
bundle install

# Setup database
bin/rails db:prepare

# Setup Python environment (creates .venv/)
./python/setup.sh
```

### 3. Run the services

Async export needs three things running:

```bash
# Terminal 1: Redis
redis-server

# Terminal 2: Sidekiq (jobs)
bundle exec sidekiq

# Terminal 3: Rails (web)
bin/rails server
```

Visit http://localhost:3000

## Docker (optional)

This repo includes a production-style Dockerfile that also installs the Python DOCX dependencies.

Build:

```bash
docker build -t inspection-cms .
```

Run (you still need a Postgres + Redis; easiest is Compose):

```bash
docker run -p 3000:3000 \
	-e DATABASE_URL=postgres://user:pass@host:5432/dbname \
	-e REDIS_URL=redis://host:6379/0 \
	inspection-cms
```

If you want a ready-to-run compose example (web + worker + redis + db), see `docs/ASYNC_EXPORT_SETUP.md`.

## Config (env vars)

- `DATABASE_URL` (Postgres)
- `REDIS_URL` (Redis; defaults to `redis://localhost:6379/0`)
- `APP_TIME_ZONE` (defaults to `Pacific Time (US & Canada)`; impacts defaults like report `shift_start`)


## Templates

### Python template syntax

Python export uses `docxtpl` (Jinja2-style placeholders), e.g.:

```text
{{ project }}
{{ inspector }}

{% for item in placed_quantities %}
	{{ item.code }}
{% endfor %}
```

For a complete list of accepeted placeholders and an in depth description of table formatting, see: `docs/TEMPLATE_GUIDE.md`

### Photo placeholder whitespace issue

If photos 1–4 fail to render but 5–6 work, it may be due to whitespace preserved inside the DOCX XML.

See `PHOTO_TAG_FIX.md` and use the helper:

```bash
python3 python/clean_template.py app/assets/documents/inspection_template.docx
```

## Troubleshooting

### Export stuck / progress never moves

- Ensure Redis is running: `redis-cli ping` → `PONG`
- Ensure Sidekiq is running: `bundle exec sidekiq`
- Ensure ActionCable can connect (check browser console + Rails logs)

### Python exporter failures

- Recreate Python env: `./python/setup.sh`
- Confirm packages installed: `.venv/bin/pip show docxtpl`
- Confirm exporter works standalone:

```bash
source .venv/bin/activate
python3 python/export_report.py \
	--input /path/to/report_data.json \
	--template app/assets/documents/inspection_template.docx \
	--output /tmp/test.docx
```



### Template not found

The exporters look for one of:

- `app/assets/Context/inspection_template.docx`
- `app/assets/documents/inspection_template.docx`

Make sure at least one exists in your environment.

## Testing

Run Rails tests:

```bash
bin/rails test
```

## Related docs

- `docs/ASYNC_EXPORT_SETUP.md` — running async export + sample docker-compose
- `docs/IMPLEMENTATION_SUMMARY.md` — implementation details of Python exporter integration
- `docs/DEPLOYMENT_CHECKLIST.md` — deployment checklist for Python-based export
- `python/README.md` — Python exporter internals
- `python/SETUP.md` — OS-specific Python setup help


