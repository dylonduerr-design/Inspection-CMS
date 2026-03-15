# Plan: Improve PWA / Offline System

## TL;DR
The app has a solid offline foundation (service worker, IndexedDB, auto-save for reports), but has several bugs, gaps, and areas for improvement. This plan addresses: critical bugs (IndexedDB version mismatch, incomplete form serialization), missing offline capabilities (project/phase browsing, sync UI), caching improvements, and UX polish.

---

## Current State Summary

**Working well:**
- Service worker with network-first caching and offline fallback page
- IndexedDB with 3 stores: `drafts`, `pendingReports`, `photos`
- Auto-save every 2 seconds on report forms
- Background sync via SW `sync` API
- Heartbeat connection check every 30s to `/health_check`
- PWA manifest, icons, install prompt all functional
- Offline indicator with badge showing pending count

**Bugs Found:**
1. **IndexedDB version mismatch** — `offline_storage_controller.js` opens DB at v2, but `service-worker.js` and `offline_indicator_controller.js` open at v1. When the SW tries to sync in the background and opens the DB at v1, it may open a stale schema or fail silently if the DB was created at v2.
2. **Shallow form serialization** — `formDataToObject()` only parses one level of bracket nesting (`report[title]`), but Rails nested attributes go deeper (`report[weather_attributes][temperature]`). Offline-saved reports may lose nested data.
3. **CSRF token staleness** — Tokens stored at save time may expire before sync. The sync POST (both SW and controller) sends the original token which could be invalid hours/days later.

**Gaps Identified:**
1. No offline browsing for projects/phases (all pages return generic offline.html)
2. No manual sync button (intentionally commented out in MVP)
3. No draft/pending management UI (only badge count)
4. Photos stored as Base64 but NOT included when syncing reports
5. Limited precache list — only `/`, CSS, JS, and offline.html
6. No cache size management or expiration policy
7. No per-page caching of previously visited project/phase pages

---

## Steps

### Phase 1: Fix Critical Bugs

1. **Unify IndexedDB version across all files** — Change `service-worker.js` and `offline_indicator_controller.js` to open the DB at version 2 (matching `offline_storage_controller.js`). This prevents schema mismatch errors during background sync.
   - Files: `public/service-worker.js` (line 160 `openOfflineDB()`), `app/javascript/controllers/offline_indicator_controller.js` (line 113 `openDB()`)

2. **Fix deep nested form serialization** — Rewrite `formDataToObject()` in `offline_storage_controller.js` to handle arbitrary nesting depth for Rails-style `report[a][b][c]` keys. Use a recursive bracket parser or simply store raw `FormData` entries as key-value pairs and reconstruct on sync.
   - File: `app/javascript/controllers/offline_storage_controller.js` (`formDataToObject()` at ~line 350)

3. **Handle stale CSRF tokens** — Before syncing a pending report, fetch a fresh CSRF token from the server (e.g. `HEAD /` to get the meta tag, or add a `/csrf_token` endpoint). Fall back to stored token if fetch fails.
   - Files: `offline_storage_controller.js` (`syncPendingReports()`), `public/service-worker.js` (`syncReport()`)

### Phase 2: Enable Offline Browsing of Projects/Phases

4. **Expand service worker cache strategy for navigation pages** — Add runtime caching for previously visited HTML pages under `/projects/*` and `/phases/*`. When a user visits a project or phase page online, cache the response. On subsequent offline access, serve from cache instead of the generic `offline.html`. *depends on step 1*
   - File: `public/service-worker.js` (fetch event handler)

5. **Add cache expiration / size limits** — Implement a cache eviction policy: limit the runtime cache to ~50 entries using an LRU approach (delete oldest entries when limit exceeded). Add a `max-age` check (e.g. 7 days) to prevent serving very stale content.
   - File: `public/service-worker.js`

6. **Precache key navigation routes** — Extend `PRECACHE_ASSETS` to include the projects index page (`/projects`) so the landing page after login is always available offline.
   - File: `public/service-worker.js` (`PRECACHE_ASSETS` array)

### Phase 3: Silent Auto-Sync & Minimal UI

