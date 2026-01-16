# FIXME

- Development saves currently fail if Redis is down because ActiveStorage enqueues `AnalyzeJob` to Sidekiq. Temporary workaround applied: in `config/environments/development.rb` we set `config.active_job.queue_adapter = :async`. Revert to Sidekiq once Redis is available in dev, or point to a reachable Redis instance and remove the override.
