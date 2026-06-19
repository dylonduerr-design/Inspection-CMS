# frozen_string_literal: true

# Compresses an ActiveStorage image blob to fit under MAX_BYTES.
# Strips EXIF metadata, caps dimensions, and progressively lowers
# JPEG quality using binary search until the target size is reached.
# Returns a Tempfile with the compressed image, or nil if no compression needed.
class ImageCompressor
  MAX_BYTES = 3.megabytes
  MAX_DIMENSION = 4096
  JPEG_QUALITY_START = 92
  JPEG_QUALITY_FLOOR = 75

  def self.compress(blob)
    return nil unless blob.content_type&.start_with?("image/")
    return nil if blob.byte_size <= MAX_BYTES

    source = download_to_tempfile(blob)
    result = process(source, blob.content_type)
    source.close!
    result
  rescue => e
    Rails.logger.error("ImageCompressor: Failed to compress blob #{blob.id}: #{e.message}")
    nil
  end

  private_class_method def self.download_to_tempfile(blob)
    ext = File.extname(blob.filename.to_s).presence || ".jpg"
    tmp = Tempfile.new(["compress", ext])
    tmp.binmode
    blob.download { |chunk| tmp.write(chunk) }
    tmp.rewind
    tmp
  end

  private_class_method def self.process(source, content_type)
    low = JPEG_QUALITY_FLOOR
    high = JPEG_QUALITY_START
    best_result = nil
    convert_to_jpeg = !content_type.in?(%w[image/jpeg image/jpg])

    while low <= high
      quality = (low + high) / 2
      pipeline = ImageProcessing::MiniMagick
        .source(source.path)
        .resize_to_limit(MAX_DIMENSION, MAX_DIMENSION)
        .strip
        .saver(quality: quality)

      result = convert_to_jpeg ? pipeline.convert("jpeg").call : pipeline.call
      result_size = File.size(result.path)

      if result_size <= MAX_BYTES
        cleanup_tempfile(best_result)
        best_result = result
        low = quality + 1
      else
        cleanup_tempfile(result)
        high = quality - 1
      end
    end

    return best_result if best_result

    # If nothing fits under MAX_BYTES, return the floor-quality output.
    floor_pipeline = ImageProcessing::MiniMagick
      .source(source.path)
      .resize_to_limit(MAX_DIMENSION, MAX_DIMENSION)
      .strip
      .saver(quality: JPEG_QUALITY_FLOOR)

    convert_to_jpeg ? floor_pipeline.convert("jpeg").call : floor_pipeline.call
  end

  private_class_method def self.cleanup_tempfile(tempfile)
    return unless tempfile

    tempfile.close! if tempfile.respond_to?(:close!)
  rescue => _e
    nil
    end
end
