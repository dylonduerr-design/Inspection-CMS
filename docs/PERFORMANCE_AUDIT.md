# Performance Audit Report

**Date:** April 6, 2026
**Scope:** Full-stack analysis of the Inspection CMS application

> Known slowdowns (Word doc export, AI summaries) are excluded from recommendations since they are already identified. This report focuses on **other** bottlenecks and optimization opportunities.

---

## Critical Issues

### 1. Full SpecItem Collection Embedded in Every Report Form

**File:** `app/views/reports/_spec_check_card.html.erb:56`

```erb
SpecItem.all.select(:id, :code, :description, :division, :checklist_questions).to_json
```

Every time a report form loads, the **entire** SpecItem table is serialized to JSON and embedded inline in the HTML. With hundreds of spec items, this adds significant page weight and blocks rendering.

**Fix:** Fetch via a cacheable JSON endpoint with ETags instead of embedding inline. Cache the result in `Rails.cache` with a key that busts when spec items change.

---

### 2. N+1 Queries in CSV Export

**File:** `app/controllers/reports_controller.rb`

The reports index loads with `.includes(:user, :project, :phase, :placed_quantities)` but the CSV export iterates through `placed_quantities` and accesses `entry.bid_item.code`, `entry.bid_item.description`, etc. — each triggering a separate query.

**Fix:** Change includes to: `.includes(:user, :project, :phase, placed_quantities: :bid_item)`

---

### 3. N+1 Queries in Data View

**File:** `app/controllers/reports_controller.rb` (build_data_view method)

`bid_items_scope.find_each` loops through bid items and calls `bid_item.spec_item.division` on each — triggering a query per bid item.

**Fix:** Add `.includes(:spec_item)` to the bid_items_scope query.

---

### 4. No View or Fragment Caching Anywhere

Zero `cache` directives exist across all view templates. Every page render recalculates and re-renders all data from scratch, even for data that rarely changes (project details, bid item lists, spec items).

**Fix:** Add Russian doll caching to expensive partials — especially report show sections, bid item tables, and project overview tabs. The models already use `touch: true` on associations which supports cache invalidation.

---

## High-Priority Issues

### 5. Phases Tab N+1 on Report Counts

**File:** `app/views/projects/_phases_tab.html.erb:23`

```erb
phase.reports.size
```

Inside a loop over phases, `.reports.size` fires a COUNT query per phase. Phases are not eager-loaded with reports in the controller.

**Fix:** In `ProjectsController#show`, load phases with: `@project.phases.left_joins(:reports).select('phases.*, COUNT(reports.id) AS reports_count').group('phases.id')` or simply `.includes(:reports)`.

---

### 6. Core Generations JSON Endpoint N+1

**File:** `app/controllers/asphalt_lots_controller.rb` (core_generations_json)

Each generation's `.core_locations.includes(...)` runs inside a `.map`, meaning the includes aren't batched.

**Fix:** Use a single chained query:
```ruby
@asphalt_lot.core_generations
  .includes(core_locations: [:asphalt_sublot, :asphalt_lane])
  .order(created_at: :desc)
```

---

### 7. Report Show Page Renders Everything At Once (527 lines)

**File:** `app/views/reports/show.html.erb`

A single report show page renders ALL checklist entries, QA entries, core locations, crew entries, equipment entries, placed quantities, and attachments — potentially hundreds of DOM nodes with no lazy loading or pagination.

**Fix:** Wrap each section in a `<turbo-frame>` with `loading="lazy"` and `src=` pointing to a section-specific endpoint. This way the page loads instantly and sections fill in as the user scrolls.

---

### 8. Report Form is a 754-line Monolith

**File:** `app/views/reports/_form.html.erb`

The entire report form (crew, equipment, quantities, photos, checklists, weather) is one massive partial. The server must parse and render all 754 lines on every form load.

**Impact:** Slower Time-to-First-Byte on form pages, and harder to add fragment caching to individual sections.

---

### 9. ImageCompressor Uses Inefficient Linear Quality Search

**File:** `app/services/image_compressor.rb:40-53`

The service reduces JPEG quality by 5% per iteration in a loop, re-encoding the entire image each time. A large photo might require 5-10 full re-encodes to hit the target size.

**Fix:** Use a binary search on quality (e.g., start at 50%, check size, bisect up or down). This cuts iterations from ~10 to ~4.

---

### 10. ImageUrlCache Makes O(n) Redis Calls for Stats

**File:** `app/services/image_url_cache.rb:111`

```ruby
attachment_ids.count { |id| cached?(id) }
```

Checks each attachment ID individually against Redis. With 100 attachments, that's 100 round-trips.

**Fix:** Use `Rails.cache.read_multi(*keys)` for a single Redis MGET operation.

---

## Medium-Priority Issues

### 11. No Production Cache Store Configured

**File:** `config/environments/production.rb`

