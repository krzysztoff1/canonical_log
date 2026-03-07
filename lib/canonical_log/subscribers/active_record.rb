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
        return unless CanonicalLog.configuration.enabled
        event = Context.current
        return unless event
        payload = notification.payload
        return if ['SCHEMA', 'CACHE'].include?(payload[:name])

        track_query_metrics(event, notification.duration)
        capture_slow_query(event, notification.duration, payload)
      end

      def self.track_query_metrics(event, duration_ms)
        event.increment(:db_query_count)
        event.increment(:db_total_time_ms, duration_ms.round(2))
      end

      def self.capture_slow_query(event, duration_ms, payload)
        threshold = CanonicalLog.configuration.slow_query_threshold_ms
        return unless duration_ms >= threshold

        sql = resolve_sql(payload[:sql])
        event.append(:slow_queries, {
          sql: sql,
          duration_ms: duration_ms.round(2),
          name: payload[:name],
        })
      end

      def self.resolve_sql(raw_sql)
        CanonicalLog.configuration.filter_sql_literals ? SqlSanitizer.sanitize(raw_sql) : raw_sql
      end
    end
  end
end
