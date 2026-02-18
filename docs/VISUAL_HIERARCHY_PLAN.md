# Visual Layout Improvement Plan

> Detailed implementation plan for strengthening visual hierarchy, improving compliance UX,
> and refining the IDR summary page.

---

## A. Establish a Stronger Visual Hierarchy

### A1. Elevate Primary Action Buttons

**Problem:** `btn-primary` currently has a flat solid blue (`#2563eb`) with only `var(--shadow-sm)` — identical visual weight to secondary buttons except for color.

**Current CSS** (`application.css` ~L85):
```css
.btn-primary { background-color: var(--primary); }
.btn-primary:hover { background-color: var(--primary-hover); transform: translateY(-1px); }
```

**Changes:**

| Property | Before | After |
|---|---|---|
| `box-shadow` | `var(--shadow-sm)` (inherited from `.btn`) | `0 2px 8px rgba(37,99,235,0.35)` |
| `background` | `var(--primary)` flat | `linear-gradient(180deg, #3b82f6, #2563eb)` subtle top-light gradient |
| `font-weight` | 500 (inherited) | 600 |
| `hover box-shadow` | none | `0 4px 14px rgba(37,99,235,0.4)` |

**Files to edit:**
- [app/assets/stylesheets/application.css](app/assets/stylesheets/application.css) — update `.btn-primary` and `.btn-primary:hover` rules (~L85-86)

**Implementation:**
```css
.btn-primary {
  background: linear-gradient(180deg, #3b82f6, #2563eb);
  box-shadow: 0 2px 8px rgba(37, 99, 235, 0.35);
  font-weight: 600;
}
.btn-primary:hover {
  background: linear-gradient(180deg, #60a5fa, #2563eb);
  box-shadow: 0 4px 14px rgba(37, 99, 235, 0.4);
  transform: translateY(-1px);
}
```

---

### A2. Add Data Density Contrast in Tables

**Problem:** All table cells use the same font size (~0.95rem) and weight, making project names blend in with contract numbers and other secondary info.

**Current CSS** (`application.css`): `.dashboard-table td` has uniform `font-size` and `font-weight`.

**Changes:**

1. **Add utility classes for table cell hierarchy:**

| Class | Font Size | Font Weight | Color |
|---|---|---|---|
| `.cell-primary` | 0.95rem | 600 | `var(--text-main)` |
| `.cell-secondary` | 0.82rem | 400 | `var(--text-muted)` |

2. **Apply classes in views:**

**Files to edit:**
- [app/assets/stylesheets/application.css](app/assets/stylesheets/application.css) — add new utility classes after the `.dashboard-table` rules
- [app/views/projects/index.html.erb](app/views/projects/index.html.erb) — apply `cell-primary` to Project Name, `cell-secondary` to Contract #, Location
- [app/views/reports/index.html.erb](app/views/reports/index.html.erb) — apply `cell-primary` to IDR #/Date, `cell-secondary` to Project name, Phase in table

**CSS to add:**
```css
/* Table data-density hierarchy */
.cell-primary {
  font-weight: 600;
  color: var(--text-main);
}
.cell-secondary {
  font-size: 0.82rem;
  color: var(--text-muted);
}
```

**View changes (projects/index.html.erb):** Wrap project name `<td>` content in `<span class="cell-primary">` and contract number in `<span class="cell-secondary">`.

**View changes (reports/index.html.erb):** Wrap the date/IDR# `<td>` content in `<span class="cell-primary">` and the project/phase `<td>` content in `<span class="cell-secondary">`.

---

## B. Improve the "Compliance & Checklists" UX

### B1. Standardize Radio Button Group Component

**Problem:** Two inconsistent radio button styles exist:
1. **Deficiency/Safety radios** (`.radio-group` + `.radio-label`): Larger padded labels (8px 12px) with white bg and visible border
2. **Compliance item radios** (`.compliance-options` + `.compliance-option-label`): Smaller (0.85rem), no background, gap-spaced, muted text

**Changes:**

Create a single **`.response-group`** component that replaces both patterns:

**Files to edit:**
- [app/assets/stylesheets/application.css](app/assets/stylesheets/application.css) — add new `.response-group` component styles; deprecate or refactor `.radio-group`/`.radio-label` and `.compliance-options`/`.compliance-option-label`
- [app/views/reports/_compliance_check_card.html.erb](app/views/reports/_compliance_check_card.html.erb) — replace both radio group markups with unified `.response-group` markup