The cache store configuration is commented out. Rails defaults to in-process memory cache, which doesn't share across Puma workers and is ineffective.

**Fix:** Uncomment and configure `config.cache_store = :redis_cache_store` (Redis is already available for Sidekiq).

---

### 12. Missing Composite Database Indexes

**File:** `db/schema.rb`

Several common query patterns lack optimized indexes:

| Table | Missing Index | Used By |
|-------|--------------|---------|
| `reports` | `(project_id, status, start_date)` | Index page filtering + sorting |
| `reports` | `(user_id, status)` | User-scoped report lists |
| `placed_quantities` | `(report_id, bid_item_id)` | Data view aggregation |
| `core_locations` | `(core_generation_id, asphalt_sublot_id)` | Core location filtering |

---

### 13. Equipment Dropdown Plucked Per Entry Template

**File:** `app/views/reports/_form_templates.html.erb:86-92`

```erb
approved_equipment_list.pluck(:name).each do |name|
```

This pluck runs inside a template that's rendered for each equipment entry row. With 50 equipment entries, the pluck fires 50 times.

**Fix:** Cache the equipment list in a local variable or controller instance variable.

---

### 14. PythonDocxExporter Loads All Attachments Then Filters in Memory

**File:** `app/services/python_docx_exporter.rb:216-218`

```ruby
.select { |a| image_attachment?(a) }
```

Loads all report attachments into memory, then filters for images. Should filter at the query level.

**Fix:** Use a scope: `report.report_attachments.where(slot: image_slots)` or similar.

---

### 15. Heavy Spec Drilldown Controller Generates HTML Client-Side

**File:** `app/javascript/controllers/spec_drilldown_controller.js` (643 lines)

Builds large HTML strings by concatenating 100+ form fields with JavaScript (lines 176-241). With 50+ questions, this becomes noticeably slow.

**Fix:** Use server-rendered Turbo Stream responses instead of client-side HTML string building.

---

### 16. No Debounce on Equipment Picker Checkboxes

**File:** `app/javascript/controllers/equipment_picker_controller.js`

Each checkbox click triggers `updateSelection()` immediately. Rapid clicking can cause multiple DOM updates.

**Fix:** Add a short debounce (100-200ms) to the selection handler.

---

## Low-Priority / Quick Wins

### 17. Report.count on Every Page Load

**File:** `app/views/layouts/application.html.erb` (detective window)

The layout includes debug code that calls `Report.count` on every request. Should be removed or gated behind a dev-only flag.

---

### 18. Unbounded Report.all in Copy Candidates

**File:** `app/controllers/reports_controller.rb` (copy_source_scope)

```ruby
def copy_source_scope
  Report.all
end
```

Returns all reports without limit. Should scope to the current project or add a reasonable limit.

---

### 19. Missing Performance Monitoring Gems

**File:** `Gemfile`

Neither `bullet` (N+1 detection) nor `rack-mini-profiler` are active. Both are essential for catching regressions during development.

**Fix:** Add to development group:
```ruby
gem "bullet"
gem "rack-mini-profiler"
```

---

## Summary by Impact

| Priority | Issue | Type | Effort |
|----------|-------|------|--------|
| CRITICAL | SpecItem JSON embedded in form | Frontend/DB | Medium |
| CRITICAL | CSV export N+1 on bid_items | DB | Low |
| CRITICAL | Data view N+1 on spec_items | DB | Low |
| CRITICAL | No caching anywhere | Full-stack | High |
| HIGH | Phases tab N+1 on reports | DB | Low |
| HIGH | Core generations JSON N+1 | DB | Low |
| HIGH | Report show renders everything | Frontend | Medium |
| HIGH | Image compressor linear search | Service | Low |
| MEDIUM | No production cache store | Config | Low |
| MEDIUM | Missing composite indexes | DB | Low |
| MEDIUM | Equipment pluck per template | Frontend/DB | Low |
| MEDIUM | Attachments loaded then filtered | Service | Low |
| MEDIUM | Spec drilldown client HTML build | Frontend | High |
| LOW | Report.count in layout | DB | Low |
| LOW | Unbounded Report.all | DB | Low |
| LOW | Missing bullet/mini-profiler | Dev tooling | Low |

---

## Recommended Action Order

1. **Add `.includes(:bid_item)` and `.includes(:spec_item)`** to the two N+1 queries — 5 minutes each, immediate impact on CSV export and data view.
2. **Enable `redis_cache_store`** in production config — unlocks all caching.
3. **Add `bullet` gem** to development — catches future N+1 regressions automatically.
4. **Move SpecItem JSON to a cached endpoint** — biggest single page-load improvement for report forms.
5. **Add composite indexes** via migration — low risk, improves filtering/sorting on reports index.
6. **Add fragment caching** to project show tabs and report show sections.
7. **Wrap report show sections in Turbo Frames** — major perceived-speed improvement.
8. **Fix image compressor** to use binary search — reduces export time for image-heavy reports.
