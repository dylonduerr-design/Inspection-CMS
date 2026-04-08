# Quick Template Guide for Designers

This guide helps non-developers edit the Word template for automated report generation.

## Basic Concept

The template is a regular Word document with special placeholder codes that get replaced with actual data when a report is exported.

## Simple Field Placeholders

Replace text with data using double curly braces:

```
{{ variable_name }}
```

### Available Fields

**Project Information:**
- `{{ project }}` - Project name
- `{{ contract_number }}` - Contract number
- `{{ project_manager }}` - PM name
- `{{ construction_manager }}` - CM name
- `{{ contractor }}` - Contractor name

**Report Details:**
- `{{ date }}` - Report date
- `{{ start_date }}` - Start date
- `{{ end_date }}` - End date
- `{{ day_x_of_y }}` - Contract day (e.g., "Day 45 of 120")
- `{{ inspector }}` - Inspector email/name
- `{{ reviewed_by }}` - Reviewer/approver (QC) email/name
- `{{ start_shift }}` - Shift start time
- `{{ end_shift }}` - Shift end time

**Weather:**
- `{{ temp }}` - Temperature (combined periods)
- `{{ weather }}` - Weather summary
- `{{ wind }}` - Wind conditions
- `{{ precip }}` - Precipitation
- `{{ vis }}` - Visibility
- `{{ surface }}` - Surface conditions
- `{{ notable_weather_events }}` - Notable weather events

**Compliance:**
- `{{ sec_status }}` - Security status
- `{{ tc_status }}` - Traffic control status
- `{{ air_ops }}` - Air operations coordination
- `{{ swppp }}` - SWPPP controls
- `{{ env_status }}` - Environmental status
- `{{ phase_status }}` - Phasing compliance
- `{{ saf_status }}` - Safety incident status
- `{{ saf_description }}` - Safety description
- `{{ def_status }}` - Deficiency status
- `{{ def_desc }}` - Deficiency description
- `{{ tc_note }}` - Traffic control note/incident detail
- `{{ env_note }}` - Environmental note/incident detail
- `{{ sec_note }}` - Security note/incident detail
- `{{ air_ops_note }}` - Air ops coordination note
- `{{ swppp_note }}` - SWPPP note/incident detail
- `{{ phase_note }}` - Phasing compliance note

**Notes:**
- `{{ commentary }}` - General commentary
- `{{ add_activity }}` - Additional activities
- `{{ add_info }}` - Additional information

**AI-Generated Fields:**
- `{{ ai_work_summary }}` - AI-generated work summary text
- `{{ ai_generated_commentary }}` - AI-generated commentary text

## Photos

Insert photos using special placeholders:

```
{{ photo_1 }}
{{ photo_2 }}
{{ photo_3 }}
{{ photo_4 }}
{{ photo_5 }}
{{ photo_6 }}
```

And their captions:

```
{{ caption_1 }}
{{ caption_2 }}
etc...
```

### Example Photo Section in Word:

```
┌────────────────────────────┐
│                            │
│      {{ photo_1 }}         │
│                            │
└────────────────────────────┘

Caption: {{ caption_1 }}
```

## Tables with Repeating Rows

For tables where rows repeat based on data (like quantities or equipment), you have two options:

### Option 1: Auto-Generate Rows (Dynamic)

Use loops to automatically create as many rows as there is data.

**Correct Table Structure:**
The loop tags must remain inside the **same row** as the data to avoid empty blank rows appearing between your items.

```
┌──────────┬─────────────────┬──────────┬────────────┐
│ Code     │ Description     │ Quantity │ Notes      │
├──────────┼─────────────────┼──────────┼────────────┤
│ {% for item in placed_quantities %} {{ item.code }} │ {{ item.desc }} │ {{ item.qty }} │ {{ item.notes }} {% endfor %} │
└──────────┴─────────────────┴──────────┴────────────┘
```

> **⚠️ CRITICAL WARNING:** Do not put `{% for ... %}` and `{% endfor %}` in separate rows above and below the data row. If you do, those rows will be repeated as blank spaces in your final report!

