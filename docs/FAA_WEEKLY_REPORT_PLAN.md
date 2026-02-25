# FAA Weekly Report Implementation Plan

This document outlines the step-by-step plan to implement the FAA Weekly Report (FAA Form 5370-1) system, which aggregates authorized daily reports, summarizes work using AI, and exports to a structured DOCX template.

> **Reference:** FAA Form 5370-1 (2/24) — Construction Progress & Inspection Report

## FAA Form 5370-1 Sections

| Section | Title | Data Source |
|---------|-------|-------------|
| 1 | Contract Time / Days Charged / Last Working Day | Computed from project + authorized reports |
| 2 | Brief Weather Summary this Period | AI-generated from aggregated weather data |
| 3 | Rough Estimate of Percent Completion to Date | Category completion from `spec_item.division` groups |
| 4 | Work Completed or In Progress this Period | AI-generated from daily report commentary |
| 5a | Summary of Laboratory and Field Testing | AI-generated from `QaEntry` data |
| 5b | Material (subject to pay reduction) | AI-generated from failed/OOT QA results |
| 6 | Description of Anticipated Work (Next Period) | *Deferred — not in current scope* |
| 7 | Problem Areas / Other Comments | AI-generated from deficiencies + issues |

---

## Step 1: `WeeklyReport` Model

Create a new model to store the metadata and generated summaries for the weekly period.

*   **Model Name:** `WeeklyReport`
*   **Associations:**
    *   `belongs_to :project`
    *   `belongs_to :user` (the creator of the weekly report)
*   **Fields:**
    *   `start_date` (date): The start of the reporting period.
    *   `end_date` (date): The end of the reporting period ("Period Ending" date).
    *   `report_number` (integer): Sequential weekly report number per project.
    *   `status` (integer/enum): `draft` (0), `generated` (1), `finalized` (2).
    *   `weather_summary` (text): Section 2 — AI-generated weather narrative for the period.
    *   `weather_data_json` (jsonb): Computed weather stats (high/low temp, avg wind, precip totals) used as AI input.
    *   `completion_data_json` (jsonb): Cached category completion breakdown for Section 3, from `spec_item.division` groups.
    *   `work_summary` (text): Section 4 — AI-generated narrative of work completed/in progress, grouped by category.
    *   `lab_testing_summary` (text): Section 5a — AI-generated from `QaEntry` data, editable.
    *   `materials_summary` (text): Section 5b — AI-generated from failed/out-of-tolerance QA results, editable.
    *   `problem_areas` (text): Section 7 — AI-generated combined field (bulletin issuance + other issues).
    *   `ai_status` (string): Tracks AI generation state (`idle`, `queued`, `running`, `success`, `failed`).
    *   `ai_error` (text): Stores AI generation error message if failed.

## Step 2: Aggregation Service (`WeeklyReportService`)

Develop a service class responsible for querying daily `Report` records and computing the data for each section.

*   **Scope:** Query all `Report` records for the `Project` within the `start_date` and `end_date` range where `authorized_by_id IS NOT NULL` (Authorized Reports).
*   **Computations:**

    ### Section 1 — Contract Time (computed at export time, not stored)
    *   `contract_time`: From `project.contract_days`.
    *   `days_charged`: Count of **distinct** `start_date` values across ALL authorized reports for the project from `project.contract_start_date` through `weekly_report.end_date` (cumulative).
    *   `last_working_day`: The latest `start_date` among authorized reports within the weekly period.

    ### Section 2 — Weather
    *   Aggregate `temp_1/2/3`, `wind_1/2/3`, `precip_1/2/3` from authorized reports in the period.
    *   Compute: high temp, low temp, average wind, total precipitation.
    *   Concatenate `notable_weather_events`.
    *   Store computed stats in `weather_data_json` → feed to AI → store narrative in `weather_summary`.

    ### Section 3 — Completion % (by Category)
    *   Replicates the **data view** logic from `ReportsController#build_data_view`.
    *   Group `BidItem` records by `spec_item.division` (the category).
    *   For each category: `percent = (placed_quantities.sum(:quantity) / bid_item.bid_quantity.sum) * 100`.
    *   Uses `PlacedQuantity` from **finalized** reports (`status: :finalize`).
    *   Compute overall project completion percentage.
    *   Store the full breakdown in `completion_data_json`.

    ### Section 4 — Work Summary
    *   Concatenate `commentary`, `ai_work_summary`, `additional_activities` from authorized reports in the period.
    *   Feed to AI with instruction to group by `spec_item.division` category names → store in `work_summary`.

    ### Section 5a — Lab/Field Testing
    *   Query `QaEntry` records from authorized reports in the period.
    *   Feed test type, result, location, and remarks to AI → store in `lab_testing_summary`.

    ### Section 5b — Materials
    *   Derive from `QaEntry` records with `result: :qa_fail` or out-of-tolerance results.
    *   Feed to AI → store in `materials_summary`.

    ### Section 7 — Problem Areas
    *   Concatenate `deficiency_desc` from reports where `deficiency_status != :no_deficiency`.
    *   Include safety incidents, notable weather issues.
    *   Feed to AI → store in `problem_areas`.

## Step 3: AI Summarization

Implement a job to synthesize all narrative sections.

*   **Job:** `WeeklyReportAiGenerateJob`
*   **Generates 5 narrative fields:**
    1.  `weather_summary` — From computed weather stats in `weather_data_json`.
    2.  `work_summary` — From daily report commentary, grouped by `spec_item.division` categories.
    3.  `lab_testing_summary` — From `QaEntry` data (type, result, location, remarks).
    4.  `materials_summary` — From failed/out-of-tolerance QA results.
    5.  `problem_areas` — From deficiencies, safety incidents, and notable issues.
*   **All fields are editable** by the user before export.

## Step 4: Export Infrastructure

Enhance the existing export system to handle the new report type.

*   **Template:** Create `FAA_Weekly_Template.docx` in `app/assets/documents/` with Jinja2 tags matching the defined tag list (see `docs/TEMPLATE_GUIDE.md` — FAA Weekly section).
*   **Ruby Exporter:** Create `WeeklyReportExporter` service following the `PythonDocxExporter` pattern — builds JSON payload from the `WeeklyReport` model.
*   **Python Script:** Reuse existing `python/export_report.py` — it already accepts arbitrary Jinja2 context. No Python changes needed.

## Step 5: User Interface

*   **Tab:** "Weekly Reports" tab already stubbed in `reports/index.html.erb`.
*   **List view:** Show existing weekly reports for the selected project with status badges.
*   **New form:** Select project and period ending date to create a `WeeklyReport`.
*   **Show/Edit view:** Display all sections with editable text areas for AI-generated content. "Generate" button triggers AI. "Export" button generates DOCX.
*   **Section 3:** Read-only display of category completion percentages from `completion_data_json`.

---

## Key Decisions

| Decision | Choice |
|----------|--------|
| Section 3 display | Category name + percentage only (no bid item codes) |
| Section 7 structure | Single combined `problem_areas` field |
| Sections 5a/5b | AI-generated from QA entry data, editable before export |
| Days Charged | Cumulative from project start (all authorized report dates) |
| Section 6 | Deferred — field removed from model |
| Category source | `spec_item.division` (matches data view) |
| Quantity model | `PlacedQuantity` (not `PlacementLog`) |
| Phasing | Ignored for now (no phase filtering in completion) |
