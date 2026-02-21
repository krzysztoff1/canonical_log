# frozen_string_literal: true

require 'json'
require 'time'

module CanonicalLog
  class Event
    CATEGORIES = %i[user business infra service].freeze

    def initialize
      @fields = {}
      @categories = {}
      @mutex = Mutex.new
      @started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def add(hash)
      @mutex.synchronize do
        @fields.merge!(hash)
      end
    end

    def set(key, value)
      @mutex.synchronize do
        @fields[key.to_sym] = value
      end
    end

    def increment(key, by = 1)
      @mutex.synchronize do
        @fields[key.to_sym] = (@fields[key.to_sym] || 0) + by
      end
    end

    def append(key, value)
      @mutex.synchronize do
        @fields[key.to_sym] ||= []
        @fields[key.to_sym] << value
      end
    end

    # Categorized context: event.context(:user, id: 123, tier: "premium")
    def context(category, data)
      raise ArgumentError, "Unknown category: #{category}" unless CATEGORIES.include?(category.to_sym)

      @mutex.synchronize do
        @categories[category.to_sym] ||= {}
        @categories[category.to_sym].merge!(data)
      end
    end

    # Structured error capture
    def add_error(error, metadata = {})
      @mutex.synchronize do
        @fields[:error] = {
          class: error.class.name,
          message: error.message
        }.merge(metadata)
      end
    end

    def duration_ms
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - @started_at
      (elapsed * 1000).round(2)
    end

    def to_h
      @mutex.synchronize do
        result = { timestamp: Time.now.utc.iso8601(3), duration_ms: duration_ms }
        result.merge!(@fields)
        @categories.each { |cat, data| result[cat] = data unless data.empty? }
        result
      end
    end

    def to_json(*_args)
      to_h.to_json
    end
  end
end