**Short tags (recommended for tables):**

```
│ {% for pq in pqs %} {{ pq.code }} │ {{ pq.desc }} │ {{ pq.qty }} │ {{ pq.notes }} {% endfor %} │
```

**Important:** 
- The loop goes in the first cell of the row
- Each variable gets its own cell
- Close the loop with `{% endfor %}`

### Option 2: Manual Fixed Rows (Static)

Manually create fixed rows and reference items by index (zero-based: 0, 1, 2, etc.):

```
┌──────────┬─────────────────┬──────────┬────────────┐
│ Code     │ Description     │ Quantity │ Notes      │
├──────────┼─────────────────┼──────────┼────────────┤
│ {{ pqs[0].code }} │ {{ pqs[0].desc }} │ {{ pqs[0].qty }} │ {{ pqs[0].notes }} │
├──────────┼─────────────────┼──────────┼────────────┤
│ {{ pqs[1].code }} │ {{ pqs[1].desc }} │ {{ pqs[1].qty }} │ {{ pqs[1].notes }} │
├──────────┼─────────────────┼──────────┼────────────┤
│ {{ pqs[2].code }} │ {{ pqs[2].desc }} │ {{ pqs[2].qty }} │ {{ pqs[2].notes }} │
└──────────┴─────────────────┴──────────┴────────────┘
```

**Pros of Manual Rows:**
- Complete control over table layout
- Can leave blank rows for spacing
- No need to understand loop syntax

**Cons of Manual Rows:**
- If a report has more items than rows, some data won't appear
- If a report has fewer items than rows, you'll get empty cells
- Must create enough rows to handle maximum expected items

### Placed Quantities Table

### Placed Quantities Table

**Loop (dynamic):**
```
│ {% for pq in pqs %} {{ pq.code }} │ {{ pq.desc }} │ {{ pq.qty }} │ {{ pq.notes }} {% endfor %} │
```

**Manual rows (static):**
```
Row 1: {{ pqs[0].code }} │ {{ pqs[0].desc }} │ {{ pqs[0].qty }} │ {{ pqs[0].notes }}
Row 2: {{ pqs[1].code }} │ {{ pqs[1].desc }} │ {{ pqs[1].qty }} │ {{ pqs[1].notes }}
Row 3: {{ pqs[2].code }} │ {{ pqs[2].desc }} │ {{ pqs[2].qty }} │ {{ pqs[2].notes }}
```

### QA Entries Table

**Loop (dynamic):**
```
│ {% for qa in qas %} {{ qa.code }} │ {{ qa.test }} │ {{ qa.location }} │ {{ qa.result }} │ {{ qa.remarks }} {% endfor %} │
```

**Manual rows (static):**
```
Row 1: {{ qas[0].code }} │ {{ qas[0].test }} │ {{ qas[0].location }} │ {{ qas[0].result }} │ {{ qas[0].remarks }}
Row 2: {{ qas[1].code }} │ {{ qas[1].test }} │ {{ qas[1].location }} │ {{ qas[1].result }} │ {{ qas[1].remarks }}
```

### Equipment Table

**Loop (dynamic):**
```
│ {% for eq in eqs %} {{ eq.contractor }} │ {{ eq.equipment }} │ {{ eq.qty }} │ {{ eq.hours }} │ {{ eq.remarks }} {% endfor %} │
```

**Manual rows (static):**
```
Row 1: {{ eqs[0].contractor }} │ {{ eqs[0].equipment }} │ {{ eqs[0].qty }} │ {{ eqs[0].hours }} │ {{ eqs[0].remarks }}
Row 2: {{ eqs[1].contractor }} │ {{ eqs[1].equipment }} │ {{ eqs[1].qty }} │ {{ eqs[1].hours }} │ {{ eqs[1].remarks }}
```

### Crew Table

