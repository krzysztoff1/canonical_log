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
        return unless CanonicalLog.configuration.enabled

        event = Context.current
        return unless event

        payload = notification.payload
        event.add(extract_fields(payload))
      end

      def self.extract_fields(payload)
        params = (payload[:params] || {}).except('controller', 'action')
        filtered_params = filter_params(params, CanonicalLog.configuration.param_filter_keys)

        {
          controller: payload[:controller],
          action: payload[:action],
          format: payload[:format],
          params: filtered_params,
          view_runtime_ms: payload[:view_runtime]&.round(2),
          db_runtime_ms: payload[:db_runtime]&.round(2),
        }
      end

      def self.filter_params(params, filter_keys)
        if defined?(ActiveSupport::ParameterFilter)
          ActiveSupport::ParameterFilter.new(filter_keys).filter(params)
        else
          deep_filter(params, filter_keys)
        end
      end

      def self.deep_filter(params, filter_keys)
        params.each_with_object({}) do |(key, value), filtered|
          filtered[key] = if filter_keys.include?(key.to_s)
                            '[FILTERED]'
                          elsif value.is_a?(Hash)
                            deep_filter(value, filter_keys)
                          elsif value.is_a?(Array)
                            value.map { |v| v.is_a?(Hash) ? deep_filter(v, filter_keys) : v }
                          else
                            value
                          end
        end
      end
    end
  end
end
