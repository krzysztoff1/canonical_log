# frozen_string_literal: true

module CanonicalLog
  module Sampling
    # Default sampling: always keep errors and slow requests, sample the rest.
    def self.sample?(event_hash, config)
      status = event_hash[:http_status] || 0
      duration = event_hash[:duration_ms] || 0

      # Always keep errors and slow requests
      return true if status >= 500 || event_hash[:error]
      return true if duration >= config.slow_request_threshold_ms

      rand < config.sample_rate
    end
  end
end