**Loop (dynamic):**
```
│ {% for cr in crs %} {{ cr.contractor }} │ {{ cr.survey }} │ {{ cr.super }} │ {{ cr.foreman }} │ {{ cr.operator }} │ {{ cr.laborer }} │ {{ cr.electrician }} │ {{ cr.remarks }} {% endfor %} │
```

**Manual rows (static):**
```
Row 1: {{ crs[0].contractor }} │ {{ crs[0].survey }} │ {{ crs[0].super }} │ {{ crs[0].foreman }} │ {{ crs[0].operator }} │ {{ crs[0].laborer }} │ {{ crs[0].electrician }} │ {{ crs[0].remarks }}
Row 2: {{ crs[1].contractor }} │ {{ crs[1].survey }} │ {{ crs[1].super }} │ {{ crs[1].foreman }} │ {{ crs[1].operator }} │ {{ crs[1].laborer }} │ {{ crs[1].electrician }} │ {{ crs[1].remarks }}
```

### Core Sample Locations Table (Conditional)

This entire section only appears when a report has core locations linked. It is wrapped in a conditional block so reports without asphalt core data will have no trace of this section in the export.

**Conditional wrapper** (required — place on its own line before and after the section):
```
{% if has_core_locations %}
...your section header and table here...
{% endif %}
```

**Section header fields:**

| Tag | Description | Example |
|-----|-------------|---------|
| `{{ core_lot_number }}` | Lot number | "1" |
| `{{ core_mix_type }}` | Mix type | "P-401" |
| `{{ core_plant }}` | Plant name | "Santa Clara" |
| `{{ core_count }}` | Total core count | 8 |
| `{{ core_mat_count }}` | MAT core count | 4 |
| `{{ core_joint_count }}` | JOINT core count | 4 |

**Example header text:**
```
Core Sample Locations — Lot {{ core_lot_number }} ({{ core_mix_type }}, {{ core_plant }})
{{ core_count }} cores ({{ core_mat_count }} mat, {{ core_joint_count }} joint)
```

**Loop (dynamic):**
```
│ {% for core in cores %} {{ core.mark }} │ {{ core.core_type }} │ {{ core.sublot }} │ {{ core.lane }} │ {{ core.joint_lr }} │ {{ core.sublot_station_ft }} │ {{ core.lane_station_ft }} │ {{ core.offset_ft }} {% endfor %} │
```

**Manual rows (static):**
```
Row 1: {{ cores[0].mark }} │ {{ cores[0].core_type }} │ {{ cores[0].sublot }} │ {{ cores[0].lane }} │ {{ cores[0].joint_lr }} │ {{ cores[0].sublot_station_ft }} │ {{ cores[0].lane_station_ft }} │ {{ cores[0].offset_ft }}
Row 2: {{ cores[1].mark }} │ {{ cores[1].core_type }} │ {{ cores[1].sublot }} │ {{ cores[1].lane }} │ {{ cores[1].joint_lr }} │ {{ cores[1].sublot_station_ft }} │ {{ cores[1].lane_station_ft }} │ {{ cores[1].offset_ft }}
```

**Per-core fields:**

| Tag | Description | Example |
|-----|-------------|---------|
| `{{ core.mark }}` | Core mark identifier | "M 1-1" or "J 1-2" |
| `{{ core.core_type }}` | MAT or JOINT | "MAT" |
| `{{ core.sublot }}` | Sublot position | 1 |
| `{{ core.lane }}` | Lane position | 3 |
| `{{ core.joint_lr }}` | Joint lane pair (blank for MAT) | "1-2" |
| `{{ core.sublot_station_ft }}` | Station on total sublot footage | 352.5 |
| `{{ core.lane_station_ft }}` | Station within the specific lane | 152.5 |
| `{{ core.offset_ft }}` | Lateral offset from lane edge (MAT only) | 8.5 |
| `{{ core.lot_number }}` | Parent lot number | "1" |
| `{{ core.mix_type }}` | Parent lot mix type | "P-401" |
| `{{ core.plant }}` | Parent lot plant | "Santa Clara" |

