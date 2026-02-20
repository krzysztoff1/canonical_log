# frozen_string_literal: true

module CanonicalLog
  module Subscribers
    module ActionController
      def self.subscribe!
        ActiveSupport::Notifications.subscribe('process_action.action_controller') do |*args|
          event = ActiveSupport::Notifications::Event.new(*args)
          handle(event)
        end
      end

      def self.handle(notification)
        event = Context.current
        return unless event

        payload = notification.payload
        config = CanonicalLog.configuration

        params = (payload[:params] || {}).except('controller', 'action')
        filtered_params = filter_params(params, config.param_filter_keys)

        event.add(
          controller: payload[:controller],
          action: payload[:action],
          format: payload[:format],
          params: filtered_params,
          view_runtime_ms: payload[:view_runtime]&.round(2),
          db_runtime_ms: payload[:db_runtime]&.round(2)
        )
      end

      def self.filter_params(params, filter_keys)
        params.each_with_object({}) do |(key, value), filtered|
          filtered[key] = if filter_keys.include?(key.to_s)
                            '[FILTERED]'
                          elsif value.is_a?(Hash)
                            filter_params(value, filter_keys)
                          else
                            value
                          end
        end
      end
    end
  end
end
