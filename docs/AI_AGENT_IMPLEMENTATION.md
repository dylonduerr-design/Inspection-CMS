# AI Agent Implementation Plan + Current Progress

## Goal
Implement an AI agent that ingests report form data (checklists, bid items, workforce, commentary, etc.) and generates:
- A concise work summary (new dedicated report field).
- A generated commentary draft shown beneath the inspector’s own commentary.

The integration should use Azure OpenAI initially, but remain provider-agnostic so it can be swapped later.

## Product Vision (Locked In)
- Storage: AI outputs persist on `reports`.
- UX:
   - Inspector writes their own `commentary` first.
   - Button: “Generate Work Summary” (fills `ai_work_summary`).
   - Button: “Generate Commentary” (fills `ai_generated_commentary`, displayed beneath inspector commentary).
   - Inspector can edit AI fields for accuracy.
- Regenerate behavior: overwrites existing AI fields.
- Permissions: only the report owner can generate; QC cannot generate on another inspector’s report.
- Status gating: follow existing report edit constraints (e.g., `in_progress` / `revise`).
- Partial reports: AI generation is allowed on partially filled reports.
- Exports: include AI text in DOCX export; do not include AI fields in CSV export by default.

---

## Plan (High-Level)
1. **Inventory report inputs**
   - Identify where report data lives (models, controllers, views, JS).
   - Map checklist data (spec checklists and bid-item checklists).
2. **Define a canonical payload**
   - Build a stable JSON payload from report data for AI prompting.
   - Include schema versioning and deterministic ordering.
3. **Persist AI outputs on reports** (future)
   - Add `reports.ai_work_summary` and `reports.ai_generated_commentary`.
   - Add operational fields: `ai_status`, `ai_generated_at`, `ai_error`.
   - Ensure AI field persistence does not require full report validation.
4. **Async generation + UI trigger** (future)
   - Job(s) to call the AI provider via a clean interface.
   - Controller endpoints + UI buttons:
     - “Generate Work Summary”
     - “Generate Commentary”
5. **Provider interface** (future)
   - Implement `ReportAi::Generator` interface.
   - Add `ReportAi::AzureGenerator` and `ReportAi::FakeGenerator` for dev/test.
6. **Guardrails + observability** (future)
   - Input size limits, prompt injection handling, logging, and auditing.
7. **Export integration** (future)
   - Include AI fields in DOCX export output.
   - Exclude AI fields from CSV export by default.

---

## Steps Completed So Far
### 1) Inventory report inputs
Confirmed report domain shape and form entry points:
- **Model aggregate:** `Report` with nested children (`PlacedQuantity`, `CrewEntry`, `EquipmentEntry`, `QaEntry`, `ChecklistEntry`, `ReportAttachment`).
- **Checklist inputs:**
  - Spec checklists: `SpecItem.checklist_questions` definitions, answers stored on `ChecklistEntry.checklist_answers`.
  - Bid-item checklists: definitions via `BidItem#active_questions`, answers stored on `PlacedQuantity.checklist_answers`.
- **Form locations:** Report form and checklist UI in `app/views/reports/_form.html.erb` plus Stimulus controllers handling spec drilldown and dynamic rows.

### 2) Payload builder (API-agnostic)
Implemented a canonical AI payload builder:
- File: `app/services/report_ai/payload_builder.rb`
- Output includes: project, phase, inspector, authorization, weather, compliance, narrative, bid items + checklists, QA, workforce, equipment, spec checklists, and attachments.
- Adds deterministic ordering + schema version `report_ai_payload_v1`.

### 3) Testing wiring (no AI API required)
Added a JSON preview endpoint so payloads can be validated quickly:
- **Route:** `GET /reports/:id/ai_payload`
- **Controller action:** `ReportsController#ai_payload`
- **UI button:** “AI Payload (JSON)” on report show page.

---

## What’s Ready for Testing
- Payload builder can be called directly in Rails console:
  - `ReportAi::PayloadBuilder.build(Report.last)`
- Report show page now exposes the payload for verification:
  - Open any report and click **AI Payload (JSON)**.
- AI generation can be tested end-to-end:
  - Edit a report you own (in `in_progress` or `revise` status)
  - Click "Generate Work Summary" or "Generate Commentary"
  - Wait for the job to complete (status will update automatically)
  - Edit the generated content if needed
  - Save the report

---

## Implementation Complete ✅
All core features have been implemented:

1. ✅ **DB storage for AI output fields on reports** (`ai_work_summary`, `ai_generated_commentary`, plus status/error/timestamp).
2. ✅ **Generator interface + Azure adapter** (provider-agnostic seam; support intent `work_summary` vs `commentary`).
3. ✅ **Background job(s) to generate AI text** (ActiveJob + Sidekiq) with overwrite semantics.
4. ✅ **UI form fields + buttons** on the report edit form (two actions, owner-only, status-gated).
5. ✅ **DOCX export includes AI fields** (CSV unchanged by default).
6. ✅ **Logging, audit trail** (size limits and prompt safeguards are future enhancements).

---

## Files Created/Modified

### New Files
- `app/services/report_ai/generator.rb` - Base generator interface
- `app/services/report_ai/azure_generator.rb` - Azure OpenAI implementation
- `app/services/report_ai/fake_generator.rb` - Dev/test implementation
- `app/services/report_ai/prompt_templates.rb` - Prompt definitions
- `app/jobs/report_ai_generate_job.rb` - Async generation job
- `app/javascript/controllers/ai_generation_controller.js` - Stimulus controller
- `config/initializers/report_ai.rb` - Configuration initializer
- `db/migrate/20260121212659_add_ai_fields_to_reports.rb` - Migration

### Modified Files
- `app/models/report.rb` - Added AI helper methods
- `app/controllers/reports_controller.rb` - Added AI endpoints
- `config/routes.rb` - Added AI routes
- `app/views/reports/_form.html.erb` - Added AI UI section
- `app/services/python_docx_exporter.rb` - Added AI fields to export

---

## Environment Variables for Production
Set these in your production environment (do NOT commit to git):

```
AZURE_OPENAI_ENDPOINT=https://your-resource.openai.azure.com/
AZURE_OPENAI_API_KEY=<your-api-key>
AZURE_OPENAI_DEPLOYMENT_NAME=<your-deployment-name>
AZURE_OPENAI_API_VERSION=2024-12-01-preview
```
