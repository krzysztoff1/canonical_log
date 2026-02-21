# frozen_string_literal: true

module CanonicalLog
  class Middleware
    def initialize(app)
      @app = app
    end

    def call(env)
      return @app.call(env) if ignored_path?(env)

      Context.init!
      seed_request_fields(env)

      status, headers, body = @app.call(env)
      Context.current&.set(:http_status, status)
      enrich_user_context(env)
      [status, headers, body]
    rescue Exception => e # rubocop:disable Lint/RescueException
      Context.current&.add_error(e)
      Context.current&.set(:http_status, 500)
      raise
    ensure
      emit! if Context.current
      Context.clear!
    end

    private

    def seed_request_fields(env)
      event = Context.current
      return unless event

      request_id = env['action_dispatch.request_id'] ||
                   env['HTTP_X_REQUEST_ID'] ||
                   SecureRandom.uuid

      event.add(
        request_id: request_id,
        http_method: env['REQUEST_METHOD'],
        path: env['PATH_INFO'],
        query_string: env['QUERY_STRING'].to_s.empty? ? nil : env['QUERY_STRING'],
        remote_ip: env['HTTP_X_FORWARDED_FOR'] || env['REMOTE_ADDR'],
        user_agent: env['HTTP_USER_AGENT'],
        content_type: env['CONTENT_TYPE']
      )
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

    def emit!
      event = Context.current
      return unless event

      config = CanonicalLog.configuration
      config.before_emit&.call(event)

      event_hash = event.to_h
      return unless config.should_sample?(event_hash)

      event_hash[:message] ||= build_message(event_hash)

      json = event_hash.to_json

      config.resolved_sinks.each do |sink|
        sink.write(json)
      rescue StandardError => e
        warn "[CanonicalLog] Sink error (#{sink.class}): #{e.message}"
      end
    rescue StandardError => e
      warn "[CanonicalLog] Emit error: #{e.message}"
    end

    def build_message(event_hash)
      [event_hash[:http_method], event_hash[:path], event_hash[:http_status]].compact.join(' ')
    end

    def ignored_path?(env)
      path = env['PATH_INFO']
      CanonicalLog.configuration.ignored_paths.any? do |pattern|
        case pattern
        when Regexp then pattern.match?(path)
        when String then path.start_with?(pattern)
        end
      end
    end
  end
end
