# Asphalt Core Locator Integration

Integration of the standalone Asphalt Core Locator application into the Inspector Daily Reports (IDR) system. Inspectors can now generate ASTM D3665-compliant random core sample locations within their daily workflow and include that data in report exports.

## Architecture

Core data lives at the **Project** level, not the Report level. A paving lot spans multiple days, so multiple reports may reference the same lot's core generation.

```
Project
  └── AsphaltLot (was standalone Lot)
        ├── AsphaltSublot → AsphaltLane (geometry)
        └── CoreGeneration → CoreLocation (generated samples)
                └── linked to Reports through ReportCoreGeneration join records
```

Core locations are a **separate section** in reports — not embedded in QaEntry. Core data has a fundamentally different shape (sublot, lane, station, offset, mark, core_type) vs. QaEntry's simple (type, location, pass/fail).

---

## Database Tables (7 new)

| Table | Purpose |
|---|---|
| `astm_random_numbers` | ASTM D3665 random number lookup table (row, column, value). 2000 entries seeded from CSV. |
| `asphalt_lots` | Paving lots scoped to a project. Unique on `[project_id, lot_number]`. |
| `asphalt_sublots` | Subdivisions within a lot. Supports `locked_for_core_generation` flag. |
| `asphalt_lanes` | Individual lanes within a sublot, with `length_ft` and `width_ft`. |
| `core_generations` | A generation run with parameters (seed, buffers, cores per sublot). |
| `core_locations` | Individual core sample points with station, offset, mark, and core_type (mat/joint). |
| `report_core_generations` | Join table linking reports to one or more reusable core generations. |

Migrations: `db/migrate/20260406000001` through `20260406000007`.

## Models (7 new, 2 updated)

**New models:**
- `AstmRandomNumber` — simple lookup record
- `AsphaltLot` — `belongs_to :project`, constants for PLANTS and MIX_TYPES
- `AsphaltSublot` — `belongs_to :asphalt_lot`, lock flag for preserving generated locations
- `AsphaltLane` — `belongs_to :asphalt_sublot`, length/width geometry
- `CoreGeneration` — `belongs_to :asphalt_lot`, auto-generates seed
- `CoreLocation` — `belongs_to :core_generation`, enum `core_type: { mat: 0, joint: 1 }`
- `ReportCoreGeneration` — join model (`belongs_to :report`, `belongs_to :core_generation`)

**Updated models:**
- `Project` — added `has_many :asphalt_lots, dependent: :destroy`
- `Report` — added `has_many :core_generations, through: :report_core_generations`

## Services (2 new)

### CoreGenerator (`app/services/core_generator.rb`)
Ported from the source app with all model references renamed to `Asphalt*`. Uses the ASTM D3665 random number table for deterministic, auditable core location selection:
- Configurable mat core count per sublot (lane selected by length-weighted random)
- Configurable joint core count per adjacent lane pair (station randomized, offset at lane boundary)
- Respects locked sublots and supports partial regeneration (single-sublot re-roll)

### CoreLocationXlsxExporter (`app/services/core_location_xlsx_exporter.rb`)
Styled Excel export with:
- MAT rows: `#CCFFFF` background
- JOINT rows: `#FFFFCC` background
- Distance columns: `#BFBFBF` (grey)
- Frozen header row, 20 blank rows for field notes

## Controllers (4 new)

| Controller | Actions |
|---|---|
| `AsphaltLotsController` | CRUD + `core_generations_json` (AJAX endpoint for Stimulus) |
| `AsphaltSublotsController` | create, update, destroy, `toggle_core_lock` |
| `CoreGenerationsController` | new, create, show, `create_for_sublot`, `export_csv`, `export_xlsx` |
| `BulkSetupsController` | new, create (batch sublot/lane creation) |

## Routes

All nested under `resources :projects`:

```ruby
resources :asphalt_lots do
  member { get :core_generations_json }
  resource :bulk_setup, only: [:new, :create]
  resources :asphalt_sublots, only: [:create, :update, :destroy] do
    member { patch :toggle_core_lock }
  end
  resources :core_generations, only: [:new, :create, :show] do
    member do
      get :export_csv
      get :export_xlsx
    end
    collection { post :create_for_sublot }
  end
end
```

## Views (8 new files)

- `asphalt_lots/` — index, show, new, edit, _form (IDR CSS classes, not Tailwind)
- `core_generations/` — new (generation params form), show (results table with sort toggle)
- `bulk_setups/new` — batch sublot/lane setup with bulk-fill and dynamic lane add/remove

## Report Integration

### Report Form (`_form.html.erb`)
New "Core Sample Locations" sub-section in Section 4 (QA & Quantities):
- Dropdown to select an existing AsphaltLot from the project
- Dropdown to select a core generation for that lot (populated via Stimulus AJAX)
- Read-only preview table of core locations (mark, type, sublot, lane, station, offset)
- Hidden fields with `core_generation_ids[]` to link generation to report on save
- Link to "Manage Asphalt Lots" (opens in new tab)

### Report Show (`show.html.erb`)
"Core Sample Locations" section displayed below QA entries when linked core data exists. Shows lot info, seed, and a full table of core locations.

### Stimulus Controller (`core_generation_selector_controller.js`)
Handles lot selection → fetches available generations via AJAX → renders preview table → manages hidden field for `core_generation_ids`.

### Report Params
`core_generation_ids: []` added to `report_params` in `ReportsController`.

## Word Export

### Ruby (`python_docx_exporter.rb`)
`core_locations` array added to the export payload after `crew_entries`. Each entry contains: mark, core_type, sublot, lane, lot_dist_ft, station_ft, offset_ft, lot_number, mix_type.

### Python (`export_report.py`)
`core_locations` added to the context dict, padded with empty dicts (same pattern as other table data). Available as `core_locations` or `cores` alias in the template.

### Word Template (manual step required)
The template file (`app/assets/documents/inspection_template.docx`) must be manually edited in Word to add a "Core Sample Locations" table with Jinja2 row iteration:

```
{% for core in core_locations %}
  {{ core.mark }} | {{ core.core_type }} | {{ core.sublot }} | {{ core.lane }} | {{ core.lot_dist_ft }} | {{ core.station_ft }} | {{ core.offset_ft }}
{% endfor %}
```

## Seed Data

- CSV: `db/astm_d3665_random_numbers.csv` (100 rows x 20 columns = 2000 values)
- Rake task: `rake astm:load_random_numbers` (idempotent, uses `find_or_create_by!`)
- Must be run post-deploy in production

## Gemfile

Added `gem "caxlsx", "~> 4.0"` for styled XLSX export.

## Navigation

"Asphalt Lots" button added to the Project show page header alongside "Edit Project", "Manage Library", etc.

## Key Differences from Source App

| Aspect | Source (standalone) | IDR (integrated) |
|---|---|---|
| Lot scoping | Global, unique on `[plant, mix_type, lot_number]` | Per-project, unique on `[project_id, lot_number]` |
| Styling | Tailwind CSS utilities | IDR custom classes (`form-card`, `nested-entry-card`, etc.) |
| Report linking | N/A | Join table (`report_core_generations`) |
| Haul logs | Included | Not ported (separate concern) |
| OCR scanning | Included | Not ported |
| PWA / offline | Included | Not ported |
| Random source | ASTM table (primary), Ruby Random (alternative) | ASTM table only (CoreGenerationRunner not ported) |
