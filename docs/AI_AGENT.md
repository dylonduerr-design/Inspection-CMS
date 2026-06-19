# AI Assistant (Reports)

This app supports AI-assisted generation for two report fields:

- **Work Summary** → stored on `reports.ai_work_summary`
- **Generated Commentary** → stored on `reports.ai_generated_commentary`

The feature is designed to be provider-agnostic (Azure OpenAI in production; deterministic fake generator in dev/test when Azure isn’t configured).

## User Flow

1. Inspector opens a report they own (must be editable: `in_progress` or `revise`).
2. In the report edit form, under **AI-Assisted Content**:
   - Click **Generate Work Summary** or **Generate Commentary**.
3. The UI queues a job and polls status until completion.
4. The generated text is written into the form fields (editable) and can be saved like normal.

Related UI implementation:
- AI section + fields/buttons: `app/views/reports/_form.html.erb`
- Stimulus controller (polling + POST trigger): `app/javascript/controllers/ai_generation_controller.js`

## Endpoints (Rails)

All routes are report member routes:

- `GET /reports/:id/ai_payload` (debug) — returns the canonical AI payload JSON
- `POST /reports/:id/generate_work_summary` — queues generation for `ai_work_summary`
- `POST /reports/:id/generate_commentary` — queues generation for `ai_generated_commentary`
- `GET /reports/:id/ai_status` — returns `{ status, ai_stage, ai_work_summary, ai_generated_commentary, ai_generated_at, ai_error }`

Implementation:
- Controller: `app/controllers/reports_controller.rb`
- Routes: `config/routes.rb`

## Authorization + Status Gating

AI generation is **owner-only** and only allowed when the report is editable:

- Owner-only: `report.user_id == current_user.id`
- Status: `in_progress` or `revise`

Implementation:
- Guard: `Report#ai_generation_allowed_by?`
- Enqueue: `Report#enqueue_ai_generation!`

## Background Job + State Machine

Generation runs asynchronously via ActiveJob (Sidekiq in production).

Statuses are stored as strings on `reports.ai_status`:

- `idle` (default)
- `queued`
- `running`
- `success`
- `failed`

For commentary generation, `reports.ai_stage` tracks the current pipeline step:

- `outline` — Pass 1 (extracting structured facts from report data)
- `writing` — Pass 2 (writing prose commentary from the outline)
- `nil` — cleared on success or failure

Job behavior:

- On enqueue: report is set to `queued`
- Job start: report is set to `running`, `ai_stage` set to `outline`
- After Pass 1: `ai_stage` updated to `writing`
- On success:
  - sets `ai_status = success`, clears `ai_stage`
  - sets `ai_generated_at = Time.current`
  - for commentary: writes outline to `ai_work_summary` and prose to `ai_generated_commentary`
- On failure:
  - sets `ai_status = failed`, clears `ai_stage`
  - sets `ai_error` to the failure message

Implementation:
- Job: `app/jobs/report_ai_generate_job.rb`
- Status helpers: `app/models/report.rb`

Audit logging:
- A log entry is created when generation is requested.
- Another log entry is created on success/failure.

## Provider Selection (Azure vs Fake)

Provider selection is automatic:

- **Test**: always uses `ReportAi::FakeGenerator`
- **Non-test**: uses `ReportAi::AzureGenerator` only when Azure env vars are present; otherwise falls back to `FakeGenerator`

Implementation:
- Factory: `ReportAi::Generator.for_env`
- Azure adapter: `app/services/report_ai/azure_generator.rb`
- Fake adapter: `app/services/report_ai/fake_generator.rb`
- Config warning: `config/initializers/report_ai.rb`

## Azure OpenAI Configuration

Set these environment variables in production (do not commit secrets):

```
AZURE_OPENAI_ENDPOINT=https://your-resource.openai.azure.com/
AZURE_OPENAI_API_KEY=...
AZURE_OPENAI_DEPLOYMENT_NAME=...
AZURE_OPENAI_API_VERSION=2024-12-01-preview
```

Notes:
- `AZURE_OPENAI_API_VERSION` defaults to `2024-12-01-preview` in code.
- If any required Azure vars are missing, the app will fall back to the fake generator and log a warning in production.

## Prompting + Payload

The AI prompt is built from a canonical payload:

- Builder: `app/services/report_ai/payload_builder.rb`
- Schema version: `report_ai_payload_v1`
- Deterministic ordering is used where possible.

Prompts:

- Templates: `app/services/report_ai/prompt_templates.rb`
- Intents supported:
  - `commentary` — two-pass pipeline (outline extraction → prose writing)
  - `commentary_outline` — internal; used as Pass 1 of the commentary pipeline
  - `work_summary` — legacy; no longer user-facing but still registered

Commentary generation uses a two-pass pipeline (see `TWO_PASS_COMMENTARY_PLAN.md`):
- Pass 1 extracts structured facts into an outline (saved to `ai_work_summary`)
- Pass 2 writes prose commentary from the outline (saved to `ai_generated_commentary`)
- The generator returns `{ outline:, commentary: }` which the job unpacks into the two columns

Debugging payloads:

- Use `GET /reports/:id/ai_payload` to see exactly what is being sent into prompting.

## Export Behavior

DOCX export includes AI fields:

- `ai_work_summary`
- `ai_generated_commentary`

CSV export intentionally does **not** include AI fields by default.

Implementation:
- Rails → Python export payload includes AI fields in: `app/services/python_docx_exporter.rb`

## Troubleshooting

- **Buttons disabled forever / stuck “in progress”**: ensure Sidekiq + Redis are running and check `log/development.log`.
- **Azure errors**: check `AZURE_OPENAI_*` env vars and outbound network access; inspect Rails logs for `[ReportAi::AzureGenerator]`.
- **Fake generator used unexpectedly**: confirm env vars are set; provider selection lives in `ReportAi::Generator.for_env`.
