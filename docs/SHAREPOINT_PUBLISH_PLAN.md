# Plan: SharePoint Publish Step for Finalized Reports

## TL;DR
After a finalized report (`report.status == 'finalize'`) is exported to DOCX, automatically publish the DOCX and photo attachments to a SharePoint Document Library via the Microsoft Graph API. Azure Blob Storage remains the primary file store; SharePoint is a read-only organizational archive destination. The trigger is the existing `ReportExportJob` completion hook.

---

## Phase 1: Azure AD App Registration (Admin Prerequisite)

The existing SSO uses `AZURE_CLIENT_ID` + `AZURE_TENANT_ID` (authorization_code flow). Server-to-server
Graph API requires a **client_credentials** flow — this may reuse the same app registration with
additional application permissions added, or be a separate app registration.

1. In Azure Portal → Entra ID → App Registrations, open (or create) the app registration
   - Add API permission: `Sites.ReadWrite.All` (Application type, not Delegated) — this covers upload to any SharePoint site/library
   - Grant admin consent for the permission
   - Add a client secret (Certificates & Secrets) → copy the value immediately
2. In SharePoint, create a Document Library if not existing:
   - Recommended name: `InspectionDocuments` (no spaces)
   - Folder pattern the app will create: `InspectionDocuments/{project_name}/{YYYY-MM-DD}_Report{id}/`
3. Retrieve `SHAREPOINT_SITE_ID` and `SHAREPOINT_DRIVE_ID` using Graph Explorer or the SharePoint REST endpoint
4. Add new environment variables to production (Azure App Service config):
   - `SHAREPOINT_CLIENT_SECRET` — the app registration client secret (separate from SSO secret)
   - `SHAREPOINT_SITE_ID` — Graph API site identifier
   - `SHAREPOINT_DRIVE_ID` — Document Library drive identifier
   - `SHAREPOINT_LIBRARY_ROOT` — root folder name (default: `InspectionDocuments`)
   - Reuse existing `AZURE_CLIENT_ID` and `AZURE_TENANT_ID`

---

## Phase 2: Database Migration

5. Generate migration `AddSharepointFieldsToReportExports`:
   - `sharepoint_item_id` (string, nullable) — Graph driveItem ID for the uploaded file
   - `sharepoint_web_url` (string, nullable) — Full URL for human-accessible SharePoint link
   - `sharepoint_published_at` (datetime, nullable) — When successfully published
   - `sharepoint_publish_status` (string, default: `'unpublished'`) — values: `unpublished`, `published`, `failed`
   - `sharepoint_publish_error` (text, nullable) — Last failure message

---

## Phase 3: SharepointPublishService

6. Create `app/services/sharepoint_publish_service.rb` with:
   - `publish(export)` — public entry point; downloads blob from Active Storage, calls upload, writes result back to export record
   - `authenticate` — POST to `https://login.microsoftonline.com/{tenant}/oauth2/v2.0/token` with `grant_type=client_credentials`, `scope=https://graph.microsoft.com/.default`. Cache the token in `Rails.cache` under key `"sharepoint_oauth_token"` with TTL from token expiry - 60s buffer.
   - `upload_file(token, folder_path, filename, io)` — PUT to `https://graph.microsoft.com/v1.0/drives/{drive_id}/root:/{folder_path}/{filename}:/content`; returns driveItem JSON with `id` and `webUrl`
   - `ensure_folder(token, folder_path)` — PATCH/POST to create nested folder structure if it doesn't already exist
   - `folder_path_for(export)` — builds `{SHAREPOINT_LIBRARY_ROOT}/{project_name}/{report_date}_Report{report_id}/`; sanitizes project name (strip special chars, collapse spaces to underscores)
   - Use Ruby stdlib `Net::HTTP` (no new gem dependency)
   - Re-authenticate on 401 (clear cache entry, retry once)

---

## Phase 4: SharepointPublishJob

7. Create `app/jobs/sharepoint_publish_job.rb`:
   - `queue_as :default`
   - Finds `ReportExport` by id, returns early if not found or already `published`
   - Calls `SharepointPublishService.new.publish(export)`
   - On success: updates `sharepoint_publish_status: 'published'`, `sharepoint_published_at: Time.current`, `sharepoint_item_id`, `sharepoint_web_url`
   - On failure: updates `sharepoint_publish_status: 'failed'`, `sharepoint_publish_error: e.message`; logs full backtrace
