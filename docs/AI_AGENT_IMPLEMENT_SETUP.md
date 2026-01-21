# AI Agent Implementation Setup (Project Requirements)

## Goal
Add “Generate Work Summary” and “Generate Commentary” to reports. The inspector writes their own commentary first, then AI generation produces:
- A short, structured work summary.
- Expanded commentary shown beneath the inspector’s notes, editable for accuracy.

AI outputs are stored on the `reports` record and included in DOCX exports (not CSV by default). Provider starts as Azure OpenAI but remains swappable.

## Decisions (Locked In)
- Storage: AI outputs persist on `reports`.
- Regenerate behavior: overwrites existing AI fields (no append history).
- Permissions: only the report owner can generate; QC cannot generate on other inspectors’ reports.
- Availability: follow current report edit constraints (owner-only + status gating).
- Partial reports: AI generation is allowed on partially filled reports (must not require report “valid” state).
- Exports: include AI text in DOCX export; exclude from CSV export by default.

## Prerequisites to Add Before Implementation

### 1) Infrastructure / Processes
- Redis available and configured via `REDIS_URL` (already required by Sidekiq + ActionCable patterns).
- Sidekiq worker process must run anywhere generation is expected to work.

References:
- docs/ASYNC_EXPORT_SETUP.md
- config/sidekiq.yml
- config/cable.yml

### 2) Provider Configuration (Azure OpenAI)
Add required environment variables (do not commit secrets):
- `AZURE_OPENAI_ENDPOINT`
- `AZURE_OPENAI_API_KEY`
- `AZURE_OPENAI_DEPLOYMENT_NAME`
- `AZURE_OPENAI_API_VERSION`

Reference:
- docs/AI_AGENT_INFORMATION.md

### 3) Database Schema (Report-level fields)
Add columns to `reports`:
- `ai_work_summary` (text)
- `ai_generated_commentary` (text)
- `ai_status` (string) values: `idle`, `queued`, `running`, `success`, `failed`
- `ai_generated_at` (datetime)
- `ai_error` (text)

Notes:
- Overwrite semantics require replacing the AI text fields on each generation request and clearing `ai_error` on success.
- Partial-report generation means AI persistence must not be blocked by existing `Report` validations.

Reference:
- db/schema.rb

### 4) Authorization + Status Gating Requirements
Generation endpoints must enforce:
- Owner-only access (same ownership logic used for editing/updating reports).
- Allowed only when the report is editable under current constraints (same statuses used for `edit/update`, currently `in_progress` and `revise`).

Reference patterns:
- app/controllers/reports_controller.rb

### 5) Validation / Persistence Semantics (Partial Reports Allowed)
Define and implement a persistence rule for AI generation:
- “Generate” can run and save AI fields even if the report would fail full validation.
- Saving AI fields must not force the report into an invalid state that blocks the request.

Requirement: generation must update only the AI-related columns and status/error timestamps without requiring a full “report update” submit flow.

Reference:
- app/models/report.rb

### 6) UI Requirements (Two Buttons + Editable Fields)
Add to the report edit form:
- “Generate Work Summary” button
- “Generate Commentary” button
- Editable “Work Summary” field (bound to `ai_work_summary`)
- Editable “Generated Commentary” field (bound to `ai_generated_commentary`)
- Display rule: generated commentary appears beneath whatever the inspector already wrote in `commentary`.

Reference:
- app/views/reports/_form.html.erb

### 7) Background Job Requirements (Async Generation)
Add an async job that:
- Enqueues on button click
- Sets `ai_status` to `queued` then `running`
- Writes outputs to the report fields on success and sets `ai_generated_at`
- Captures failures into `ai_error`, sets `ai_status = failed`

No real-time requirements are mandated, but status must be queryable (polling or refresh).

Reference async architecture patterns:
- docs/ASYNC_EXPORT_SETUP.md

### 8) Canonical Payload + Prompt Template Requirements
- Continue using the canonical deterministic payload for prompting; keep schema versioning stable.
- Add a template/spec for the “Work Summary” prompt and the “Generated Commentary” prompt (two distinct prompt intents).
- Ensure prompt uses report payload plus your supplied summary template.

References:
- app/services/report_ai/payload_builder.rb
- docs/AI_AGENT_IMPLEMENTATION.md

### 9) Export Requirements (DOCX yes, CSV no by default)
DOCX export:
- Must include `ai_work_summary` and `ai_generated_commentary` in the exported report output.
- Placement requirement: generated commentary should appear after the inspector’s commentary.

CSV export:
- Must NOT include AI fields by default.
- Leave current CSV behavior unchanged unless an explicit opt-in flag is introduced later.

References:
- python/export_report.py

### 10) Observability / Audit Requirements
- Log AI generation requests and outcomes with identifiers: report id, user id, job id.
- Create an audit entry when generation is requested (and optionally on success/failure), consistent with report workflow audit patterns.

References:
- app/controllers/reports_controller.rb
- app/models/activity_log.rb

## Non-Goals (for initial implementation)
- Versioned history of AI generations (since regenerate overwrites).
- QC-triggered generation on others’ reports.
- Including AI fields in CSV by default.