7. **Auto-sync on reconnection via the offline indicator** — The `offline_indicator_controller` already detects when the server becomes reachable (heartbeat + `online` event). When transitioning from offline→online, it should automatically open IndexedDB, check for pending reports, and sync them silently (no toast unless there's a failure). This centralizes sync triggering in the always-present indicator controller rather than requiring the report form's storage controller to be mounted.
   - Add a `syncPendingReports()` method directly to `offline_indicator_controller.js` that mirrors the logic from `offline_storage_controller.js` (open DB, iterate pendingReports, POST each, delete on success).
   - Call it from `checkConnection()` whenever `isServerReachable` transitions to `true`.
   - Suppress success toasts — only show a brief notification if a sync *fails* after retries.
   - File: `app/javascript/controllers/offline_indicator_controller.js`

8. **Auto-sync on page load** — When the indicator controller `connect()`s (every page navigation), check for pending reports and sync them silently if online. This catches cases where reports were queued offline and the user later opens the app while already online.
   - File: `app/javascript/controllers/offline_indicator_controller.js` (in `connect()`, after `checkPendingSync()`)

9. **Add a subtle global "Sync Now" fallback button** — In the offline indicator, show a small sync icon/button only when `pendingCount > 0`. Clicking it triggers `syncPendingReports()`. This is the *only* manual control; it's a safety net, not the primary sync mechanism.
   - Files: `app/views/layouts/application.html.erb` (add button inside indicator markup), `app/javascript/controllers/offline_indicator_controller.js` (add target + action)

10. **Auto-refresh badge after sync** — After each sync attempt (success or partial), re-run `checkPendingSync()` to update the badge count. When count hits 0, hide the sync button. Listen for `SYNC_SUCCESS` messages from the service worker to also refresh.
    - File: `app/javascript/controllers/offline_indicator_controller.js` *depends on step 7*

11. **Silence non-critical notifications** — Review `offline_storage_controller.js` and `offline_indicator_controller.js` for status toasts/messages. Remove or downgrade to `console.log`:
    - Remove: "Draft saved locally", "No pending reports to sync", "Draft loaded", "Syncing N report(s)..."
    - Keep as subtle/brief: "You are offline" (important context), sync *failure* warnings
    - Keep: "Report saved offline. Will sync when online." (confirms offline submit worked)
    - Files: `offline_storage_controller.js` (`showStatus()` calls), `offline_indicator_controller.js` (`showNotification()` calls)

12. **Keep report form sync button commented out** — The per-form "Sync Now" button stays disabled. Auto-sync and the global indicator button cover this. No change needed.

### Phase 4: Photo Sync & Data Integrity

13. **Include photos when syncing reports** — When `syncPendingReports()` runs, look up associated photos in the `photos` store by `reportId`, attach them as `FormData` (multipart), and POST to `/reports` as a multipart request instead of JSON. Update the server-side `ReportsController#create` to accept both JSON and multipart formats.
    - Files: `offline_storage_controller.js` (`syncPendingReports()`), `public/service-worker.js` (`syncReport()`), `app/controllers/reports_controller.rb`

14. **Add last-write-wins conflict resolution** — When sync receives a 409 Conflict (or the server detects a version mismatch), compare timestamps. If the offline version is newer, force-update. If the server version is newer, discard the offline version and notify the user. Add a `updated_at` timestamp to pending reports and compare during sync.
    - Files: `offline_storage_controller.js`, `reports_controller.rb` (add conflict detection in `create`/`update`)

### Phase 5: Polish & Robustness

15. **Add retry with exponential backoff for failed syncs** — Currently, if a sync POST fails, it just logs an error and moves on. Implement retry logic (3 attempts with 1s/5s/15s delays) before marking a report as failed-to-sync.
    - File: `offline_storage_controller.js` (`syncPendingReports()`)

16. **Show sync failure status to users** — If a report fails to sync after retries, show a persistent warning with the report details and a "Retry" action.
    - Files: `offline_storage_controller.js`, `app/assets/stylesheets/application.css`

17. **Add `scope` to manifest.json** — The PWA manifest is missing the `scope` property. Add `"scope": "/"` to ensure the service worker scope is explicit.
    - File: `public/manifest.json`

18. **Improve `populateForm()` to handle nested data** — The draft restoration function currently uses simple `querySelector('[name="key"]')` which won't work for nested Rails attribute names. Fix to match the improved serialization from step 2.
    - File: `offline_storage_controller.js` (`populateForm()`)

---

## Relevant Files

| File | Role | Steps |
|------|------|-------|
| `public/service-worker.js` | Cache strategy, background sync, DB version | 1, 3, 4, 5, 6, 13 |
| `app/javascript/controllers/offline_storage_controller.js` | Core offline logic: form serialization, CSRF, sync, notifications | 2, 3, 11, 13, 14, 15, 18 |
| `app/javascript/controllers/offline_indicator_controller.js` | DB version, auto-sync on reconnect/page-load, sync button, badge, notifications | 1, 7, 8, 9, 10, 11 |
| `app/views/layouts/application.html.erb` | Global sync button in indicator | 9 |
| `public/manifest.json` | Add scope property | 17 |
| `app/controllers/reports_controller.rb` | Accept multipart sync, conflict detection | 13, 14 |
| `app/assets/stylesheets/application.css` | Sync failure UI styles | 16 |
| `config/routes.rb` | Optional CSRF token endpoint | 3 |

## Verification

1. **IndexedDB version fix** — Open DevTools → Application → IndexedDB, confirm all three consumers (storage controller, indicator, service worker) successfully open DB at v2 without errors
2. **Form serialization** — Create a report offline with nested fields (weather, photos, checklist entries), sync, verify all data arrives intact in the server DB
3. **CSRF token** — Save a report offline, wait >30 min, reconnect, verify sync succeeds (not 422 Unprocessable Entity)
4. **Offline browsing** — Visit a project page, go offline (DevTools → Network → Offline), navigate back to that project page → should load from cache, not show offline.html
5. **Cache limits** — Visit >50 pages, confirm old entries are evicted and cache doesn't grow unbounded
6. **Auto-sync on reconnect** — Save a report offline, re-enable network → reports sync automatically without any user action, badge silently updates to 0
7. **Auto-sync on page load** — Save a report offline, close browser, re-open while online → pending reports sync automatically on first page load
8. **Manual sync fallback** — With pending reports, click the "Sync Now" icon in the offline indicator → syncs and badge updates
9. **Silent UX** — During normal auto-save and sync operations, verify NO toast notifications appear. Only offline→online transition and sync failures produce visible feedback
10. **Photo sync** — Attach a photo while offline, sync report online, verify photo appears on the server-side report
11. **Conflict resolution** — Edit report offline + edit on server, sync → last-write-wins by timestamp
12. **Retry logic** — Simulate intermittent network → retries succeed or shows failure UI

## Decisions

- **Scope**: Only projects/phases get offline browsing (not weekly reports, checklists, or other form types). Report form remains the only offline-editable form.
- **Draft UI**: Minimal — badge count + global sync button. No full draft manager dashboard.
- **Conflict strategy**: Last-write-wins by timestamp, no side-by-side merge UI.
- **CSRF approach**: Prefer fetching a fresh token over adding a dedicated endpoint; fall back to stored token.
- **Photo format**: Switch from Base64 in IndexedDB to Blob storage if photo sizes become a concern (deferred).

## Further Considerations

1. **Storage quota monitoring** — Browsers limit IndexedDB/Cache storage (~50-100MB typically). Consider adding quota detection via `navigator.storage.estimate()` and warning users when storage is running low. Recommend for Phase 5 but not critical for initial improvement.
2. **Periodic Sync API** — Chrome supports `periodicSync` for background data freshening. Could be used to keep project/phase data current even when app isn't actively open. Low priority, Chrome-only.
3. **Workbox migration** — Google's Workbox library provides battle-tested caching strategies, precaching manifest generation, and background sync with retry. Could replace the hand-rolled service worker with less code and better reliability. Trade-off: adds a build-time dependency to a currently importmap-based app.
