# frozen_string_literal: true

CanonicalLog.configure do |config|
  # Master on/off switch. Defaults to true in production, false otherwise.
  config.enabled = Rails.env.production?

  # Silence Rails' built-in ActionController/ActionView log output.
  config.suppress_rails_logging = false

  # Shortcut: enable colorized, indented JSON output (sets format to :pretty).
  config.pretty = Rails.env.development?

  # Output format: :json (default), :pretty (colorized JSON), :logfmt (key=value).
  # config.format = :json

  # Where to write log lines. :auto sends JSON to $stdout.
  # config.sinks = :auto

  # Parameter keys replaced with [FILTERED] in params and query strings.
  # config.param_filter_keys = %w[password password_confirmation token secret]

  # Replace literal values in SQL captured as slow queries.
  # config.filter_sql_literals = true

  # Filter sensitive params from the query_string field.
  # config.filter_query_string = true

  # SQL queries slower than this (ms) are captured in slow_queries.
  # config.slow_query_threshold_ms = 100.0

  # Requests slower than this (ms) are always logged, even when sampled out.
  # config.slow_request_threshold_ms = 2000.0

  # Fraction of requests to log (1.0 = all). Errors and slow requests are always kept.
  # config.sample_rate = 1.0

  # Custom sampling: ->(event_hash, config) { true/false }. Overrides sample_rate.
  # config.sampling = nil

  # Number of backtrace lines in structured errors (0 to disable).
  # config.error_backtrace_lines = 5

  # Custom log level: ->(event_hash) { :info/:warn/:error }. Default: 5xx->error, 4xx->warn.
  # config.log_level_resolver = nil

  # Static fields merged into every event.
  # config.default_fields = {}

  # Extract user context from Rack env. Without this, Warden/Devise is auto-detected.
  # config.user_context = ->(env) {
  #   user = env["warden"]&.user
  #   user ? { user_id: user.id } : {}
  # }

  # Hook called with the Event just before emission.
  # config.before_emit = ->(event) {
  #   event.set(:app_version, ENV["APP_VERSION"])
  # }

  # Paths to skip entirely. Strings match by prefix, Regexps by pattern.
  # config.ignored_paths = ["/health", "/assets", %r{\A/packs}]
end
