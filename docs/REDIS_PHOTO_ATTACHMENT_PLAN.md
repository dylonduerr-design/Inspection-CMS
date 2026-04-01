# Redis Feasibility For Photo Attachments

## Summary

Redis is not a good primary fix if the requirement is durable photo attachments. The current root cause is that production stores uploads on local disk through Active Storage, and the export flow reads those attachments back during DOCX generation. Redis is already appropriate in this app for Sidekiq and ActionCable, but it is only suitable here as a temporary staging layer.

Under the current constraint of staying on the existing host plus Redis only, the feasible approach is an ephemeral workflow, not true persistent storage.

## Feasibility Decision

- Feasible: use Redis to hold uploaded photo bytes briefly so a report can be exported shortly after save.
- Not feasible: use Redis as a durable attachment store for reopening old reports, surviving Redis restarts, or keeping exports available long-term.
- Practical conclusion: if users need photos and exported DOCX files to remain available over time, the hosting/storage constraint has to change.

## Root Cause In Current Application

- Production uses local Active Storage in [config/environments/production.rb](config/environments/production.rb).
- Storage backends are defined in [config/storage.yml](config/storage.yml), and the active production path is local disk.
- Report photos are attached through [app/models/report_attachment.rb](app/models/report_attachment.rb).
- The Word export pipeline in [app/services/python_docx_exporter.rb](app/services/python_docx_exporter.rb) reads attachment bytes and writes them to temporary files for Python processing.
- Redis is already configured for background jobs and realtime progress in [config/initializers/sidekiq.rb](config/initializers/sidekiq.rb) and [config/cable.yml](config/cable.yml).

## Recommended Scope Under Redis-Only Constraint

Treat Redis as a short-lived staging area for uploaded photos and generated exports.

That means:

- Photos can exist long enough to save and export a report.
- Exports can be downloaded for a short time after generation.
- Old reports cannot reliably keep their photos forever.
- Redis restarts or key expiry can invalidate pending photos and exports.

If that behavior is not acceptable, Redis-only should be rejected.

## Implementation Plan

### 1. Confirm Constraint Boundary

Validate that the hosting environment does not offer any persistent mounted volume and that external object storage is out of scope. If a persistent volume is available, use that before Redis.

### 2. Introduce A Storage Abstraction

Separate report photo persistence from the current direct dependency on Active Storage blobs.

The abstraction should support:

- write
- read
- delete
- exists
- refresh_ttl
- list_for_report

This keeps the rest of the app insulated from backend changes.

### 3. Keep Existing Behavior In Development And Test

Retain the current Active Storage path in development and test so existing workflows continue to work locally. The Redis-backed path should be production-specific for the constrained environment.

### 4. Add A Redis-Backed Temporary Photo Store

Store photo payloads in Redis with metadata such as:

- report id
- attachment id or temporary key
- filename
- content type
- caption
- byte size
- checksum
- upload timestamp
- expiration timestamp

Use per-report key namespaces so cleanup and export lookup stay simple.

### 5. Enforce Size And Count Limits

Add hard limits for:

- maximum number of photos per report
- maximum bytes per photo
- maximum total bytes per report
- TTL duration for staged photos

Without these limits, Redis memory becomes the new operational failure point.

### 6. Update Report Save Flows

Modify the report create and update paths so uploaded photos write through the storage abstraction instead of assuming local disk persistence in production.

This work will mainly touch:

- [app/controllers/reports_controller.rb](app/controllers/reports_controller.rb)
- [app/models/report_attachment.rb](app/models/report_attachment.rb)

Attachment metadata can still remain in the database so captions and ordering survive even if the file backend is abstracted.

### 7. Update Export Generation

Modify [app/services/python_docx_exporter.rb](app/services/python_docx_exporter.rb) so exports read photo bytes from the storage abstraction.

The exporter should still materialize local temporary files during the job because the Python DOCX tooling expects file paths, but those temp files should be derived from Redis data at export time rather than local persistent storage.

When an export starts:

- validate all photo keys exist
- refresh photo TTLs so they do not expire mid-job
- fail fast with a clear message if keys are missing

### 8. Decide Export Artifact Behavior

Do not promise long-term storage of generated DOCX files under Redis-only constraints.

Recommended behavior:

- generate DOCX in the background job
- store it in Redis briefly with a short TTL
- expose a short-lived download endpoint
- prompt the user to download promptly

If later downloads are required, Redis-only is the wrong design.

### 9. Add Expiration And Failure Handling

If a photo or export has expired, surface an explicit user-facing status such as:

> Photos expired. Re-upload required before export.

Avoid generic missing-file or blob-not-found failures.

### 10. Add Operational Safeguards

Add monitoring and logging for:

- Redis memory usage
- staged photo count
- export count
- expired-key failures
- Redis connectivity failures

Sidekiq retries should not endlessly retry exports whose photo payloads have already expired.

### 11. Update The UI

The product behavior must reflect the storage model.

Users should be told that:

- photo attachments are temporary in the hosted environment
- exports must be downloaded soon after generation
- expired photos require re-upload before export

### 12. Verify End-To-End Behavior

Test at least the following:

1. Save a report with photos and export it before TTL expiry.
2. Allow TTL expiry and confirm the app shows a clear expiration message.
3. Restart Redis and confirm the app fails in a clear, recoverable way.
4. Measure Redis memory usage with realistic image sizes.
5. Regression-test normal report save and export behavior without photos.

## Key Files Affected

- [config/environments/production.rb](config/environments/production.rb)
- [config/storage.yml](config/storage.yml)
- [app/controllers/reports_controller.rb](app/controllers/reports_controller.rb)
- [app/models/report_attachment.rb](app/models/report_attachment.rb)
- [app/services/python_docx_exporter.rb](app/services/python_docx_exporter.rb)
- [app/jobs/report_export_job.rb](app/jobs/report_export_job.rb)
- [app/models/report_export.rb](app/models/report_export.rb)
- [config/initializers/sidekiq.rb](config/initializers/sidekiq.rb)
- [config/cable.yml](config/cable.yml)

## Final Recommendation

Redis should not be treated as persistent photo storage.

It is acceptable only if the business requirement is reduced to a temporary save-and-export workflow. If the application must preserve photo attachments and exported documents over time, the correct solution is durable storage rather than Redis.