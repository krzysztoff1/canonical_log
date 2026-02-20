# frozen_string_literal: true

module CanonicalLog
  module Sampling
    # Default sampling: always keep errors and slow requests, sample the rest.
    def self.sample?(event_hash, config)
      status = event_hash[:http_status] || 0
      duration = event_hash[:duration_ms] || 0

      # Always keep errors
      return true if status >= 500
      return true if event_hash[:error]

      # Always keep slow requests
      return true if duration >= config.slow_request_threshold_ms

      # Sample the rest
      rand < config.sample_rate
    end
  end
end
