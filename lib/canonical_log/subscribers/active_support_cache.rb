# frozen_string_literal: true

module CanonicalLog
  module Subscribers
    module ActiveSupportCache
      EVENTS = [
        'cache_read.active_support',
        'cache_write.active_support',
        'cache_fetch_hit.active_support',
      ].freeze

      def self.subscribe!
        EVENTS.each do |event_name|
          ActiveSupport::Notifications.subscribe(event_name) do |*args|
            event = ActiveSupport::Notifications::Event.new(*args)
            handle(event)
          end
        end
      end

      def self.handle(notification)
        return unless CanonicalLog.configuration.enabled

        event = Context.current
        return unless event

        event.increment(:cache_total_time_ms, notification.duration.round(2))
        track_operation(event, notification)
      end

      def self.track_operation(event, notification)
        case notification.name
        when 'cache_read.active_support'
          event.increment(:cache_read_count)
          event.increment(notification.payload[:hit] ? :cache_hit_count : :cache_miss_count)
        when 'cache_write.active_support'
          event.increment(:cache_write_count)
        when 'cache_fetch_hit.active_support'
          event.increment(:cache_read_count)
          event.increment(:cache_hit_count)
        end
      end
      private_class_method :track_operation
    end
  end
end