**New CSS component:**
```css
/* Unified Response Group component */
.response-group {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
}
.response-group__option {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 6px 14px;
  border-radius: 8px;
  font-size: 0.85rem;
  font-weight: 500;
  color: var(--text-muted);
  background: var(--bg-card);
  border: 1px solid var(--border-color);
  cursor: pointer;
  transition: all 0.15s ease;
}
.response-group__option:hover {
  color: var(--primary);
  border-color: var(--primary);
  background: rgba(37, 99, 235, 0.04);
}
/* Highlight when the radio inside is checked */
.response-group__option:has(input:checked) {
  color: var(--primary);
  border-color: var(--primary);
  background: rgba(37, 99, 235, 0.08);
  font-weight: 600;
}
```

**Markup pattern (both deficiency/safety AND compliance items):**
```erb
<div class="response-group">
  <label class="response-group__option">
    <input type="radio" name="..." value="yes"> Yes
  </label>
  <label class="response-group__option">
    <input type="radio" name="..." value="no"> No
  </label>
  <label class="response-group__option">
    <input type="radio" name="..." value="na"> N/A
  </label>
</div>
```

---

### B2. Switch Compliance Items to Vertical Layout on Mobile

**Problem:** The horizontal radio layout works on desktop but is cramped on mobile.

**Changes:** Add a responsive breakpoint that stacks `.response-group` vertically on small screens.

**Files to edit:**
- [app/assets/stylesheets/application.css](app/assets/stylesheets/application.css) — add media query

**CSS to add:**
```css
@media (max-width: 640px) {
  .response-group {
    flex-direction: column;
    gap: 6px;
  }
  .response-group__option {
    justify-content: flex-start;
    width: 100%;
  }
}
```

**Desktop behavior:** Stays horizontal (faster scanning for power users with wide screens).
**Mobile behavior:** Stacks vertically (larger touch targets, easier one-handed use).

---

## C. Refine the IDR # Summary Page

### C1. Add Breadcrumb Navigation

**Problem:** No breadcrumb trail exists anywhere. Users navigate with "Back" buttons and lose spatial context. The layout (`application.html.erb`) has no shared navigation bar.

**Changes:**

1. **Create a reusable breadcrumb partial** rendered in the layout or injected per-page via `content_for`.
2. **Add breadcrumbs to the IDR show page** and other detail pages.

**Files to create:**
- [app/views/shared/_breadcrumbs.html.erb](app/views/shared/_breadcrumbs.html.erb) — reusable breadcrumb partial

**Files to edit:**
- [app/assets/stylesheets/application.css](app/assets/stylesheets/application.css) — breadcrumb styles
- [app/views/reports/show.html.erb](app/views/reports/show.html.erb) — render breadcrumbs above report header
- [app/views/reports/edit.html.erb](app/views/reports/edit.html.erb) — render breadcrumbs (optional, phase 2)
- [app/views/projects/show.html.erb](app/views/projects/show.html.erb) — render breadcrumbs (optional, phase 2)

**Breadcrumb partial (`_breadcrumbs.html.erb`):**
```erb
<nav class="breadcrumb-trail" aria-label="Breadcrumb">
  <ol class="breadcrumb-list">
    <% breadcrumbs.each_with_index do |crumb, i| %>
      <li class="breadcrumb-item">
        <% if i < breadcrumbs.size - 1 %>
          <%= link_to crumb[:label], crumb[:path], class: "breadcrumb-link" %>
          <span class="breadcrumb-sep" aria-hidden="true">›</span>
        <% else %>
          <span class="breadcrumb-current" aria-current="page"><%= crumb[:label] %></span>
        <% end %>
      </li>
    <% end %>
  </ol>
</nav>
```

**Usage in `reports/show.html.erb`:**
```erb
<%= render "shared/breadcrumbs", breadcrumbs: [
  { label: "Projects", path: projects_path },
  { label: @report.project.name, path: project_path(@report.project) },
  { label: "IDR ##{@report.dir_number}", path: "#" }
] %>
```

**CSS:**
```css
/* Breadcrumb trail */
.breadcrumb-trail {
  max-width: 1000px;
  margin: 0 auto 1rem;
  padding: 0 0.5rem;
}
.breadcrumb-list {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 4px;
  list-style: none;
  padding: 0;
  margin: 0;
  font-size: 0.82rem;
  font-family: var(--font-accent);
}
.breadcrumb-item {
  display: flex;
  align-items: center;
  gap: 4px;
}
.breadcrumb-link {
  color: var(--primary);
  text-decoration: none;
  font-weight: 500;
}
.breadcrumb-link:hover {
  text-decoration: underline;
}
.breadcrumb-sep {
  color: var(--text-muted);
  font-size: 0.9rem;
  user-select: none;
}
.breadcrumb-current {
  color: var(--text-muted);
  font-weight: 600;
}
```

