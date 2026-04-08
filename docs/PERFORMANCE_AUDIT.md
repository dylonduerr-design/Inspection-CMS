# Performance Audit Report

**Date:** April 6, 2026
**Last Updated:** April 8, 2026 (post-lazy-section implementation)
**Scope:** Full-stack analysis of the Inspection CMS application

> Known slowdowns (Word doc export, AI summaries) are excluded from recommendations since they are already identified. This report focuses on **other** bottlenecks and optimization opportunities.

---

## Delta Audit Update (April 8, 2026)

This section is a current-state delta against the April 6 baseline, based on direct code inspection.

### Resolved Since Baseline

1. **SpecItem inline payload issue is fixed**
  - **Now:** `SpecItemsController#index` serves JSON with ETag + `Rails.cache`.
  - **Evidence:** `app/controllers/spec_items_controller.rb`

2. **CSV export eager loading issue is fixed**
  - **Now:** reports query includes `placed_quantities: :bid_item`.
  - **Evidence:** `app/controllers/reports_controller.rb` (`index`)

3. **Production cache store issue is fixed**
  - **Now:** `config.cache_store = :redis_cache_store` is configured in production.
  - **Evidence:** `config/environments/production.rb`

4. **Performance tooling gap is fixed**
  - **Now:** `bullet` and `rack-mini-profiler` are present in development gems.
  - **Evidence:** `Gemfile`

### Still Open (Validated)

#### Critical

1. **Fragment/view caching coverage is incomplete** — PARTIAL
  - **Now:** Fragment caching covers heavy report show sections (checklists, core locations, quantities, attachments), plus project tab content (`_bid_items_tab`, `_asphalt_lots_tab`) and report-form checklist cards (`_spec_check_card`).
  - **Remaining:** Evaluate additional safe caching opportunities in project tabs that include mutable forms.

2. ~~**Report show page remains monolithic**~~ — DONE
  - **Fixed:** show page now lazy-loads heavy sections via Turbo Frame endpoints (`reports#show_section`) with section-specific eager loading.
  - **Evidence:** `app/views/reports/show.html.erb`, `app/controllers/reports_controller.rb`, `app/views/reports/show_section.html.erb`, `app/views/reports/show_sections/*`

3. ~~**Core generations JSON endpoint still performs per-generation include/map work**~~ — DONE
  - **Fixed:** `includes(core_locations: [:asphalt_sublot, :asphalt_lane])` applied at query level; in-memory `sort_by` replaces per-association `.order()` call.

#### High

4. ~~**Phases tab report count N+1 pattern**~~ — DONE
  - **Fixed:** `ProjectsController#show` now loads phases with `left_joins(:reports).select(...COUNT...).group(...)`. View reads virtual `reports_count` attribute.

5. ~~**Repeated equipment-name plucks in templates**~~ — DONE
  - **Fixed:** Names plucked once at top of `_form.html.erb` and passed as `approved_equipment_names` to `_form_templates` and `_equipment_entry_fields` partials.

6. ~~**Image URL cache stats performs O(n) cache existence checks**~~ — DONE
  - **Fixed:** Now uses `Rails.cache.read_multi(*keys)` for a single bulk read.

7. ~~**Image compression quality search is linear**~~ — DONE
  - **Fixed:** quality selection now uses binary search in `ImageCompressor`.

8. ~~**DOCX exporter loads all attachments and filters in Ruby**~~ — DONE
  - **Fixed:** image filtering now happens at query level using attachment blob content type.

#### Medium

9. ~~**Report copy source scope is unbounded**~~ — DONE
  - **Fixed:** `copy_source_scope` now scopes by project and inspector context.

10. ~~**Reports filter panel can load full SpecItem table when no project is selected**~~ — DONE
  - **Fixed:** Fallback changed to `SpecItem.none`. Dropdown disabled with "Select project first" placeholder when no project is selected.

11. ~~**Missing composite indexes for common access paths**~~ — DONE
  - **Fixed:** migration `20260408000010_add_missing_composite_indexes` added and applied.

12. ~~**Layout still runs `Report.count` on each request**~~ — DONE
  - **Fixed:** Gated behind `Rails.env.development?` check. Shows "Hidden" in non-dev environments.

