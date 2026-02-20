# frozen_string_literal: true

module CanonicalLog
  module Integrations
    class Sidekiq
      def call(_job_instance, msg, queue)
        Context.init!
        event = Context.current
        event.add(
          job_class: msg['class'],
          queue: queue,
          jid: msg['jid']
        )

        yield
      rescue Exception => e # rubocop:disable Lint/RescueException
        event&.add(
          error_class: e.class.name,
          error_message: e.message
        )
        raise
      ensure
        emit!
        Context.clear!
      end

      private

      def emit!
        event = Context.current
        return unless event

        config = CanonicalLog.configuration
        config.before_emit&.call(event)
        json = event.to_json

        config.resolved_sinks.each do |sink|
          sink.write(json)
        rescue StandardError => e
          warn "[CanonicalLog] Sink error (#{sink.class}): #{e.message}"
        end
      rescue StandardError => e
        warn "[CanonicalLog] Emit error: #{e.message}"
      end
    end
  end
end
