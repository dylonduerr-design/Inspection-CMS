redis_config = {
  url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"),
  # Azure Redis requires SSL verification
  ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE } # Azure manages certs
}

Sidekiq.configure_server do |config|
  config.redis = redis_config
end

Sidekiq.configure_client do |config|
  config.redis = redis_config
end
