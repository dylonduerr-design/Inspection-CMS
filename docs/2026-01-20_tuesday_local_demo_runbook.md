# Tuesday Local Demo Runbook (2026-01-20)

This runbook is optimized for a local demo streamed in a meeting, run by you.

The demo narrative is:

1) Login → 2) Create a report fast → 3) Show data management + visualization → 4) Finish with Word export (hero moment)

---

## Demo Goals

- Show an end-to-end “happy path” in under ~15–20 minutes.
- Keep the demo low-risk: rely on known-good flows and preflight checks.
- Make the Word export feel like the payoff: progress bar → download → open DOCX.

---

## What We’re Demoing (Repo Reality)

- Auth: Devise email/password login (local).
- Reports: create/edit, workflow statuses (in-progress → review → revise → finalize).
- Data management: projects/phases/specs, report data capture (quantities, QA, equipment, crew, compliance, checklists).
- Visualization: Reports index includes a “Data Viewer” section (bid item progress rollups).
- CSV export: Reports index can export CSV.
- Word export (hero): async Sidekiq + Redis + ActionCable progress, rendered via Python `docxtpl`.

---

## Prioritized Backlog (Difficulty / Disruption / Bug Risk)

### By Tuesday (P0: must be rock-solid)

1) Golden path demo script + rehearsal
- Aim: smooth, repeatable flow that fits within the meeting slot.
- Risk control: avoids “wandering” into unfinished areas.

2) Demo dataset (realistic)
- Ensure at least one report has meaningful content (placed quantities, some notes, optional photos/captions if possible).
- Ensure at least one report can be finalized/authorized (for Data Viewer story).

3) Word export reliability preflight
- Redis + Sidekiq running, ActionCable progress visible.
- Python env has dependencies, template present, exports succeed end-to-end.

4) Fallback plan
- Have a pre-generated DOCX ready to open if export stalls.
- Have CSV export ready as a secondary “deliverable” hero.

### By Tuesday (P1: high leverage polish if time allows)

5) UI fixes only on demo path
- Ghost/doubled buttons, misalignment, dark mode login issues ONLY if they will be seen on Tuesday.
- Avoid broad UI rewrites.

6) Template hygiene (only if needed)
- If the template has been edited recently, re-test export immediately.
- Prefer “don’t touch the template” unless you must.

### After Tuesday (P2: explicitly defer)

7) Report form friction fixes
- Equipment table selectable before save, better handling of required fields + nested rows.

8) FAA spec library build (mostly manual)
- Use the SpecItem/checklist editor as the source of truth.
- Add process: who owns edits, how review/approval works.

9) Field limiters for templates
- Decide scope: checklist-input limits vs DOCX/template-linting.

10) Enhance CSV export
- More robust Excel-friendly templates and additional columns/row grains.

11) Enhance data visualization
- Additional rollups (trends, per-phase, per-inspector, QA failures), optionally a chart library.

12) Fix Word exporter “perfect tables”
- Start with docxtpl template governance + linting; consider XML manipulation only if docxtpl can’t meet needs.

13) Microsoft login cutover (replaces password auth)
- Highest disruption: tenant config, role mapping, provisioning, and dev workflow changes.

14) Implement Azure AI agent
- Best after identity + data boundaries are stable; build around structured report JSON and audited outputs.

---

## What NOT to Change Before Tuesday (“Freeze List”)

Avoid any work that could create unexpected demo regression:

- Don’t change authentication (no SSO work, no Devise refactors, no role model changes).
- Don’t change export plumbing (Sidekiq/Redis/ActionCable/export job wiring).
- Don’t upgrade Ruby/Rails/gems/Python deps right before the demo.
- Don’t run new migrations or restructure stored checklist answer formats.
- Don’t do broad UI redesign or navigation reshuffles.
- Don’t edit the Word template unless absolutely necessary; if you do, re-test export immediately.

---

## Preflight Checklist (Do 30–60 minutes before the meeting)

### Services

- Rails server runs
- DB is migrated/prepared
- Redis responds:
  - `redis-cli ping` → `PONG`
- Sidekiq is running
- (Optional) Keep a terminal tab open tailing Sidekiq logs

