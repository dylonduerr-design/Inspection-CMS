# Pre-Rollout Fixes — Changelog

**Branch:** `prerollout-fixes`  
**Target:** `redis-work`  
**Date:** 2026-03-31  
**Commits:** 5

---

## Summary

This batch of fixes addresses critical bugs and data integrity issues discovered during pre-rollout testing. Changes span AI report generation, weather handling, photo uploads, checklist data, Word template output, and database schema.

---

## Changes

### 1. AI Report Generation Overhaul
**Commit:** `3438fca` — Pre-rollout fixes: AI generation, bid items, phases, user fields, reports, routes, schema updates

- **Azure AI generator** (`app/services/report_ai/azure_generator.rb`): New service added to handle Azure OpenAI-backed report generation as an alternative to the fake/stub generator.
- **Prompt templates** (`app/services/report_ai/prompt_templates.rb`): Significantly expanded (~166 lines added) to improve generated report quality and structure.
- **Fake generator** (`app/services/report_ai/fake_generator.rb`): Updated to better simulate realistic AI output for development/testing.
- **AI generation job** (`app/jobs/report_ai_generate_job.rb`): Fixed job logic and improved error handling.
- **AI stage tracking**: New migration (`20260320000000_add_ai_stage_to_reports.rb`) adds an `ai_stage` column to `reports` to track generation progress.
- **AI generation controller** (`app/javascript/controllers/ai_generation_controller.js`): Frontend controller updated to handle stage-based generation flow.

---

### 2. Weather Auto-Fetch Fixes
**Commit:** `4464f64` — fix: weather auto-fetch for overnight shifts and shift-time changes

- Fixed a bug where overnight shifts (e.g., 22:00–06:00) returned an incorrect midpoint hour due to integer math wrapping.
- Added event listeners on `shift_start` and `shift_end` inputs so weather re-fetches automatically when shift times change (previously only fetched once on page load).
- Fixed overnight date handling so the Open-Meteo API is queried for both days when a shift crosses midnight.

**Files:** `app/javascript/controllers/report_form_controller.js`

---

### 3. Photo Upload Size Limit Increased
**Commit:** `510862b` — fix: increase nginx client_max_body_size to 50M for photo uploads

- Added `client_max_body_size 50M;` to `nginx.conf`.
- Previously, the nginx default of 1MB caused silent 413 errors when submitting forms with phone photos (typically 3–8 MB each), resulting in attachments not being saved.

**Files:** `nginx.conf`

---

### 4. Word Template Fix
**Commit:** `d79d211` — word template fix

- Updated `app/assets/documents/inspection_template.docx` to resolve a formatting or merge-field issue in the generated inspection report.
- Added `inspection_template55.docx` as a reference/backup copy.

---

### 5. Spec Checklist Updates
**Commit:** `62a6c33` — updating spec checklist

- Added two new data migrations for checklist questions:
  - `20260319000000_update_checklist_questions_for_p603_p610_p219.rb` — P-603, P-610, and P-219 spec items.
  - `20260319000001_update_checklist_questions_for_p101_p151.rb` — P-101 and P-151 spec items.
- Added `docs/WIP_INSPECTOR_CHECKLISTS.md` documenting the in-progress checklist structure.

---

## Schema Changes

The following migrations were added (apply with `rails db:migrate`):

| Migration | Description |
|---|---|
| `20260319000000` | Checklist questions for P-603, P-610, P-219 |
| `20260319000001` | Checklist questions for P-101, P-151 |
| `20260319205410` | Add `first_name` / `last_name` to `users` |
| `20260319211518` | Add `project_id` to `phases` |
| `20260320000000` | Add `ai_stage` to `reports` |

---

## Other Notable Changes

- **User model** (`app/models/user.rb`): Added `first_name` and `last_name` fields; `inspector_name` and `inspector_initials` on reports now use real names instead of email addresses.
- **Phase model & controller** (`app/models/phase.rb`, `app/controllers/phases_controller.rb`): Phases are now scoped to a project via the new `project_id` foreign key.
- **Bid items** (`app/views/bid_items/_form.html.erb`, `app/views/bid_items/index.html.erb`): Minor UI improvements and form field additions.
- **Reports data view** (`app/views/reports/data_view.html.erb`): Expanded with additional fields and display improvements.
- **Project show page** (`app/views/projects/show.html.erb`): Added phase/bid item sections (~48 lines).
- **Delete report button** (`app/views/reports/show.html.erb`): Delete action now exposed in the UI.
- **Routes** (`config/routes.rb`): Minor route correction.
- **Seeds** (`db/seeds.rb`): Updated to reflect current project name and data structure.
- **Dev services script** (`bin/dev_services`): Updated service startup configuration.

---

## Deployment Notes

1. Run `rails db:migrate` — 5 new migrations.
2. Restart nginx after deploying to apply the `client_max_body_size` change.
3. No breaking API changes.
