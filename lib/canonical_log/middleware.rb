# frozen_string_literal: true

require 'uri'

module CanonicalLog
  class Middleware
    def initialize(app)
      @app = app
    end

    def call(env)
      return @app.call(env) if skip?(env)

      Context.init!
      seed_request_fields(env)
      execute_request(env)
    rescue Exception => e # rubocop:disable Lint/RescueException
      Context.current&.add_error(e)
      Context.current&.set(:http_status, 500)
      raise
    ensure
      finalize!
    end

    private

    def skip?(env)
      config = CanonicalLog.configuration
      !config.enabled || config.ignored_path?(env['PATH_INFO'])
    end

    def seed_request_fields(env)
      event = Context.current
      return unless event

      event.add(
        request_id: resolve_request_id(env),
        http_method: env['REQUEST_METHOD'],
        path: env['PATH_INFO'],
        query_string: resolve_query_string(env),
        remote_ip: env['HTTP_X_FORWARDED_FOR'] || env['REMOTE_ADDR'],
        user_agent: env['HTTP_USER_AGENT'],
        content_type: env['CONTENT_TYPE'],
      )

      enrich_trace_context(event)
    end

    def resolve_request_id(env)
      env['action_dispatch.request_id'] || env['HTTP_X_REQUEST_ID'] || SecureRandom.uuid
    end

    def resolve_query_string(env)
      raw = env['QUERY_STRING'].to_s
      return nil if raw.empty?

      CanonicalLog.configuration.filter_query_string ? CanonicalLog.configuration.filtered_query(raw) : raw
    end

    def enrich_trace_context(event)
      return unless defined?(OpenTelemetry::Trace)

      span_context = OpenTelemetry::Trace.current_span.context
      return unless span_context.valid?

      event.add(
        trace_id: span_context.hex_trace_id,
        span_id: span_context.hex_span_id,
      )
    end

    def execute_request(env)
      status, headers, body = @app.call(env)
      Context.current&.set(:http_status, status)
      enrich_user_context(env)
      [status, headers, body]
    end

    def enrich_user_context(env)
      event = Context.current
      return unless event

      config = CanonicalLog.configuration
      if config.user_context
        enrich_from_user_context_proc(env, event, config)
      elsif defined?(Warden::Manager) && env['warden']
        enrich_from_warden(env, event)
      end
    end

    def enrich_from_user_context_proc(env, event, config)
      user_fields = config.user_context.call(env)
      event.add(user_fields) if user_fields.is_a?(Hash)
    rescue StandardError => e
      warn "[CanonicalLog] user_context error: #{e.message}"
    end

    def enrich_from_warden(env, event)
      user = env['warden'].user
      event.context(:user, id: user.try(:id), email: user.try(:email)) if user
    rescue StandardError
      nil
    end

    def finalize!
      emit! if Context.current
      Context.clear!
    end

    def emit!
      event = Context.current
      return unless event

      Emitter.emit!(event)
    end
  end
end