### Dataset

- Demo accounts work (Inspector + QC). Use two browser profiles to avoid logging out.
- At least one report contains:
  - placed quantities (so tables and Data Viewer are meaningful)
  - some narrative text (commentary/additional info)
  - optional: photos + captions (if you want a higher-fidelity export)
- Decide how you want Data Viewer to be non-empty:
  - Option A (recommended): finalize one report live during demo
  - Option B (lower risk): pre-finalize one report ahead of time

### Word Export Pipeline

- Python environment is usable (docxtpl installed)
- Template exists and is the one used by the app
- Run at least one export locally before the meeting and open the DOCX

### Fallbacks Prepared

- If export stalls: pivot to Data Viewer + CSV export, then come back to DOCX if it finishes.
- If export fails: open a pre-generated DOCX (prepared in advance).

---

## Tuesday Demo Flow (Local, Streamed)

Target: ~15–20 minutes total.

### 0:00–1:00 — Framing

- “We’ll start from login, create a report quickly, show how data rolls up, and finish by generating a Word report.”

### 1:00–2:00 — Login (Inspector)

- Go directly to login and sign in as Inspector.
- Goal: land on Reports dashboard as quickly as possible.

### 2:00–6:00 — Create a Report Fast (start here)

- Click New Report.
- Fill only what you must to get moving:
  - Project context (if not already selected)
  - Phase/Area
  - Start date (usually default)
- Add 1–2 placed quantities (enough to make Data Viewer and DOCX tables meaningful).
- Save and land on the report show page.

Narration cue:
- “Drafting is fast; we can capture minimal required data and iterate.”

### 6:00–8:30 — Show the Report Show Page (data capture breadth)

- Scroll through key sections quickly:
  - Compliance (call out the structure)
  - Quantities / QA / equipment tables (show it’s structured)
  - Any notes fields

Keep this tight; don’t get pulled into edge cases.

### 8:30–10:30 — Workflow Handoff (Inspector → QC)

- Submit report for QC review (or equivalent transition).

Narration cue:
- “QC gates what becomes ‘authorized’ and eligible for rollups/exports.”

### 10:30–12:30 — QC Finalize (two-browser-profile recommended)

- Switch to QC browser/profile.
- Find the submitted report in Review.
- Finalize/approve it.

Narration cue:
- “Finalized reports become ‘authorized’ inputs into project-level tracking and exports.”

### 12:30–15:00 — Loop Back to Data Management + Visualization

- Go to the Reports dashboard.
- Show the “Data Viewer” (bid item progress rollups).
- Explain what it’s doing (rollups from authorized/finalized reports).

Optional quick add:
- Show how filters change the dataset (project/status/date range).

### 15:00–16:30 — CSV Export (spreadsheet deliverable)

- Apply a filter (e.g., project or date range).
- Click Export CSV.

Narration cue:
- “This is the operational spreadsheet output for analysis and sharing.”

### 16:30–20:00 — Hero Moment: Word Export

- Go back to the finalized report show page.
- Click Export Word.
- Let the progress bar run (call out that it’s async background processing).
- Download the export and open the DOCX.

Narration cue:
- “This is generated as a real Word document with structured tables and photos.”

---

## Live Recovery Plan (If Something Goes Sideways)

- If Word export stalls:
  - Continue talking and pivot to Data Viewer + CSV export.
  - Say: “This is running in the background; we’ll return to the download once it finishes.”

- If Sidekiq/Redis is down:
  - Demo report creation + workflow + Data Viewer/CSV.
  - Explain: “Export uses background jobs; we can enable the worker after the session.”

- If Data Viewer looks empty:
  - Ensure you are scoped to the intended project.
  - Finalize one report live as QC (that’s the designed gate).

---

## Notes for After Tuesday (Roadmap Talking Points)

- SSO: Microsoft login replacing password auth is a large, planned cutover (role mapping + provisioning + dev workflow).
- AI: build around structured report JSON and governed retrieval (token efficiency, chunking, audit logs).
- Exporter: keep improving docxtpl workflow first; consider XML-level table rendering only if absolutely necessary.
