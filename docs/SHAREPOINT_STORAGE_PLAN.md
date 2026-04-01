# Plan: SharePoint Photo Storage Integration

## TL;DR
Replace local-disk ActiveStorage photo handling with Microsoft SharePoint Document Library via the Microsoft Graph API. This fixes two problems: (1) photos can't persist on Azure App Service's ephemeral filesystem, and (2) the DOCX exporter crashes when photo blobs are missing. A new `SharePointPhotoService` will handle upload/download/delete through Graph API, with the app authenticating via Entra ID (Azure AD) app registration.

---

## Phase 1: Fix Immediate Offline Storage Bug

**Goal**: Fix the `TypeError: Cannot convert undefined or null to object` in `populateForm` that prevents saving reports with photo attachments.

1. **Add null guard in `populateForm()`** — `app/javascript/controllers/offline_storage_controller.js` ~line 352. Wrap `Object.keys(data)` with a check: `if (!data) return;`
2. **Fix `formDataToObject()` to skip File objects** — ~line 360. When iterating FormData entries, skip values that are `File` instances (they can't be serialized to IndexedDB). Photo files should instead go through the existing `savePhoto()` method which properly Base64-encodes them.
3. **Wire up photo saving during draft save** — In `saveDraft()` ~line 101, extract file inputs from the form and call `savePhoto()` for each, storing the returned IDs alongside the draft data so `loadDraft()` can re-associate them.

---

## Phase 2: Entra ID (Azure AD) App Registration

**Goal**: Establish server-to-server auth with Microsoft Graph API.

4. **Register an application in Azure Portal → Entra ID → App Registrations**
   - Set redirect URI (not needed for client_credentials flow)
   - Note: Tenant ID, Client ID, Client Secret
5. **Configure API Permissions**:
   - `Sites.ReadWrite.All` (application permission) — upload/download files to SharePoint
   - `Files.ReadWrite.All` (application permission) — manage drive items
   - Grant admin consent
6. **Create a SharePoint Document Library** (if not already existing)
   - Recommended structure: `Photos/{ProjectName}/{ReportDate}_{ReportId}/`
   - This organizes photos by project and report for easy browsing by non-app users
7. **Store credentials in Rails encrypted credentials**:
   - `rails credentials:edit` → add `sharepoint.tenant_id`, `sharepoint.client_id`, `sharepoint.client_secret`, `sharepoint.site_id`, `sharepoint.drive_id`

---

## Phase 3: SharePoint Service Layer

**Goal**: Create a Ruby service that wraps Microsoft Graph API for photo operations.

8. **Add HTTP client gem** — Add `faraday` (or use existing `net/http`) to Gemfile for Graph API requests. No specialized Microsoft gem needed; the REST API is straightforward.
9. **Create `app/services/sharepoint_photo_service.rb`** with these methods:
   - `authenticate` — OAuth2 client_credentials flow → `POST https://login.microsoftonline.com/{tenant}/oauth2/v2.0/token`; cache token until expiry
   - `upload_photo(report, file_io, filename, content_type)` — `PUT https://graph.microsoft.com/v1.0/drives/{driveId}/root:/{path}/{filename}:/content`; returns driveItem metadata (id, webUrl, @microsoft.graph.downloadUrl)
   - `download_photo(drive_item_id)` — `GET https://graph.microsoft.com/v1.0/drives/{driveId}/items/{itemId}/content`; returns binary file data
   - `delete_photo(drive_item_id)` — `DELETE https://graph.microsoft.com/v1.0/drives/{driveId}/items/{itemId}`
   - `photo_url(drive_item_id)` — Fetches a short-lived download URL for displaying in browser
   - Private: `folder_path_for(report)` — Generates path like `Photos/{project_name}/{report_date}_{report_id}/`
   - Private: `ensure_folder_exists(path)` — Creates folder hierarchy if missing via Graph API
10. **Token caching** — Cache the OAuth token in Rails.cache with TTL matching token expiry (~3600s). Re-authenticate automatically on 401 responses.

---

## Phase 4: Database Migration

**Goal**: Track SharePoint metadata alongside existing ReportAttachment records.

11. **Generate migration** `AddSharepointFieldsToReportAttachments`:
    - `sharepoint_item_id` (string, nullable) — Graph API driveItem ID
    - `sharepoint_web_url` (string, nullable) — SharePoint web URL for direct browser access
    - `sharepoint_filename` (string, nullable) — filename as stored in SharePoint
    - Add index on `sharepoint_item_id`
12. **Update `ReportAttachment` model** — Add validations. A record is valid if it has either an ActiveStorage `file` attached OR a `sharepoint_item_id` present (for backward compat during transition).

---

## Phase 5: Modify Photo Upload Flow

**Goal**: Upload photos to SharePoint instead of (or in addition to) local ActiveStorage.

13. **Update `ReportsController#create` and `#update`** — After the report is saved with nested `report_attachments_attributes`, iterate new attachments that have ActiveStorage files attached:
    - Download the blob content
    - Call `SharePointPhotoService.upload_photo(report, blob_data, filename, content_type)`
    - Store returned `sharepoint_item_id` and `sharepoint_web_url` on the ReportAttachment
    - Optionally purge the local ActiveStorage blob (to avoid ephemeral disk issues)
14. **Update DOCX import flow** in `ReportsController#import_docx` (~line 38-49) — After extracting photos from imported DOCX, upload each to SharePoint via the service, storing metadata on the `ImportedReport` or creating `ReportAttachment` records.
15. **Add a `before_destroy` callback on `ReportAttachment`** — Call `SharePointPhotoService.delete_photo(sharepoint_item_id)` to clean up SharePoint when attachments are removed.

---

## Phase 6: Modify Photo Display & Retrieval

**Goal**: Serve photos from SharePoint in views and exports.

16. **Add a proxy endpoint** in `ReportsController` or a new `PhotosController`:
    - `GET /reports/:report_id/photos/:attachment_id`
    - Calls `SharePointPhotoService.download_photo(item_id)`
    - Streams the response with correct content_type and caching headers
    - This avoids exposing SharePoint URLs directly to the browser (security) and handles auth transparently
17. **Update report show view** — `app/views/reports/show.html.erb` ~line 389-410. Replace `image_tag attach.file.representation(...)` with the proxy URL when `sharepoint_item_id` is present; fall back to ActiveStorage for legacy attachments.
18. **Update report form view** — `app/views/reports/_form.html.erb` ~line 446-475. For existing attachments, show thumbnail via the proxy URL instead of ActiveStorage variant.
19. **Update `PythonDocxExporter.extract_photos`** — `app/services/python_docx_exporter.rb` ~line 182-207. When `sharepoint_item_id` is present, download from SharePoint to a temp file instead of calling `attachment.file.download`. The temp file path is passed to Python as before — **no changes needed to the Python export script**.

---

## Phase 7: Offline Photo Sync (Enhancement)

**Goal**: Ensure offline-captured photos eventually reach SharePoint.

20. **Offline flow remains the same** — Photos captured offline are stored as Base64 in IndexedDB via `savePhoto()`. No changes needed to the offline capture UX.
21. **Update `syncPendingReports()`** — When syncing, include photo data in the POST body (or use FormData with files). The server-side controller receives them and uploads to SharePoint as part of the normal upload flow (Step 13).
22. **Fix photo association during sync** — Currently the sync sends JSON but doesn't include photos. Convert to `FormData` multipart upload that includes both report data and photo files.

---

## Phase 8: Seeds & Existing Data

**Goal**: Clean up seeds and handle migration of any existing data.

23. **Update seeds** — Remove or guard any photo-attachment expectations. Currently seeds only set `photos_taken` checklist answers (no actual files are attached), so the main fix is ensuring the exporter gracefully handles reports with zero photo attachments (it already does via `.compact` in `extract_photos`).
24. **Create a rake task** `rails sharepoint:migrate_photos` — For any existing ActiveStorage photo blobs, upload them to SharePoint and populate the new `sharepoint_item_id` fields. This is a one-time migration task.

---

## Relevant Files

| File | Purpose |
|------|---------|
| `app/javascript/controllers/offline_storage_controller.js` | Fix `populateForm` null guard; fix `formDataToObject` File handling; update sync to include photos |
| `app/services/python_docx_exporter.rb` | Update `extract_photos` to download from SharePoint (~L182-207) |
| `app/controllers/reports_controller.rb` | Upload photos to SharePoint on create/update (~L737 params, create/update actions) |
| `app/models/report_attachment.rb` | Add SharePoint field validations |
| `app/views/reports/show.html.erb` | Update photo display (~L389-410) |
| `app/views/reports/_form.html.erb` | Update photo preview (~L446-475) |
| `config/storage.yml` | Reference only (no changes needed if bypassing ActiveStorage for photos) |
| `config/routes.rb` | Add photo proxy route |
| `db/seeds.rb` | Verify no actual photo files expected |
| **NEW**: `app/services/sharepoint_photo_service.rb` | Core SharePoint Graph API integration |
| **NEW**: `db/migrate/XXX_add_sharepoint_fields_to_report_attachments.rb` | Database migration for SharePoint metadata |

---

## Verification

1. **Unit tests for `SharePointPhotoService`** — Mock Graph API responses; test upload returns item_id, download returns binary, delete removes, auth token caches and refreshes
2. **Integration test: photo upload cycle** — Upload a photo via the report form → verify SharePoint metadata saved on ReportAttachment → view report show page → verify photo displays via proxy
3. **Integration test: DOCX export with SharePoint photos** — Create report with SharePoint-stored photos → trigger export → verify generated DOCX contains embedded images
4. **Offline test** — Capture photo offline → go online → sync → verify photo appears in SharePoint and on report
5. **Manual: Azure deployment** — Deploy to Azure App Service → upload photo → restart app service → verify photos survive (proving ephemeral disk is no longer a dependency)
6. **Manual: SharePoint browsing** — Navigate to SharePoint Document Library → verify photos organized by project/report folder structure

---

## Decisions

- **SharePoint Document Library** over SharePoint List: Document Libraries are designed for file storage, support folder hierarchy, and have better Graph API support for large files
- **Server-side proxy** for photo display: Avoids exposing SharePoint auth tokens or direct URLs to the browser; enables caching and access control
- **Keep ActiveStorage for non-photo files**: ReportExport (DOCX files) and ImportedReport (source DOCX) can continue using ActiveStorage with Azure Blob Storage or local storage — only photo attachments move to SharePoint per employer requirements
- **Client credentials OAuth flow**: Since this is server-to-server (no user login to Microsoft needed), client_credentials is the simplest and most appropriate auth flow
- **Faraday over specialized gem**: The Graph API is simple REST; a lightweight HTTP client avoids heavy dependencies

---

## Further Considerations

1. **Azure Blob Storage as fallback/cache**: Consider caching SharePoint photos in Azure Blob Storage for faster retrieval during exports, since Graph API calls add latency. The ActiveStorage Azure adapter is already templated in `config/storage.yml`. *Recommendation: Start without caching; add if performance is an issue.*
2. **Photo size limits**: SharePoint has a 250MB file upload limit via simple upload, 60MB for the PUT endpoint. For photos > 4MB, the Graph API requires a resumable upload session. *Recommendation: Implement simple upload first (most photos are < 4MB); add resumable upload support if field photos are high-resolution.*
3. **Rate limiting**: Graph API has throttling limits (~10,000 requests per 10 minutes per app). Bulk photo operations (migration rake task, reports with 6 photos) should include retry-with-backoff logic. *Recommendation: Add exponential backoff in the service layer from the start.*
