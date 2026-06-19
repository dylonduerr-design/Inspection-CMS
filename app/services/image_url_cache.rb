class ImageUrlCache
  # Cache signed URLs for 6 days (URLs expire after 7 days, cache before that)
  CACHE_EXPIRATION = 6.days

  class << self
    # Cache a signed URL for an attachment
    # @param attachment_id [Integer] the ReportAttachment ID
    # @param signed_url [String] the signed blob URL
    # @param filename [String] original filename
    # @return [Boolean] success status
    def cache_url(attachment_id, signed_url, filename:)
      cache_key = url_cache_key(attachment_id)

      cache_data = {
        url: signed_url,
        filename: filename,
        cached_at: Time.current.iso8601
      }

      Rails.cache.write(cache_key, cache_data, expires_in: CACHE_EXPIRATION)
      Rails.logger.info("ImageUrlCache: Cached URL for attachment_id=#{attachment_id}, filename=#{filename}")

      true
    rescue => e
      Rails.logger.error("ImageUrlCache: Failed to cache URL for attachment_id=#{attachment_id}: #{e.message}")
      false
    end

    # Get cached URL for an attachment
    # @param attachment_id [Integer] the ReportAttachment ID
    # @return [Hash, nil] hash with :url, :filename, :cached_at keys, or nil if not found
    def get_cached_url(attachment_id)
      cache_key = url_cache_key(attachment_id)
      cached_data = Rails.cache.read(cache_key)

      if cached_data
        Rails.logger.info("ImageUrlCache: Retrieved cached URL for attachment_id=#{attachment_id}")
        cached_data.symbolize_keys
      else
        nil
      end
    rescue => e
      Rails.logger.error("ImageUrlCache: Failed to retrieve cached URL for attachment_id=#{attachment_id}: #{e.message}")
      nil
    end

    # Download image from cached URL or generate new URL
    # @param attachment [ReportAttachment] the attachment object
    # @return [String] binary image data
    def fetch_image(attachment)
      # Try cached URL first
      cached_url_data = get_cached_url(attachment.id)

      if cached_url_data && cached_url_data[:url].present?
        begin
          image_data = download_from_url(cached_url_data[:url])
          Rails.logger.info("ImageUrlCache: Downloaded from cached URL for attachment_id=#{attachment.id}, size=#{image_data.bytesize} bytes")
          return image_data
        rescue => e
          Rails.logger.warn("ImageUrlCache: Failed to download from cached URL for attachment_id=#{attachment.id}: #{e.message}, falling back to direct download")
        end
      end

      # Fallback 1: Try generating new URL and downloading
      begin
        Rails.logger.info("ImageUrlCache: Cache miss for attachment_id=#{attachment.id}, generating new URL")
        blob = attachment.file.blob
        signed_url = generate_signed_url(blob)

        # Cache the new URL for future use
        cache_url(attachment.id, signed_url, filename: blob.filename.to_s)

        # Download using the new URL
        image_data = download_from_url(signed_url)
        Rails.logger.info("ImageUrlCache: Downloaded from new URL for attachment_id=#{attachment.id}, size=#{image_data.bytesize} bytes")
        return image_data
      rescue => e
        Rails.logger.warn("ImageUrlCache: Failed to download from URL for attachment_id=#{attachment.id}: #{e.message}, using direct ActiveStorage download")
      end

      # Fallback 2: Direct ActiveStorage download (most reliable)
      Rails.logger.info("ImageUrlCache: Using direct ActiveStorage download for attachment_id=#{attachment.id}")
      attachment.file.download
    end

    # Invalidate cached URL
    # @param attachment_id [Integer] the ReportAttachment ID
    def invalidate_cache(attachment_id)
      cache_key = url_cache_key(attachment_id)
      Rails.cache.delete(cache_key)
      Rails.logger.info("ImageUrlCache: Invalidated cache for attachment_id=#{attachment_id}")
    rescue => e
      Rails.logger.error("ImageUrlCache: Failed to invalidate cache for attachment_id=#{attachment_id}: #{e.message}")
    end

    # Check if URL is cached
    # @param attachment_id [Integer] the ReportAttachment ID
    # @return [Boolean]
    def cached?(attachment_id)
      cache_key = url_cache_key(attachment_id)
      Rails.cache.exist?(cache_key)
    rescue => e
      Rails.logger.error("ImageUrlCache: Failed to check cache for attachment_id=#{attachment_id}: #{e.message}")
      false
    end

    # Get cache statistics for a set of attachment IDs
    # @param attachment_ids [Array<Integer>]
    # @return [Hash] with :cached_count, :total_count, :hit_rate
    def cache_stats(attachment_ids)
      keys = attachment_ids.map { |id| url_cache_key(id) }
      cached_entries = keys.any? ? Rails.cache.read_multi(*keys) : {}
      cached_count = cached_entries.size
      total_count = attachment_ids.size
      hit_rate = total_count > 0 ? (cached_count.to_f / total_count * 100).round(2) : 0.0

      {
        cached_count: cached_count,
        total_count: total_count,
        hit_rate: hit_rate
      }
    end

    private

    def url_cache_key(attachment_id)
      "image_url:#{attachment_id}"
    end

    # Generate a signed URL for a blob
    # @param blob [ActiveStorage::Blob]
    # @return [String] signed URL
    def generate_signed_url(blob)
      # Generate URL that expires in 7 days
      blob.url(expires_in: 7.days)
    end

    # Download image data from a URL
    # @param url [String] the URL to download from
    # @return [String] binary image data
    def download_from_url(url)
      require 'net/http'
      uri = URI.parse(url)

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
        request = Net::HTTP::Get.new(uri.request_uri)
        http.request(request)
      end

      unless response.is_a?(Net::HTTPSuccess)
        raise "Failed to download image: HTTP #{response.code} #{response.message}"
      end

      response.body
    end
  end
end