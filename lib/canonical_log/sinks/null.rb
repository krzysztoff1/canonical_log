# frozen_string_literal: true

module CanonicalLog
  module Sinks
    class Null < Base
      def write(_json_string)
        # no-op
      end
    end
  end
end
