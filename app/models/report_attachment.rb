class ReportAttachment < ApplicationRecord
  belongs_to :report

  # This replaces the old attachment logic
  has_one_attached :file

  # Validations
  validates :file, presence: true

  # Cache image URLs after they're saved (using local disk cache)
  after_commit :cache_image_url, on: [:create, :update]
  after_commit :invalidate_url_cache, on: :destroy

  private

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