### Infra/Runtime Opportunities (Validated)

1. ~~**Nginx missing gzip compression and explicit static cache headers**~~ — DONE
  - **Fixed:** gzip enabled and `/assets/` responses now include immutable cache headers in `nginx.conf`.

2. **Puma/DB pool defaults remain conservative for upload-heavy workloads** — PARTIAL
  - **Now:** production thread/pool defaults raised (`RAILS_MAX_THREADS` fallback 8 in Puma; `DB_POOL`/`RAILS_MAX_THREADS` fallback 8 in production DB config).
  - **Remaining:** finalize values from load-test results per hosting limits.

3. ~~**Blocking CSS font imports in main stylesheet**~~ — DONE
  - **Fixed:** removed CSS `@import` font loading; moved to `<link rel="preconnect">` + `<link rel="stylesheet">` in layout head.

### Updated Recommended Fix Order

1. ~~**Immediate / security (same day)**~~ — ALL DONE
  - ~~Remove `params.to_json` from application layout (security).~~
  - ~~Add authorization to `ProjectsController` mutations (security).~~
  - ~~Remove/gate `Report.count` from layout.~~

2. ~~**Quick wins — backend (same day)**~~ — ALL DONE
  - ~~Fix phase count N+1 (`_phases_tab` + `ProjectsController#show`).~~
  - ~~Replace `ImageUrlCache#cache_stats` with `read_multi`.~~
  - ~~Avoid repeated `approved_equipment_list.pluck(:name)` in templates.~~
  - ~~Fix `File.open` block form in `ReportExportJob`.~~
  - ~~Combine duplicate QA queries in `WeeklyReportService`.~~

3. ~~**Quick wins — frontend (same day)**~~ — ALL DONE
  - ~~Add `disconnect()` to all 10 Stimulus controllers (biggest memory leak fix).~~
  - ~~Add `loading: "lazy"` to report photo `image_tag` calls.~~
  - ~~Add visibility throttling to AI/weekly/offline polling controllers.~~
  - ~~Fix ActionCable subscription leak in `report_export_controller.js`.~~

4. **High-value app changes (1-2 days)** — 8 of 8 DONE
  - ~~Refactor report show to preload in controller and lazy-load heavy sections.~~
  - ~~Add fragment caching around stable report/project subtrees.~~
  - ~~Restrict `copy_source_scope` (partial — `.limit(100)` added) and avoid `SpecItem.all` fallback in filters (done — uses `SpecItem.none`).~~
  - ~~Stream CSV export instead of buffering in memory.~~
  - ~~Add eager loading for `core_locations` in `WeeklyReportService`.~~
  - ~~Ensure `ImageCompressor` always runs in a Sidekiq job.~~
  - ~~Convert `application.js` turbo:load listeners to Stimulus controllers.~~
  - ~~Add weather API response caching + AbortController timeout.~~

5. **Database/runtime improvements (1 day + rollout)** — PARTIAL
  - ~~Add composite indexes listed above.~~
  - ~~Enable gzip/static caching in nginx.~~
  - ~~Enable Content Security Policy headers.~~ (enabled in report-only rollout mode)
  - Tune Puma threads and DB pool based on load test results. (defaults raised; validation still pending)

6. **Export path optimization (1 day)** — DONE
  - ~~Query-level image filtering in `PythonDocxExporter`.~~
  - ~~Binary-search quality selection in `ImageCompressor`.~~

### New Findings (April 8 Deep Audit)

#### Critical — Frontend Memory Leaks

13. ~~**10 Stimulus controllers missing `disconnect()` — event listener and data leaks**~~ — DONE
  - **Fixed:** All 10 controllers now have `disconnect()` methods with appropriate cleanup (nullifying stored data, clearing timeouts, closing modals, removing event listeners).

#### High — Backend

14. **Unbounded `Report.all` / `ImportedReport.all` on index page for QC users** — PARTIAL
  - **Now:** index base scopes are constrained with project context before pagination/filtering helpers.
  - **Remaining:** evaluate count-estimation or keyset pagination for very large datasets.

15. ~~**CSV export buffers entire response in memory**~~ — DONE
  - **Fixed:** CSV now streams via an `Enumerator` response body.

