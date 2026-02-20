# frozen_string_literal: true

module CanonicalLog
  module Subscribers
    module ActiveRecord
      def self.subscribe!
        ActiveSupport::Notifications.subscribe('sql.active_record') do |*args|
          event = ActiveSupport::Notifications::Event.new(*args)
          handle(event)
        end
      end

      def self.handle(notification)
        event = Context.current
        return unless event

        payload = notification.payload
        return if %w[SCHEMA CACHE].include?(payload[:name])

        duration_ms = notification.duration
        event.increment(:db_query_count)
        event.increment(:db_total_time_ms, duration_ms.round(2))

        threshold = CanonicalLog.configuration.slow_query_threshold_ms
        return unless duration_ms >= threshold

        event.append(:slow_queries, {
                       sql: payload[:sql],
                       duration_ms: duration_ms.round(2),
                       name: payload[:name]
                     })
      end
    end
  end
end
