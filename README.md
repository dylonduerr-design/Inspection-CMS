# Inspection CMS

A Rails 7.1 web application for managing FAA airport construction inspection workflows. Inspectors log daily activity (weather, compliance, workforce, bid item placement, QA tests, photos), QC staff review and approve reports, and the system exports finalized inspection daily reports (IDRs) as high-fidelity Word documents.

## Feature Overview

- **Daily Inspection Reports (IDRs):** Structured capture of weather (3 time slices), compliance flags, workforce/equipment logs, placed quantities against bid items, QA test results, and photos.
- **Workflow:** Reports move through `in_progress` → `review` → `revise` (if returned) → `finalize`, with a full audit trail at every step.
- **Roles:** Inspector, QC, Admin — with Microsoft Azure AD SSO (Entra ID) or local Devise accounts.
- **AI-Assisted Writing:** Two-pass Azure OpenAI pipeline generates work summaries and commentary from structured report data.
- **Word Export:** Async background job renders a high-fidelity `.docx` via a Python `docxtpl` exporter, with real-time progress via ActionCable.
- **CSV Export:** Reports index exports a filtered result set as an Excel-friendly CSV.
- **FAA Weekly Reports (Form 5370-1):** Rolls up daily reports into weekly sections — weather stats, work summary, lab testing, materials, problem areas — with AI-generated narrative for each section.
- **Bid Item & Spec Checklists:** Project bid items link to an FAA spec library. Each placed quantity can carry per-spec checklist answers.
- **Data View:** Completion percentage chart, broken down by spec division/category.
- **Legacy DOCX Import:** Python importer extracts data from legacy Word reports.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Web framework | Ruby 3.2.2 / Rails 7.1 |
| Database | PostgreSQL (full-text search via tsvector) |
| Background jobs | Sidekiq + Redis |
| Real-time | ActionCable (Hotwire/Turbo) |
| Auth | Devise + OmniAuth (Microsoft Graph / Azure AD) |
| File storage | Azure Blob Storage (Active Storage) |
| AI | Azure OpenAI (GPT-4 series via HTTP) |
| DOCX generation | Python 3.8+ / `docxtpl` (subprocess) |
| Pagination | Pagy |
| Containerization | Docker (nginx + Puma + Python, managed by Supervisor) |

---

## Data Model

### Hierarchy

```
Project
 ├── Phases
 ├── BidItems  ──── SpecItem (shared FAA spec library)
 ├── WeeklyReports
 └── Reports (IDRs)
      ├── PlacedQuantities ──── BidItem
      ├── ChecklistEntries ──── SpecItem
      ├── EquipmentEntries
      ├── CrewEntries
      ├── QaEntries
      ├── ReportAttachments (photos)
      ├── ReportExports (async Word exports)
      └── AuditLogs
```

### Report Status Workflow

```
in_progress → review → finalize
                ↓ ↑
              revise
```

### Report Result

`pending` → `pass` / `fail` / `as_built`

### User Roles

| Role | Permissions |
|---|---|
| `inspector` | Create and edit own reports |
| `qc` | Review, approve, or return all reports; manage projects |
| `admin` | Full access including spec item editing |

---

## AI Generation

The AI pipeline uses Azure OpenAI with a provider-agnostic interface (`ReportAi::Generator`). A `FakeGenerator` is available for development/test environments.

### Report-Level (Daily IDR)

Triggered from the report show page:

1. **Work Summary** — Single-pass extraction of key facts from the structured report payload.
2. **Commentary** — Two-pass pipeline:
   - Pass 1 (`outline`): Extracts structured facts → saved to `ai_work_summary`
   - Pass 2 (`writing`): Converts outline + original notes into polished prose → saved to `ai_generated_commentary`

Progress is tracked via `ai_status` (`idle / queued / running / success / failed`) and `ai_stage` (`outline / writing`), polled from the frontend.

### Weekly Report

Seven AI intents, each written to its own field:
- `weekly_weather` → `weather_summary`
- `weekly_work_summary` → `work_summary` (chunked map-reduce for large datasets)
- `weekly_lab_testing` → `lab_testing_summary`
- `weekly_materials` → `materials_summary`
- `weekly_problem_areas` → `problem_areas`

### Payload

`ReportAi::PayloadBuilder` assembles a rich JSON context including project/phase metadata, weather across 3 periods, compliance statuses, all bid items placed (with quantities and checklist answers), QA results, workforce logs, equipment logs, spec checklists, and photo slot metadata.

---

## Word Export

