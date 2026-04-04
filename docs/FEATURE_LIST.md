# Feature List

This document lists the user-facing features of Inspection CMS (what an end user can see and do in the product).

## Authentication & roles
- Sign in/out (Devise-based authentication).
- Role-based experiences:
  - Inspector workflows (create/edit their own reports).
  - QC workflows (review/approve reports).

## Reports (IDRs)
- Reports dashboard with tabs/filters.
- Create a new report.
- Edit an existing report (when in an editable status).
- View a report in a read-friendly “show” layout.
- Delete a report.

## Report workflow (statuses)
- In-progress: report is being drafted.
- Submit for QC: send a report to review.
- Review: QC can review and either approve or request revision.
- Request revision: send report back for edits with a required note.
- Revise: inspector can modify a returned report.
- Approve/finalize: QC finalizes a report.

## Report form sections
- General info
  - Project selection/association.
  - Phase / Area selection.
  - Contractor / Prime Contractor fields.
  - Start/end date, shift start/end.
  - Contract day display (when project contract dates are present).
- Weather
  - Three time-slices (start/mid/end) with temperature, condition summary, wind, precipitation, and visibility.
  - “Auto-Fill” weather using the user’s geolocation and a public weather API.
  - Surface/site conditions text field.
- Compliance & site conditions
  - Deficiencies / NCR / CDR selection.
  - Conditional deficiency description field.
  - Safety incident selection.
  - Conditional safety description field.
  - Site compliance radios (traffic control, environmental, security, air ops coordination, SWPPP controls, phasing compliance) with conditional notes when non-compliant.
- Workforce log
  - Add/remove dynamic crew rows.
  - Per-row counts (superintendent, foreman, survey, operator, laborer, electrician) and notes.
- Equipment log
  - Add/remove dynamic equipment rows.
  - Per-row make/model, hours, quantity, contractor.
- QA log
  - Add/remove QA entries.
  - QA type, location, result, and remarks.
- Placed quantities (bid items)
  - Add/remove placed quantity rows.
  - Select bid item from the project’s bid item library.
  - Quantity, location, and notes per placed item.
  - Per-bid-item “Open Checklist” to answer inspection questions for that placed quantity.
- Narrative
  - General commentary.
  - Optional “Additional Activities” section.
  - Optional “Additional Information” section.
- Photos & attachments
  - Upload photos/documents.
  - Add captions.
  - Mark attachments for deletion.

## Checklists
### Spec compliance checklists (report-level)
- Add one or more spec-level checklists to a report.
- Navigate by spec division, then pick a spec.
- Answer spec checklist questions (supports multiple field types).
- Edit an existing spec checklist’s answers.

### Bid item checklists (quantity-level)
- Each placed quantity can have its own checklist.
- Checklist questions are tied to the selected bid item.
- Supports multiple question/field types (e.g., radio, checkbox, text, number, textarea).

### Checklist authoring (library)
- Spec Checklist Editor (Projects Directory tab)
  - Browse specs.
  - Filter by division.
  - Search specs.
  - Add/edit/duplicate/remove questions.
  - Configure question settings (prompt, required, type, options, placeholder, default value, helper text, validation).
  - Save changes to publish spec checklist updates.
- Bid item checklist overrides
  - Bid items can inherit checklist questions from their spec.
  - Bid items can also have their own checklist override (so a specific item can differ from the spec default).

## Projects Directory
- View all projects.
- Create a project.
- Edit a project.
- View a project.
- Manage a project’s bid item library.
- Delete a project with a typed confirmation step.

## Bid items (per project)
- View a project’s bid items.
- Create/edit/delete bid items.
- Each bid item has:
  - Code, description, unit, bid quantity.
  - Associated spec item.
  - Checklist questions (inherited or overridden).

## Exports
- Export a report to Word (.docx).
- Async export experience:
  - Start an export.
  - See progress updates.
  - Download when complete.

## Import
- Import a previously exported Word (.docx) report back into the system.
- Creates an `ImportedReport` record linked to the importing user.

## Data views & downloads
- Master log export to CSV from the reports list.
- Reports data tab for quantity/progress rollups (project-level perspective).

## UI / UX
- Tabbed navigation in the Projects Directory (Projects vs Spec Checklist Editor).
- Dynamic add/remove row UX for repeated sections (crew/equipment/QA/quantities).
- Inline status badges and helpful empty states.
- Light/dark theme toggle.
- Floating debug panel (“Detective”) showing current controller/action and params.

## Back-end
- These are implementation details that support features, but aren’t typically “noticed” directly by users.
- Uses Ruby on Rails for the web app, with server-rendered views enhanced by Hotwire (Turbo/Stimulus).
- Stores checklist schemas and answers as structured JSON (so checklists can evolve without schema migrations).
- Uses background jobs + real-time progress updates for long-running exports.
- Uses Active Storage for uploads (photos/attachments).
- Uses a Python-based DOCX export pipeline under the hood.
