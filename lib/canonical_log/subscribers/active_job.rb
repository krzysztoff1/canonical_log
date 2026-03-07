# frozen_string_literal: true

module CanonicalLog
  module Subscribers
    module ActiveJob
      def self.subscribe!
        ActiveSupport::Notifications.subscribe('perform.active_job') do |*args|
          notification = ActiveSupport::Notifications::Event.new(*args)
          handle(notification)
        end
      end

      def self.handle(notification)
        return unless CanonicalLog.configuration.enabled

        Context.init!
        event = Context.current
        enrich_job_fields(event, notification.payload)
        event.set(:duration_ms, notification.duration.round(2))
        Emitter.emit!(event)
      ensure
        Context.clear!
      end

      def self.enrich_job_fields(event, payload)
        job = payload[:job]
        event.add(
          job_class: job.class.name,
          queue: job.queue_name,
          job_id: job.job_id,
          executions: job.executions,
          priority: job.priority,
        )

        return unless payload[:exception_object]

        event.add(
          error_class: payload[:exception_object].class.name,
          error_message: payload[:exception_object].message,
        )
      end
      private_class_method :enrich_job_fields
    end
  end
end