Open any report and click **Export Word**. A progress bar updates in real time while the job runs in the background.

**Pipeline:**
1. `ReportExportJob` (Sidekiq) prepares the data payload
2. Calls `PythonDocxExporter`, which spawns `python/export_report.py`
3. Python renders `app/assets/documents/inspection_template.docx` using `docxtpl` (Jinja2-style placeholders)
4. Output file is saved to Azure Blob Storage via Active Storage
5. A **Download Export** button appears on the report page

**Template syntax overview:**

```text
{{ project }}
{{ inspector }}

{% for item in placed_quantities %}
  {{ item.code }} | {{ item.desc }} | {{ item.qty }}
{% endfor %}

{{ photo_1 }}   {# InlineImage #}
{{ caption_1 }}
```

For full placeholder reference and table formatting details, see [docs/TEMPLATE_GUIDE.md](docs/TEMPLATE_GUIDE.md).

**Photo slots:** The first 6 attachments on the report are embedded as inline images. More than 6 photos are ignored by the template.

**Template file:** `app/assets/documents/inspection_template.docx`

---

## Weekly Reports (FAA Form 5370-1)

Weekly reports aggregate all finalized daily reports within a date range for a project:

- **Weather stats:** High/low temp, average wind, total precip, notable events
- **Completion %:** Calculated per spec division (`∑ placed quantities / ∑ bid quantities × 100`)
- **AI narrative sections:** Weather summary, work summary, lab testing, materials, problem areas

---

## Local Setup

### Prerequisites

- Ruby 3.2.2 + Bundler
- PostgreSQL
- Redis
- Python 3.8+ (for DOCX export)

Ubuntu/Debian:
```bash
sudo apt update && sudo apt install -y python3-venv python3-pip
```

### Installation

```bash
bundle install
bin/rails db:prepare
./python/setup.sh   # creates .venv/ and installs docxtpl dependencies
```

### Running Services

Three services are required for full functionality:

```bash
# Terminal 1: Redis
redis-server

# Terminal 2: Sidekiq (background jobs)
bundle exec sidekiq

# Terminal 3: Rails
bin/rails server
```