**Complete example in the template:**
```
{% if has_core_locations %}
Core Sample Locations — Lot {{ core_lot_number }} ({{ core_mix_type }}, {{ core_plant }})
{{ core_count }} cores ({{ core_mat_count }} mat, {{ core_joint_count }} joint)

┌──────────┬──────┬────────┬──────┬───────┬───────────────────┬────────────────┬────────────┐
│ Mark     │ Type │ Sublot │ Lane │ Joint │ Sublot Sta. (ft)  │ Lane Sta. (ft) │ Offset (ft)│
├──────────┼──────┼────────┼──────┼───────┼───────────────────┼────────────────┼────────────┤
│ {% for core in cores %} {{ core.mark }} │ {{ core.core_type }} │ {{ core.sublot }} │ {{ core.lane }} │ {{ core.joint_lr }} │ {{ core.sublot_station_ft }} │ {{ core.lane_station_ft }} │ {{ core.offset_ft }} {% endfor %} │
└──────────┴──────┴────────┴──────┴───────┴───────────────────┴────────────────┴────────────┘
{% endif %}
```

> **Note:** The `{% if has_core_locations %}` / `{% endif %}` tags completely remove the section from the rendered document when no core locations exist. Reports without asphalt work will show no trace of this table.

---

## Conditional Sections

Show/hide content based on conditions:

```
{% if def_status != "N/A" %}
Deficiency Details:
{{ def_desc }}
{% endif %}
```

```
{% if saf_status == "Yes" %}
⚠️ Safety Incident Reported
Details: {{ saf_description }}
{% endif %}
```

## Common Mistakes to Avoid

❌ **Wrong:** `{{project}}` (no spaces)
✅ **Correct:** `{{ project }}`

❌ **Wrong:** `{% pq %}` or `{% for pq %}` (incomplete tag)
✅ **Correct:** `{% for pq in pqs %}` (must specify collection)

❌ **Wrong:** Forgetting `{% endfor %}`
✅ **Correct:** Always close loops

❌ **Wrong:** Loop in wrong table cell
✅ **Correct:** Loop must be in first cell of row

❌ **Wrong:** `{{ Photo_1 }}` (capital letters)
✅ **Correct:** `{{ photo_1 }}` (lowercase)

## How to Edit the Template

1. Open `inspection_template.docx` in Microsoft Word
2. Find existing placeholder text
3. Replace with appropriate placeholder code from this guide
4. For tables, ensure loop syntax is in first cell
5. Save the document
6. Test with sample data

## Testing Your Template

After editing, ask a developer to run (replace with a real report JSON export):

```bash
python3 python/export_report.py \
  --input /path/to/your_data.json \
  --template app/assets/documents/inspection_template.docx \
  --output test.docx
```

Then open `test.docx` to verify:
- ✅ All placeholders are replaced with data
- ✅ Photos appear correctly
- ✅ Tables have the right number of rows
- ✅ Formatting is preserved
- ✅ No `{{ }}` or `{% %}` codes remain visible

## Getting Help

If you see:
- Placeholders not replaced → Check spelling and case
- Table rows not repeating → Verify loop syntax
- Photos not appearing → Check placeholder matches `photo_1` through `photo_6`
- Formatting broken → Ensure codes are in text runs, not across formatting boundaries

## Quick Reference Card

```
SIMPLE FIELDS:         {{ field_name }}
PHOTOS:                {{ photo_1 }} through {{ photo_6 }}
CAPTIONS:              {{ caption_1 }} through {{ caption_6 }}

TABLE LOOP:            {% for item in collection %}
                       {{ item.field }}
                       {% endfor %}

CONDITIONALS:          {% if condition %}
                       content
                       {% endif %}
```

---

## FAA Weekly Report (Form 5370-1)

The FAA Weekly Report uses a separate template (`FAA_Weekly_Template.docx`) with its own set of fields. These tags map to the sections of FAA Form 5370-1.

### Header / Project Info

