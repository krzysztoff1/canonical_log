# frozen_string_literal: true

module CanonicalLog
  module RailsLogSuppressor
    SUPPRESSED_SUBSCRIBERS = [
      'ActionController::LogSubscriber',
      'ActionView::LogSubscriber',
      'ActiveRecord::LogSubscriber',
    ].freeze

    def self.suppress!
      suppress_log_subscribers!
      suppress_rack_logger!
    end

    def self.suppress_log_subscribers!
      null_logger = Logger.new(File::NULL)

      ActiveSupport::LogSubscriber.log_subscribers.each do |subscriber|
        next unless SUPPRESSED_SUBSCRIBERS.include?(subscriber.class.name)

        subscriber.logger = null_logger
      end
    end

    def self.suppress_rack_logger!
      return unless defined?(Rails::Rack::Logger)

      Rails::Rack::Logger.prepend(SilentRackLogger)
    end

    # Keeps Rails::Rack::Logger in the middleware stack (preserves tagged logging
    # and request_id setup) but silences its log output.
    module SilentRackLogger
      private

      def started_request_message(_request)
        nil
      end

      def logger
        @logger ||= Logger.new(File::NULL)
      end
    end
  end
end
