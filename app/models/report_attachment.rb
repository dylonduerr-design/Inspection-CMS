class ReportAttachment < ApplicationRecord
  belongs_to :report

  # This replaces the old attachment logic
  has_one_attached :file

  # Validations
  validates :file, presence: true

  # Compress oversized images on upload
  after_commit :compress_image, on: [:create, :update], if: :image_needs_compression?

  # Cache image URLs after they're saved (using local disk cache)
  after_commit :cache_image_url, on: [:create, :update]
  after_commit :invalidate_url_cache, on: :destroy

  private

  def image_needs_compression?
    file.attached? &&
      file.blob.content_type&.start_with?("image/") &&
      file.blob.byte_size > ImageCompressor::MAX_BYTES
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
  ensure
    compressed&.close! if compressed.respond_to?(:close!)
  end

  def cache_image_url
    return unless file.attached?
    return unless file.blob.content_type&.start_with?('image/')

    begin
      blob = file.blob
      signed_url = blob.url(expires_in: 7.days)
      ImageUrlCache.cache_url(id, signed_url, filename: blob.filename.to_s)
    rescue => e
      Rails.logger.error("ReportAttachment: Failed to cache URL for attachment_id=#{id}: #{e.message}")
    end
  end

  def invalidate_url_cache
    ImageUrlCache.invalidate_cache(id)
  end
end