16. ~~**Weekly report service N+1 on core_locations**~~ — DONE
  - **Fixed:** `includes(core_generations: { core_locations: [:asphalt_sublot, :asphalt_lane] })` added to reports query. In-memory `sort_by` replaces per-association `.order()`.

17. ~~**Duplicate QA queries in weekly report service**~~ — DONE
  - **Fixed:** Memoized `qa_entries_in_period` method loads all QA entries once. `materials_payload` filters the cached result with `.select` in Ruby.

18. ~~**Image compressor blocks request thread (not just algorithm inefficiency)**~~ — DONE
  - **Fixed:** report attachment compression now enqueues `ReportAttachmentCompressionJob` and runs off-request.

19. ~~**File descriptor leak risk in export job**~~ — DONE
  - **Fixed:** Changed to `File.open(path, 'rb') { |file| ... }` block form ensuring FD cleanup on exception.

#### High — Frontend

20. ~~**Polling without visibility throttling**~~ — DONE
  - **Fixed:** All three controllers (`ai_generation`, `weekly_ai_status`, `offline_indicator`) now pause polling/heartbeat when `document.hidden` and resume on visibility change. Listeners cleaned up in `disconnect()`.

21. ~~**ActionCable subscription leak in export controller**~~ — DONE
  - **Fixed:** `disconnect()` unsubscribes active export channel subscription.

#### Medium — Frontend

22. ~~**No image lazy loading in views**~~ — DONE
  - **Fixed:** `loading: "lazy"` added to `image_tag` in both `show.html.erb` and `_form.html.erb`.

23. ~~**Weather API calls without caching or timeout**~~ — DONE
  - **Fixed:** added sessionStorage caching and `AbortController` timeout handling for weather requests.

24. ~~**Global `turbo:load` listeners in application.js instead of Stimulus controllers**~~ — DONE
  - **Fixed:** Detective toggle and dark mode logic removed from `application.js`. Only `js-enabled` class toggle remains. Logic now handled by `ui_controller.js` Stimulus controller.

#### Security Findings (Bonus)

25. ~~**`params.to_json` exposed in application layout**~~ — DONE
  - **Fixed:** Gated behind `Rails.env.development?`. Non-dev environments show "Params hidden outside development". Also strips `controller`/`action` keys from output.

26. ~~**Missing authorization on ProjectsController mutations**~~ — DONE
  - **Fixed:** `before_action :require_admin!, only: %i[ create update destroy ]` added. Returns redirect with alert for HTML, 403 for JSON.

27. ~~**Content Security Policy disabled**~~ — DONE
  - **Fixed:** CSP is enabled with conservative allowlist and report-only rollout mode by default in production.

### Verification Checklist

1. Compare SQL query counts for report show, projects show (phases), and reports index advanced filters.
2. Measure TTFB before/after report show refactor and fragment caching.
3. Confirm cache hit behavior for `ImageUrlCache` stats after `read_multi` change.
4. Validate index usage with `EXPLAIN ANALYZE` for report filtering and placed quantity aggregations.
5. Confirm `Content-Encoding: gzip` and static `Cache-Control` headers after nginx updates.
6. Profile browser memory across 10+ Turbo navigations before/after adding `disconnect()` to Stimulus controllers.
7. Confirm polling pauses when tab is backgrounded (DevTools Network tab).
8. Verify `params.to_json` no longer appears in production HTML source.
9. Confirm non-admin users receive 403 on ProjectsController create/update/destroy.
10. Test CSV streaming with a large report set (1000+ rows) and verify constant memory usage.

### Remaining Work Snapshot (As Of April 8, 2026)

1. **Finalize production concurrency tuning**
  - Run load tests and set final `RAILS_MAX_THREADS`, `RAILS_MIN_THREADS`, and `DB_POOL` values for hosting limits.

2. **Evaluate additional safe fragment caching in form-heavy tabs**
  - Focus on project/form regions that do not embed CSRF/nonces or rapidly changing inline form state.

3. **Scale strategy for very large QC index datasets**
  - Prototype keyset pagination or count-estimation approach for `Report`/`ImportedReport` index paths under high row counts.

---

## Historical Baseline (April 6, 2026)

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
