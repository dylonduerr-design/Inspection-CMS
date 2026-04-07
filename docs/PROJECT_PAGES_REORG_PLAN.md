# Plan: Reorganizing Project Pages

## The Problem

Project information is scattered across 4 separate pages with inconsistent edit/view behavior. An inspector has to already know which page a given piece of data lives on before they can find or change it.

### Current page map

| Page | URL | What's on it | Editable? |
|---|---|---|---|
| **Project Show** | `/projects/:id` | Project summary (contract #, PM, CM, dates) | Read-only |
| | | Bid items list | Read-only (duplicate of Library) |
| | | Approved equipment list | Read-only (duplicate of Library) |
| | | Phases | **Yes** — full inline CRUD |
| | | Delete project | **Yes** — destructive action |
| **Project Edit** | `/projects/:id/edit` | Name, contract #, PM, CM, dates, coordinates | **Yes** — standard form |
| **Manage Library** | `/projects/:id/bid_items` | Bid items | **Yes** — full CRUD table |
| | | Approved equipment | **Yes** — add/remove |
| **Asphalt Lots** | `/projects/:id/asphalt_lots` | Lot listing → sublots → lanes → core gen | **Yes** — deep nesting |

### What's wrong

1. **Show page does edit work it shouldn't.** Phases have full inline CRUD (add, rename, delete) on a page labeled "show." Meanwhile bid items and equipment are displayed read-only — duplicating the Library page but without any functionality. Why can I edit phases here but not equipment?

2. **Read-only lists on Show are dead weight.** The bid items and equipment lists on the show page are strictly worse versions of what's on the Library page. They add visual bulk but zero capability. An inspector sees them, thinks "I need to add one," and then has to navigate somewhere else.

3. **"Manage Library" is a grab bag.** It combines bid items and approved equipment under a name ("Library") that doesn't clearly describe either. These are both project configuration, but the label suggests something more like a reference catalog.

4. **Edit page is a dead end.** The core project fields (name, contract number, PM, CM, coordinates) are on a separate form that feels disconnected from the rest of the project. No indication that phases, equipment, or bid items exist — you just save and bounce back.

5. **No single mental model.** An inspector asking "where do I change X?" has to know:
   - Project name → Edit page
   - Add a phase → Show page
   - Add a bid item → Manage Library page
   - Add equipment → Manage Library page
   - Set up asphalt lots → Asphalt Lots page
   - Change the PM → Edit page

   There's no organizing principle behind this split. It's the result of features being added incrementally to whichever page was convenient.

---

## Proposed: Single Tabbed Project Page

Consolidate everything into **one page** with tabs. Kill the Edit page and the Manage Library page as separate destinations. The project show page becomes the project's home — everything is here, organized into logical sections.

```
┌─────────────────────────────────────────────────────────────┐
│  Runway 1R Rehabilitation                    [Back to Projects] │
│  Contract #8983.61 · PM: John Smith                          │
├──────────┬───────────┬───────────┬────────┬─────────────────┤
│ Overview │ Bid Items │ Equipment │ Phases │ Asphalt Lots    │
├──────────┴───────────┴───────────┴────────┴─────────────────┤
│                                                              │
│  (tab content here)                                          │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

### Tab breakdown

#### Overview (default tab)
What it has:
- Project details — **editable inline** (name, contract #, PM, CM, contractor, contract days, start date, coordinates with geolocation detect)
- Project stats — report count, bid item count, equipment count, lot count (quick-glance numbers, not full lists)
- Delete project section (at bottom, behind confirmation — same as now)

What changed:
- The Edit page's form fields move here as inline-editable fields or a collapsible edit form (click "Edit Details" to toggle fields into edit mode, save in place)
- The read-only bid items/equipment lists are **removed** — they're accessible in their own tabs now
- Phase CRUD moves to its own tab

#### Bid Items tab
What it has:
- Full bid items table with CRUD (exactly what's on Manage Library today)
- "+ New Item" button
- SoV category, linked spec, edit/delete per row

What changed:
- Moved from a separate page (`/projects/:id/bid_items`) into a tab
- The bid items CRUD routes stay the same (they still POST/PATCH to nested routes) — only the "index" view is embedded
- New/Edit bid item forms can either be inline modals or still navigate to their own pages (the current `new` and `edit` views for bid items are simple single-field forms, so modals would work well)

#### Equipment tab
What it has:
- Approved equipment list with add/remove (exactly the `_approved_equipment_manager` partial)

What changed:
- Moved from being the bottom half of Manage Library into its own tab
- Gets equal billing instead of being an afterthought below bid items

#### Phases tab
What it has:
- Phase table with inline rename, add, delete (exactly what's on Show today)
- Report count per phase

What changed:
- Moved from Show page into its own tab
- No functional changes needed — the inline forms already work

#### Asphalt Lots tab
What it has:
- Lot listing table (lot number, plant, mix type, paving date, sublot count, generation count)
- "+ New Lot" button
- Each row links to the individual lot page (`/projects/:id/asphalt_lots/:lot_id`)

What changed:
- The asphalt lots index view is embedded as a tab instead of being a separate page
- Individual lot pages (show, bulk setup, core generations) remain as their own pages — they have too much depth (sublots → lanes → core generations → core locations) to cram into a tab

### Navigation simplification

**Before (4+ buttons in header):**
```
[Edit Project] [Manage Library] [Asphalt Lots] [Back to Projects]
```

**After (1 button in header):**
```
[Back to Projects]
```

Everything else is tabs. No more guessing which button leads where.

**Projects index table also simplifies:**

Before: `[Manage Library] [Edit] [Show]` — three links per row, unclear which to click.
After: `[Open]` — one link, goes to the tabbed page.

---

## Implementation approach

### Stimulus

The app already has a `tabs` controller used on the projects index page (for Projects/Spec Checklist Editor tabs). Reuse it on the project show page. The tab state can be preserved in the URL hash (`#bid-items`, `#phases`) so direct links and back-button work correctly.

### Routes

No route changes needed. The existing nested resource routes (`project_bid_items_path`, etc.) continue to handle form submissions. Only the "index" views are visually embedded — the controllers still respond normally. The bid items index can check `request.format` or a param to decide whether to render a full page or a partial (for Turbo Frame embedding).

Alternatively, and more simply: just render the content directly in the show template using partials. No Turbo Frames needed. The bid items table, equipment manager, phases section, and asphalt lots table are all already partials or easily extractable into partials.

### Files to change

| File | Change |
|---|---|
| `app/views/projects/show.html.erb` | **Rewrite.** Tabbed layout with all 5 sections. |
| `app/views/projects/_overview_tab.html.erb` | **New partial.** Project details with inline edit + stats + delete. |
| `app/views/projects/_bid_items_tab.html.erb` | **New partial.** Embed bid items index content. |
| `app/views/projects/_equipment_tab.html.erb` | **New partial.** Wrap existing `_approved_equipment_manager`. |
| `app/views/projects/_phases_tab.html.erb` | **New partial.** Extract phase CRUD from current show. |
| `app/views/projects/_asphalt_lots_tab.html.erb` | **New partial.** Embed asphalt lots index content. |
| `app/views/projects/edit.html.erb` | **Delete** (or redirect to show with `#overview`). |
| `app/views/projects/_form.html.erb` | Keep for `new` action only. Overview tab gets its own inline version. |
| `app/views/projects/index.html.erb` | Simplify action links per row. |
| `app/controllers/projects_controller.rb` | `show` action loads bid_items, approved_equipments, phases, asphalt_lots. |
| `app/views/bid_items/index.html.erb` | Keep as standalone fallback, but primary access is via tab. |

### What about the project `new` page?

Keep it as-is. When creating a new project, you only need the core fields (name, contract #, etc.). The tabs don't make sense until the project exists and has things to configure. After create, redirect to the new tabbed show page.

### What about deep-linked tabs?

Use URL hash fragments. When an inspector bookmarks `/projects/5#bid-items`, the tabs controller reads the hash on connect and activates the right tab. This also means links like "Manage Library" from other parts of the app can point to `/projects/5#bid-items` instead of a separate page.

---

## Alternative considered: Two-page split (Dashboard + Settings)

Instead of one tabbed page, keep a clean read-only Dashboard and create a separate "Project Settings" page that absorbs Edit + Manage Library + Phases:

- **Dashboard**: Summary stats, quick links, recent reports for this project
- **Settings**: Tabbed page with General / Bid Items / Equipment / Phases

I rejected this because:
1. It still requires knowing "is this a dashboard thing or a settings thing?" — just trading one confusion for another
2. The "dashboard" would be thin (project details are ~6 fields) and the "settings" page would be doing all the real work
3. Two pages with navigation between them is strictly worse than one page with tabs when the content volume is this manageable

---

## Summary

The root cause is incremental growth without a unifying layout. The fix is consolidation: one project page, five tabs, zero guesswork. The `new` page stays simple. Individual asphalt lot pages stay deep. Everything else collapses into the tabbed show page.
