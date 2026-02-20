# frozen_string_literal: true

module CanonicalLog
  module Sinks
    # Duck-type interface for sinks.
    # Any object responding to #write(json_string) can be used as a sink.
    class Base
      def write(json_string)
        raise NotImplementedError, "#{self.class} must implement #write"
      end
    end
  end
end