8. **Photo publishing** — within the same job, after the DOCX upload, iterate `report.report_attachments.includes(:file_attachment)`:
   - For each attachment where `attachment.file.attached?`: call `attachment.file.download` (same pattern as `PythonDocxExporter#extract_photos`) and call `service.upload_file(token, folder_path, photo_filename, io)`
   - `photo_filename` built as `"#{index.to_s.rjust(2,'0')}_#{attachment.caption.parameterize.presence || 'photo'}.#{extension}"` — produces meaningful, collision-free names (e.g., `01_concrete_pour.jpg`)
   - Files land in the same SharePoint folder as the DOCX:
     ```
     InspectionDocuments/Highway_101/2026-03-16_Report42/
       ├── Report_42_2026-03-16.docx
       ├── 01_concrete_pour.jpg
       └── 02_rebar_placement.jpg
     ```
   - Individual photo upload failures are logged and skipped — a single missing photo does not fail the entire publish

---

## Phase 5: Hook into ReportExportJob

9. In `app/jobs/report_export_job.rb`, after `export.mark_completed!`, add:
   ```ruby
   SharepointPublishJob.perform_later(export.id) if report.finalize?
   ```
   This is the only change to the existing job — minimal, reversible.

---

## Phase 6: UI — SharePoint Link on Report Show

10. In `app/views/reports/show.html.erb`, in the export section:
    - Show a "View in SharePoint" link when `export.sharepoint_publish_status == 'published'` and `export.sharepoint_web_url.present?`
    - Display as a simple anchor tag with `target="_blank"` opening in SharePoint
    - For failed publishes, show a small status badge (e.g., "SharePoint sync failed") visible only to admins/inspectors

---

## Relevant Files

| File | Change |
|---|---|
| `app/jobs/report_export_job.rb` | Add publish hook after `mark_completed!` (1 line) |
| `app/jobs/sharepoint_publish_job.rb` | **New file** |
| `app/services/sharepoint_publish_service.rb` | **New file** |
| `db/migrate/TIMESTAMP_add_sharepoint_fields_to_report_exports.rb` | **New migration** |
| `app/models/report_export.rb` | Add scopes/methods for `sharepoint_publish_status` if needed |
| `app/views/reports/show.html.erb` | Add SharePoint link in export section |
| `.env` / Azure App Service config | Add new env vars |

---

## Verification

1. In staging: set env vars and trigger an export on a `finalized` report → confirm `SharepointPublishJob` enqueues via Sidekiq dashboard
2. Check `Rails.cache.read("sharepoint_oauth_token")` confirms token is cached
3. Confirm the DOCX appears in the correct SharePoint folder with expected filename
4. Confirm photo files appear in the same folder alongside the DOCX
5. Confirm `report_exports` record shows `sharepoint_publish_status: 'published'` and `sharepoint_web_url` is set
6. Visit the `sharepoint_web_url` in a browser — should open the DOCX in SharePoint preview
7. Trigger a second export of the same report — confirm a new versioned folder is created (keyed by `export.id`)
8. Test failure path: misconfigure `SHAREPOINT_DRIVE_ID` → confirm job logs error and sets `failed` status without breaking the DOCX download

---

## Decisions

- **Trigger**: Only publish when `report.finalize?` — in-progress or review-stage exports are not published
- **Re-publish behavior**: Each export creates a new folder in SharePoint (keyed by `export.id`), so re-exports don't overwrite — each export record has its own independent link
- **HTTP client**: Ruby stdlib `Net::HTTP` — no new gem required
- **Auth model**: App-only `client_credentials` (server-to-server); no user needs to be logged in
- **Env var sharing**: Reuse `AZURE_CLIENT_ID` and `AZURE_TENANT_ID` from SSO setup; add only `SHAREPOINT_CLIENT_SECRET`
- **Photo failures**: Non-fatal — logged and skipped individually, publish status reflects DOCX upload outcome
- **Out of scope**: Deleting from SharePoint when a report is deleted; SharePoint search indexing

---

## Further Considerations

1. **Same app registration vs. separate**: Reusing the SSO app registration saves admin steps, but mixing delegated (SSO) and application (`Sites.ReadWrite.All`) permissions on one registration can raise security review concerns. A separate app registration is cleaner from a least-privilege standpoint.
2. **Large photo sets**: If a report has many high-resolution photos, the publish job may take significant time. Consider a separate `queue_as :low_priority` queue or chunked uploads so the job doesn't block the default queue.
