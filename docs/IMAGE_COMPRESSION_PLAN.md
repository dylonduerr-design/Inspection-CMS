# Plan: Automatic Image Compression on Attachment Upload

## Problem

Photo attachments uploaded to reports can exceed size limits. Large images from modern phone cameras (8-12 MB+) bloat Azure storage costs and slow down exports. We want every image automatically compressed to 3 MB or less on upload, without visible quality loss.

## Current State

- `ReportAttachment` uses `has_one_attached :file` (ActiveStorage)
- `image_processing ~> 1.2` gem is already in the Gemfile (provides `ImageProcessing::Vips` and `ImageProcessing::MiniMagick`)
- Storage backends: local disk (dev), Azure Blob (prod)
- Thumbnails are already generated on-the-fly for display via `resize_to_limit` variants
- No compression or size enforcement happens at upload time
- The Word export pipeline (`PythonDocxExporter`) downloads the original blob, so smaller originals = faster exports

## Approach

Compress in an `before_save` / `after_commit` callback on `ReportAttachment`. When a new file is attached (or replaced), check if it's an image over 3 MB — if so, reprocess it and re-attach the compressed version. This is a single-pass operation that replaces the original blob, so downstream code (exports, thumbnails, URL caching) requires zero changes.

### Why not ActiveStorage variants?

Variants are on-the-fly transformations that create *additional* representations — the original blob is kept untouched. That doesn't solve the storage or export size problem. We want to replace the original with a compressed version so every consumer benefits automatically.

## Implementation

### 1. Create `ImageCompressor` service

`app/services/image_compressor.rb`

Single-responsibility service that takes an ActiveStorage blob reference and returns a compressed tempfile if the image exceeds the size threshold.

```ruby
class ImageCompressor
  MAX_BYTES = 3.megabytes
  MAX_DIMENSION = 4096          # longest edge — preserves plenty of detail
  JPEG_QUALITY_START = 92       # first pass quality
  JPEG_QUALITY_FLOOR = 75       # lowest we'll go
  JPEG_QUALITY_STEP = 5         # decrement per pass

  def self.compress(blob)
    return nil unless blob.content_type&.start_with?("image/")
    return nil if blob.byte_size <= MAX_BYTES

    tempfile = download_to_tempfile(blob)
    result = process(tempfile, blob.content_type)
    tempfile.close!
    result
  end

  private

  def self.download_to_tempfile(blob)
    tmp = Tempfile.new(["compress", File.extname(blob.filename.to_s)])
    tmp.binmode
    blob.download { |chunk| tmp.write(chunk) }
    tmp.rewind
    tmp
  end

  def self.process(tempfile, content_type)
    quality = JPEG_QUALITY_START

    loop do
      pipeline = ImageProcessing::MiniMagick
        .source(tempfile.path)
        .resize_to_limit(MAX_DIMENSION, MAX_DIMENSION)
        .strip                           # remove EXIF (saves ~200-500 KB on phone photos)
        .saver(quality: quality)

      # Convert non-JPEG images (PNG screenshots, HEIC) to JPEG for
      # better compression. Skip if already JPEG.
      result = if content_type.in?(%w[image/jpeg image/jpg])
        pipeline.call
      else
        pipeline.convert("jpeg").call
      end

      break result if File.size(result.path) <= MAX_BYTES
      break result if quality <= JPEG_QUALITY_FLOOR

      quality -= JPEG_QUALITY_STEP
    end
  end
end
```

**Key decisions:**
- **Strip EXIF** — phone photos carry 200-500 KB of metadata. Orientation is baked in by MiniMagick's auto-orient (default behavior) before stripping.
- **Cap dimensions at 4096px** — a 4096×3072 JPEG at quality 85 is ~1.5 MB. Most phone photos are 4032×3024, so this is nearly lossless but catches outlier 12K panoramas.
- **Progressive quality reduction** — start at 92 and step down to 75 only if still over 3 MB. In practice, the dimension cap + EXIF strip alone will bring most photos under 3 MB on the first pass.
- **Convert PNG/HEIC → JPEG** — PNGs of real photographs are absurdly large. Converting to JPEG at quality 90 typically gives a 10× size reduction with no perceptible difference.

### 2. Add callback to `ReportAttachment`

```ruby
class ReportAttachment < ApplicationRecord
  # ... existing code ...

  after_commit :compress_image, on: [:create, :update], if: :image_needs_compression?

  private

  def image_needs_compression?
    file.attached? && file.blob.content_type&.start_with?("image/") && file.blob.byte_size > ImageCompressor::MAX_BYTES
  end

  def compress_image
    compressed = ImageCompressor.compress(file.blob)
    return unless compressed

    filename = file.filename.to_s.sub(/\.\w+$/, ".jpg")
    file.attach(
      io: File.open(compressed.path),
      filename: filename,
      content_type: "image/jpeg"
    )

    compressed.close! if compressed.respond_to?(:close!)
  end
end
```

Using `after_commit` ensures the original blob is fully persisted before we reprocess. The `file.attach` call replaces the blob — ActiveStorage handles purging the old one via `has_one_attached`'s default `dependent: :purge_later`.

### 3. Handle the re-attachment loop

The `after_commit` fires on update too, so re-attaching the compressed file would trigger it again. The guard clause `image_needs_compression?` prevents this: after compression the byte_size will be under `MAX_BYTES`, so it short-circuits.

### 4. Update URL cache invalidation

`ReportAttachment` already has `after_commit :invalidate_url_cache, on: [:update, :destroy]`. When we re-attach the compressed image, this fires and clears the stale cached URL. No changes needed — the next access will cache the new URL.

## Files to Change

| File | Change |
|---|---|
| `app/services/image_compressor.rb` | **New.** Compression logic. |
| `app/models/report_attachment.rb` | Add `after_commit :compress_image` callback + guard. |

That's it. No controller, view, route, migration, or export changes.

## Edge Cases

| Scenario | Handling |
|---|---|
| Non-image file (PDF, DOCX) | Guard clause skips — `content_type` check |
| Image already under 3 MB | Guard clause skips — `byte_size` check |
| Corrupt or unreadable image | MiniMagick raises → `compress_image` rescues and logs, original kept as-is |
| PNG screenshot of UI (text-heavy) | Converted to JPEG — may have slight artifacts on hard text edges at quality 75, but screenshots of UIs are rare in field inspection photos |
| HEIC from iPhone | Converted to JPEG — better browser/export compatibility as a bonus |
| Animated GIF | MiniMagick flattens to single frame JPEG — acceptable for inspection reports |

## Testing Checklist

1. Upload a 6 MB JPEG phone photo → verify blob size is under 3 MB after save, image looks fine
2. Upload a 1 MB JPEG → verify it is NOT reprocessed (byte_size unchanged)
3. Upload a 5 MB PNG screenshot → verify converted to JPEG and under 3 MB
4. Upload a PDF document → verify it is untouched
5. Verify the URL cache is invalidated after compression (cached_url returns new signed URL)
6. Verify Word export uses the compressed image (not the original)
7. Verify thumbnail display still works on form and show views

## Optional Enhancement: Background Processing

If synchronous compression adds noticeable latency to report saves (unlikely — MiniMagick processes a 10 MB photo in ~1-2 seconds), move to `ActiveJob`:

```ruby
after_commit :enqueue_compression, on: [:create, :update], if: :image_needs_compression?

def enqueue_compression
  ImageCompressionJob.perform_later(id)
end
```

This adds complexity (the form would briefly show the uncompressed original) so only do it if latency is actually a problem.
