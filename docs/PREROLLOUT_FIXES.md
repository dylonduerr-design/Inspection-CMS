# Pre-Rollout Issue Triage — Ranked by Impact

## TIER 1 — Active Bugs Causing Data Loss or Corruption

### #4 — Only one attachment saved at a time `CRITICAL`

Root cause is **not** a cache issue — `nginx.conf` has no `client_max_body_size` directive, which defaults to **1MB**. Phone photos are 3–8 MB each, so submitting a form with even one uncompressed photo can silently fail with a 413 error. The Rails nested attributes system already supports multiple attachments.

**Fix**: add `client_max_body_size 50M;` to `nginx.conf`. The user's "Fix A" (auto-save per photo) is a UX enhancement, not the root fix. "Fix B" (expand cache) is a red herring.

**Files**: `nginx.conf`

---

### #2 — Weather breaks for overnight shifts `CRITICAL`

The midpoint calculation in `app/javascript/controllers/report_form_controller.js` (lines 232–348) does `Math.round((startHour + endHour) / 2)`. A 22:00–06:00 shift yields hour **14** (2 PM) — completely wrong. The API call also only fetches data for `start_date`, missing next-day hours entirely.

**Fix**: detect overnight (`endHour < startHour`), add 24 for midpoint calculation, fetch two days of hourly data from Open-Meteo.

**Files**: `app/javascript/controllers/report_form_controller.js`

---

### #1 — Weather doesn't update when shift time changes `HIGH`

`autoFetchWeather()` runs once on page load via `connect()`. There are **no event listeners** on the `shift_start`/`shift_end` inputs. Changing shift times does nothing.

**Fix**: add `change` event listeners on both inputs to re-trigger the weather fetch with the new times.

**Files**: `app/javascript/controllers/report_form_controller.js`, `app/views/reports/_form.html.erb`

---

## TIER 2 — Usability Blockers for Field Inspectors

### #3 — Photo compression before upload `HIGH`

No client-side compression exists. Combined with the 1MB nginx limit (#4), mobile uploads are essentially broken. The `image_processing` gem is in the `Gemfile` but only used for display thumbnails, not upload processing.

**Fix**: add client-side JS compression (e.g., `browser-image-compression`) to resize before submission, plus a server-side `image_processing` callback on `ReportAttachment` as a safety net. Must fix #4 first or in parallel.

**Files**: New JS module or updates to `app/javascript/controllers/report_form_controller.js`, `app/models/report_attachment.rb`

---

### #6 — Add delete report button `HIGH`

The `destroy` action exists in the controller (`reports_controller.rb` lines 190–193) and routes are registered, but **no UI button** is exposed. Inspectors with erroneous reports have no recourse.

**Fix**: add a `button_to` with `method: :delete` and a Turbo confirmation dialog to `app/views/reports/show.html.erb`, gated to creator/admin roles. Consider soft-delete (`discarded_at` column) if audit trail matters.

**Files**: `app/views/reports/show.html.erb`, possibly `app/models/report.rb`

---

### #5 — User emails need names `MEDIUM`

The User model has **no name fields** — only `email`. `report.rb` `inspector_name` returns `user.email`, and `inspector_initials` is hardcoded. Both appear in exported Word documents.

**Fix**: migration to add `first_name`/`last_name` to `users` table, update `inspector_name`/`inspector_initials` methods, and ideally auto-populate names from Azure AD claims during SSO login.

**Files**: New migration, `app/models/user.rb`, `app/models/report.rb` (lines 241–248), SSO callback controller

---

## TIER 3 — Data Seeding & Configuration

### #7 — Missing FAA specs and checklists `MEDIUM`

~13 spec items are seeded but P-219 and others are missing. The schema fully supports this — `spec_items` has `checklist_questions` (JSONB) and `bid_items` link to specs per project.

**Fix**: data-only migration or seed update. Requires the project specification documents to enumerate exactly which items and checklist questions to add.

**Files**: `db/seeds.rb` or a new migration file

---

### #10 — Default to correct project `LOW`

`reports_controller.rb` (line 68–70) hardcodes `Project.find_by(name: 'Runway 1R Rehabilitation')`. The desired project name "Runway 1R-19L Rehabilitation & TWY W" doesn't exist in seeds.

**Fix**: rename the project in the DB (migration or seed update) and update the controller lookup string. Better long-term: make it configurable via an environment variable.

**Files**: `db/seeds.rb`, `app/controllers/reports_controller.rb` (line 68–70)

---

### #9 — SoV category for bid items `LOW`

Good news: `sov_category` column **already exists** on `bid_items` (string, indexed). It just needs to be populated.

**Fix**: update seed data to set `sov_category` values per bid item. If a percent-completion tracking view is needed, that is a separate feature build.

**Files**: `db/seeds.rb`

---

## TIER 4 — UX Polish

### #8 — Remind users about 6-photo limit `LOW`

`PHOTO_SLOT_COUNT = 6` is hardcoded in both `app/services/python_docx_exporter.rb` and `python/export_report.py`. Users aren't warned before or after upload.

**Fix**: add a visible note in the attachments section of `app/views/reports/_form.html.erb` (~line 482) and optionally a warning badge when attachment count exceeds 6.

**Files**: `app/views/reports/_form.html.erb`

---

## Further Considerations

1. **#4 and #3 are coupled** — fixing nginx alone lets large files through but doesn't solve slow mobile uploads. Both should ship together.
2. **#6 soft vs. hard delete** — needs stakeholder input. Hard delete is simpler; soft delete (via `discarded_at` column) preserves an audit trail.
3. **#5 Azure AD integration** — if SSO is active, names can be auto-populated from OIDC claims in the OmniAuth callback, avoiding manual data entry entirely.

---

## Verification Checklist

- [ ] **#4**: Upload 3+ phone photos (3 MB each) simultaneously → all persist after save
- [ ] **#2**: Create report with shift 22:00–06:00 → weather slots show correct hours (22:00, 02:00, 06:00)
- [ ] **#1**: Change shift_start from 07:00 to 10:00 → weather auto-refetches for new times
- [ ] **#3**: Upload a 5 MB photo from phone → arrives compressed (< 1 MB) at server
- [ ] **#6**: Delete button visible on report show page → confirm dialog → report removed → redirect to index
- [ ] **#5**: User with name set → export shows "John Smith" not "jsmith@company.com"
- [ ] **#7**: New spec items visible in checklist dropdowns when creating a report
- [ ] **#10**: New report form defaults to "Runway 1R-19L Rehabilitation & TWY W"
- [ ] **#9**: SoV categories populated and visible on bid items
- [ ] **#8**: Warning text visible in attachments section of report form
