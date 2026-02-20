# frozen_string_literal: true

module CanonicalLog
  module Context
    THREAD_KEY = :canonical_log_event

    def self.init!
      Thread.current[THREAD_KEY] = Event.new
    end

    def self.current
      Thread.current[THREAD_KEY]
    end

    def self.clear!
      Thread.current[THREAD_KEY] = nil
    end
  end
end
