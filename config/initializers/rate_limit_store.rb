# One shared in memory store for rate limits, so every controller counts in the same place.
# It is per process and starts empty after a restart. Review on Day 15 with hosting.
RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new