Visit [http://localhost:3000](http://localhost:3000).

---

## Docker

A production-style Dockerfile (multi-stage build) installs Ruby, Python, and nginx. Supervisor manages nginx + Puma inside the container.

Build:
```bash
docker build -t inspection-cms .
```

Run (requires external Postgres + Redis):
```bash
docker run -p 3000:3000 \
  -e DATABASE_URL=postgres://user:pass@host:5432/dbname \
  -e REDIS_URL=redis://host:6379/0 \
  inspection-cms
```

For a ready-to-run compose example (web + worker + redis + db), see [docs/ASYNC_EXPORT_SETUP.md](docs/ASYNC_EXPORT_SETUP.md).

---

## Environment Variables

### Required (Production)

| Variable | Purpose |
|---|---|
| `DATABASE_URL` | PostgreSQL connection string |
| `REDIS_URL` | Redis (Sidekiq + ActionCable). Defaults to `redis://localhost:6379/0` |
| `RAILS_MASTER_KEY` | Rails secret key base |

### Azure Blob Storage (Active Storage — photos & exports)

| Variable | Purpose |
|---|---|
| `AZURE_STORAGE_ACCOUNT_NAME` | Storage account name |
| `AZURE_STORAGE_ACCESS_KEY` | Storage account key |

### Azure OpenAI (AI generation)

| Variable | Purpose |
|---|---|
| `AZURE_OPENAI_ENDPOINT` | Full endpoint URL (e.g. `https://my-resource.openai.azure.com/`) |
| `AZURE_OPENAI_API_KEY` | API key |
| `AZURE_OPENAI_DEPLOYMENT_NAME` | Deployment name (e.g. `gpt-4-turbo`) |
| `AZURE_OPENAI_API_VERSION` | API version. Defaults to `2024-12-01-preview` |

### Azure AD SSO (OmniAuth / Devise)

| Variable | Purpose |
|---|---|
| `AZURE_CLIENT_ID` | App registration client ID |
| `AZURE_CLIENT_SECRET` | App registration client secret |
| `AZURE_TENANT_ID` | Azure AD tenant ID |

### Optional

| Variable | Purpose |
|---|---|
| `APP_TIME_ZONE` | Rails time zone. Defaults to `Pacific Time (US & Canada)` |

---

## Templates

### Authoring DOCX Templates

The Python exporter uses `docxtpl` (Jinja2-style placeholders). Template files must be saved as `.docx` and stored at:

```
app/assets/documents/inspection_template.docx
```

For a full list of accepted placeholders and table/photo formatting details, see [docs/TEMPLATE_GUIDE.md](docs/TEMPLATE_GUIDE.md).

### Photo Whitespace Issue

If photos 1–4 fail to render but 5–6 work, there may be preserved whitespace in the DOCX XML. Use the cleanup helper:

```bash
python3 python/clean_template.py app/assets/documents/inspection_template.docx
```

---

## Troubleshooting

### Export stuck / progress never moves

- Confirm Redis is running: `redis-cli ping` → `PONG`
- Confirm Sidekiq is running: `bundle exec sidekiq`
- Check browser console + Rails logs for ActionCable connection errors

### Python exporter failures

Recreate the Python environment:
```bash
./python/setup.sh
```

Run the exporter standalone to isolate the error:
```bash
source .venv/bin/activate
python3 python/export_report.py \
  --input /path/to/report_data.json \
  --template app/assets/documents/inspection_template.docx \
  --output /tmp/test.docx
```

### Template not found

Confirm the template file exists at `app/assets/documents/inspection_template.docx`.

### AI generation not completing

- Verify all four `AZURE_OPENAI_*` environment variables are set.
- Check Sidekiq logs for `ReportAiGenerateJob` errors.
- The `ai_error` field on the report record stores the last generation error.

---

## Testing

```bash
bin/rails test
```

---

## Planned Features

These features are documented and designed but not yet implemented.

### SharePoint Publish on Finalize

**Plan:** [docs/SHAREPOINT_PUBLISH_PLAN.md](docs/SHAREPOINT_PUBLISH_PLAN.md)

After a report is finalized and exported, automatically upload the DOCX and photos to a SharePoint Document Library via Microsoft Graph API. This would add:
- New `SharepointPublishJob` (Sidekiq)
- New `SharepointPublishService` (Graph API client)
- New report fields: `sharepoint_item_id`, `sharepoint_web_url`, `sharepoint_published_at`, `sharepoint_publish_status`
- New environment variables: `SHAREPOINT_CLIENT_SECRET`, `SHAREPOINT_SITE_ID`, `SHAREPOINT_DRIVE_ID`, `SHAREPOINT_LIBRARY_ROOT`
- Requires Azure AD app registration with `Sites.ReadWrite.All` permission

### Expanded Inspector Checklists

**Plan:** [docs/WIP_INSPECTOR_CHECKLISTS.md](docs/WIP_INSPECTOR_CHECKLISTS.md)

The FAA spec library (`spec_items`) supports per-spec checklist questions (stored as JSONB). Checklist data migrations for P-101, P-151, P-219, P-603, and P-610 have shipped. The remaining FAA specs in the library still use placeholder questions. The plan is to author detailed inspection questions for each remaining spec based on the project specification documents.

### Azure Cache for Redis (Optional Infrastructure)

**Plan:** [docs/AZURE_CACHE_REDIS.md](docs/AZURE_CACHE_REDIS.md)

Replace self-managed Redis with Azure Cache for Redis for production scalability. The app currently falls back to in-process adapters when Redis is unavailable, and uses local disk caching for image URLs to avoid Redis size limits. This is optional — the app runs fully on a self-hosted Redis instance.

---

## Related Docs

| File | Description |
|---|---|
| [docs/TEMPLATE_GUIDE.md](docs/TEMPLATE_GUIDE.md) | DOCX template authoring — full placeholder reference, tables, photos |
| [docs/ASYNC_EXPORT_SETUP.md](docs/ASYNC_EXPORT_SETUP.md) | Async export setup + sample docker-compose |
| [docs/AI_AGENT.md](docs/AI_AGENT.md) | AI generation architecture and prompt design |
| [docs/DEPLOYMENT_CHECKLIST.md](docs/DEPLOYMENT_CHECKLIST.md) | Production deployment checklist |
| [docs/SSO_SETUP.md](docs/SSO_SETUP.md) | Azure AD / Microsoft Graph SSO configuration |
| [docs/FEATURE_LIST.md](docs/FEATURE_LIST.md) | User-facing feature inventory |
| [docs/PREROLLOUT_FIXES.md](docs/PREROLLOUT_FIXES.md) | Pre-rollout issue triage and fix notes |
| [docs/changelog/prerollout-fixes.md](docs/changelog/prerollout-fixes.md) | Changelog for the prerollout-fixes branch |
| [python/README.md](python/README.md) | Python exporter internals and standalone usage |
