# frozen_string_literal: true

module CanonicalLog
  module Emitter
    def self.emit!(event, config = CanonicalLog.configuration)
      config.before_emit&.call(event)
      event_hash = config.default_fields.merge(event.to_h)
      return unless config.should_sample?(event_hash)

      level = config.resolve_log_level(event_hash)
      event_hash[:level] = level.to_s
      event_hash[:message] ||= build_message(event_hash)
      write_to_sinks(event_hash, config, level: level)
    rescue StandardError => e
      warn "[CanonicalLog] Emit error: #{e.message}"
    end

    def self.build_message(event_hash)
      [event_hash[:http_method], event_hash[:path], event_hash[:http_status]].compact.join(' ')
    end

    def self.write_to_sinks(event_hash, config, level: :info)
      json = serialize(event_hash, config)
      config.resolved_sinks.each do |sink|
        sink.write(json, level: level)
      rescue StandardError => e
        warn "[CanonicalLog] Sink error (#{sink.class}): #{e.message}"
      end
    end

    def self.serialize(event_hash, config)
      case config.format
      when :pretty then CanonicalLog::Formatters::Pretty.format(event_hash)
      when :logfmt then CanonicalLog::Formatters::Logfmt.format(event_hash)
      else event_hash.to_json
      end
    end

    private_class_method :build_message, :write_to_sinks, :serialize
  end
end
