# frozen_string_literal: true

module CanonicalLog
  class Configuration
    attr_accessor :sinks, :param_filter_keys, :slow_query_threshold_ms,
                  :user_context, :before_emit, :ignored_paths,
                  :sample_rate, :slow_request_threshold_ms, :sampling

    def initialize
      @sinks = :auto
      @param_filter_keys = %w[password password_confirmation token secret]
      @slow_query_threshold_ms = 100.0
      @user_context = nil
      @before_emit = nil
      @ignored_paths = []
      @sample_rate = 1.0            # Log everything by default
      @slow_request_threshold_ms = 2000.0
      @sampling = nil               # Custom sampling proc, receives (event_hash, config) -> bool
    end

    def resolved_sinks
      case @sinks
      when :auto
        [CanonicalLog::Sinks::Stdout.new]
      when Array
        @sinks
      else
        [@sinks]
      end
    end

    def should_sample?(event_hash)
      if @sampling
        @sampling.call(event_hash, self)
      elsif @sample_rate >= 1.0
        true
      else
        Sampling.default(event_hash, self)
      end
    end
  end
end
