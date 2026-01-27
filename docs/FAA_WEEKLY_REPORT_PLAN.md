# FAA Weekly Report Implementation Plan

This document outlines the step-by-step plan to implement the FAA Weekly Report system, which aggregates authorized daily reports, summarizes work using AI, and exports to a specific FAA text-based template.

## Step 1: `WeeklyReport` Model
Create a new model to store the metadata and generated summaries for the weekly period.

*   **Model Name:** `WeeklyReport`
*   **Associations:**
    *   `belongs_to :project`
    *   `belongs_to :user` (the creator of the weekly report)
*   **Fields:**
    *   `start_date` (date): The Monday (or start) of the reporting week.
    *   `end_date` (date): The Sunday (or end) of the reporting week.
    *   `status` (integer/enum): e.g., `draft`, `generated`, `finalized`.
    *   `work_summary` (text): AI-generated summary of work "Completed or In Progress".
    *   `anticipated_work` (text): Description of upcoming work (see Step 2).
    *   `deficiencies_summary` (text): Aggregated comments on problem areas.
    *   `weather_summary_json` (json): Store calculated min/max/avg payload.
    *   `lab_summary_json` (json): Store list of QA tests performed.

## Step 2: Aggregation Service (`WeeklyReportService`)
Develop a service class responsible for querying daily `Report` records and calculating the required fields.

*   **Scope:** Query all `Report` records for the `Project` within the `start_date` and `end_date` range that have `authorized_by_id` present (Authorized Reports).
*   **Calculations:**
    1.  **Days Charged:** Calculate the count of *unique* dates where at least one authorized report exists for the project (to handle multiple inspectors on the same day).
    2.  **Last Working Day:** Identify the most recent date within the period where work was performed.
    3.  **Completion %:**
        *   numerator: Sum of all `PlacementLog` quantities to date.
        *   denominator: Sum of all `BidItem` quantities.
    4.  **Weather:**
        *   Temperature: Min/Max/Average of `temp_1`, `temp_2`, `temp_3`.
        *   Wind: Average of `wind_1`, `wind_2`, `wind_3`.
        *   Precipitation: Sum of `precip_1`, `precip_2`, `precip_3`.
        *   Events: Concatenate `notable_weather_events`.
    5.  **Anticipated Work:** Integrate and utilize auto_calendar application.

## Step 3: AI Summarization
Implement a job to synthesize the narrative sections of the report.

*   **Job:** `WeeklyReportAiGenerateJob`
*   **Input:** Concatenate the "Work Performed" / "Commentary" sections from all authorized daily reports in the week.
*   **Prompt Strategy:** Instruct the AI to:
    *   Summarize work completed by category.
    *   Identify distinct problem areas or deficiencies.
*   **Output:** Populate `work_summary` and `deficiencies_summary` on the `WeeklyReport` record.

## Step 4: Export Infrastructure
Enhance the existing export system to handle the new report type.

*   **Template:** Create `FAA_Weekly_Template.docx` with Jinja2 tags matching the field requirements (e.g., `{{ period_ending }}`, `{{ days_charged }}`, `{{ weather_summary }}`).
*   **Ruby Exporter:** Update `PythonDocxExporter` (or create `WeeklyReportExporter`) to build the JSON payload from the `WeeklyReport` model.
*   **Python Script:** Ensure `python/export_report.py` accepts the payload structure.

## Step 5: User Interface
*   Add a "Weekly Reports" tab to the Report Dashboard.
*   Create a form to initialize a `WeeklyReport` by selecting the Week Ending date.
*   Provide an editor view to review/modify the AI-generated summaries before exporting.
