# frozen_string_literal: true

require 'uri'

module CanonicalLog
  class Configuration
    attr_accessor :sinks, :param_filter_keys, :slow_query_threshold_ms,
                  :user_context, :before_emit, :ignored_paths,
                  :sample_rate, :slow_request_threshold_ms, :sampling,
                  :enabled, :suppress_rails_logging, :format,
                  :filter_sql_literals, :filter_query_string,
                  :log_level_resolver, :default_fields,
                  :error_backtrace_lines

    def initialize
      set_defaults
      set_filter_defaults
    end

    def pretty=(value)
      self.format = value ? :pretty : :json
    end

    def pretty?
      format == :pretty
    end

    def resolve_log_level(event_hash)
      if @log_level_resolver
        @log_level_resolver.call(event_hash)
      else
        status = event_hash[:http_status].to_i
        if event_hash[:error] || status >= 500
          :error
        elsif status >= 400
          :warn
        else
          :info
        end
      end
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
        Sampling.sample?(event_hash, self)
      end
    end

    def ignored_path?(path)
      @ignored_paths.any? do |pattern|
        case pattern
        when Regexp then pattern.match?(path)
        when String then path.start_with?(pattern)
        end
      end
    end

    def filtered_query(query)
      params = URI.decode_www_form(query)
      filtered = params.map do |key, value|
        @param_filter_keys.include?(key) ? [key, '[FILTERED]'] : [key, value]
      end
      URI.encode_www_form(filtered)
    rescue ArgumentError
      query
    end

    private

    def set_defaults
      @sinks = :auto
      @user_context = nil
      @before_emit = nil
      @ignored_paths = []
      @sample_rate = 1.0
      @slow_request_threshold_ms = 2000.0
      @slow_query_threshold_ms = 100.0
      @sampling = nil
      @enabled = defined?(Rails) ? Rails.env.production? : true
      @suppress_rails_logging = false
      @format = :json
      @log_level_resolver = nil
      @default_fields = {}
      @error_backtrace_lines = 5
    end

    def set_filter_defaults
      @param_filter_keys = [
        'password', 'password_confirmation', 'token', 'secret',
        'secret_key', 'api_key', 'access_token', 'credit_card',
        'card_number', 'cvv', 'ssn', 'authorization'
      ]
      @filter_sql_literals = true
      @filter_query_string = true
    end
  end
end
