if defined?(Rack::MiniProfiler)
  # Keep profiler installed but off by default to avoid UI overlays in normal dev flow.
  Rack::MiniProfiler.config.enabled = ENV["ENABLE_RACK_MINI_PROFILER"] == "1"
end