---

### C2. Upgrade Status Indicators to Pill Badges

**Problem:** The current `.status-badge` has only `border-radius: 6px` and `padding: 4px 10px` — it looks like a rounded rectangle, not a distinct pill badge. It's functional but lacks visual punch for quick identification.

**Current CSS** (`application.css` ~L706):
```css
.status-badge {
  padding: 4px 10px; border-radius: 6px; font-size: 0.75rem; font-weight: 600;
  display: inline-flex; align-items: center; line-height: 1;
}
```

**Changes:**
- Increase `border-radius` to `999px` (full pill shape)
- Add a left dot indicator for color reinforcement
- Slightly increase padding for better readability
- Add subtle inner border for definition

**Files to edit:**
- [app/assets/stylesheets/application.css](app/assets/stylesheets/application.css) — update `.status-badge` rule (~L706)

**Updated CSS:**
```css
.status-badge {
  padding: 5px 12px 5px 10px;
  border-radius: 999px;
  font-size: 0.75rem;
  font-weight: 600;
  display: inline-flex;
  align-items: center;
  gap: 6px;
  line-height: 1;
  white-space: nowrap;
}

/* Status dot indicator */
.status-badge::before {
  content: "";
  width: 7px;
  height: 7px;
  border-radius: 50%;
  flex-shrink: 0;
}
.status-in_progress::before { background: var(--status-in-progress-text); }
.status-review::before      { background: var(--status-review-text); }
.status-revise::before       { background: var(--status-revise-text); }
.status-finalize::before     { background: var(--status-finalize-text); }
```

**No view changes needed** — existing `<span class="status-badge status-<%= report.status %>">` markup already uses the right classes; the CSS-only change upgrades the appearance everywhere automatically.

---

## Implementation Order

| Phase | Task | Files | Effort | Risk |
|---|---|---|---|---|
| **1** | A1 — Primary button elevation | `application.css` | 15 min | Low — CSS-only, no markup changes |
| **2** | C2 — Status badge pill upgrade | `application.css` | 15 min | Low — CSS-only, auto-applies everywhere |
| **3** | A2 — Table data density | `application.css`, `projects/index`, `reports/index` | 30 min | Low — additive classes |
| **4** | B1 — Unified response-group component | `application.css`, `_compliance_check_card` | 45 min | Medium — markup refactor in form partial |
| **5** | B2 — Mobile vertical layout | `application.css` | 10 min | Low — responsive media query only |
| **6** | C1 — Breadcrumb navigation | new partial, `application.css`, `reports/show`, `projects/show` | 45 min | Medium — new partial + helper, applied per-page |

**Total estimated effort: ~2.5 hours**

---

## D. Enforce 8pt Grid Spacing

### Problem

The CSS uses **dozens of ad-hoc spacing values** that break the 8pt grid. All padding, margin, and gap values should be multiples of 8px (4px acceptable for small UI elements). This creates visual inconsistency — elements feel unevenly spaced and the rhythm is broken.

### Violations Found (partial list — most impactful)

