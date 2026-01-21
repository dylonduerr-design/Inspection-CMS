# AI Agent Information

## Context
This file refines the AI agent plan into smaller, actionable steps and documents where Azure OpenAI configuration is used in the codebase.

## Current Status (from implementation plan)
- *Inventory report inputs*
- *Define canonical payload*
- *Testing wiring (JSON preview endpoint + UI button)*

## Next Steps (broken down)
### 1) Persistence for AI outputs
- Add DB fields on `reports` (store on the report record):
  - `ai_work_summary` (short, structured summary)
  - `ai_generated_commentary` (AI draft shown beneath inspector commentary)
  - `ai_status` (`idle`, `queued`, `running`, `success`, `failed`)
  - `ai_error`
  - `ai_generated_at`
- Regenerate behavior: overwrites existing `ai_work_summary` / `ai_generated_commentary`.
- Generation is allowed on partially filled reports:
  - Persisting AI fields must not require the report to pass full validations.
- Add migrations + rollback path.

### 2) Provider-agnostic generator interface
- Create `ReportAi::Generator` interface with:
  - `generate!(payload:, intent:)` returning structured output for:
    - `work_summary`
    - `commentary`
- Implement:
  - `ReportAi::AzureGenerator` (production)
  - `ReportAi::FakeGenerator` (dev/test)
- Add adapter selection in `ReportAi::Generator.for_env` or via configuration.

### 3) Background job + orchestration
- Add `ReportAi::GenerateJob` (or separate jobs per intent):
  - Load report
  - Build payload
  - Call generator (intent-based)
  - Persist outputs + status (overwrite semantics)
  - Capture errors
- Add retry strategy and timeout handling.

### 4) Controller endpoints + UI
- Endpoints to trigger generation (POST):
  - `ReportsController#generate_work_summary`
  - `ReportsController#generate_commentary`
- Status endpoint (GET):
  - `ReportsController#ai_status`
- UI on the report edit form:
  - Button: “Generate Work Summary”
  - Button: “Generate Commentary”
  - Editable fields for `ai_work_summary` and `ai_generated_commentary`
  - Display rule: generated commentary appears beneath whatever the inspector already wrote in `commentary`.
- Authorization:
  - Only the report owner can generate AI.
  - Follow current report edit constraints for status gating (e.g., `in_progress` / `revise`).

### 5) Guardrails + observability
- Input size limits and truncation strategy
- Prompt-injection safeguards
- Logging with correlation IDs (report id, user id)
- Audit events for AI generation requests

### 6) Export behavior
- DOCX export must include AI fields:
  - Include `ai_work_summary`
  - Include `ai_generated_commentary` (placed after inspector commentary)
- CSV export should not include AI fields by default.

## Where Azure OpenAI Configuration Is Used
When the provider interface is implemented:
- `ReportAi::AzureGenerator` should read environment variables for:
  - `AZURE_OPENAI_ENDPOINT`
  - `AZURE_OPENAI_API_KEY`
  - `AZURE_OPENAI_DEPLOYMENT_NAME`
  - `AZURE_OPENAI_API_VERSION`
- These values should be referenced from:
  - application config initializer (e.g., `config/initializers/report_ai.rb`)
  - or read directly inside the Azure generator class

## Environment Variables (do not commit secrets)
Add the following to your local `.env` (or secret manager). Do **not** commit real keys to git.

```
AZURE_OPENAI_ENDPOINT=https://azure-openai-inspection-report.openai.azure.com/
AZURE_OPENAI_API_KEY=<set-in-local-env>
AZURE_OPENAI_DEPLOYMENT_NAME=gpt-5-nano
AZURE_OPENAI_API_VERSION=2024-12-01-preview
```

## Notes
- Provider remains swappable; keep `ReportAi::Generator` interface stable.
- Payload builder already produces a deterministic JSON structure (`report_ai_payload_v1`).
