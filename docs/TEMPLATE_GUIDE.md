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

**Remember:** The template is just a regular Word document. You can use all Word features (bold, tables, colors, etc.) - just insert the placeholder codes where you want data to appear!
