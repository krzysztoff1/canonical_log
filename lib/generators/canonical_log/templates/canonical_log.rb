# frozen_string_literal: true

CanonicalLog.configure do |config|
  # Sinks determine where the canonical log line is written.
  # :auto uses RailsLogger in development, Stdout in production.
  # config.sinks = :auto
  # config.sinks = [CanonicalLog::Sinks::Stdout.new]
  # config.sinks = [CanonicalLog::Sinks::RailsLogger.new]

  # Parameter keys to filter from log output (replaced with [FILTERED]).
  # config.param_filter_keys = %w[password password_confirmation token secret]

  # SQL queries slower than this threshold (in ms) are captured individually.
  # config.slow_query_threshold_ms = 100.0

  # Proc to extract user context from the controller notification.
  # Receives an ActiveSupport::Notifications::Event and should return a Hash.
  # config.user_context = ->(notification) {
  #   controller = notification.payload[:headers]&.env&.dig("action_controller.instance")
  #   if controller&.respond_to?(:current_user) && controller.current_user
  #     { user_id: controller.current_user.id }
  #   else
  #     {}
  #   end
  # }

  # Hook called with the Event just before it is serialized and emitted.
  # config.before_emit = ->(event) {
  #   event.set(:app_version, ENV["APP_VERSION"])
  # }

  # Paths to ignore (no canonical log line will be emitted).
  # Supports strings (prefix match) and regexps.
  # config.ignored_paths = ["/health", "/assets", %r{\A/packs}]
end