| Tag | Description | Example Value |
|-----|-------------|---------------|
| `{{ project_name }}` | Project name | "Runway 12-30 Rehabilitation" |
| `{{ contract_number }}` | Contract number | "DOT-FA25-001" |
| `{{ report_number }}` | Sequential weekly report number | "3" |
| `{{ period_start }}` | Reporting period start date | "08/18/2025" |
| `{{ period_end }}` | Reporting period end date ("Period Ending") | "08/22/2025" |
| `{{ contractor_name }}` | Prime contractor | "ABC Construction Inc." |

### Section 1 — Contract Time

| Tag | Description | Example Value |
|-----|-------------|---------------|
| `{{ contract_time }}` | Total contract calendar days | "200 Calendar Days" |
| `{{ days_charged }}` | Cumulative authorized working days to date | "56" |
| `{{ last_working_day }}` | Last working day charged (with day-of-week) | "Friday, 8/22/2025" |

### Section 2 — Weather Summary

| Tag | Description |
|-----|-------------|
| `{{ weather_summary }}` | AI-generated narrative weather summary for the period. Includes temperature highs/lows, wind averages, precipitation totals, and soil conditions. |

### Section 3 — Completion Percentages

Section 3 uses a **loop** over bid item categories (grouped by `spec_item.division`).

| Tag | Description |
|-----|-------------|
| `{{ overall_completion_pct }}` | Overall project completion percentage (e.g., "5%") |
| `{% for cat in categories %}` | Begin loop over bid item categories |
| `{{ cat.name }}` | Category name (e.g., "Storm Drainage") |
| `{{ cat.percent }}` | Category completion percentage (e.g., "0%") |
| `{% endfor %}` | End category loop |

**Example in template:**
```
Estimated percent completion is {{ overall_completion_pct }}.
{% for cat in categories %}
• {{ cat.name }}: {{ cat.percent }}
{% endfor %}
```

### Section 4 — Work Completed or In Progress

| Tag | Description |
|-----|-------------|
| `{{ work_summary }}` | AI-generated narrative of work completed or in progress this period, organized by category (e.g., Mobilization, Asphalt Pavement, Airfield Electrical). Editable before export. |

### Section 5a — Summary of Lab/Field Testing

| Tag | Description |
|-----|-------------|
| `{{ lab_testing_summary }}` | AI-generated summary of laboratory and field testing this period. Notes failing tests, retests, and out-of-tolerance results. Editable before export. |

### Section 5b — Materials (Subject to Pay Reduction)

| Tag | Description |
|-----|-------------|
| `{{ materials_summary }}` | AI-generated summary of materials subject to pay reduction. Identifies items that failed acceptance criteria. Editable before export. |

### Section 7 — Problem Areas / Other Comments

| Tag | Description |
|-----|-------------|
| `{{ problem_areas }}` | AI-generated combined field covering bulletin issuance, plan revisions, delays, difficulties, and other notable comments. Editable before export. |

### Section Not Yet Implemented

| Section | Tag | Status |
|---------|-----|--------|
| 6 — Anticipated Work | *No tags yet* | Deferred to future release |

### Example Section 3 Table Layout

```
┌────────────────────────────────────────────────────────────────────────┐
│ 3. Rough Estimate of Percent Completion to Date                       │
├────────────────────────────────────────────────────────────────────────┤
│ Estimated percent completion is {{ overall_completion_pct }}.         │
│                                                                       │
│ {% for cat in categories %}                                           │
│ • {{ cat.name }}: {{ cat.percent }}                                   │
│ {% endfor %}                                                          │
└────────────────────────────────────────────────────────────────────────┘
```

### Testing Your FAA Weekly Template

```bash
python3 python/export_report.py \
  --input /path/to/weekly_data.json \
  --template app/assets/documents/FAA_Weekly_Template.docx \
  --output test_weekly.docx
```

---

**Remember:** The template is just a regular Word document. You can use all Word features (bold, tables, colors, etc.) - just insert the placeholder codes where you want data to appear!