| Selector | Property | Current | Corrected (8pt) |
|---|---|---|---|
| `.btn` | padding | `10px 24px` | `8px 24px` |
| `.btn-sm` | padding | `6px 16px` | `8px 16px` |
| `.btn-add` | padding | `9px 16px` | `8px 16px` |
| `.btn-search` | padding | `8px 20px` | `8px 16px` |
| `.btn-clear` | padding | `8px 16px` | ✓ OK |
| `.dashboard-container` | padding | `40px 20px` | `40px 24px` |
| `.page-header` | padding | `0 2px 16px` | `0 0 16px` |
| `.page-header-left` | gap | `12px` | `16px` |
| `.filter-panel > summary` | padding | `14px 20px` | `16px 24px` |
| `.filter-panel-body` | padding | `20px 24px 24px` | `24px` |
| `.filter-grid` | gap | `20px` | `24px` |
| `.status-badge` | padding | `4px 10px` | `4px 12px` |
| `.form-card` | padding | `2.75rem` (~44px) | `2.5rem` (40px) |
| `.form-sub-card` | padding | `2.25rem` (~36px) | `2rem` (32px) |
| `.form-sub-card` | margin-top | `1.25rem` (~20px) | `1.5rem` (24px) |
| `.form-group input` | padding | `12px` | `12px` (keep — input inner spacing is OK at 12) |
| `.radio-group` | gap | `20px` | `16px` |
| `.radio-label` | padding | `8px 12px` | `8px 16px` |
| `.nested-entry-card` | padding | `24px` | ✓ OK |
| `.nested-entry-card` | margin-bottom | `20px` | `24px` |
| `.report-header` | padding | `30px` | `32px` |
| `.report-header` | margin-bottom | `30px` | `32px` |
| `.header-title` | margin/padding-bottom | `25px` | `24px` |
| `.meta-data-grid` | gap | `30px` | `32px` |
| `.meta-item label` | margin-bottom | `6px` | `8px` |
| `.report-section` | padding | `30px` | `32px` |
| `.report-section h3` | padding-bottom | `15px` | `16px` |
| `.report-section h3` | margin-bottom | `20px` | `24px` |
| `.compliance-grid` | gap | `15px` | `16px` |
| `.compliance-form-item` | padding | `18px` | `16px` |
| `.compliance-options` | gap | `15px` | `16px` |
| `.compliance-note-container` | margin-top | `10px` | `8px` |
| `.gallery-grid` | gap | `20px` | `24px` |
| `.gallery-card` | padding-bottom | `12px` | `16px` |
| `.weather-grid` | gap | `20px` | `24px` |
| `.weather-grid` | margin-top | `15px` | `16px` |
| `.weather-col` | padding | `20px` | `24px` |
| `.weather-col label` | margin-bottom | `12px` | `8px` |
| `.qc-panel` | padding | `25px` | `24px` |
| `.qc-header-row` | margin-bottom | `15px` | `16px` |
| `.qc-divider` | margin | `20px 0` | `24px 0` |
| `.activity-feed` | padding-left | `25px` | `24px` |
| `.activity-feed` | margin-left | `10px` | `8px` |
| `.activity-feed` | margin-top | `20px` | `24px` |
| `.feed-item` | margin-bottom | `30px` | `32px` |
| `.feed-note` | padding | `15px` | `16px` |
| `.sunken-tray` | padding | `18px` | `16px` |
| `.spec-empty-state` | padding | `34px` | `32px` |
| `.modal-header (dialog)` | padding | `20px 25px` | `24px` |
| `.modal-body (dialog)` | padding | `25px` | `24px` |
| `.modal-footer (dialog)` | padding | `20px 25px` | `24px` |
| `.modal-footer (dialog)` | gap | `15px` | `16px` |
| `.alert` | padding | `15px 20px` | `16px 24px` |
| `.alert` | margin-bottom | `25px` | `24px` |
| `.error-explanation` | padding | `20px` | `24px` |
| `.error-explanation` | margin-bottom | `25px` | `24px` |
| `.floating-actions` | bottom/left | `25px` | `24px` |
| `.floating-actions` | gap | `15px` | `16px` |
| `.float-btn` | width/height | `50px` | `48px` |
| `.float-btn` | font-size | `20px` | `20px` (keep) |
| `.eyebrow` | margin-bottom | `6px` | `8px` |
| `.compliance-alert-box` | padding | `18px` | `16px` |
| `.spec-modal-header` | padding | `15px 25px` | `16px 24px` |
| `.spec-modal-body` | padding | `20px 25px` | `24px` |
| `.spec-selection-btn` | padding | `15px` | `16px` |
| `.spec-selection-btn` | margin-bottom | `10px` | `8px` |
| `.auth-card` | padding | `28px` | `32px` |
| `.checklist-header` | padding | `12px 15px` | `12px 16px` |
| `.date-range-fields` | gap | `14px` | `16px` |
| `.advanced-filters` | padding-top | `12px` | `16px` |
| `.header-context-row` | padding-bottom | `12px` | `16px` |
| `.header-context-row` | margin-bottom | `22px` | `24px` |

### Implementation

All changes are CSS-only in [app/assets/stylesheets/application.css](app/assets/stylesheets/application.css). No view changes needed.

---

## E. Font Consistency & Rationalization

### Problem

The stylesheet currently uses **19 distinct font sizes**: 0.7, 0.74, 0.75, 0.8, 0.82, 0.85, 0.875, 0.9, 0.95, 1.0, 1.1, 1.15, 1.2, 1.25, 1.3, 1.35, 1.6, 1.8, 2.0 rem. A well-designed type scale should have **7–8 steps**. Close sizes (e.g. 0.7/0.74/0.75, or 0.85/0.875) create inconsistency without perceptible difference.

### Current Fonts

