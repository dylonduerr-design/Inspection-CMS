# Plan: Reorganize Core Locator in Report Form

## TL;DR

Restructure the report form's core locator section from 4 tabs (Overview / Create Lot / Generate Cores / Manage Lot) to 4 better-organized tabs (Overview / Quick Setup / Sublots & Lanes / Generate Cores). The "Manage Lot" tab is bloated — extract sublot/lane management into its own tab with collapsible cards, move lot metadata editing to the project-level Asphalt Lots tab. Add per-core-type lock granularity via enum. The report form acts as a "portal" into the project's asphalt lot data — same API endpoints, same source of truth.

## Context

- **SANDEEP_REPO** is the only codebase being modified (asphalt_core_locater is reference only)
- The Asphalt Lots tab already exists in the project show view with collapsible sublot cards, inline lane editing, core diagram, bulk setup, and generation/locking
- The report form currently has a `core_generation_selector_controller.js` Stimulus controller that renders sublot cards via JS (`sublotMarkup()`) — these are NOT collapsible
- Sublots should be **expanded by default** (not collapsed)
- Lock granularity: enum (`none` / `mat` / `joint` / `all`) replaces single boolean

## Key Decisions

- Report form = portal into project lot data (reads/writes same records)
- Quick create stays in report form (useful scaffold for field inspectors)
- Lot metadata editing (contractor, mix design, PG, etc.) moves OUT of report form → project tab only
- Sublot/lane management stays in report form but gets its own dedicated tab
- Sublot cards must be collapsible in both report form (JS-rendered) and project tab (server-rendered, already done)
- Per-core-type locking via enum

---

## Phase 1: Schema — Lock Granularity Enum

1. **Migration**: Add `core_lock_mode` integer column to `asphalt_sublots` (default `0` = `none`). Keep `locked_for_core_generation` temporarily for backward compat.
2. **Model enum**: `enum core_lock_mode: { none: 0, mat_only: 1, joint_only: 2, all: 3 }` on `AsphaltSublot`.
3. **Data migration**: Backfill `core_lock_mode = :all` where `locked_for_core_generation = true`, else `:none`.
4. **Update CoreGenerator service**: Respect enum — skip mat generation if locked for `mat_only` or `all`, skip joint if `joint_only` or `all`.
5. **Remove old boolean** in follow-up migration after confirming everything works.

## Phase 2: Report Form Tab Reorganization

6. **Rename/reorder tabs** in `app/views/reports/_form.html.erb`: Overview → Quick Setup → Sublots & Lanes → Generate Cores. Drop "Manage Lot".
7. **Update `switchCoreTab` JS** in `core_generation_selector_controller.js` for new tab IDs (`overview`, `setup`, `sublots`, `generate`).
8. **Build "Sublots & Lanes" tab** placeholder in ERB, loaded when lot is selected.
9. **Refactor `sublotMarkup()` in JS**: Wrap each sublot in `<details open>` (expanded by default). Summary: `Sublot {n} — {lanes} lanes, {ft} ft — Lock: {mode}`. Remove lot metadata fields (contractor, mix design, PG, etc.) from JS rendering.
10. **Add lock mode selector** in sublot cards: segmented control (None / Mat / Joint / All).
11. **Update `renderLotPanel()` / `fetchLotManagement()`** to render into the new "Sublots & Lanes" tab, strip lot-level edit fields.
12. **Add "Manage in Project →" link** to overview or sublots tab.

## Phase 3: Project Tab — Update Lock UI

13. **Update `app/views/asphalt_lots/show.html.erb`**: Replace binary Lock/Unlock button with lock mode selector using the new enum.
14. **Update `asphalt_sublots_controller#toggle_core_lock`**: Accept `core_lock_mode` param instead of toggling boolean.
15. **Update `management_json` endpoint**: Include `core_lock_mode` in sublot JSON payload instead of (or alongside) `locked_for_core_generation`.

## Phase 4: Verification

16. **Manual**: Create lot via Quick Setup → verify sublot cards expanded + collapsible → edit lanes → set lock modes (e.g., sublot 2 = Mat, sublot 4 = Joint) → generate cores → verify locked types preserved → export CSV → verify project tab matches.
17. **Automated**: `rails test`, test enum values, test CoreGenerator lock mode logic.

---

## Relevant Files

| File | Purpose |
|------|---------|
| `app/views/reports/_form.html.erb` (Lines ~340-590) | 4-tab core locator UI to reorganize |
| `app/javascript/controllers/core_generation_selector_controller.js` | `sublotMarkup()` (~L862), `renderLotPanel()` (~L770), `laneRowMarkup()` (~L930), tab switching |
| `app/views/asphalt_lots/show.html.erb` | Project-level lot detail page, already has collapsible sublots |
| `app/models/asphalt_sublot.rb` | Add enum, currently has `locked_for_core_generation` boolean |
| `app/controllers/asphalt_sublots_controller.rb` | `toggle_core_lock` action |
| `app/controllers/asphalt_lots_controller.rb` | `management_json` endpoint |
| `config/routes.rb` | Existing asphalt lot nested routes |

## Scope

**IN**: Tab reorganization, collapsible sublot cards in report form JS, lock enum migration, project tab lock UI update.

**OUT**: Standalone asphalt_core_locater app changes, core diagram changes, bulk setup changes, new feature additions beyond what's described.
