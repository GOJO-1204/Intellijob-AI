# Redis location must be set on BOTH sides (Sidekiq wiki, "Using Redis").
# 127.0.0.1, not localhost: localhost tries IPv6 first.
url = ENV.fetch("REDIS_URL", "redis://127.0.0.1:6379/0")

Sidekiq.configure_server do |config|
  config.redis = { url: url }
  # Server only. sidekiq-cron loads this file itself at worker startup
  # and skips it when the file does not exist.
  Sidekiq::Cron.configure do |cron|
    cron.cron_schedule_file = "config/sidekiq_cron.yml"
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: url }
end