| Font | Usage | Verdict |
|---|---|---|
| **Inter** (400–700) | Body text, labels, buttons, inputs | **Keep** — top-tier UI font with tabular numbers and excellent screen rendering |
| **Space Grotesk** (500–600) | Eyebrow labels, spec codes, tab buttons, spec editor headings | **Keep but standardize usage** — geometric sans adds nice contrast for technical/code content |

### Font Recommendation

**Inter** is already one of the best UI fonts available — no replacement needed. **Space Grotesk** works well as an accent for technical content (spec codes, eyebrows, small caps labels). No font swaps are recommended; the issue is **size inconsistency**, not font choice.

### Proposed Type Scale (CSS Custom Properties)

Define a rationalized scale at `:root` level:

```css
--text-xs:   0.75rem;   /* 12px — badges, fine print, status labels */
--text-sm:   0.8125rem; /* 13px — labels, captions, meta text */
--text-base: 0.875rem;  /* 14px — body, buttons, inputs */
--text-md:   1rem;      /* 16px — emphasized body, card content */
--text-lg:   1.125rem;  /* 18px — section headings, card titles */
--text-xl:   1.25rem;   /* 20px — page section titles */
--text-2xl:  1.5rem;    /* 24px — page titles */
--text-3xl:  1.75rem;   /* 28px — hero/report titles */
```

### Consolidation Map

| Old Size(s) | → New Variable | Usage |
|---|---|---|
| 0.7, 0.74, 0.75rem | `--text-xs` (0.75rem) | Status badges, eyebrows, filter labels, table headers, meta labels |
| 0.8, 0.82, 0.85, 0.875rem | `--text-sm` (0.8125rem) | Button-sm, checkslist desc, small text, pagination, compliance labels |
| 0.9, 0.95rem | `--text-base` (0.875rem) | Buttons, body text, inputs, table cells, card descriptions |
| 1.0rem | `--text-md` (1rem) | Emphasized content, form inputs, checklist codes |
| 1.1, 1.15, 1.2rem | `--text-lg` (1.125rem) | Section headings (h3), meta values, modal titles |
| 1.25, 1.3, 1.35rem | `--text-xl` (1.25rem) | Form card h2, section titles, page-title |
| 1.6rem | `--text-2xl` (1.5rem) | Spec editor heading, auth header |
| 1.8rem | `--text-3xl` (1.75rem) | Report show h1 |

### Implementation

All changes in [app/assets/stylesheets/application.css](app/assets/stylesheets/application.css):
1. Add CSS custom properties to `:root`
2. Replace hard-coded font sizes with variable references throughout

---

## Updated Implementation Order

| Phase | Task | Files | Effort | Risk |
|---|---|---|---|---|
| **1** | E — Type scale variables + font consolidation | `application.css` | 30 min | Low — CSS-only |
| **2** | D — 8pt grid spacing corrections | `application.css` | 45 min | Low — CSS-only |
| **3** | A1 — Primary button elevation | `application.css` | 15 min | Low — CSS-only |
| **4** | C2 — Status badge pill upgrade | `application.css` | 15 min | Low — CSS-only |
| **5** | A2 — Table data density | `application.css`, views | 30 min | Low — additive |
| **6** | B1 — Unified response-group component | `application.css`, compliance partial | 45 min | Medium — markup refactor |
| **7** | B2 — Mobile vertical layout | `application.css` | 10 min | Low — media query |
| **8** | C1 — Breadcrumb navigation | new partial, `application.css`, views | 45 min | Medium — new partial |

**Total estimated effort: ~4 hours**

---

## Testing Checklist

- [ ] Primary buttons visually stand out from secondary/clear buttons on all pages
- [ ] Table rows show clear primary vs secondary data hierarchy
- [ ] All radio groups (deficiency, safety, compliance items) use the same `.response-group` component
- [ ] Radio groups stack vertically on viewports ≤ 640px
- [ ] Breadcrumbs render correctly on IDR show page with valid links
- [ ] Status pills display as full pill shape with color dot on index and show pages
- [ ] Dark theme: all new styles respect `[data-theme="dark"]` CSS variables
- [ ] Mobile: all changes remain usable on 375px-wide screens
- [ ] Existing Stimulus controllers (`report_form_controller`, `spec_drilldown_controller`) still function correctly after markup changes in B1
- [ ] All spacing values in CSS are multiples of 8px (4px acceptable for small elements)
- [ ] No more than 8 distinct font-size values in use across the entire stylesheet
- [ ] Type scale CSS custom properties are defined and referenced consistently
